-- SOS / crash / downed alerts on the map, and crash detection.

local alertBlips = {}

local ALERT = {
    sos = { label = 'SOS', color = 1 },
    crash = { label = 'Crash', color = 47 },
    downed = { label = 'Needs help', color = 1 },
}

RegisterNetEvent('bdev-hearth:client:alert', function(data)
    if type(data) ~= 'table' or not data.x then return end
    local a = ALERT[data.kind] or ALERT.sos

    local blip = AddBlipForCoord(data.x + 0.0, data.y + 0.0, (data.z or 0.0) + 0.0)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, a.color)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s: %s'):format(a.label, data.name or '?'))
    EndTextCommandSetBlipName(blip)

    local radius = AddBlipForRadius(data.x + 0.0, data.y + 0.0, (data.z or 0.0) + 0.0, 60.0)
    SetBlipColour(radius, a.color)
    SetBlipAlpha(radius, 90)

    alertBlips[#alertBlips + 1] = { blip, radius }
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)

    SetTimeout(Config.Alerts.SOSBlipSeconds * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        if DoesBlipExist(radius) then RemoveBlip(radius) end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, pair in ipairs(alertBlips) do
        for _, b in ipairs(pair) do
            if DoesBlipExist(b) then RemoveBlip(b) end
        end
    end
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
