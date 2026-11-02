-- NUI bridge: the phone app page calls these with fetch('https://<resource>/<name>')
-- and each one forwards to the matching server callback.

local function proxy(name, ...)
    local ok, result = pcall(lib.callback.await, 'bdev-hearth:' .. name, false, ...)
    if not ok or type(result) ~= 'table' then
        return { ok = false, error = 'Server did not respond.' }
    end
    return result
end

--- False only when the phone says it is closed (Smartphone V3 IsPhoneOpen export).
local function phoneOpen()
    for _, name in ipairs({ Config.Phone ~= 'auto' and Config.Phone or 'qs-smartphone', 'qs-smartphone-pro' }) do
        if GetResourceState(name) == 'started' then
            local ok, open = pcall(function() return exports[name]:IsPhoneOpen() end)
            if ok and open == false then return false end
            return true
        end
    end
    return true
end

-- The page keeps polling in the background iframe; don't hit the server while the phone is closed.
RegisterNUICallback('getState', function(data, cb)
    if not data.force and not phoneOpen() then return cb({ ok = false, closed = true }) end
    cb(proxy('getState', data.circleId))
end)

RegisterNUICallback('createCircle', function(data, cb) cb(proxy('createCircle', data.name)) end)
RegisterNUICallback('joinCircle', function(data, cb) cb(proxy('joinCircle', data.code)) end)
RegisterNUICallback('leaveCircle', function(data, cb) cb(proxy('leaveCircle', data.circleId)) end)
RegisterNUICallback('deleteCircle', function(data, cb) cb(proxy('deleteCircle', data.circleId)) end)
RegisterNUICallback('renameCircle', function(data, cb) cb(proxy('renameCircle', data.circleId, data.name)) end)
RegisterNUICallback('newInviteCode', function(data, cb) cb(proxy('newInviteCode', data.circleId)) end)
RegisterNUICallback('removeMember', function(data, cb) cb(proxy('removeMember', data.circleId, data.citizenid)) end)
RegisterNUICallback('setFlag', function(data, cb) cb(proxy('setFlag', data.circleId, data.flag, data.value == true)) end)
RegisterNUICallback('invitePhone', function(data, cb) cb(proxy('invitePhone', data.circleId, data.number)) end)

RegisterNUICallback('addPlace', function(data, cb) cb(proxy('addPlace', data.circleId, data.place)) end)
RegisterNUICallback('updatePlace', function(data, cb) cb(proxy('updatePlace', data.circleId, data.placeId, data.place)) end)
RegisterNUICallback('deletePlace', function(data, cb) cb(proxy('deletePlace', data.circleId, data.placeId)) end)

RegisterNUICallback('getTrail', function(data, cb) cb(proxy('getTrail', data.citizenid)) end)
RegisterNUICallback('checkIn', function(data, cb) cb(proxy('checkIn', data.circleId, data.message)) end)
RegisterNUICallback('sos', function(data, cb) cb(proxy('sos', data.message)) end)

RegisterNUICallback('waypoint', function(data, cb)
    local res = proxy('waypointTo', data.citizenid)
    if res.ok then
        SetNewWaypoint(res.x + 0.0, res.y + 0.0)
        lib.notify({ title = Config.App.label, description = 'GPS set', type = 'success' })
    end
    cb(res)
end)

RegisterNUICallback('waypointCoords', function(data, cb)
    local x, y = tonumber(data.x), tonumber(data.y)
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
        lib.notify({ title = Config.App.label, description = 'GPS set', type = 'success' })
    end
    cb({ ok = x ~= nil })
end)

RegisterNUICallback('copy', function(data, cb)
    if type(data.text) == 'string' then
        lib.setClipboard(data.text)
        lib.notify({ title = Config.App.label, description = data.label or 'Copied', type = 'success' })
    end
    cb({ ok = true })
end)

---------------------------------------------------------------------
-- Street / zone labels. Positions themselves are read on the server.
---------------------------------------------------------------------
CreateThread(function()
    local lastStreet, lastZone
    while true do
        if LocalPlayer.state.isLoggedIn ~= false then
            local coords = GetEntityCoords(cache.ped)
            local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local street = GetStreetNameFromHashKey(s1)
            local cross = s2 ~= 0 and GetStreetNameFromHashKey(s2) or nil
            if cross and cross ~= '' then street = ('%s & %s'):format(street, cross) end
            local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
            if zone == 'NULL' then zone = '' end
            if street ~= lastStreet or zone ~= lastZone then
                lastStreet, lastZone = street, zone
                TriggerServerEvent('bdev-hearth:server:context', street, zone)
            end
        end
        Wait(2000)
    end
end)
