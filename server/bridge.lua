-- Qbox (qbx_core) + Quasar phone bridge. Everything framework- or phone-specific lives here.
Bridge = {}

local qbx = exports.qbx_core

function Bridge.GetCitizenId(src)
    local player = qbx:GetPlayer(src)
    return player and player.PlayerData.citizenid or nil
end

function Bridge.GetName(src)
    local player = qbx:GetPlayer(src)
    if not player then return 'Unknown' end
    local ci = player.PlayerData.charinfo or {}
    local name = ('%s %s'):format(ci.firstname or '', ci.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or 'Unknown'
end

--- True when the character is dead or in last stand (Qbox metadata).
function Bridge.IsDowned(src)
    local player = qbx:GetPlayer(src)
    if not player then return false end
    local meta = player.PlayerData.metadata or {}
    return meta.isdead == true or meta.inlaststand == true
end

--- Whether the player carries a phone item (only used when Config.RequirePhoneItem = true).
function Bridge.HasPhone(src)
    if not Config.RequirePhoneItem then return true end
    if GetResourceState('ox_inventory') ~= 'started' then return true end
    for _, item in ipairs(Config.PhoneItems) do
        local ok, count = pcall(function() return exports.ox_inventory:GetItemCount(src, item) end)
        if ok and (tonumber(count) or 0) > 0 then return true end
    end
    return false
end

---------------------------------------------------------------------
-- Phone
---------------------------------------------------------------------
local PHONES = { 'qs-smartphone', 'qs-smartphone-pro' }

local function activePhone()
    if Config.Phone ~= 'auto' then
        return GetResourceState(Config.Phone) == 'started' and Config.Phone or nil
    end
    for _, name in ipairs(PHONES) do
        if GetResourceState(name) == 'started' then return name end
    end
end

--- Phone push notification (Smartphone V3), ox_lib notification as a fallback.
function Bridge.Notify(src, title, message, kind)
    local phone = activePhone()
    if phone then
        local ok, sent, code = pcall(function()
            return exports[phone]:sendPhoneNotification(src, {
                appId = Config.App.name,
                title = title,
                text = message,
                closeTimeout = 6000,
            })
        end)
        if ok and sent ~= false then return end
        if Config.Debug then
            print(('[bdev-hearth] sendPhoneNotification(%s) failed: %s'):format(src, tostring(ok and code or sent)))
        end
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = title,
        description = message,
        type = kind or 'inform',
        duration = 6000,
    })
end

local function digits(v)
    return (tostring(v or ''):gsub('[^%d]', ''))
end

--- The player's active phone number, or nil.
function Bridge.GetPhoneNumber(src)
    local phone = activePhone()
    if not phone then return nil end
    local ok, number = pcall(function() return exports[phone]:GetCurrentPhoneNumber(src) end)
    if ok and number and digits(number) ~= '' then return tostring(number) end
    return nil
end

--- Server id of the online player whose active number matches, or nil.
--- (Quasar has no number -> character lookup, so this only finds online players.)
function Bridge.FindSourceByPhone(number)
    number = digits(number)
    if number == '' then return nil end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local mine = Bridge.GetPhoneNumber(src)
        if mine and digits(mine) == number then return src end
    end
    return nil
end

--- Sends an in-phone text message from the app. Returns true on success.
function Bridge.SendText(src, message)
    local phone = activePhone()
    if not phone then return false end
    local ok, res = pcall(function()
        return exports[phone]:SendNewMessageFromApp(src, Config.App.label, message)
    end)
    return ok and res ~= false
end
