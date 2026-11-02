// Browser preview only: a fake server so the app can be developed outside FiveM
// (open html/index.html with any static server). Not used in game.
window.HearthMock = (() => {
    'use strict';
    const now = () => Math.floor(Date.now() / 1000);
    const ME = 'ME001';
    let nextId = 100;

    // Routes are lists of world coordinates members drive/walk between.
    const ROUTES = {
        B2: [[1150, -650], [900, -900], [300, -900], [200, -800], [300, -590]],
        C3: [[-1640, 200], [-1400, -200], [-800, -300], [-300, -600], [195, -933]],
    };
    const db = {
        circles: [
            { id: 1, name: 'Family', code: 'HX7K2P', owner: ME, places: [], members: {} },
            { id: 2, name: 'The Crew', code: 'QW3RT9', owner: 'D4', places: [], members: {} },
        ],
        events: { 1: [], 2: [] },
        people: {
            ME001: { name: 'Brayden Herrell', x: 1140, y: -660, street: 'Nikola Ave', zone: 'Mirror Park', online: true },
            B2: { name: 'Jordan Herrell', online: true, driving: true, route: 'B2', t: 0.1 },
            C3: { name: 'Riley Herrell', online: true, route: 'C3', t: 0.4, street: 'Vespucci Blvd', zone: 'Little Seoul' },
            D4: { name: 'Sam Ortiz', online: false, noPhone: false, x: 1850, y: 3700, street: 'Alhambra Dr', zone: 'Sandy Shores', updated: now() - 7200 },
            E5: { name: 'Alex Kim', online: true, x: -200, y: 6300, street: 'Paleto Blvd', zone: 'Paleto Bay', downed: false },
        },
    };
    const add = (cid, id, role, sharing = true) => (db.circles[id - 1].members[cid] = { citizenid: cid, role, sharing, notify: true });
    add(ME, 1, 'admin'); add('B2', 1, 'member'); add('C3', 1, 'member'); add('D4', 1, 'member', true);
    add(ME, 2, 'member'); add('D4', 2, 'admin'); add('E5', 2, 'member');
    db.circles[0].places = [
        { id: 1, name: 'Home', icon: 'home', x: 1150, y: -650, radius: 90, created_by: ME },
        { id: 2, name: 'Work', icon: 'work', x: 300, y: -590, radius: 120, created_by: ME },
        { id: 3, name: 'ULSA', icon: 'school', x: -1640, y: 200, radius: 150, created_by: 'C3' },
    ];
    db.circles[1].places = [{ id: 4, name: 'Clubhouse', icon: 'star', x: 1990, y: 3050, radius: 80, created_by: 'D4' }];

    const seed = (circle, cid, kind, ago, extra = {}) => db.events[circle].push({ id: nextId++, citizenid: cid, name: db.people[cid].name, kind, created_at: now() - ago, ...extra });
    seed(1, 'B2', 'left', 600, { place: 'Home' });
    seed(1, 'C3', 'checkin', 2400, { place: 'Little Seoul', message: 'Grabbing food' });
    seed(1, 'C3', 'left', 4000, { place: 'ULSA' });
    seed(1, 'D4', 'joined', 90000);
    seed(2, 'E5', 'arrived', 1500, { place: 'Clubhouse' });
    db.events[1].sort((a, b) => b.created_at - a.created_at);
    db.events[1].forEach((e, i) => (e.id = 50 - i));

    // Move people along their routes.
    const trails = {};
    function lerpRoute(route, t) {
        const pts = ROUTES[route];
        const seg = Math.min(pts.length - 2, Math.floor(t * (pts.length - 1)));
        const f = t * (pts.length - 1) - seg;
        return [pts[seg][0] + (pts[seg + 1][0] - pts[seg][0]) * f, pts[seg][1] + (pts[seg + 1][1] - pts[seg][1]) * f];
    }
    function tick() {
        for (const [cid, p] of Object.entries(db.people)) {
            if (p.route) {
                p.t = (p.t + 0.004) % 1;
                [p.x, p.y] = lerpRoute(p.route, p.t);
                p.speed = p.driving ? 24 : 1.4;
                p.street = p.driving ? 'Mirror Park Blvd' : p.street;
                p.zone = p.driving ? 'Mirror Park' : p.zone;
            }
            if (p.online) {
                p.updated = now();
                (trails[cid] ||= []).push([Math.round(p.x), Math.round(p.y), now()]);
                if (trails[cid].length > 120) trails[cid].shift();
            }
        }
    }
    // Pre-fill trails so "Location history" has something to draw.
    for (let i = 0; i < 60; i++) tick();
    setInterval(tick, 1500);

    function placeOf(cid, circle) {
        const p = db.people[cid];
        return circle.places.find((pl) => Math.hypot(pl.x - p.x, pl.y - p.y) <= pl.radius) || null;
    }

    function view(circle) {
        const self = circle.members[ME];
        const members = Object.values(circle.members).map((m) => {
            const p = db.people[m.citizenid];
            const v = { citizenid: m.citizenid, name: p.name, role: m.role, isMe: m.citizenid === ME, sharing: m.sharing, owner: circle.owner === m.citizenid };
            if (!m.sharing && !v.isMe) return v;
            Object.assign(v, {
                online: p.online, noPhone: p.noPhone, x: p.x, y: p.y, street: p.street, zone: p.zone,
                speed: p.speed || 0, driving: !!p.driving, downed: !!p.downed, updated: p.updated,
            });
            const pl = placeOf(m.citizenid, circle);
            if (pl && p.online) v.place = { id: pl.id, name: pl.name, icon: pl.icon };
            return v;
        }).sort((a, b) => (a.isMe !== b.isMe ? (a.isMe ? -1 : 1) : a.name.localeCompare(b.name)));
        return {
            id: circle.id, name: circle.name, code: circle.code, isAdmin: self.role === 'admin',
            sharing: self.sharing, notify: self.notify, members,
            places: circle.places.map((p) => ({ ...p, mine: p.created_by === ME })),
            events: db.events[circle.id] || [],
        };
    }

    const SETTINGS = {
        speedUnit: 'mph', staleSeconds: 20, refreshMs: 1500, history: true, maxMembers: 12, nameMax: 24,
        places: { minRadius: 25, maxRadius: 400, defaultRadius: 75, icons: ['home', 'work', 'school', 'gym', 'shop', 'star'], membersCanEdit: true },
        map: { Image: 'map/gta5.webp', Bounds: { minX: -5661.6, maxX: 6693.6, minY: -4058.5, maxY: 8429.3 }, Background: '#0fa8d2' },
    };

    const mine = () => db.circles.filter((c) => c.members[ME]);
    const byId = (id) => db.circles.find((c) => c.id === Number(id));
    const ok = (extra = {}) => ({ ok: true, ...extra });
    const fail = (error) => ({ ok: false, error });

    const handlers = {
        getState({ circleId }) {
            const list = mine();
            const active = list.find((c) => c.id === Number(circleId)) || list[0];
            return {
                ok: true, me: ME, now: now(), settings: SETTINGS,
                circles: list.map((c) => ({ id: c.id, name: c.name, role: c.members[ME].role, members: Object.keys(c.members).length })),
                circle: active ? view(active) : undefined,
            };
        },
        createCircle({ name }) {
            const id = db.circles.length + 1;
            db.circles.push({ id, name, code: Math.random().toString(36).slice(2, 8).toUpperCase(), owner: ME, places: [], members: {} });
            db.events[id] = [];
            add(ME, id, 'admin');
            return ok({ id });
        },
        joinCircle({ code }) {
            const c = db.circles.find((x) => x.code === String(code).toUpperCase());
            if (!c) return fail('No circle has that invite code.');
            if (c.members[ME]) return fail('You are already in this circle.');
            add(ME, c.id, 'member');
            return ok({ id: c.id, name: c.name });
        },
        leaveCircle({ circleId }) { delete byId(circleId).members[ME]; return ok(); },
        deleteCircle({ circleId }) { const c = byId(circleId); c.members = {}; return ok(); },
        renameCircle({ circleId, name }) { byId(circleId).name = name; return ok(); },
        newInviteCode({ circleId }) { byId(circleId).code = Math.random().toString(36).slice(2, 8).toUpperCase(); return ok(); },
        removeMember({ circleId, citizenid }) { delete byId(circleId).members[citizenid]; return ok(); },
        setFlag({ circleId, flag, value }) { byId(circleId).members[ME][flag] = value; return ok(); },
        invitePhone({ number }) { return String(number).length < 3 ? fail('Nobody online has that number.') : ok(); },
        addPlace({ circleId, place }) {
            const me = db.people[ME];
            const p = { id: nextId++, name: place.name, icon: place.icon, radius: place.radius, created_by: ME,
                x: place.here ? me.x : place.x, y: place.here ? me.y : place.y };
            byId(circleId).places.push(p);
            return ok({ id: p.id });
        },
        updatePlace({ circleId, placeId, place }) { Object.assign(byId(circleId).places.find((p) => p.id === placeId), place); return ok(); },
        deletePlace({ circleId, placeId }) { const c = byId(circleId); c.places = c.places.filter((p) => p.id !== placeId); return ok(); },
        getTrail({ citizenid }) { return ok({ points: (trails[citizenid] || []).slice(-40) }); },
        waypoint() { return ok(); },
        waypointCoords() { return ok(); },
        checkIn({ circleId, message }) {
            db.events[circleId].unshift({ id: nextId++, citizenid: ME, name: db.people[ME].name, kind: 'checkin', created_at: now(), place: 'Mirror Park', message: message || 'Nikola Ave, Mirror Park', x: db.people[ME].x, y: db.people[ME].y });
            return ok();
        },
        sos() {
            const p = db.people[ME];
            for (const c of mine()) db.events[c.id].unshift({ id: nextId++, citizenid: ME, name: p.name, kind: 'sos', created_at: now(), message: 'Nikola Ave, Mirror Park', x: p.x, y: p.y });
            return ok();
        },
        copy() { return ok(); },
    };

    return {
        async handle(name, data) {
            await new Promise((r) => setTimeout(r, 60));
            const fn = handlers[name];
            return fn ? JSON.parse(JSON.stringify(fn(data || {}))) : fail('Unknown action ' + name);
        },
    };
})();
