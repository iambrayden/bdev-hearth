fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bdev-hearth'
author 'bdev'
description 'Hearth: family & friends location sharing for the Quasar smartphone (Qbox)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/phone.lua',
    'client/main.lua',
    'client/alerts.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/db.lua',
    'server/circles.lua',
    'server/tracker.lua',
    'server/main.lua',
}

-- No ui_page: the phone shows https://cfx-nui-<resource>/html/index.html in an iframe,
-- so every file the page loads must be listed here.
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/mock.js',
    'html/icon.png',
    'html/vendor/leaflet/leaflet.js',
    'html/vendor/leaflet/leaflet.css',
    'html/map/*.webp',
    'html/map/*.jpg',
    'html/map/*.png',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    '/onesync',
}
