fx_version 'cerulean'
game 'gta5'

author "Striker"
version "1.0"

ui_page_preload "yes"
ui_page "web/index.html"

client_scripts {
	"client/client.lua",
}

server_scripts {
	"shared/server.lua",

	"server/server.lua",
}

shared_scripts {
	"@vrp/lib/Utils.lua",

	"shared/shared.lua",
}

files {
	"web/**",
}