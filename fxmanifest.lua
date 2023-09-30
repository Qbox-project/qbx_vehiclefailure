fx_version 'cerulean'
game 'gta5'

description 'Vehiclefailure for Qbox'
repository 'https://github.com/Qbox-project/qbx-vehiclefailure'

version '1.0.0'

shared_scripts {
    '@qbx_core/import.lua',
    '@ox_lib/init.lua',
    '@qbx_core/shared/locale.lua',
    'locales/en.lua',
    'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'

modules {
	'qbx_core:playerdata',
    'qbx_core:utils'
}

lua54 'yes'

use_experimental_fxv2_oal 'yes'
