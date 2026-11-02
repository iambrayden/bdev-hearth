Config = {}

Config.Debug = false

---------------------------------------------------------------------
-- Phone integration
---------------------------------------------------------------------
-- 'auto' finds Smartphone V3 ('qs-smartphone') or Smartphone PRO ('qs-smartphone-pro').
-- If you renamed the phone's folder, put the new resource name here.
Config.Phone = 'auto'

Config.App = {
    name = 'bdev-hearth',          -- internal app id (must be unique on the phone)
    label = 'Hearth',
    description = 'See where your family and friends are, get alerts when they arrive or leave, and send an SOS.',
    category = 'Social',           -- app store category
    creator = 'bdev',
    age = '12+',
    appStoreOnly = true,           -- true = players download it from the App Store, false = already on every home screen
    price = 0,                     -- App Store price (only used when appStoreOnly = true)
    job = false,                   -- Smartphone PRO only: false = everyone, or a job name
    blockedJobs = {},              -- Smartphone PRO only
}

---------------------------------------------------------------------
-- Phone item
---------------------------------------------------------------------
-- When true, a member only shares a live location while they carry a phone item
-- (checked with ox_inventory). Without one they show as "No phone · last seen …".
Config.RequirePhoneItem = false
Config.PhoneItems = { 'phone' }    -- add every phone item your Quasar setup uses
Config.PhoneItemCheckSeconds = 30

---------------------------------------------------------------------
-- Circles
---------------------------------------------------------------------
Config.Circles = {
    MaxPerPlayer = 5,              -- circles a character can belong to
    MaxMembers = 12,
    NameMaxLength = 24,
    InviteCodeLength = 6,
}

---------------------------------------------------------------------
-- Location
---------------------------------------------------------------------
-- Positions are read on the server (OneSync), so players cannot fake them.
Config.Location = {
    UpdateSeconds = 3,             -- how often the server samples every member's position
    SaveLastSeenSeconds = 60,      -- how often last-known positions are written to the database
    StaleSeconds = 20,             -- a live position older than this shows as "updated Xs ago"
}

-- Location trail shown when you tap "History" on a member.
Config.History = {
    Enabled = true,
    Minutes = 60,                  -- how far back the trail goes (kept in memory only)
    SampleSeconds = 20,            -- one trail point at most this often…
    MinDistance = 30.0,            -- …and only after moving this far (metres)
}

Config.SpeedUnit = 'mph'           -- 'mph' or 'kmh'
Config.DrivingSpeed = 4.5          -- m/s; faster than this in a vehicle shows "Driving"

---------------------------------------------------------------------
-- Places (geofences)
---------------------------------------------------------------------
Config.Places = {
    MaxPerCircle = 15,
    MembersCanEdit = true,         -- false = only the circle admin can add/remove places
    MinRadius = 25.0,
    MaxRadius = 400.0,
    DefaultRadius = 75.0,
    ExitBuffer = 25.0,             -- metres past the edge before "left" fires (stops GPS flicker spam)
    Icons = { 'home', 'work', 'school', 'gym', 'shop', 'star' },
}

---------------------------------------------------------------------
-- Alerts
---------------------------------------------------------------------
Config.Alerts = {
    SOSCooldown = 60,              -- seconds between SOS alerts per player
    SOSBlipSeconds = 300,          -- how long the SOS/crash blip stays on circle members' maps
    CheckInCooldown = 30,

    CrashDetection = true,         -- tell your circle when you are in a hard vehicle crash
    CrashMinSpeed = 22.0,          -- m/s (~50 mph) you must have been travelling
    CrashMinDrop = 15.0,           -- m/s lost within ~half a second
    CrashCooldown = 180,

    DownedAlert = true,            -- tell your circle when you go down (Qbox isdead / inlaststand)
}

---------------------------------------------------------------------
-- Activity feed
---------------------------------------------------------------------
Config.Activity = {
    ShowLimit = 40,                -- events sent to the app
    KeepDays = 14,                 -- older events are deleted on resource start
}

---------------------------------------------------------------------
-- App UI
---------------------------------------------------------------------
Config.UI = {
    RefreshMs = 3000,              -- how often the open app polls for fresh positions
}

-- Map background: html/map/map.jpg (the server's postal map, with Cayo Perico drawn as an inset).
-- Bounds are the world coordinates of the image's edges. They were calibrated by matching the
-- 865 OCRP postal labels printed on the image to their real coordinates (median error ~12 m).
-- If you swap in a higher-resolution export of the SAME map, keep these numbers.
Config.Map = {
    Image = 'map/map.jpg',
    Bounds = { minX = -7729.3, maxX = 5763.0, minY = -6554.6, maxY = 10215.9 },
    Background = '#0a2250',        -- ocean colour around the image

    -- For a sharp map, cut a high-resolution export of this same map into tiles with
    --   python tools/make_tiles.py path/to/big-map.png
    -- and paste the Tiles line it prints here. Tiles replace Image when set.
    -- Tiles = { Url = 'map/tiles/{z}/{x}/{y}.webp', MinZoom = -6, MaxZoom = 0 },

    -- Areas the image draws somewhere other than their real position. Positions inside the
    -- real-world box are shifted by offset onto the drawn copy (and back when picking a spot).
    Insets = {
        {
            name = 'Cayo Perico',
            minX = 3700.0, maxX = 5900.0, minY = -6300.0, maxY = -4100.0,
            offsetX = -2744.0, offsetY = 52.0,
        },
    },
}
