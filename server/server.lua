src = {}
Tunnel.bindInterface(GetCurrentResourceName(), src)
vCLIENT = Tunnel.getInterface(GetCurrentResourceName())

----------[ VARIABLES ]--------------------------------------------------------------------------------------------------------

-- Cache de dados de missões
local Missions = {}

-- Cache de dados de jogadores
local Players = {}


----------[ SQL ]--------------------------------------------------------------------------------------------------------

vRP._Prepare(GetCurrentResourceName().."/CreateTables_Daily", [[CREATE TABLE IF NOT EXISTS `daily_missions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `available` BOOLEAN NOT NULL DEFAULT TRUE,
  `name` varchar(50) NOT NULL DEFAULT '',
  `reward` int(11) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;]])

vRP._Prepare(GetCurrentResourceName().."/CreateTables_Players", [[CREATE TABLE IF NOT EXISTS `daily_missions_players` (
  `user_id` int(11) NOT NULL,
  `started_missions` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`started_missions`)),
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;]])

vRP._Prepare(GetCurrentResourceName().."/getAllMissions", "SELECT * FROM `daily_missions`")
vRP._Prepare(GetCurrentResourceName().."/getUserMissions", "SELECT * FROM `daily_missions_players` WHERE user_id = @user_id")
vRP._Prepare(GetCurrentResourceName().."/addUserDaily", "INSERT IGNORE INTO daily_missions_players(user_id,started_missions) VALUES(@user_id,@started_missions)")
vRP._Prepare(GetCurrentResourceName().."/updateUserMissions", "UPDATE daily_missions_players SET started_missions = @started_missions WHERE user_id = @user_id")

Citizen.CreateThread(function()
	vRP._Query(GetCurrentResourceName().."/CreateTables_Daily")
	vRP._Query(GetCurrentResourceName().."/CreateTables_Players")

    for k,v in pairs(vRP.Query(GetCurrentResourceName().."/getAllMissions")) do
        Missions[v.id] = {
            available = v.available,
            name = v.name,
            reward = v.reward,
            createAt = v.created_at,
        }
    end
end)

----------[ CODE ]--------------------------------------------------------------------------------------------------------

function src.getMissions()
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return {} end
    return Players:getMissions(Passport)
end

-- @ Obtem todas as missões disponíveis para o jogador
function Players:getMissions(user_id)
    local availableMissions = {}
    local Player = self[user_id]
    if not Player then return {} end

    for id, v in ipairs(Missions) do
        if v.available then
            local started = Player.started_missions[tostring(id)]
            
            v.started = started or false
            v.conclude = started and started.conclude or false
            v.redeemed = started and started.redeemed or false
            
            v.id = id
            table.insert(availableMissions, v)
        end
    end

    return availableMissions
end

-- @ Função chamada ao concluir uma missão
function Players:concludeMission(source, user_id, id)
    local Player = self[user_id]
    if not Player then return end

    local Mission = Missions[tonumber(id)]
    -- Missão não existe
    if not Mission then return end

    -- Missão não disponível
    if not Mission.available then return end

    -- Missão não iniciada
    local completedMission = Player.started_missions[id]
    if not completedMission then return end

    completedMission.conclude = true
    Player.started_missions.mission = nil

    TriggerClientEvent("Notify", source, "verde", "Missão <b>#"..id.."</b> concluída!<br><br>Objetivo: "..Mission.name)

    SendWebhookMessage(Config.webhooks["concludeMission"], "```prolog\n[ID]: "..user_id.."\n[CONCLUIU MISSAO]\n[ID]: "..id.."\n[OBJETIVO]: "..Mission.name..os.date("\n[Data]: %d/%m/%Y [Hora]: %H:%M:%S").." \r```")
end

-- @ Chamada ao iniciar uma missão
function Players:initMission(source, user_id, id)
    local Player = self[user_id]
    if not Player then return end

    local Mission = Missions[tonumber(id)]
    -- Missão não existe
    if not Mission then return end

    -- Missão não disponível
    if not Mission.available then return end

    local startedMissions = Player.started_missions
    -- Missão já iniciada ou finalizada
    if startedMissions[id] then return end

    if startedMissions.mission then
        TriggerClientEvent("Notify", source, "vermelho", "Você já possuí uma missão em andamento.")
        return
    end

    startedMissions.mission = id
    startedMissions[id] = { conclude = false, time = os.time() }

    calculateMission(source, user_id, tonumber(id))

    TriggerClientEvent("Notify", source, "verde", "Missão #"..id.." iniciada.<br><br><b>"..Mission.name.."</b>")

    SendWebhookMessage(Config.webhooks["initMission"], "```prolog\n[ID]: "..user_id.."\n[INICIOU MISSAO]\n[ID]: "..id.."\n[OBJETIVO]: "..Mission.name..os.date("\n[Data]: %d/%m/%Y [Hora]: %H:%M:%S").." \r```")

    return true
end

function src.initMission(id)
    if not id then return end
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return end
    return Players:initMission(source, Passport, id)
end

-- @ Chamada ao resgatar as recompensas de uma missão
local cooldown = {}
function Players:redeemMission(source, user_id, id)
    
    -- Anti-Flood
    if cooldown[source] then
        TriggerClientEvent("Notify", source, "vermelho", "Espere para fazer isso novamente!")
        return { tasks = Players:getMissions(), error = true }
    end
    
    cooldown[source] = true
    Citizen.SetTimeout(500, function () cooldown[source] = false end)

    local Player = self[user_id]
    if not Player then return { tasks = Players:getMissions(), error = true } end

    local Mission = Missions[tonumber(id)]
    -- Missão não existe
    if not Mission then return { tasks = Players:getMissions(), error = true } end

    -- Missão não disponível
    if not Mission.available then return { tasks = Players:getMissions(), error = true } end

    -- Missão não iniciada
    local completedMission = Player.started_missions[id]
    if not completedMission then return { tasks = Players:getMissions(), error = true } end

    -- Missão não concluída
    if not completedMission.conclude then
        TriggerClientEvent("Notify", source, "vermelho", "Você ainda não concluiu esta missão!")
        return { tasks = Players:getMissions(), error = true }
    end

    -- Missão já resgatada
    if completedMission.redeemed then
        TriggerClientEvent("Notify", source, "vermelho", "Você já resgatou a recompensa da missão!")
        return { tasks = Players:getMissions(), error = true }
    end

    -- Missão já resgatada em 24 horas
    if Player.started_missions.redeem and Player.started_missions.redeem > os.time() then
        TriggerClientEvent("Notify", source, "vermelho", "Você já resgatou uma missão hoje! espere "..MinimalTimers(Player.started_missions.redeem - os.time())..".")
        return { tasks = Players:getMissions(), error = true }
    end

    Player.started_missions.redeem = os.time() + 86400
    completedMission.redeemed = true

    vRP._GiveBank(user_id, Mission.reward)

    TriggerClientEvent("Notify", source, "verde", "Você resgatou a recompensa da missão #"..id.."!<br><br>Objetivo: "..Mission.name)

    SendWebhookMessage(Config.webhooks["redeemMission"], "```prolog\n[ID]: "..user_id.."\n[RESGATOU MISSAO]\n[ID]: "..id.."\n[OBJETIVO]: "..Mission.name..os.date("\n[Data]: %d/%m/%Y [Hora]: %H:%M:%S").." \r```")

    return { tasks = Players:getMissions(), error = false }
end

function src.redeemMission(id)
    if not id then return { tasks = Players:getMissions(), error = true } end
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return { tasks = Players:getMissions(), error = true } end
    return Players:redeemMission(source, Passport, id)
end

-- @ Calcula objetivo de cada missão
function calculateMission(source, user_id, id)
    if id == 1 then

        Citizen.CreateThread(function ()
            -- Citizen.Wait(1000 * 60 * 30)
            Citizen.Wait(1000 * 6)

            Players:concludeMission(source, user_id, tostring(id))
        end)

    end
end

-- @ Cria e carrega dados do jogador
function Players:New(source)
    local user_id = vRP.Passport(source)
    if user_id then
        if not self[user_id] then
            local missions = vRP.Query(GetCurrentResourceName().."/getUserMissions", { user_id = user_id })[1]

            if not missions then
                -- Insere novos dados no banco e cria a entrada na tabela
                vRP._Query(GetCurrentResourceName().."/addUserDaily", {
                    user_id = user_id,
                    started_missions = json.encode({}),
                })

                missions = {}
                missions.started_missions = json.encode({})
            end

            missions.started_missions = json.decode(missions.started_missions)

            -- Limpar missões não disponíveis mais
            for k,v in pairs(missions.started_missions) do
                if type(v) == "table" then
                    if not Missions[tonumber(k)].available and not v.redeemed then
                        missions.started_missions[k] = nil
                    end
                end
            end

            self[user_id] = {
                user_id = user_id,
                started_missions = missions.started_missions,
            }
        end
    end
end

-- @Cria e carregar dados do jogador
function Players:Exit(source, user_id)
    local Player = self[user_id]
    if not Player then return end

    local user_id = vRP.Passport(source)
    if user_id then
        vRP._Query(GetCurrentResourceName().."/updateUserMissions", {
            user_id = user_id,
            started_missions = json.encode(Player.started_missions),
        })
    end
end

AddEventHandler("Connect",function(Passport,source)
    Players:New(source)
end)

AddEventHandler("Disconnect",function(Passport,source)
    Players:Exit(source, Passport)
end)


function SendWebhookMessage(webhook, content)
    if webhook ~= nil and webhook ~= "" then
        PerformHttpRequest(webhook, function(err, text, headers) end, "POST", json.encode({content = content}), {["Content-Type"] = "application/json"})
    end
end

function MinimalTimers(Seconds)
	local Hours = math.floor(Seconds / 3600)
	Seconds = Seconds - Hours * 3600
	local Minutes = math.floor(Seconds / 60)

	if Hours > 0 then
		return string.format("%d horas",Hours)
    end

	return string.format("%d minutos",Minutes)
end