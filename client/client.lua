src = {}
Tunnel.bindInterface(GetCurrentResourceName(), src)
vSERVER = Tunnel.getInterface(GetCurrentResourceName())

----------[ NUI ]--------------------------------------------------------------------------------------------------------

-- Desbugar ao reiniciar
Citizen.CreateThread(function()
	SetNuiFocus(false,false)
    TriggerScreenblurFadeOut(500)
end)

-- Callbacks
RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false,false)
    SendNUIMessage({
        hide = true,
    })
    TriggerScreenblurFadeOut(500)
end)

RegisterNUICallback("initMission", function(data, cb)
    cb(vSERVER.initMission(data.id))
end)

RegisterNUICallback("redeemMission", function(data, cb)
    cb(vSERVER.redeemMission(data.id))
end)

-- Abrir UI
RegisterCommand("missions", function(source, args, rawCommand)
    local missions = vSERVER.getMissions()
    if missions then
        SetNuiFocus(true,true)
        SendNUIMessage({
            show = true,
            data = missions,
        })
        TriggerScreenblurFadeIn(500)
    end
end)