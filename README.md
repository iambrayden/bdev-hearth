# Hearth: circles & location sharing for the Quasar Smartphone

A family/friends location-sharing app for **Quasar Smartphone V3** (`qs-smartphone`) on **Qbox**.
Players form private *circles*, see each other on a live map, get notified when someone
arrives at or leaves a saved place, check in, and send an SOS. It also detects hard
vehicle crashes and alerts the circle when a member goes down.

![icon](html/icon.png)

## Features

- **Circles**: create several (default 5 per character), invite with a 6-character code
  or by texting a phone number, admin roles, rename, regenerate the code, remove members.
  When the admin leaves, the longest-standing member takes over.
- **Live map**: member pins with initials, a driving badge, offline/greyed and alert states.
  It uses your own GTA V map image (see `html/map/README.md`), or a grid if none is installed.
- **Member status**: "At Home", "Driving · 54 mph on Route 68", "Near Vinewood Blvd, Downtown Vinewood",
  "Offline · Sandy Shores, 2h ago", distance from you, speed and area.
- **Places (geofences)**: Home/Work/School/etc. with a radius. Arrive/leave alerts use an
  exit buffer so GPS jitter at the edge doesn't spam the circle. Add a place at your
  current position or pick it on the map.
- **Activity feed**: arrivals, departures, check-ins, SOS, crashes, joins and leaves,
  grouped by day. Tap an entry to see it on the map, or set GPS for urgent ones.
- **Location history**: a trail of the last 60 minutes for any member who shares with you.
- **Directions**: sets your in-game GPS waypoint to a member or a place.
- **Check-in**: tells the circle where you are, with an optional message.
- **SOS** (press and hold): goes to every circle, even ones where you paused sharing.
  Members get a phone notification and a flashing map blip.
- **Crash detection**: a big speed drop plus a collision while driving fast alerts the circle.
- **Downed alert**: triggers on Qbox `isdead` / `inlaststand`.
- **Privacy controls**: per-circle *Share my location* (pause) and *Notifications* toggles.
- **Optional phone-item requirement** (ox_inventory): no phone means no live location.
- Follows the phone's light/dark theme through the Quasar JS bridge.

## Requirements

- Qbox (`qbx_core`), `ox_lib`, `oxmysql`
- OneSync. Positions are read on the server, which needs it.
- Quasar Smartphone V3 (`qs-smartphone`). PRO is detected and supported for registration too.

## Install

1. Drop `bdev-hearth` into your resources folder.
2. Add it to `server.cfg` **after** the phone:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure qbx_core
   ensure qs-smartphone
   ensure bdev-hearth
   ```
3. Tables are created on start (`install.sql` has them if you prefer to import by hand).
4. Optional: put a GTA V map image in `html/map/` (see `html/map/README.md`).
5. Restart. **Hearth** appears on every home screen (or in the App Store with
   `Config.App.appStoreOnly = true`).

If the app doesn't show up, run `/hearthapp` in game. It re-registers the app and prints
the phone's answer in F8 (e.g. `missing_app_id`, `missing_category`).

## Configuration

Everything is in `config.lua`. The settings people usually change:

| Setting | Default | What it does |
|---|---|---|
| `Config.App.*` | `Hearth`, Social | Name, category and App Store settings |
| `Config.RequirePhoneItem` / `PhoneItems` | `false` / `{ 'phone' }` | Only share while carrying a phone item |
| `Config.Circles.MaxPerPlayer` / `MaxMembers` | 5 / 12 | Limits |
| `Config.Location.UpdateSeconds` | 3 | How often the server samples positions |
| `Config.History.Minutes` | 60 | Length of the location trail |
| `Config.Places.*` | 15 places, 25-400 m | Geofence limits, exit buffer, icons |
| `Config.Alerts.*` | on | SOS/crash/downed alerts and cooldowns |
| `Config.SpeedUnit` | `mph` | `mph` (miles/feet) or `kmh` (km/m) |
| `Config.Map` | `map/gta5.webp` | Map image and its world-coordinate bounds |

If you change `Config.App.name`, also change `appId` in `html/app.js` (`setupBridge`).

## How it works

```
phone iframe (html/)  --fetch-->  client/main.lua  --lib.callback-->  server/main.lua
   polls getState every 3 s           NUI callbacks                        |
                                                                           v
  server/tracker.lua: every 3 s reads each member's ped coords (OneSync), speed and
  vehicle, evaluates geofences, records trails and detects "downed"; logs events
  through server/circles.lua, which notifies members with sendPhoneNotification.
```

- **Server-authoritative positions.** Clients never send coordinates, so a modded client
  can't spoof its location. The client only sends street and zone names, which need
  client-side natives.
- **No database load in the hot path.** Circles, members and places are cached in memory.
  Last-known positions are written in one transaction every 60 seconds and on logout.
  The activity feed is cached until a new event arrives.
- **Silent learning.** On server start, when a place is created, or when someone resumes
  sharing, presence is learned without alerts. Nobody gets a "left Home" spam wave.
- The phone has no Lua-to-iframe push, so the app polls (`Config.UI.RefreshMs`). It
  pauses on the bridge's `app:closed` event, and `client/main.lua` doesn't call the
  server while `IsPhoneOpen()` is false, so closed phones put no load on the server.

## Files

```
client/phone.lua     registration with the phone (V3 + PRO), /hearthapp
client/main.lua      NUI callbacks -> server, street/zone sender
client/alerts.lua    SOS/crash blips, crash detection
server/bridge.lua    Qbox + Quasar exports (the only framework-specific file)
server/db.lua        oxmysql queries, auto schema
server/circles.lua   circles, members, places, events + notifications
server/tracker.lua   location loop, geofences, trails, last seen
server/main.lua      lib.callback endpoints
html/                the app (plain HTML/CSS/JS + Leaflet, no build step)
```

## Developing the UI

Open `html/index.html` in a browser through any static server (for example
`cd html && python3 -m http.server`). Outside FiveM, `mock.js` acts as a fake server
with moving members, places and events, so you can work on the UI without the game.
The 404 for `qs-phone-bridge.js` outside the phone is expected.
