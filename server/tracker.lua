-- Server-side location tracking. Positions come from OneSync (GetEntityCoords on the
-- server), never from the client, so a modded client cannot spoof where it is. The client
-- only sends street/zone labels, which need client natives to compute.
Tracker = {
    live = {},       -- [citizenid] = { src, name, x, y, z, speed, driving, street, zone, downed, hasPhone, updated }
    cidOf = {},      -- [src] = citizenid
    srcOf = {},      -- [citizenid] = src
    context = {},    -- [src] = { street, zone }
    phoneCheck = {}, -- [src] = { has = bool, at = time }
    presence = {},   -- [citizenid] = { [placeId] = inside(bool) }
    trail = {},      -- [citizenid] = { {x, y, t}, ... }
}

local dirtyLastSeen = {} -- [citizenid] = true when the position changed since the last DB save

function Tracker.SourceOf(cid)
    return Tracker.srcOf[cid]
end

--- Remember which server id plays which character (also refreshed every tick).
function Tracker.Bind(src, cid)
    if Tracker.cidOf[src] == cid then return end
    Tracker.cidOf[src], Tracker.srcOf[cid] = cid, src
end

function Tracker.ForgetPlace(placeId)
    for _, places in pairs(Tracker.presence) do places[placeId] = nil end
end

function Tracker.ForgetCircle(cid, circle)
    local p = Tracker.presence[cid]
    if not p then return end
    for placeId in pairs(circle.places) do p[placeId] = nil end
end

--- The place a member is currently inside for this circle, if any.
function Tracker.CurrentPlace(cid, circle)
    local p = Tracker.presence[cid]
    if not p then return nil end
    for placeId, place in pairs(circle.places) do
        if p[placeId] then return place end
    end
    return nil
end

local function hasPhone(src, now)
    if not Config.RequirePhoneItem then return true end
    local c = Tracker.phoneCheck[src]
    if not c or now - c.at >= Config.PhoneItemCheckSeconds then
        c = { has = Bridge.HasPhone(src), at = now }
        Tracker.phoneCheck[src] = c
    end
    return c.has
end

local function dist2d(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

---------------------------------------------------------------------
-- Geofences
---------------------------------------------------------------------
local function evaluatePlaces(cid, live)
    local presence = Tracker.presence[cid] or {}
    Tracker.presence[cid] = presence

    for circleId in pairs(Circles.byCitizen[cid] or {}) do
        local circle = Circles.byId[circleId]
        local member = circle.members[cid]
        if member.sharing then
            for placeId, place in pairs(circle.places) do
                local d = dist2d(live.x, live.y, place.x, place.y)
                local was = presence[placeId]
                if was == nil then
                    -- First look at this place (server start, new place, sharing resumed): learn silently.
                    presence[placeId] = d <= place.radius
                elseif not was and d <= place.radius then
                    presence[placeId] = true
                    Circles.Log(circle.id, cid, live.name, 'arrived', { place = place.name })
                elseif was and d > place.radius + Config.Places.ExitBuffer then
                    presence[placeId] = false
                    Circles.Log(circle.id, cid, live.name, 'left', { place = place.name })
                end
            end
        end
    end
end

local function alertCircles(cid, live, kind, message)
    local coords = vector3(live.x, live.y, live.z)
    for circleId in pairs(Circles.byCitizen[cid] or {}) do
        local circle = Circles.byId[circleId]
        if circle.members[cid].sharing then
            Circles.Log(circle.id, cid, live.name, kind, { coords = coords, message = message })
        end
    end
end
Tracker.AlertCircles = alertCircles

---------------------------------------------------------------------
-- Trail
---------------------------------------------------------------------
local function recordTrail(cid, live, now)
    if not Config.History.Enabled then return end
    local trail = Tracker.trail[cid] or {}
    Tracker.trail[cid] = trail
    local last = trail[#trail]
    if not last or (now - last.t >= Config.History.SampleSeconds
            and dist2d(last.x, last.y, live.x, live.y) >= Config.History.MinDistance) then
        trail[#trail + 1] = { x = live.x, y = live.y, t = now }
    end
    local cutoff = now - Config.History.Minutes * 60
    local drop = 0
    while trail[drop + 1] and trail[drop + 1].t < cutoff do drop = drop + 1 end
    if drop > 0 then
        local n = #trail
        table.move(trail, drop + 1, n, 1)
        for i = n - drop + 1, n do trail[i] = nil end
    end
end

function Tracker.Trail(cid)
    local cutoff = os.time() - Config.History.Minutes * 60
    local out = {}
    for _, p in ipairs(Tracker.trail[cid] or {}) do
        if p.t >= cutoff then out[#out + 1] = p end
    end
    local live = Tracker.live[cid]
    if live and live.hasPhone then out[#out + 1] = { x = live.x, y = live.y, t = live.updated } end
    return out
end

---------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------
local function sample(src, cid, now)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local coords = GetEntityCoords(ped)
    local vel = GetEntityVelocity(ped)
    local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)
    local veh = GetVehiclePedIsIn(ped, false)
    local ctx = Tracker.context[src] or {}

    local live = Tracker.live[cid]
    if not live then
        live = { src = src, name = Bridge.GetName(src) }
        Tracker.live[cid] = live
        -- Keep stored member names in sync with the character's name.
        for circleId in pairs(Circles.byCitizen[cid] or {}) do
            local m = Circles.byId[circleId].members[cid]
            if m.name ~= live.name then
                m.name = live.name
                DB.RenameMember(cid, live.name)
            end
        end
    end

    local wasDowned = live.downed
    live.src = src
    live.x, live.y, live.z = coords.x, coords.y, coords.z
    live.speed = speed
    live.driving = veh ~= 0 and speed > Config.DrivingSpeed
    live.street, live.zone = ctx.street, ctx.zone
    live.downed = Bridge.IsDowned(src)
    live.hasPhone = hasPhone(src, now)
    live.updated = now

    if not live.hasPhone then return end
    dirtyLastSeen[cid] = true
    evaluatePlaces(cid, live)
    recordTrail(cid, live, now)

    if Config.Alerts.DownedAlert and live.downed and wasDowned == false then
        alertCircles(cid, live, 'downed')
    end
end

local function saveLastSeen(onlyCids)
    local rows = {}
    for cid in pairs(onlyCids or dirtyLastSeen) do
        local live = Tracker.live[cid]
        if live and live.hasPhone and live.x then
            rows[#rows + 1] = {
                citizenid = cid, x = live.x, y = live.y, z = live.z,
                street = live.street, zone = live.zone, updated_at = live.updated,
            }
        end
    end
    if not onlyCids then dirtyLastSeen = {} end
    DB.SaveLastSeen(rows)
end
Tracker.SaveAll = function() saveLastSeen() end

local function tick()
    local now = os.time()
    local seen = {}

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local cid = Bridge.GetCitizenId(src)
        if cid then
            -- Character switch on the same connection: drop the old character first.
            local prev = Tracker.cidOf[src]
            if prev and prev ~= cid then
                saveLastSeen({ [prev] = true })
                Tracker.live[prev], Tracker.srcOf[prev] = nil, nil
            end
            Tracker.cidOf[src], Tracker.srcOf[cid] = cid, src
            seen[cid] = true
            if Circles.byCitizen[cid] then sample(src, cid, now) end
        end
    end

    -- Players who logged out or dropped: persist their last position, then forget them.
    local gone = {}
    for cid in pairs(Tracker.srcOf) do
        if not seen[cid] then gone[cid] = true end
    end
    if next(gone) then
        saveLastSeen(gone)
        for cid in pairs(gone) do
            local src = Tracker.srcOf[cid]
            Tracker.live[cid], Tracker.srcOf[cid] = nil, nil
            dirtyLastSeen[cid] = nil
            if Tracker.OnLeft then Tracker.OnLeft(cid) end
            if src and Tracker.cidOf[src] == cid then
                Tracker.cidOf[src], Tracker.context[src], Tracker.phoneCheck[src] = nil, nil, nil
            end
        end
    end
end

function Tracker.Start()
    CreateThread(function()
        while true do
            local ok, err = pcall(tick)
            if not ok then print('^1[bdev-hearth] tracker error: ' .. tostring(err) .. '^7') end
            Wait(Config.Location.UpdateSeconds * 1000)
        end
    end)
    CreateThread(function()
        while true do
            Wait(Config.Location.SaveLastSeenSeconds * 1000)
            saveLastSeen()
        end
    end)
end

-- Street / zone labels from the client (they need client-only natives).
RegisterNetEvent('bdev-hearth:server:context', function(street, zone)
    local src = source
    if type(street) ~= 'string' or type(zone) ~= 'string' then return end
    Tracker.context[src] = { street = street:sub(1, 80), zone = zone:sub(1, 80) }
end)

AddEventHandler('playerDropped', function()
    Tracker.context[source], Tracker.phoneCheck[source] = nil, nil
end)
