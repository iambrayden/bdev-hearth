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
    appStoreOnly = false,          -- false = already on every home screen, true = download it from the App Store
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

-- Map background. Drop a top-down GTA V map image into html/map/ and set its name
-- and the world coordinates of its edges. Without an image the app draws a grid
-- (members, places and trails still work, they just float on a blank canvas).
-- The default bounds match the common square 8192px "GTA V atlas/satellite" renders.
Config.Map = {
    Image = 'map/gta5.webp',
    Bounds = { minX = -5661.6, maxX = 6693.6, minY = -4058.5, maxY = 8429.3 },
    Background = '#0fa8d2',        -- colour around the image (ocean)
}
