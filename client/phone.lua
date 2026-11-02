--[[
    Quasar smartphone integration. This is the ONLY client file that talks to the phone resource.

    Quasar has two phones with different custom-app APIs:
      Smartphone V3  (resource 'qs-smartphone')     addCustomApp({ id, label, icon, iframe = { url }, ... })
                                                    returns ok, errorCode. Docs: quasar-store.com/docs/smartphone/integrations
      Smartphone PRO (resource 'qs-smartphone-pro') addCustomApp({ app, label, ui, image, ... })
    Sending the PRO payload to V3 fails with 'missing_app_id', so the API is detected by what the
    resource exports (only V3 has getCustomApps), not by its folder name.

    The app page (html/index.html) talks to this resource through NUI callbacks (client/main.lua).
    Use /hearthapp in game to re-register the app and print the phone's answer in F8.
]]

local resource = GetCurrentResourceName()
local origin = ('https://cfx-nui-%s'):format(resource)
local base = origin .. '/html/'

local CANDIDATES = { 'qs-smartphone', 'qs-smartphone-pro' }
if Config.Phone ~= 'auto' then CANDIDATES[#CANDIDATES + 1] = Config.Phone end

local registered = false

local function log(msg, ...)
    print(('[bdev-hearth] ' .. msg):format(...))
end

--- Returns the phone resource name and its API flavour ('v3' or 'pro'), or nil.
local function detect()
    local list = Config.Phone == 'auto' and CANDIDATES or { Config.Phone }
    for _, name in ipairs(list) do
        if GetResourceState(name) == 'started' then
            if name ~= 'qs-smartphone-pro' and pcall(function() return exports[name]:getCustomApps() end) then
                return name, 'v3'
            end
            return name, 'pro'
        end
    end
    return nil
end

local function v3Payload()
    local a = Config.App
    return {
        id = a.name,
        label = a.label,
        icon = base .. 'icon.png',
        category = a.category,
        creator = a.creator,
        description = a.description,
        age = a.age,
        appStoreOnly = a.appStoreOnly,
        price = a.price > 0 and a.price or nil,
        sizeMb = 1,
        extraDescription = {},
        iframe = { url = base .. 'index.html' },
        custom = {
            enabled = true,
            bridge = { enabled = true, allowedOrigins = { origin } },
        },
    }
end

local function proPayload()
    local a = Config.App
    return {
        app = a.name,
        label = a.label,
        image = base .. 'icon.png',
        icon = base .. 'icon.png',
        ui = base .. 'index.html',
        job = a.job,
        blockedJobs = a.blockedJobs,
        timeout = 5000,
        creator = a.creator,
        category = a.category:lower(),
        isGame = false,
        description = a.description,
        age = a.age,
        price = a.price,
        extraDescription = {},
    }
end

--- Registers the app with the phone. Returns true on success.
local function register(verbose)
    local phone, api = detect()
    if not phone then
        log('no Quasar phone is running (looked for %s). Start qs-smartphone before this resource.',
            table.concat(Config.Phone == 'auto' and CANDIDATES or { Config.Phone }, ', '))
        return false
    end

    local ok, added, err = pcall(function()
        return exports[phone]:addCustomApp(api == 'v3' and v3Payload() or proPayload())
    end)

    if not ok then
        log('%s:addCustomApp errored (%s API): %s', phone, api, tostring(added))
        return false
    end

    -- V3 returns (ok, errorCode); PRO returns a boolean. An app that is already
    -- registered (e.g. on a second attempt) counts as success.
    if added == false or (added == nil and err) then
        local reason = tostring(err or 'no reason given')
        if reason:lower():find('exist') or reason:lower():find('duplicate') then
            registered = true
            if verbose then log('app already registered with %s', phone) end
            return true
        end
        log('%s refused the app (%s API): %s', phone, api, reason)
        return false
    end

    registered = true
    if verbose or Config.Debug then log('app registered with %s (%s API)', phone, api) end
    return true
end

local function unregister()
    local phone = detect()
    if phone then
        pcall(function() exports[phone]:removeCustomApp(Config.App.name) end)
    end
    registered = false
end

--- Waits for the phone to start, then registers (retries a few times while the phone boots).
local function registerWhenReady()
    CreateThread(function()
        local waited = 0
        while not detect() and waited < 60000 do
            Wait(500)
            waited = waited + 500
        end
        Wait(1000)
        for attempt = 1, 5 do
            if register(attempt == 1 and Config.Debug) then return end
            Wait(3000)
        end
    end)
end

registerWhenReady()

-- Re-register when the phone restarts or the character loads.
AddEventHandler('onClientResourceStart', function(res)
    for _, name in ipairs(CANDIDATES) do
        if res == name then
            registered = false
            registerWhenReady()
            return
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if not registered then registerWhenReady() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == resource then unregister() end
end)

-- Manual re-register + diagnostics (output in F8).
RegisterCommand('hearthapp', function()
    local phone, api = detect()
    log('phone: %s, API: %s', tostring(phone), tostring(api))
    if register(true) then
        lib.notify({ title = Config.App.label, description = 'App registered with the phone', type = 'success' })
    else
        lib.notify({ title = Config.App.label, description = 'Phone refused the app, see F8 console', type = 'error' })
    end
end, false)
