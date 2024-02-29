fx_version 'cerulean'
game 'gta5'

description 'qbx_vehiclefailure'
repository 'https://github.com/Qbox-project/qbx_vehiclefailure'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

files {
    'locales/*.json'
}

server_script 'server/main.lua'

lua54 'yes'
use_experimental_fxv2_oal 'yes'
