fx_version 'cerulean'
game 'gta5'

author 'DevRex'
description 'Hablar con los npcs usando ia'
version '1.0.0'

dependencies {
    'ox_lib',
    'sounity'
}


shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/client.lua'
server_scripts {
    'server/server.lua',
}

files {
    'data/human-peds.json',
}
