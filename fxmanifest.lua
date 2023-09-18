fx_version 'cerulean'
game 'gta5'

description 'https://github.com/Qbox-project/qbx-vehiclefailure'
version '1.0.0'

shared_scripts {
    '@qbx-core/import.lua',
    '@ox_lib/init.lua',
    '@qbx-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'

modules {
	'qbx-core:core',
    'qbx-core:utils'
}

lua54 'yes'

use_experimental_fxv2_oal 'yes'