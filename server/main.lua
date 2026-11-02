-- Server callbacks used by the phone app (client/main.lua forwards NUI calls here).

local lastAction = {}    -- [src] = GetGameTimer() of last mutating action
local cooldowns = {}     -- [src..kind] = os.time() when the cooldown ends
local lastSeenCache = {} -- [citizenid] = { row = row|false, at = os.time() }

local function err(message) return { ok = false, error = message } end

local function throttled(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < 400 then return true end
    lastAction[src] = now
    return false
end

local function onCooldown(src, kind, seconds)
    local key = src .. ':' .. kind
    local now = os.time()
    if cooldowns[key] and cooldowns[key] > now then return cooldowns[key] - now end
    cooldowns[key] = now + seconds
    return false
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

--- Last-known rows for offline members, cached for 30 seconds so polling stays cheap.
local function lastSeen(cids)
    local now, missing = os.time(), {}
    for _, cid in ipairs(cids) do
        local c = lastSeenCache[cid]
        if not c or now - c.at > 30 then missing[#missing + 1] = cid end
    end
    if #missing > 0 then
        local rows = DB.LastSeen(missing)
        for _, cid in ipairs(missing) do lastSeenCache[cid] = { row = rows[cid] or false, at = now } end
    end
    local out = {}
    for _, cid in ipairs(cids) do
        local row = lastSeenCache[cid] and lastSeenCache[cid].row
        if row then out[cid] = row end
    end
    return out
end

-- A member who just went offline has a fresh row in the database.
function Tracker.OnLeft(cid) lastSeenCache[cid] = nil end

local function round(n) return n and math.floor(n * 10 + 0.5) / 10 or nil end

local function memberView(circle, member, viewerCid, offline)
    local cid = member.citizenid
    local isMe = cid == viewerCid
    local v = {
        citizenid = cid, name = member.name, role = member.role,
        isMe = isMe, sharing = member.sharing, owner = circle.owner == cid,
    }
    if not member.sharing and not isMe then return v end

    local live = Tracker.live[cid]
    if live and live.hasPhone and live.x then
        local place = Tracker.CurrentPlace(cid, circle)
        v.online = true
        v.x, v.y = round(live.x), round(live.y)
        v.street, v.zone = live.street, live.zone
        v.speed = round(live.speed)
        v.driving = live.driving
        v.downed = live.downed
        v.place = place and { id = place.id, name = place.name, icon = place.icon } or nil
        v.updated = live.updated
    else
        v.online = false
        v.noPhone = live ~= nil and not live.hasPhone
        local row = offline[cid]
        if row then
            v.x, v.y = round(row.x), round(row.y)
            v.street, v.zone = row.street, row.zone
            v.updated = row.updated_at
        end
    end
    return v
end

local function settings()
    return {
        speedUnit = Config.SpeedUnit,
        staleSeconds = Config.Location.StaleSeconds,
        refreshMs = Config.UI.RefreshMs,
        places = {
            minRadius = Config.Places.MinRadius,
            maxRadius = Config.Places.MaxRadius,
            defaultRadius = Config.Places.DefaultRadius,
            icons = Config.Places.Icons,
            membersCanEdit = Config.Places.MembersCanEdit,
        },
        history = Config.History.Enabled,
        map = Config.Map,
        maxMembers = Config.Circles.MaxMembers,
        nameMax = Config.Circles.NameMaxLength,
    }
end

local function withCitizen(handler)
    return function(src, ...)
        local cid = Bridge.GetCitizenId(src)
        if not cid then return err('Your character is not loaded yet.') end
        Tracker.Bind(src, cid)
        local ok, result = pcall(handler, src, cid, ...)
        if not ok then
            print('^1[bdev-hearth] callback error: ' .. tostring(result) .. '^7')
            return err('Something went wrong.')
        end
        return result
    end
end

local function mutate(fn)
    return withCitizen(function(src, cid, ...)
        if throttled(src) then return err('Slow down a little.') end
        return fn(src, cid, ...)
    end)
end

local function result(ok, e)
    if ok then return { ok = true } end
    return err(e)
end

---------------------------------------------------------------------
-- State (polled by the open app)
---------------------------------------------------------------------
lib.callback.register('bdev-hearth:getState', withCitizen(function(_, cid, circleId)
    local circles = Circles.ForCitizen(cid)
    local list = {}
    local active
    for _, c in ipairs(circles) do
        list[#list + 1] = { id = c.id, name = c.name, role = c.members[cid].role, members = Circles.count(c.members) }
        if c.id == tonumber(circleId) then active = c end
    end
    active = active or circles[1]

    local out = { ok = true, me = cid, now = os.time(), circles = list, settings = settings() }
    if not active then return out end

    local offlineCids = {}
    for memberCid in pairs(active.members) do
        local live = Tracker.live[memberCid]
        if not (live and live.hasPhone) then offlineCids[#offlineCids + 1] = memberCid end
    end
    local offline = lastSeen(offlineCids)

    local members = {}
    for _, m in pairs(active.members) do members[#members + 1] = memberView(active, m, cid, offline) end
    table.sort(members, function(a, b)
        if a.isMe ~= b.isMe then return a.isMe end
        return a.name < b.name
    end)

    local places = {}
    for _, p in pairs(active.places) do
        places[#places + 1] = {
            id = p.id, name = p.name, icon = p.icon, x = round(p.x), y = round(p.y), radius = p.radius,
            mine = p.created_by == cid,
        }
    end
    table.sort(places, function(a, b) return a.name < b.name end)

    local self = active.members[cid]
    out.circle = {
        id = active.id, name = active.name, code = active.code,
        isAdmin = self.role == 'admin',
        sharing = self.sharing, notify = self.notify,
        members = members, places = places,
        events = Circles.Events(active.id),
    }
    return out
end))

---------------------------------------------------------------------
-- Circles
---------------------------------------------------------------------
lib.callback.register('bdev-hearth:createCircle', mutate(function(src, cid, name)
    local ok, res = Circles.Create(cid, name, Bridge.GetName(src))
    if not ok then return err(res) end
    return { ok = true, id = res.id }
end))

lib.callback.register('bdev-hearth:joinCircle', mutate(function(src, cid, code)
    local ok, res = Circles.Join(cid, code, Bridge.GetName(src))
    if not ok then return err(res) end
    return { ok = true, id = res.id, name = res.name }
end))

lib.callback.register('bdev-hearth:leaveCircle', mutate(function(_, cid, id)
    return result(Circles.Leave(cid, id))
end))

lib.callback.register('bdev-hearth:deleteCircle', mutate(function(_, cid, id)
    return result(Circles.Delete(cid, id))
end))

lib.callback.register('bdev-hearth:renameCircle', mutate(function(_, cid, id, name)
    return result(Circles.Rename(cid, id, name))
end))

lib.callback.register('bdev-hearth:newInviteCode', mutate(function(_, cid, id)
    return result(Circles.NewInviteCode(cid, id))
end))

lib.callback.register('bdev-hearth:removeMember', mutate(function(_, cid, id, target)
    return result(Circles.RemoveMember(cid, id, target))
end))

lib.callback.register('bdev-hearth:setFlag', mutate(function(_, cid, id, flag, value)
    return result(Circles.SetFlag(cid, id, flag, value))
end))

lib.callback.register('bdev-hearth:invitePhone', mutate(function(src, cid, id, number)
    local member, circle = Circles.Member(id, cid)
    if not member then return err('You are not in this circle.') end
    local wait = onCooldown(src, 'invite', 10)
    if wait then return err(('Wait %ds before sending another invite.'):format(wait)) end
    local target = Bridge.FindSourceByPhone(number)
    if not target then return err('Nobody online has that number.') end
    if target == src then return err('That is your own number.') end
    local text = ('%s invited you to the circle "%s" on %s. Open %s and join with code %s')
        :format(member.name, circle.name, Config.App.label, Config.App.label, circle.code)
    Bridge.SendText(target, text)
    Bridge.Notify(target, Config.App.label, ('%s invited you to "%s". Code: %s'):format(member.name, circle.name, circle.code))
    return { ok = true }
end))

---------------------------------------------------------------------
-- Places
---------------------------------------------------------------------
lib.callback.register('bdev-hearth:addPlace', mutate(function(src, cid, id, data)
    if type(data) ~= 'table' then return err('Invalid place.') end
    if data.here then
        local c = pedCoords(src)
        if not c then return err('Could not read your location.') end
        data.x, data.y, data.z = c.x, c.y, c.z
    end
    local ok, res = Circles.AddPlace(cid, id, data)
    if not ok then return err(res) end
    return { ok = true, id = res.id }
end))

lib.callback.register('bdev-hearth:updatePlace', mutate(function(_, cid, id, placeId, data)
    if type(data) ~= 'table' then return err('Invalid place.') end
    return result(Circles.UpdatePlace(cid, id, placeId, data))
end))

lib.callback.register('bdev-hearth:deletePlace', mutate(function(_, cid, id, placeId)
    return result(Circles.DeletePlace(cid, id, placeId))
end))

---------------------------------------------------------------------
-- Members
---------------------------------------------------------------------
local function visibleCoords(cid, target)
    if not Circles.CanSee(cid, target) then return nil end
    local live = Tracker.live[target]
    if live and live.hasPhone and live.x then return live end
    return lastSeen({ target })[target]
end

lib.callback.register('bdev-hearth:getTrail', withCitizen(function(_, cid, target)
    if not Config.History.Enabled then return err('Location history is disabled.') end
    if not Circles.CanSee(cid, target) then return err('That person is not sharing with you.') end
    local points = {}
    for i, p in ipairs(Tracker.Trail(target)) do points[i] = { round(p.x), round(p.y), p.t } end
    return { ok = true, points = points }
end))

lib.callback.register('bdev-hearth:waypointTo', withCitizen(function(_, cid, target)
    local c = visibleCoords(cid, target)
    if not c then return err('That person is not sharing their location.') end
    return { ok = true, x = c.x, y = c.y }
end))

---------------------------------------------------------------------
-- Check-in / SOS / crash
---------------------------------------------------------------------
lib.callback.register('bdev-hearth:checkIn', mutate(function(src, cid, id, message)
    local member, circle = Circles.Member(id, cid)
    if not member then return err('You are not in this circle.') end
    local wait = onCooldown(src, 'checkin', Config.Alerts.CheckInCooldown)
    if wait then return err(('You can check in again in %ds.'):format(wait)) end
    local c = pedCoords(src)
    local ctx = Tracker.context[src] or {}
    local place = Tracker.CurrentPlace(cid, circle)
    local where = place and place.name or (ctx.street and ('%s, %s'):format(ctx.street, ctx.zone or '')) or nil
    message = type(message) == 'string' and message:gsub('[%c<>]', ''):sub(1, 80) or ''
    Circles.Log(circle.id, cid, member.name, 'checkin', {
        place = where,
        message = message ~= '' and message or where,
        coords = c,
    })
    return { ok = true }
end))

lib.callback.register('bdev-hearth:sos', mutate(function(src, cid, message)
    local circles = Circles.ForCitizen(cid)
    if #circles == 0 then return err('Join a circle first.') end
    local wait = onCooldown(src, 'sos', Config.Alerts.SOSCooldown)
    if wait then return err(('SOS already sent. Try again in %ds.'):format(wait)) end
    local c = pedCoords(src)
    local ctx = Tracker.context[src] or {}
    message = type(message) == 'string' and message:gsub('[%c<>]', ''):sub(1, 80) or ''
    if message == '' and ctx.street then message = ('%s, %s'):format(ctx.street, ctx.zone or '') end
    -- An SOS goes to every circle, even ones where sharing is paused: the player asked for help.
    for _, circle in ipairs(circles) do
        Circles.Log(circle.id, cid, circle.members[cid].name, 'sos', { coords = c, message = message })
    end
    return { ok = true }
end))

RegisterNetEvent('bdev-hearth:server:crash', function()
    local src = source
    if not Config.Alerts.CrashDetection then return end
    local cid = Bridge.GetCitizenId(src)
    local live = cid and Tracker.live[cid]
    if not live or not live.hasPhone then return end
    -- Sanity check the client: they must actually be in a vehicle.
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or GetVehiclePedIsIn(ped, false) == 0 then return end
    if onCooldown(src, 'crash', Config.Alerts.CrashCooldown) then return end
    local c = GetEntityCoords(ped)
    live.x, live.y, live.z = c.x, c.y, c.z
    local ctx = Tracker.context[src] or {}
    Tracker.AlertCircles(cid, live, 'crash', ctx.street and ('%s, %s'):format(ctx.street, ctx.zone or '') or nil)
end)

---------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    lastAction[src] = nil
    for key in pairs(cooldowns) do
        if key:find('^' .. src .. ':') then cooldowns[key] = nil end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Tracker.SaveAll() end
end)

MySQL.ready(function()
    DB.Init()
    Circles.Load()
    Tracker.Start()
end)
