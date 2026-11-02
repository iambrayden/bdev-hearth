-- SOS / crash / downed alerts on the map, and crash detection.

local alerts = {} -- [id (citizenid of the person in trouble)] = { blip, radius, token }

local ALERT = {
    sos = { label = 'SOS', color = 1 },
    crash = { label = 'Crash', color = 47 },
    downed = { label = 'Needs help', color = 1 },
}

local function removeAlert(id)
    local a = alerts[id]
    if not a then return end
    if DoesBlipExist(a.blip) then RemoveBlip(a.blip) end
    if DoesBlipExist(a.radius) then RemoveBlip(a.radius) end
    alerts[id] = nil
end

RegisterNetEvent('bdev-hearth:client:alert', function(data)
    if type(data) ~= 'table' or not data.x then return end
    local a = ALERT[data.kind] or ALERT.sos
    local id = data.id or ('%s:%s'):format(data.name, GetGameTimer())
    removeAlert(id) -- a new alert from the same person replaces the old blip

    local x, y, z = data.x + 0.0, data.y + 0.0, (data.z or 0.0) + 0.0
    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, a.color)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false)
    SetBlipPriority(blip, 12)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s: %s'):format(a.label, data.name or '?'))
    EndTextCommandSetBlipName(blip)

    local radius = AddBlipForRadius(x, y, z, 60.0)
    SetBlipColour(radius, a.color)
    SetBlipAlpha(radius, 90)

    local token = {}
    alerts[id] = { blip = blip, radius = radius, token = token }
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)

    -- Safety net in case the server's "alert ended" message never arrives.
    SetTimeout(((data.seconds or Config.Alerts.SOSBlipSeconds) + 15) * 1000, function()
        if alerts[id] and alerts[id].token == token then removeAlert(id) end
    end)
end)

-- The server pushes the person's position while the alert is active, so the blip
-- follows them on the pause-menu map and minimap.
RegisterNetEvent('bdev-hearth:client:alertMove', function(id, x, y, z)
    local a = alerts[id]
    if not a or not x then return end
    local pos = vector3(x + 0.0, y + 0.0, (z or 0.0) + 0.0)
    if DoesBlipExist(a.blip) then SetBlipCoords(a.blip, pos.x, pos.y, pos.z) end
    if DoesBlipExist(a.radius) then SetBlipCoords(a.radius, pos.x, pos.y, pos.z) end
end)

RegisterNetEvent('bdev-hearth:client:alertEnd', function(id)
    removeAlert(id)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(alerts) do removeAlert(id) end
end)

---------------------------------------------------------------------
-- Crash detection: a big speed drop while driving fast plus a collision.
-- The server double-checks the player is in a vehicle and applies a cooldown.
---------------------------------------------------------------------
if not Config.Alerts.CrashDetection then return end

CreateThread(function()
    local history = {} -- recent speeds, ~0.6 s window
    while true do
        local veh = cache.vehicle
        if veh and GetPedInVehicleSeat(veh, -1) == cache.ped then
            local speed = GetEntitySpeed(veh)
            history[#history + 1] = speed
            if #history > 3 then table.remove(history, 1) end

            local peak = 0.0
            for _, s in ipairs(history) do peak = math.max(peak, s) end

            if peak >= Config.Alerts.CrashMinSpeed
                and peak - speed >= Config.Alerts.CrashMinDrop
                and HasEntityCollidedWithAnything(veh) then
                TriggerServerEvent('bdev-hearth:server:crash')
                history = {}
                Wait(Config.Alerts.CrashCooldown * 1000)
            end
            Wait(200)
        else
            history = {}
            Wait(1000)
        end
    end
end)
