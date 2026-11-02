-- Database layer. Tables are created automatically on start (see also install.sql).
DB = {}

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `bdev_hearth_circles` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `name` VARCHAR(48) NOT NULL,
        `invite_code` VARCHAR(12) NOT NULL,
        `owner` VARCHAR(50) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `invite_code` (`invite_code`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `bdev_hearth_members` (
        `circle_id` INT UNSIGNED NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `role` VARCHAR(10) NOT NULL DEFAULT 'member',
        `sharing` TINYINT(1) NOT NULL DEFAULT 1,
        `notify` TINYINT(1) NOT NULL DEFAULT 1,
        `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`circle_id`, `citizenid`),
        KEY `citizenid` (`citizenid`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `bdev_hearth_places` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `circle_id` INT UNSIGNED NOT NULL,
        `name` VARCHAR(32) NOT NULL,
        `icon` VARCHAR(16) NOT NULL DEFAULT 'star',
        `x` FLOAT NOT NULL,
        `y` FLOAT NOT NULL,
        `z` FLOAT NOT NULL DEFAULT 0,
        `radius` FLOAT NOT NULL,
        `created_by` VARCHAR(50) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `circle_id` (`circle_id`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `bdev_hearth_events` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `circle_id` INT UNSIGNED NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `kind` VARCHAR(20) NOT NULL,
        `place` VARCHAR(32) DEFAULT NULL,
        `message` VARCHAR(160) DEFAULT NULL,
        `x` FLOAT DEFAULT NULL,
        `y` FLOAT DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `circle_id` (`circle_id`, `id`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `bdev_hearth_lastseen` (
        `citizenid` VARCHAR(50) NOT NULL,
        `x` FLOAT NOT NULL,
        `y` FLOAT NOT NULL,
        `z` FLOAT NOT NULL,
        `street` VARCHAR(80) DEFAULT NULL,
        `zone` VARCHAR(80) DEFAULT NULL,
        `updated_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`citizenid`)
    )]],
}

local function q(fn, query, params)
    local ok, res = pcall(fn, query, params or {})
    if not ok then
        print(('^1[bdev-hearth] query failed: %s^7\n%s'):format(tostring(res), query))
        return nil
    end
    return res
end

function DB.Init()
    for _, query in ipairs(SCHEMA) do q(MySQL.query.await, query) end
    local cutoff = os.time() - Config.Activity.KeepDays * 86400
    q(MySQL.update.await, 'DELETE FROM bdev_hearth_events WHERE created_at < ?', { cutoff })
end

---------------------------------------------------------------------
-- Bulk load (the server keeps circles, members and places in memory)
---------------------------------------------------------------------
function DB.LoadAll()
    return {
        circles = q(MySQL.query.await, 'SELECT id, name, invite_code, owner FROM bdev_hearth_circles') or {},
        members = q(MySQL.query.await,
            'SELECT circle_id, citizenid, name, role, sharing, notify, UNIX_TIMESTAMP(joined_at) AS joined_at FROM bdev_hearth_members') or {},
        places = q(MySQL.query.await,
            'SELECT id, circle_id, name, icon, x, y, z, radius, created_by FROM bdev_hearth_places') or {},
    }
end

---------------------------------------------------------------------
-- Circles
---------------------------------------------------------------------
function DB.CreateCircle(name, code, owner)
    return q(MySQL.insert.await, 'INSERT INTO bdev_hearth_circles (name, invite_code, owner) VALUES (?, ?, ?)',
        { name, code, owner })
end

function DB.RenameCircle(id, name)
    return q(MySQL.update.await, 'UPDATE bdev_hearth_circles SET name = ? WHERE id = ?', { name, id })
end

function DB.SetInviteCode(id, code)
    return q(MySQL.update.await, 'UPDATE bdev_hearth_circles SET invite_code = ? WHERE id = ?', { code, id })
end

function DB.SetOwner(id, citizenid)
    q(MySQL.update.await, 'UPDATE bdev_hearth_circles SET owner = ? WHERE id = ?', { citizenid, id })
    q(MySQL.update.await, "UPDATE bdev_hearth_members SET role = 'admin' WHERE circle_id = ? AND citizenid = ?",
        { id, citizenid })
end

function DB.DeleteCircle(id)
    q(MySQL.update.await, 'DELETE FROM bdev_hearth_members WHERE circle_id = ?', { id })
    q(MySQL.update.await, 'DELETE FROM bdev_hearth_places WHERE circle_id = ?', { id })
    q(MySQL.update.await, 'DELETE FROM bdev_hearth_events WHERE circle_id = ?', { id })
    q(MySQL.update.await, 'DELETE FROM bdev_hearth_circles WHERE id = ?', { id })
end

---------------------------------------------------------------------
-- Members
---------------------------------------------------------------------
function DB.AddMember(circleId, citizenid, name, role)
    return q(MySQL.insert.await,
        'INSERT INTO bdev_hearth_members (circle_id, citizenid, name, role) VALUES (?, ?, ?, ?)',
        { circleId, citizenid, name, role }) ~= nil
end

function DB.RemoveMember(circleId, citizenid)
    q(MySQL.update.await, 'DELETE FROM bdev_hearth_members WHERE circle_id = ? AND citizenid = ?',
        { circleId, citizenid })
end

function DB.SetMemberFlag(circleId, citizenid, column, value)
    assert(column == 'sharing' or column == 'notify')
    q(MySQL.update.await,
        ('UPDATE bdev_hearth_members SET `%s` = ? WHERE circle_id = ? AND citizenid = ?'):format(column),
        { value and 1 or 0, circleId, citizenid })
end

function DB.RenameMember(citizenid, name)
    q(MySQL.update.await, 'UPDATE bdev_hearth_members SET name = ? WHERE citizenid = ?', { name, citizenid })
end

---------------------------------------------------------------------
-- Places
---------------------------------------------------------------------
function DB.CreatePlace(p)
    return q(MySQL.insert.await,
        'INSERT INTO bdev_hearth_places (circle_id, name, icon, x, y, z, radius, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { p.circle_id, p.name, p.icon, p.x, p.y, p.z, p.radius, p.created_by })
end

function DB.UpdatePlace(p)
    q(MySQL.update.await, 'UPDATE bdev_hearth_places SET name = ?, icon = ?, radius = ? WHERE id = ?',
        { p.name, p.icon, p.radius, p.id })
end

function DB.DeletePlace(id)
    q(MySQL.update.await, 'DELETE FROM bdev_hearth_places WHERE id = ?', { id })
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
function DB.InsertEvent(e)
    return q(MySQL.insert.await,
        'INSERT INTO bdev_hearth_events (circle_id, citizenid, name, kind, place, message, x, y, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { e.circle_id, e.citizenid, e.name, e.kind, e.place, e.message, e.x, e.y, e.created_at })
end

function DB.Events(circleId, limit)
    return q(MySQL.query.await,
        'SELECT id, citizenid, name, kind, place, message, x, y, created_at FROM bdev_hearth_events WHERE circle_id = ? ORDER BY id DESC LIMIT ?',
        { circleId, limit }) or {}
end

---------------------------------------------------------------------
-- Last seen
---------------------------------------------------------------------
function DB.SaveLastSeen(rows)
    if #rows == 0 then return end
    local queries = {}
    for i, r in ipairs(rows) do
        queries[i] = {
            query = [[INSERT INTO bdev_hearth_lastseen (citizenid, x, y, z, street, zone, updated_at)
                      VALUES (?, ?, ?, ?, ?, ?, ?)
                      ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z),
                        street = VALUES(street), zone = VALUES(zone), updated_at = VALUES(updated_at)]],
            values = { r.citizenid, r.x, r.y, r.z, r.street, r.zone, r.updated_at },
        }
    end
    local ok, err = pcall(MySQL.transaction.await, queries)
    if not ok then print('^1[bdev-hearth] could not save last-seen positions: ' .. tostring(err) .. '^7') end
end

function DB.LastSeen(citizenids)
    if #citizenids == 0 then return {} end
    local marks = string.rep('?,', #citizenids):sub(1, -2)
    local rows = q(MySQL.query.await,
        ('SELECT citizenid, x, y, z, street, zone, updated_at FROM bdev_hearth_lastseen WHERE citizenid IN (%s)'):format(marks),
        citizenids) or {}
    local out = {}
    for _, r in ipairs(rows) do out[r.citizenid] = r end
    return out
end
