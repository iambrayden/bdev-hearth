-- Circles, members and places. Everything is cached in memory (loaded on start) and
-- written through to MySQL, so the 3-second location loop never touches the database.
Circles = {
    byId = {},       -- [circleId] = { id, name, code, owner, members = {[cid] = member}, places = {[placeId] = place} }
    byCitizen = {},  -- [citizenid] = { [circleId] = true }
    codes = {},      -- [inviteCode] = circleId
}

local CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

local function trim(s)
    return (tostring(s or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
Circles.count = count

local function newCode()
    for _ = 1, 50 do
        local chars = {}
        for i = 1, Config.Circles.InviteCodeLength do
            local r = math.random(1, #CODE_ALPHABET)
            chars[i] = CODE_ALPHABET:sub(r, r)
        end
        local code = table.concat(chars)
        if not Circles.codes[code] then return code end
    end
    error('could not generate a unique invite code')
end

local function index(circle, cid, value)
    Circles.byCitizen[cid] = Circles.byCitizen[cid] or {}
    Circles.byCitizen[cid][circle.id] = value or nil
    if not next(Circles.byCitizen[cid]) then Circles.byCitizen[cid] = nil end
end

function Circles.Load()
    math.randomseed(os.time())
    local data = DB.LoadAll()
    Circles.byId, Circles.byCitizen, Circles.codes = {}, {}, {}
    for _, c in ipairs(data.circles) do
        Circles.byId[c.id] = { id = c.id, name = c.name, code = c.invite_code, owner = c.owner, members = {}, places = {} }
        Circles.codes[c.invite_code] = c.id
    end
    for _, m in ipairs(data.members) do
        local circle = Circles.byId[m.circle_id]
        if circle then
            circle.members[m.citizenid] = {
                citizenid = m.citizenid,
                name = m.name,
                role = m.role,
                sharing = m.sharing == 1 or m.sharing == true,
                notify = m.notify == 1 or m.notify == true,
                joined = tonumber(m.joined_at) or 0,
            }
            index(circle, m.citizenid, true)
        end
    end
    for _, p in ipairs(data.places) do
        local circle = Circles.byId[p.circle_id]
        if circle then
            circle.places[p.id] = {
                id = p.id, name = p.name, icon = p.icon,
                x = p.x, y = p.y, z = p.z, radius = p.radius, created_by = p.created_by,
            }
        end
    end
    print(('[bdev-hearth] loaded %d circles'):format(count(Circles.byId)))
end

function Circles.Get(id)
    return Circles.byId[tonumber(id)]
end

function Circles.Member(id, cid)
    local circle = Circles.Get(id)
    return circle and circle.members[cid] or nil, circle
end

function Circles.IsAdmin(id, cid)
    local m = Circles.Member(id, cid)
    return m ~= nil and m.role == 'admin'
end

--- Circles the citizen belongs to, oldest first.
function Circles.ForCitizen(cid)
    local out = {}
    for id in pairs(Circles.byCitizen[cid] or {}) do out[#out + 1] = Circles.byId[id] end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

--- True when a and b share at least one circle in which `b` is sharing their location.
function Circles.CanSee(viewerCid, targetCid)
    if viewerCid == targetCid then return true end
    for id in pairs(Circles.byCitizen[targetCid] or {}) do
        local circle = Circles.byId[id]
        if circle.members[viewerCid] and circle.members[targetCid].sharing then return true end
    end
    return false
end

---------------------------------------------------------------------
-- Events + notifications
---------------------------------------------------------------------
local EVENT_TEXT = {
    arrived = '%s arrived at %s',
    left = '%s left %s',
    checkin = '%s checked in',
    sos = 'SOS from %s',
    crash = 'Possible crash: %s',
    downed = '%s may need help',
    joined = '%s joined the circle',
    left_circle = '%s left the circle',
}

--- Records an event in the circle's activity feed and notifies the other members.
--- opts: { place = 'Home', message = 'text', coords = vector, silent = bool }
function Circles.Log(circleId, cid, name, kind, opts)
    opts = opts or {}
    local circle = Circles.Get(circleId)
    if not circle then return end
    local coords = opts.coords
    DB.InsertEvent({
        circle_id = circle.id, citizenid = cid, name = name, kind = kind,
        place = opts.place, message = opts.message,
        x = coords and coords.x or nil, y = coords and coords.y or nil,
        created_at = os.time(),
    })
    Circles.eventCache[circle.id] = nil
    if opts.silent then return end

    local text = (EVENT_TEXT[kind] or '%s'):format(name, opts.place or '')
    if opts.message and opts.message ~= '' then text = text .. ': ' .. opts.message end
    local urgent = kind == 'sos' or kind == 'crash' or kind == 'downed'

    for memberCid, member in pairs(circle.members) do
        local src = memberCid ~= cid and Tracker.SourceOf(memberCid)
        -- Urgent alerts ignore the member's notification toggle.
        if src and (member.notify or urgent) then
            Bridge.Notify(src, circle.name, text, urgent and 'error' or 'inform')
            if urgent and coords then
                TriggerClientEvent('bdev-hearth:client:alert', src, {
                    kind = kind, name = name, circle = circle.name,
                    x = coords.x, y = coords.y, z = coords.z,
                })
            end
        end
    end
end

Circles.eventCache = {} -- [circleId] = rows (cleared whenever an event is logged)

function Circles.Events(circleId)
    local rows = Circles.eventCache[circleId]
    if not rows then
        rows = DB.Events(circleId, Config.Activity.ShowLimit)
        Circles.eventCache[circleId] = rows
    end
    return rows
end

---------------------------------------------------------------------
-- Circle management. Every function returns ok, errorMessage.
---------------------------------------------------------------------
function Circles.Create(cid, name, ownerName)
    name = trim(name)
    if #name < 2 or #name > Config.Circles.NameMaxLength then
        return false, ('Name must be 2-%d characters.'):format(Config.Circles.NameMaxLength)
    end
    if count(Circles.byCitizen[cid] or {}) >= Config.Circles.MaxPerPlayer then
        return false, ('You can be in at most %d circles.'):format(Config.Circles.MaxPerPlayer)
    end
    local code = newCode()
    local id = DB.CreateCircle(name, code, cid)
    if not id then return false, 'Could not create the circle.' end
    if not DB.AddMember(id, cid, ownerName, 'admin') then return false, 'Could not create the circle.' end

    local circle = { id = id, name = name, code = code, owner = cid, members = {}, places = {} }
    circle.members[cid] = { citizenid = cid, name = ownerName, role = 'admin', sharing = true, notify = true, joined = os.time() }
    Circles.byId[id], Circles.codes[code] = circle, id
    index(circle, cid, true)
    return true, circle
end

function Circles.Join(cid, code, name)
    code = trim(code):upper():gsub('[^%w]', '')
    local circle = Circles.Get(Circles.codes[code])
    if not circle then return false, 'No circle has that invite code.' end
    if circle.members[cid] then return false, 'You are already in this circle.' end
    if count(circle.members) >= Config.Circles.MaxMembers then return false, 'This circle is full.' end
    if count(Circles.byCitizen[cid] or {}) >= Config.Circles.MaxPerPlayer then
        return false, ('You can be in at most %d circles.'):format(Config.Circles.MaxPerPlayer)
    end
    if not DB.AddMember(circle.id, cid, name, 'member') then return false, 'Could not join the circle.' end
    circle.members[cid] = { citizenid = cid, name = name, role = 'member', sharing = true, notify = true, joined = os.time() }
    index(circle, cid, true)
    Circles.Log(circle.id, cid, name, 'joined')
    return true, circle
end

local function deleteCircle(circle)
    DB.DeleteCircle(circle.id)
    for memberCid in pairs(circle.members) do index(circle, memberCid, false) end
    for placeId in pairs(circle.places) do Tracker.ForgetPlace(placeId) end
    Circles.codes[circle.code] = nil
    Circles.eventCache[circle.id] = nil
    Circles.byId[circle.id] = nil
end

local function removeMember(circle, cid)
    DB.RemoveMember(circle.id, cid)
    circle.members[cid] = nil
    index(circle, cid, false)
    Tracker.ForgetCircle(cid, circle)
end

function Circles.Leave(cid, id)
    local member, circle = Circles.Member(id, cid)
    if not member then return false, 'You are not in this circle.' end
    removeMember(circle, cid)

    if not next(circle.members) then
        deleteCircle(circle)
        return true
    end
    -- Hand the circle to the longest-standing member when the admin leaves.
    if circle.owner == cid then
        local heir
        for _, m in pairs(circle.members) do
            if not heir or m.joined < heir.joined then heir = m end
        end
        circle.owner, heir.role = heir.citizenid, 'admin'
        DB.SetOwner(circle.id, heir.citizenid)
    end
    Circles.Log(circle.id, cid, member.name, 'left_circle')
    return true
end

function Circles.Delete(cid, id)
    local circle = Circles.Get(id)
    if not circle or circle.owner ~= cid then return false, 'Only the circle admin can delete it.' end
    deleteCircle(circle)
    return true
end

function Circles.RemoveMember(cid, id, target)
    local circle = Circles.Get(id)
    if not circle or not Circles.IsAdmin(id, cid) then return false, 'Only the circle admin can remove members.' end
    if target == cid then return false, 'Use "Leave circle" instead.' end
    local member = circle.members[target]
    if not member then return false, 'That person is not in this circle.' end
    removeMember(circle, target)
    Circles.Log(circle.id, target, member.name, 'left_circle', { silent = true })
    return true
end

function Circles.Rename(cid, id, name)
    if not Circles.IsAdmin(id, cid) then return false, 'Only the circle admin can rename it.' end
    name = trim(name)
    if #name < 2 or #name > Config.Circles.NameMaxLength then
        return false, ('Name must be 2-%d characters.'):format(Config.Circles.NameMaxLength)
    end
    local circle = Circles.Get(id)
    DB.RenameCircle(circle.id, name)
    circle.name = name
    return true
end

function Circles.NewInviteCode(cid, id)
    if not Circles.IsAdmin(id, cid) then return false, 'Only the circle admin can change the code.' end
    local circle = Circles.Get(id)
    local code = newCode()
    DB.SetInviteCode(circle.id, code)
    Circles.codes[circle.code] = nil
    circle.code, Circles.codes[code] = code, circle.id
    return true
end

function Circles.SetFlag(cid, id, flag, value)
    if flag ~= 'sharing' and flag ~= 'notify' then return false, 'Unknown setting.' end
    local member, circle = Circles.Member(id, cid)
    if not member then return false, 'You are not in this circle.' end
    value = value == true
    DB.SetMemberFlag(circle.id, cid, flag, value)
    member[flag] = value
    -- Re-learn presence silently after a pause, so resuming never fires stale arrive/leave alerts.
    if flag == 'sharing' then Tracker.ForgetCircle(cid, circle) end
    return true
end

---------------------------------------------------------------------
-- Places
---------------------------------------------------------------------
local function validIcon(icon)
    for _, v in ipairs(Config.Places.Icons) do
        if v == icon then return v end
    end
    return 'star'
end

local function canEditPlaces(id, cid)
    return Circles.IsAdmin(id, cid) or (Config.Places.MembersCanEdit and Circles.Member(id, cid) ~= nil)
end

local function clampRadius(r)
    r = tonumber(r) or Config.Places.DefaultRadius
    return math.max(Config.Places.MinRadius, math.min(Config.Places.MaxRadius, r))
end

function Circles.AddPlace(cid, id, data)
    local circle = Circles.Get(id)
    if not circle or not canEditPlaces(id, cid) then return false, 'You cannot add places to this circle.' end
    if count(circle.places) >= Config.Places.MaxPerCircle then
        return false, ('A circle can have at most %d places.'):format(Config.Places.MaxPerCircle)
    end
    local name = trim(data.name)
    if #name < 1 or #name > 24 then return false, 'Place name must be 1-24 characters.' end
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z) or 0.0
    if not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then return false, 'Invalid location.' end

    local place = {
        circle_id = circle.id, name = name, icon = validIcon(data.icon),
        x = x, y = y, z = z, radius = clampRadius(data.radius), created_by = cid,
    }
    place.id = DB.CreatePlace(place)
    if not place.id then return false, 'Could not save the place.' end
    circle.places[place.id] = place
    return true, place
end

function Circles.UpdatePlace(cid, id, placeId, data)
    local circle = Circles.Get(id)
    local place = circle and circle.places[tonumber(placeId)]
    if not place or not canEditPlaces(id, cid) then return false, 'You cannot edit this place.' end
    local name = trim(data.name)
    if #name < 1 or #name > 24 then return false, 'Place name must be 1-24 characters.' end
    place.name, place.icon, place.radius = name, validIcon(data.icon), clampRadius(data.radius)
    DB.UpdatePlace(place)
    return true
end

function Circles.DeletePlace(cid, id, placeId)
    local circle = Circles.Get(id)
    local place = circle and circle.places[tonumber(placeId)]
    if not place then return false, 'Place not found.' end
    if not (Circles.IsAdmin(id, cid) or (Config.Places.MembersCanEdit and place.created_by == cid)) then
        return false, 'Only the admin or whoever added it can delete this place.'
    end
    DB.DeletePlace(place.id)
    circle.places[place.id] = nil
    Tracker.ForgetPlace(place.id)
    return true
end
