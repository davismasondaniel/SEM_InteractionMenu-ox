lua54 'yes'
dependency 'ox_lib'
dependency 'ox_target'

fx_version 'cerulean'
games { 'gta5' }

title 'SEM_InteractionMenu'
description 'Multi Purpose Interaction Menu'
author 'Scott M [SEM Development]'
version 'v1.7.1'

client_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'functions.lua',
    'client.lua',
    'menu.lua',
}

server_scripts {
    'config.lua',
    '@ox_lib/init.lua',
    'server.lua',
    'functions.lua',
}

exports {
    'IsOndutyLEO',
    'IsOndutyFire',
}
