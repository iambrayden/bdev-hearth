(() => {
    'use strict';

    // ------------------------------------------------------------------
    // NUI transport
    // ------------------------------------------------------------------
    // The phone loads this page from https://cfx-nui-<resource>/html/index.html
    const hostMatch = location.hostname.match(/^cfx-nui-(.+)$/);
    const RESOURCE = hostMatch ? hostMatch[1]
        : (typeof GetParentResourceName === 'function' ? GetParentResourceName() : null);
    const IN_GAME = !!RESOURCE;

    async function nui(name, data = {}) {
        if (!IN_GAME) return window.HearthMock.handle(name, data);
        try {
            const res = await fetch(`https://${RESOURCE}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data),
            });
            return await res.json();
        } catch (e) {
            return { ok: false, error: 'Connection error' };
        }
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    const $ = (id) => document.getElementById(id);
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    const ICONS = {
        home: '<path d="M3 11 12 3l9 8"/><path d="M5 9.5V21h14V9.5"/><path d="M10 21v-6h4v6"/>',
        work: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18"/>',
        school: '<path d="m2 9 10-5 10 5-10 5z"/><path d="M6 11v5c3 2.5 9 2.5 12 0v-5M22 9v6"/>',
        gym: '<path d="M6 7v10M18 7v10M3 9v6M21 9v6M6 12h12"/>',
        shop: '<path d="M5 8h14l-1 13H6z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
        star: '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.2l1-6.2L3 9.6l6.2-.9z"/>',
        car: '<path d="M5 16V11l2-5h10l2 5v5"/><path d="M3 16h18v3H3zM7 19v2M17 19v2"/><circle cx="7.5" cy="13" r=".5"/><circle cx="16.5" cy="13" r=".5"/>',
        pin: '<path d="M12 22s7-6.2 7-12a7 7 0 1 0-14 0c0 5.8 7 12 7 12z"/><circle cx="12" cy="10" r="2.5"/>',
        check: '<path d="M12 22s7-6.2 7-12a7 7 0 1 0-14 0c0 5.8 7 12 7 12z"/><path d="m9 10 2 2 4-4"/>',
        sos: '<path d="M12 3 2 21h20z"/><path d="M12 10v5M12 18h.01"/>',
        heart: '<path d="M20.8 5.6a5.5 5.5 0 0 0-7.8 0L12 6.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 22l8.8-8.6a5.5 5.5 0 0 0 0-7.8z"/>',
        in: '<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4M10 17l5-5-5-5M15 12H3"/>',
        out: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>',
        join: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.6 2.9-6.5 6.5-6.5s6.5 2.9 6.5 6.5M19 8v6M16 11h6"/>',
        nav: '<path d="m3 11 19-9-9 19-2-8z"/>',
        history: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/>',
        check2: '<path d="m5 12 5 5L20 7"/>',
    };
    const icon = (name, extra = '') => `<svg viewBox="0 0 24 24" ${extra}>${ICONS[name] || ICONS.star}</svg>`;

    const PALETTE = ['#ff7a3d', '#3c9dff', '#3ccf8e', '#b06cff', '#ff4f8b', '#f5b400', '#22c3c3', '#8a7dff', '#ff6b6b', '#5aa469'];
    function colorFor(id) {
        let h = 0;
        for (const ch of String(id)) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
        return PALETTE[h % PALETTE.length];
    }
    function initials(name) {
        const parts = String(name || '?').trim().split(/\s+/);
        return ((parts[0]?.[0] || '?') + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
    }
    function avatar(m, cls = '', dot = null) {
        return `<div class="avatar ${cls}" style="background:${colorFor(m.citizenid)}">${esc(initials(m.name))}`
            + (dot ? `<i class="status-dot ${dot}"></i>` : '') + '</div>';
    }

    // Server clock offset so "2m ago" is right even if the PC clock is off.
    let clockSkew = 0;
    const serverNow = () => Date.now() / 1000 + clockSkew;
    function ago(ts) {
        if (!ts) return '';
        const s = Math.max(0, serverNow() - ts);
        if (s < 45) return 'just now';
        if (s < 3600) return `${Math.round(s / 60)}m ago`;
        if (s < 86400) return `${Math.round(s / 3600)}h ago`;
        const d = Math.round(s / 86400);
        return d === 1 ? 'yesterday' : `${d}d ago`;
    }
    function clock(ts) {
        return new Date(ts * 1000).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
    }
    function dayLabel(ts) {
        const d = new Date(ts * 1000);
        const today = new Date((serverNow()) * 1000);
        const y = new Date(today); y.setDate(today.getDate() - 1);
        if (d.toDateString() === today.toDateString()) return 'Today';
        if (d.toDateString() === y.toDateString()) return 'Yesterday';
        return d.toLocaleDateString([], { weekday: 'long', month: 'short', day: 'numeric' });
    }

    const metric = () => state.data?.settings?.speedUnit === 'kmh';
    function speedText(mps) {
        return metric() ? `${Math.round(mps * 3.6)} km/h` : `${Math.round(mps * 2.23694)} mph`;
    }
    function distText(m) {
        if (metric()) return m < 1000 ? `${Math.round(m / 10) * 10} m` : `${(m / 1000).toFixed(m < 10000 ? 1 : 0)} km`;
        const mi = m / 1609.34;
        return mi < 0.1 ? `${Math.round(m * 3.281 / 10) * 10} ft` : `${mi.toFixed(mi < 10 ? 1 : 0)} mi`;
    }
    const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
    const hasPos = (m) => m && typeof m.x === 'number' && typeof m.y === 'number';

    let toastTimer;
    function toast(msg, ok = true) {
        const el = $('toast');
        el.textContent = msg;
        el.className = 'toast show ' + (ok ? 'ok' : 'err');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => (el.className = 'toast'), 2600);
    }

    async function act(name, data, okMsg) {
        const res = await nui(name, data);
        if (!res || !res.ok) {
            toast(res?.error || 'Something went wrong', false);
            return null;
        }
        if (okMsg) toast(okMsg);
        return res;
    }

    function store(key, value) {
        try {
            if (value === undefined) return localStorage.getItem('hearth:' + key);
            localStorage.setItem('hearth:' + key, value);
        } catch (e) { /* storage unavailable */ }
        return null;
    }

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    const state = {
        data: null,
        circleId: Number(store('circle')) || null,
        view: 'map',
        sheet: null,       // { type, id } of the open modal sheet
        trail: null,       // { citizenid, name }
        picking: null,     // place form waiting for a map pick
        fitted: null,      // circle id the map was last auto-fitted for
        renderKeys: {},
    };

    const circle = () => state.data?.circle || null;
    const me = () => circle()?.members.find((m) => m.isMe) || null;
    const memberById = (cid) => circle()?.members.find((m) => m.citizenid === cid) || null;
    const placeById = (id) => circle()?.places.find((p) => p.id === id) || null;

    /** Only touch the DOM when the data behind a block actually changed. */
    function changed(key, value) {
        const k = JSON.stringify(value);
        if (state.renderKeys[key] === k) return false;
        state.renderKeys[key] = k;
        return true;
    }

    // ------------------------------------------------------------------
    // Member status
    // ------------------------------------------------------------------
    function statusOf(m) {
        if (!m.sharing && !m.isMe) return { text: 'Location paused', dot: 'paused' };
        if (m.online) {
            if (m.downed) return { text: 'Needs help', cls: 'alert', dot: 'alert' };
            let text;
            if (m.place) text = `At ${m.place.name}`;
            else if (m.driving) text = `Driving · ${speedText(m.speed || 0)}${m.street ? ' on ' + m.street.split(' & ')[0] : ''}`;
            else if (m.street) text = `Near ${m.street}${m.zone ? ', ' + m.zone : ''}`;
            else text = 'Location on';
            return { text, dot: m.isMe && !m.sharing ? 'paused' : 'on' };
        }
        const base = m.noPhone ? 'No phone' : 'Offline';
        const where = m.place?.name || m.zone || m.street;
        return { text: base + (m.updated ? ` · ${where ? where + ', ' : ''}${ago(m.updated)}` : ''), dot: '' };
    }

    function sideText(m) {
        const mine = me();
        if (!m.isMe && hasPos(m) && hasPos(mine) && (m.sharing)) return distText(dist(m, mine));
        if (m.online && m.updated && serverNow() - m.updated > (state.data.settings.staleSeconds || 20)) return ago(m.updated);
        return '';
    }

    // ------------------------------------------------------------------
    // Map
    // ------------------------------------------------------------------
    const MapView = {
        map: null,
        members: {},  // citizenid -> { marker, html }
        places: {},   // id -> { circle, label, key }
        trail: null,
        flash: null,
        pickCircle: null,

        init(settings) {
            if (this.map) return;
            const cfg = settings.map || {};
            const b = cfg.Bounds || { minX: -5661.6, maxX: 6693.6, minY: -4058.5, maxY: 8429.3 };
            // World coordinates are used directly: lat = y, lng = x.
            this.bounds = L.latLngBounds([b.minY, b.minX], [b.maxY, b.maxX]);
            this.map = L.map('map', {
                crs: L.CRS.Simple,
                zoomControl: false,
                attributionControl: false,
                minZoom: -6,
                maxZoom: 1.5,
                zoomSnap: 0.25,
                zoomDelta: 0.5,
                wheelPxPerZoomLevel: 90,
                maxBounds: this.bounds.pad(0.2),
                maxBoundsViscosity: 0.8,
            });
            const el = this.map.getContainer();
            el.classList.add('hearth-map');
            this.map.on('zoomstart', () => el.classList.add('zooming'));
            this.map.on('zoomend', () => setTimeout(() => el.classList.remove('zooming'), 50));
            this.map.fitBounds(this.bounds);

            if (cfg.Background) el.style.background = cfg.Background;
            const img = new Image();
            img.onload = () => L.imageOverlay(img.src, this.bounds, { zIndex: 1 }).addTo(this.map);
            img.onerror = () => {
                el.style.background = '';
                el.classList.add('no-image');
                this.grid().addTo(this.map);
            };
            img.src = cfg.Image || 'map/gta5.webp';

            this.placeLayer = L.layerGroup().addTo(this.map);
            this.trailLayer = L.layerGroup().addTo(this.map);
            this.memberLayer = L.layerGroup().addTo(this.map);
            this.map.on('move', () => this.updatePick());
        },

        /** Fallback background when no map image is installed. */
        grid() {
            const Grid = L.GridLayer.extend({
                createTile() {
                    const c = document.createElement('canvas');
                    c.width = c.height = 256;
                    const g = c.getContext('2d');
                    g.strokeStyle = getComputedStyle(document.documentElement).getPropertyValue('--grid') || 'rgba(255,255,255,.06)';
                    g.lineWidth = 1;
                    g.strokeRect(0.5, 0.5, 256, 256);
                    return c;
                },
            });
            return new Grid({ tileSize: 256 });
        },

        resize() { if (this.map) this.map.invalidateSize(); },

        pinHtml(m) {
            let cls = m.isMe ? 'me' : '';
            if (!m.online) cls += ' off';
            if (m.downed) cls += ' alert';
            return `<div class="pin ${cls}"><div class="pin-body"></div>${avatar(m)}`
                + (m.online && m.driving ? `<div class="car">${icon('car')}</div>` : '')
                + `</div>`;
        },

        syncMembers(members) {
            const seen = new Set();
            for (const m of members) {
                if (!hasPos(m) || (!m.sharing && !m.isMe)) continue;
                seen.add(m.citizenid);
                const html = this.pinHtml(m);
                const ll = [m.y, m.x];
                let e = this.members[m.citizenid];
                if (!e) {
                    const marker = L.marker(ll, {
                        icon: L.divIcon({ className: 'pin-wrap smooth', html, iconSize: [0, 0] }),
                        zIndexOffset: m.isMe ? 500 : 1000,
                    }).addTo(this.memberLayer);
                    marker.on('click', () => openMember(m.citizenid));
                    e = this.members[m.citizenid] = { marker, html };
                } else {
                    e.marker.setLatLng(ll);
                    if (e.html !== html) {
                        e.marker.setIcon(L.divIcon({ className: 'pin-wrap smooth', html, iconSize: [0, 0] }));
                        e.html = html;
                    }
                }
            }
            for (const id of Object.keys(this.members)) {
                if (!seen.has(id)) {
                    this.memberLayer.removeLayer(this.members[id].marker);
                    delete this.members[id];
                }
            }
        },

        syncPlaces(places) {
            const seen = new Set();
            for (const p of places) {
                const key = `${p.x},${p.y},${p.radius},${p.name},${p.icon}`;
                seen.add(String(p.id));
                const e = this.places[p.id];
                if (e && e.key === key) continue;
                if (e) { this.placeLayer.removeLayer(e.circle); this.placeLayer.removeLayer(e.label); }
                const accent = getComputedStyle(document.documentElement).getPropertyValue('--accent').trim() || '#ff7a3d';
                const c = L.circle([p.y, p.x], { radius: p.radius, color: accent, weight: 2, fillColor: accent, fillOpacity: 0.14, interactive: false });
                const label = L.marker([p.y, p.x], {
                    icon: L.divIcon({ className: 'place-pin', html: `<div>${icon(p.icon)}${esc(p.name)}</div>`, iconSize: [0, 0] }),
                    zIndexOffset: -100,
                });
                label.on('click', () => openPlace(p.id));
                c.addTo(this.placeLayer); label.addTo(this.placeLayer);
                this.places[p.id] = { circle: c, label, key };
            }
            for (const id of Object.keys(this.places)) {
                if (!seen.has(id)) {
                    this.placeLayer.removeLayer(this.places[id].circle);
                    this.placeLayer.removeLayer(this.places[id].label);
                    delete this.places[id];
                }
            }
        },

        clear() {
            this.memberLayer?.clearLayers(); this.placeLayer?.clearLayers(); this.trailLayer?.clearLayers();
            this.members = {}; this.places = {};
        },

        focus(x, y, zoom = -1) {
            if (!this.map) return;
            this.map.flyTo([y, x], Math.max(zoom, this.map.getZoom()), { duration: 0.6 });
        },

        fitMembers() {
            const pts = (circle()?.members || []).filter((m) => hasPos(m) && (m.sharing || m.isMe)).map((m) => [m.y, m.x]);
            if (!this.map || pts.length === 0) return;
            if (pts.length === 1) return this.map.setView(pts[0], -1);
            this.map.fitBounds(L.latLngBounds(pts), { paddingTopLeft: [40, 90], paddingBottomRight: [40, 200], maxZoom: -1 });
        },

        showTrail(points, color) {
            this.trailLayer.clearLayers();
            if (!points.length) return;
            const ll = points.map((p) => [p[1], p[0]]);
            L.polyline(ll, { color, weight: 4, opacity: 0.85, lineJoin: 'round', dashArray: '1 8', lineCap: 'round' }).addTo(this.trailLayer);
            L.polyline(ll, { color, weight: 3, opacity: 0.5 }).addTo(this.trailLayer);
            L.circleMarker(ll[0], { radius: 5, color: '#fff', weight: 2, fillColor: color, fillOpacity: 1 }).addTo(this.trailLayer);
            if (ll.length > 1) this.map.fitBounds(L.latLngBounds(ll), { paddingTopLeft: [40, 130], paddingBottomRight: [40, 200], maxZoom: -0.5 });
            else this.map.setView(ll[0], -1);
        },

        flashAt(x, y) {
            if (this.flash) this.map.removeLayer(this.flash);
            this.flash = L.marker([y, x], { icon: L.divIcon({ className: 'flash-pin', html: '<div></div>', iconSize: [0, 0] }), zIndexOffset: 2000 }).addTo(this.map);
            setTimeout(() => { if (this.flash) { this.map.removeLayer(this.flash); this.flash = null; } }, 8000);
            this.focus(x, y, -0.5);
        },

        startPick(radius) {
            const c = this.map.getCenter();
            this.pickCircle = L.circle(c, { radius, color: '#fff', weight: 2, dashArray: '6 6', fillOpacity: 0.12, interactive: false }).addTo(this.map);
        },
        updatePick() { if (this.pickCircle) this.pickCircle.setLatLng(this.map.getCenter()); },
        endPick() {
            if (!this.pickCircle) return null;
            const c = this.map.getCenter();
            this.map.removeLayer(this.pickCircle);
            this.pickCircle = null;
            return { x: c.lng, y: c.lat };
        },
    };

    // ------------------------------------------------------------------
    // Rendering
    // ------------------------------------------------------------------
    function showScreen(name) {
        for (const s of ['welcome', 'main', 'loading']) $('screen-' + s).hidden = s !== name;
    }

    function render() {
        const d = state.data;
        if (!d) return;
        if (!d.circle) {
            showScreen('welcome');
            return;
        }
        showScreen('main');
        MapView.init(d.settings);
        const c = d.circle;
        if (state.lastCircle !== c.id) {
            state.lastCircle = c.id;
            state.renderKeys = {};
            MapView.clear();
            clearTrail();
        }

        $('circle-name').textContent = c.name;
        $('paused-pill').hidden = c.sharing;
        renderMembers();
        renderPlaces();
        renderActivity();
        renderCircle();
        MapView.syncMembers(c.members);
        MapView.syncPlaces(c.places);
        if (state.fitted !== c.id) {
            state.fitted = c.id;
            setTimeout(() => { MapView.resize(); MapView.fitMembers(); }, 50);
        }
        if (state.sheet?.type === 'member') renderMemberSheet(state.sheet.id);
    }

    function memberRow(m, action = 'open-member') {
        const st = statusOf(m);
        const side = sideText(m);
        const dot = st.dot || (m.online ? 'on' : '');
        return `<button class="item" data-action="${action}" data-id="${esc(m.citizenid)}">
            ${avatar(m, m.online || m.isMe ? '' : 'off', dot)}
            <div class="item-main">
                <div class="item-title"><span>${esc(m.name)}</span>${m.isMe ? '<span class="badge">You</span>' : ''}</div>
                <div class="item-sub ${st.cls || ''}">${esc(st.text)}</div>
            </div>
            ${side ? `<div class="item-side">${esc(side)}</div>` : ''}
        </button>`;
    }

    function renderMembers() {
        const c = circle();
        const rows = c.members.map((m) => [statusOf(m).text, sideText(m), m.online, m.isMe, m.name]);
        if (!changed('members', rows)) return;
        const list = c.members.map((m) => memberRow(m)).join('');
        const invite = c.members.length < 2
            ? `<div class="empty small">Nobody else here yet. Share code <b>${esc(c.code)}</b> from the Circle tab.</div>` : '';
        $('members-list').innerHTML = list + invite;
    }

    function renderPlaces() {
        const c = circle();
        const here = {};
        for (const m of c.members) if (m.online && m.place) { const k = m.place.id ?? m.place.name; (here[k] = here[k] || []).push(m.name.split(' ')[0]); }
        if (!changed('places', [c.places, here])) return;
        if (!c.places.length) {
            $('places-list').innerHTML = `<div class="empty">No places yet.<br>Add Home, Work or School to get arrival alerts.</div>`;
            return;
        }
        $('places-list').innerHTML = c.places.map((p) => {
            const who = here[p.id] || here[p.name] || [];
            return `<button class="item" data-action="open-place" data-id="${p.id}">
                <div class="place-icon">${icon(p.icon)}</div>
                <div class="item-main">
                    <div class="item-title"><span>${esc(p.name)}</span></div>
                    <div class="item-sub">${who.length ? esc(who.join(', ')) + ' here now' : distText(p.radius) + ' radius'}</div>
                </div>
            </button>`;
        }).join('');
    }

    const EVENT_META = {
        arrived: { icon: 'in', cls: 'arrived', text: (e) => `arrived at <b>${esc(e.place)}</b>` },
        left: { icon: 'out', cls: 'left', text: (e) => `left <b>${esc(e.place)}</b>` },
        checkin: { icon: 'check', cls: 'checkin', text: () => 'checked in' },
        sos: { icon: 'sos', cls: 'urgent', text: () => 'sent an <b>SOS</b>' },
        crash: { icon: 'car', cls: 'urgent', text: () => 'may have been in a <b>crash</b>' },
        downed: { icon: 'heart', cls: 'urgent', text: () => '<b>may need help</b>' },
        joined: { icon: 'join', cls: '', text: () => 'joined the circle' },
        left_circle: { icon: 'out', cls: '', text: () => 'left the circle' },
    };

    function renderActivity() {
        const c = circle();
        const events = c.events || [];
        const newest = events[0]?.id || 0;
        const seen = Number(store('seen:' + c.id)) || 0;
        $('activity-badge').hidden = state.view === 'activity' || newest <= seen;
        if (state.view === 'activity' && newest > seen) store('seen:' + c.id, newest);
        if (!changed('activity', events.map((e) => e.id).concat(Math.floor(serverNow() / 60)))) return;

        if (!events.length) {
            $('activity-list').innerHTML = '<div class="empty">Nothing yet. Arrivals, departures, check-ins and alerts show up here.</div>';
            return;
        }
        let html = '', lastDay = '';
        for (const e of events) {
            const day = dayLabel(e.created_at);
            if (day !== lastDay) { html += `<div class="day-head">${esc(day)}</div>`; lastDay = day; }
            const meta = EVENT_META[e.kind] || { icon: 'pin', cls: '', text: () => esc(e.kind) };
            const sub = [clock(e.created_at), e.message].filter(Boolean).map(esc).join(' · ');
            const hasXY = typeof e.x === 'number';
            html += `<div class="item" ${hasXY ? `data-action="event-map" data-x="${e.x}" data-y="${e.y}"` : ''}>
                <div class="ev-icon ${meta.cls}">${icon(meta.icon)}</div>
                <div class="item-main">
                    <div class="item-title" style="font-weight:500;display:block;white-space:normal"><b>${esc(e.name)}</b> ${meta.text(e)}</div>
                    <div class="item-sub">${sub}</div>
                </div>
                ${hasXY && meta.cls === 'urgent' ? `<button class="btn ghost small" data-action="event-gps" data-x="${e.x}" data-y="${e.y}">GPS</button>` : ''}
            </div>`;
        }
        $('activity-list').innerHTML = html;
    }

    function renderCircle() {
        const c = circle();
        $('circle-title').textContent = c.name;
        $('invite-code').textContent = c.code;
        $('rename-btn').hidden = !c.isAdmin;
        $('new-code-btn').hidden = !c.isAdmin;
        $('delete-btn').hidden = !c.isAdmin;
        $('toggle-sharing').checked = c.sharing;
        $('toggle-notify').checked = c.notify;
        $('members-title').textContent = `Members (${c.members.length}/${state.data.settings.maxMembers})`;
        const rows = c.members.map((m) => [m.citizenid, m.name, m.role, m.isMe, c.isAdmin]);
        if (!changed('circle-members', rows)) return;
        $('circle-members').innerHTML = c.members.map((m) => `
            <div class="item">
                ${avatar(m)}
                <div class="item-main">
                    <div class="item-title"><span>${esc(m.name)}</span>${m.isMe ? '<span class="badge">You</span>' : ''}</div>
                    <div class="item-sub">${m.role === 'admin' ? 'Admin' : 'Member'}</div>
                </div>
                ${c.isAdmin && !m.isMe ? `<button class="btn danger small" data-action="remove-member" data-id="${esc(m.citizenid)}">Remove</button>` : ''}
            </div>`).join('');
    }

    // ------------------------------------------------------------------
    // Navigation
    // ------------------------------------------------------------------
    function setView(view) {
        state.view = view;
        document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.view === view));
        document.querySelectorAll('.view').forEach((v) => v.classList.toggle('active', v.id === 'view-' + view));
        if (view === 'map') setTimeout(() => MapView.resize(), 0);
        if (view === 'activity') {
            state.renderKeys.activity = null;
            if (circle()) renderActivity();
        }
    }

    // ------------------------------------------------------------------
    // Modal sheet
    // ------------------------------------------------------------------
    function openSheet(html, type = 'generic', id = null) {
        $('sheet-body').innerHTML = html;
        $('sheet').hidden = false;
        $('backdrop').hidden = false;
        $('sheet').scrollTop = 0;
        state.sheet = { type, id };
        const first = $('sheet-body').querySelector('input[autofocus]');
        if (first) setTimeout(() => first.focus(), 250);
    }
    function closeSheet() {
        $('sheet').hidden = true;
        $('backdrop').hidden = true;
        state.sheet = null;
        if (sheetResolve) { sheetResolve(null); sheetResolve = null; }
    }

    let sheetResolve = null;
    /** Text prompt in a bottom sheet. Resolves with the trimmed text or null. */
    function prompt({ title, lead = '', placeholder = '', value = '', confirm = 'Save', maxLength = 40, code = false, type = 'text' }) {
        return new Promise((resolve) => {
            openSheet(`
                <h3>${esc(title)}</h3>
                ${lead ? `<p class="lead">${lead}</p>` : ''}
                <form id="prompt-form">
                    <div class="field">
                        <input class="input ${code ? 'code-input' : ''}" id="prompt-input" type="${type}" maxlength="${maxLength}"
                            placeholder="${esc(placeholder)}" value="${esc(value)}" autocomplete="off" autofocus>
                    </div>
                    <div class="actions">
                        <button type="button" class="btn ghost" data-action="close-sheet">Cancel</button>
                        <button type="submit" class="btn primary">${esc(confirm)}</button>
                    </div>
                </form>`, 'prompt');
            sheetResolve = resolve;
            $('prompt-form').addEventListener('submit', (ev) => {
                ev.preventDefault();
                const v = $('prompt-input').value.trim();
                if (!v) return;
                sheetResolve = null;
                closeSheet();
                resolve(v);
            });
        });
    }

    function confirmSheet({ title, lead, confirm = 'Confirm', danger = false }) {
        return new Promise((resolve) => {
            openSheet(`
                <h3>${esc(title)}</h3>
                <p class="lead">${lead}</p>
                <div class="actions">
                    <button class="btn ghost" data-action="close-sheet">Cancel</button>
                    <button class="btn ${danger ? 'danger solid' : 'primary'}" id="confirm-yes">${esc(confirm)}</button>
                </div>`, 'confirm');
            sheetResolve = resolve;
            $('confirm-yes').addEventListener('click', () => {
                sheetResolve = null;
                closeSheet();
                resolve(true);
            });
        });
    }

    // ------------------------------------------------------------------
    // Members
    // ------------------------------------------------------------------
    function openMember(cid) {
        renderMemberSheet(cid, true);
        const m = memberById(cid);
        if (hasPos(m) && (m.sharing || m.isMe) && state.view === 'map') MapView.focus(m.x, m.y, -1);
    }

    function renderMemberSheet(cid, open = false) {
        const m = memberById(cid);
        if (!m) { if (!open) closeSheet(); return; }
        const st = statusOf(m);
        const mine = me();
        const visible = (m.sharing || m.isMe) && hasPos(m);
        const stats = [];
        if (visible && !m.isMe && hasPos(mine)) stats.push(['Distance', distText(dist(m, mine))]);
        if (m.online && m.driving) stats.push(['Speed', speedText(m.speed || 0)]);
        if (visible && m.zone) stats.push(['Area', m.zone]);
        if (m.updated) stats.push(['Updated', ago(m.updated)]);
        const c = circle();
        const html = `
            <div class="profile">
                ${avatar(m, 'lg' + (m.online || m.isMe ? '' : ' off'), st.dot || (m.online ? 'on' : ''))}
                <div class="name">${esc(m.name)}</div>
                <div class="${st.cls === 'alert' ? 'item-sub alert' : 'muted'}">${esc(st.text)}</div>
            </div>
            ${stats.length ? `<div class="stat-row">${stats.slice(0, 4).map(([k, v]) => `<div class="stat"><span class="muted small">${k}</span><b>${esc(v)}</b></div>`).join('')}</div>` : ''}
            <div class="stack">
                ${visible && !m.isMe ? `<button class="btn primary block" data-action="member-gps" data-id="${esc(m.citizenid)}">${icon('nav')} Directions</button>` : ''}
                ${visible && state.data.settings.history ? `<button class="btn ghost block" data-action="member-trail" data-id="${esc(m.citizenid)}">${icon('history')} Location history</button>` : ''}
                ${m.isMe ? `<button class="btn ghost block" data-action="goto-settings">${c.sharing ? 'Pause sharing in this circle' : 'Resume sharing'}</button>` : ''}
                ${c.isAdmin && !m.isMe ? `<button class="btn danger block" data-action="remove-member" data-id="${esc(m.citizenid)}">Remove from circle</button>` : ''}
            </div>`;
        if (open || state.sheet?.type === 'member') {
            if (open) openSheet(html, 'member', cid);
            else $('sheet-body').innerHTML = html;
        }
    }

    async function showTrail(cid) {
        const m = memberById(cid);
        const res = await act('getTrail', { citizenid: cid });
        if (!res) return;
        closeSheet();
        setView('map');
        state.trail = { citizenid: cid, name: m?.name || '' };
        $('trail-bar').hidden = false;
        const first = m?.name.split(' ')[0] || '';
        const mins = res.points.length > 1 ? Math.round((serverNow() - res.points[0][2]) / 60) : 0;
        $('trail-label').textContent = res.points.length < 2 ? `${first} hasn't moved recently`
            : mins < 2 ? `${first}: last few minutes` : `${first}: last ${mins} min`;
        MapView.showTrail(res.points, colorFor(cid));
    }

    function clearTrail() {
        state.trail = null;
        $('trail-bar').hidden = true;
        MapView.trailLayer?.clearLayers();
    }

    // ------------------------------------------------------------------
    // Places
    // ------------------------------------------------------------------
    function placeForm(form) {
        const s = state.data.settings.places;
        const editing = !!form.id;
        const chips = s.icons.map((i) => `<button type="button" class="chip ${form.icon === i ? 'active' : ''}" data-action="pf-icon" data-id="${i}">${icon(i)}</button>`).join('');
        const where = editing ? '' : `
            <div class="field">
                <label>Location</label>
                <div class="seg">
                    <button type="button" class="${form.mode === 'here' ? 'active' : ''}" data-action="pf-mode" data-id="here">My location</button>
                    <button type="button" class="${form.mode === 'map' ? 'active' : ''}" data-action="pf-mode" data-id="map">${form.x != null ? 'Picked on map ✓' : 'Pick on map'}</button>
                </div>
            </div>`;
        openSheet(`
            <h3>${editing ? 'Edit place' : 'Add a place'}</h3>
            <form id="place-form">
                <div class="field">
                    <label>Name</label>
                    <input class="input" id="pf-name" maxlength="24" placeholder="Home, Work, School…" value="${esc(form.name)}" autocomplete="off">
                </div>
                <div class="field"><label>Icon</label><div class="chips">${chips}</div></div>
                ${where}
                <div class="field">
                    <label>Radius: <span id="pf-radius-label">${distText(form.radius)}</span></label>
                    <input type="range" id="pf-radius" min="${s.minRadius}" max="${s.maxRadius}" step="5" value="${form.radius}">
                </div>
                <div class="actions">
                    <button type="button" class="btn ghost" data-action="close-sheet">Cancel</button>
                    <button type="submit" class="btn primary">${editing ? 'Save' : 'Add place'}</button>
                </div>
                ${editing ? `
                <div class="stack" style="margin-top:14px">
                    <div class="row">
                        <button type="button" class="btn ghost small" style="flex:1" data-action="place-map" data-id="${form.id}">Show on map</button>
                        <button type="button" class="btn ghost small" style="flex:1" data-action="place-gps" data-id="${form.id}">Set GPS</button>
                    </div>
                    <button type="button" class="btn danger block" data-action="place-delete" data-id="${form.id}">Delete place</button>
                </div>` : ''}
            </form>`, 'place');
        state.placeForm = form;
        $('pf-name').addEventListener('input', (e) => (form.name = e.target.value));
        $('pf-radius').addEventListener('input', (e) => {
            form.radius = Number(e.target.value);
            $('pf-radius-label').textContent = distText(form.radius);
        });
        $('place-form').addEventListener('submit', (e) => { e.preventDefault(); savePlace(form); });
    }

    async function savePlace(form) {
        form.name = form.name.trim();
        if (!form.name) return toast('Give the place a name', false);
        const c = circle();
        let ok;
        if (form.id) {
            ok = await act('updatePlace', { circleId: c.id, placeId: form.id, place: { name: form.name, icon: form.icon, radius: form.radius } }, 'Place saved');
        } else {
            if (form.mode === 'map' && form.x == null) return toast('Pick a spot on the map first', false);
            const place = { name: form.name, icon: form.icon, radius: form.radius };
            if (form.mode === 'here') place.here = true;
            else Object.assign(place, { x: form.x, y: form.y });
            ok = await act('addPlace', { circleId: c.id, place }, `${form.name} added`);
        }
        if (ok) { closeSheet(); refresh(); }
    }

    function openPlace(id) {
        const p = placeById(id);
        if (!p) return;
        placeForm({ id: p.id, name: p.name, icon: p.icon, radius: p.radius });
    }

    function startPick(form) {
        state.picking = form;
        closeSheet();
        setView('map');
        $('members-sheet').hidden = true;
        $('pick-overlay').hidden = false;
        MapView.startPick(form.radius);
    }

    function endPick(confirmed) {
        const form = state.picking;
        state.picking = null;
        const pos = MapView.endPick();
        $('members-sheet').hidden = false;
        $('pick-overlay').hidden = true;
        if (!form) return;
        if (confirmed && pos) Object.assign(form, { x: pos.x, y: pos.y, mode: 'map' });
        else if (form.x == null) form.mode = 'here';
        placeForm(form);
    }

    // ------------------------------------------------------------------
    // Circle switcher / create / join
    // ------------------------------------------------------------------
    function openSwitcher() {
        const list = state.data.circles.map((c) => `
            <button class="item circle-opt ${c.id === circle()?.id ? 'active' : ''}" data-action="pick-circle" data-id="${c.id}">
                <div class="item-main">
                    <div class="item-title"><span>${esc(c.name)}</span>${c.role === 'admin' ? '<span class="badge accent">Admin</span>' : ''}</div>
                    <div class="item-sub">${c.members} member${c.members === 1 ? '' : 's'}</div>
                </div>
                ${c.id === circle()?.id ? `<span class="check">${icon('check2')}</span>` : ''}
            </button>`).join('');
        openSheet(`
            <h3>Your circles</h3>
            <div class="list" style="margin:10px 0 14px">${list}</div>
            <div class="row">
                <button class="btn ghost" style="flex:1" data-action="create-circle">Create</button>
                <button class="btn ghost" style="flex:1" data-action="join-circle">Join</button>
            </div>`, 'switcher');
    }

    function selectCircle(id) {
        state.circleId = id;
        store('circle', String(id));
        refresh();
    }

    async function createCircle() {
        const name = await prompt({
            title: 'Create a circle',
            lead: 'Name it after the people in it, like "Family" or "The Crew".',
            placeholder: 'Family',
            confirm: 'Create',
            maxLength: state.data?.settings?.nameMax || 24,
        });
        if (!name) return;
        const res = await act('createCircle', { name }, `${name} created`);
        if (res) selectCircle(res.id);
    }

    async function joinCircle() {
        const code = await prompt({
            title: 'Join a circle',
            lead: 'Enter the invite code someone shared with you.',
            placeholder: 'ABC123',
            confirm: 'Join',
            maxLength: 12,
            code: true,
        });
        if (!code) return;
        const res = await act('joinCircle', { code }, null);
        if (res) {
            toast(`Joined ${res.name}`);
            selectCircle(res.id);
        }
    }

    // ------------------------------------------------------------------
    // Check-in / SOS
    // ------------------------------------------------------------------
    function openCheckIn() {
        const m = me();
        const where = m?.place ? m.place.name : (m?.street ? `${m.street}${m.zone ? ', ' + m.zone : ''}` : 'your current location');
        openSheet(`
            <h3>Check in</h3>
            <p class="lead">Let ${esc(circle().name)} know you're at <b>${esc(where)}</b>.</p>
            <form id="checkin-form">
                <div class="field"><input class="input" id="checkin-msg" maxlength="80" placeholder="Add a message (optional)" autocomplete="off"></div>
                <div class="actions">
                    <button type="button" class="btn ghost" data-action="close-sheet">Cancel</button>
                    <button type="submit" class="btn primary">Check in</button>
                </div>
            </form>`, 'checkin');
        $('checkin-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const res = await act('checkIn', { circleId: circle().id, message: $('checkin-msg').value.trim() }, 'Checked in');
            if (res) { closeSheet(); refresh(); }
        });
    }

    function setupSOS() {
        const btn = $('sos-btn');
        const HOLD = 1500;
        let timer = null;
        btn.style.setProperty('--hold', HOLD / 1000 + 's');
        const cancel = () => {
            clearTimeout(timer);
            timer = null;
            btn.classList.remove('holding');
        };
        btn.addEventListener('pointerdown', (e) => {
            e.preventDefault();
            btn.classList.add('holding');
            timer = setTimeout(async () => {
                cancel();
                const res = await act('sos', {}, null);
                if (res) toast('SOS sent to all your circles');
                refresh();
            }, HOLD);
        });
        ['pointerup', 'pointerleave', 'pointercancel'].forEach((ev) => btn.addEventListener(ev, cancel));
        btn.addEventListener('click', () => { if (!timer) toast('Hold the button to send an SOS'); });
    }

    // ------------------------------------------------------------------
    // Actions (event delegation)
    // ------------------------------------------------------------------
    const actions = {
        'close-sheet': closeSheet,
        'create-circle': createCircle,
        'join-circle': joinCircle,
        'switch-circle': openSwitcher,
        'pick-circle': (el) => { closeSheet(); selectCircle(Number(el.dataset.id)); },
        'check-in': openCheckIn,
        'fit-all': () => { clearTrail(); MapView.fitMembers(); },
        'focus-me': () => { const m = me(); if (hasPos(m)) MapView.focus(m.x, m.y, -0.5); else toast('Your location is not available yet', false); },
        'toggle-members': () => $('members-sheet').classList.toggle('expanded'),
        'open-member': (el) => openMember(el.dataset.id),
        'member-gps': async (el) => { if (await act('waypoint', { citizenid: el.dataset.id })) closeSheet(); },
        'member-trail': (el) => showTrail(el.dataset.id),
        'clear-trail': () => { clearTrail(); MapView.fitMembers(); },
        'goto-settings': () => { closeSheet(); setView('circle'); },
        'remove-member': async (el) => {
            const m = memberById(el.dataset.id);
            if (!m) return;
            const yes = await confirmSheet({ title: `Remove ${m.name}?`, lead: 'They will stop seeing this circle and you will stop seeing their location.', confirm: 'Remove', danger: true });
            if (yes && await act('removeMember', { circleId: circle().id, citizenid: m.citizenid }, `${m.name} removed`)) refresh();
        },

        'add-place': () => {
            const s = state.data.settings.places;
            placeForm({ name: '', icon: s.icons[0] || 'home', radius: s.defaultRadius, mode: 'here', x: null, y: null });
        },
        'open-place': (el) => openPlace(Number(el.dataset.id)),
        'pf-icon': (el) => {
            state.placeForm.icon = el.dataset.id;
            el.parentElement.querySelectorAll('.chip').forEach((c) => c.classList.toggle('active', c === el));
        },
        'pf-mode': (el) => {
            const form = state.placeForm;
            if (el.dataset.id === 'map') return startPick(form);
            form.mode = 'here';
            form.x = form.y = null;
            el.parentElement.querySelectorAll('button').forEach((b) => b.classList.toggle('active', b === el));
            el.nextElementSibling.textContent = 'Pick on map';
        },
        'pick-cancel': () => endPick(false),
        'pick-confirm': () => endPick(true),
        'place-map': (el) => {
            const p = placeById(Number(el.dataset.id));
            closeSheet(); setView('map');
            if (p) MapView.focus(p.x, p.y, -0.5);
        },
        'place-gps': async (el) => {
            const p = placeById(Number(el.dataset.id));
            if (p && await act('waypointCoords', { x: p.x, y: p.y })) closeSheet();
        },
        'place-delete': async (el) => {
            const p = placeById(Number(el.dataset.id));
            if (!p) return;
            const yes = await confirmSheet({ title: `Delete ${p.name}?`, lead: 'Nobody will get alerts for this place anymore.', confirm: 'Delete', danger: true });
            if (yes && await act('deletePlace', { circleId: circle().id, placeId: p.id }, `${p.name} deleted`)) refresh();
        },

        'event-map': (el) => { setView('map'); MapView.flashAt(Number(el.dataset.x), Number(el.dataset.y)); },
        'event-gps': (el) => act('waypointCoords', { x: Number(el.dataset.x), y: Number(el.dataset.y) }),

        'rename-circle': async () => {
            const name = await prompt({ title: 'Rename circle', value: circle().name, maxLength: state.data.settings.nameMax });
            if (name && await act('renameCircle', { circleId: circle().id, name }, 'Circle renamed')) refresh();
        },
        'copy-code': () => {
            const code = circle().code;
            if (IN_GAME) nui('copy', { text: code, label: 'Invite code copied' });
            else { navigator.clipboard?.writeText(code).catch(() => {}); toast('Invite code copied'); }
        },
        'new-code': async () => {
            const yes = await confirmSheet({ title: 'Make a new invite code?', lead: 'The current code will stop working. People already in the circle stay in.', confirm: 'New code' });
            if (yes && await act('newInviteCode', { circleId: circle().id }, 'New code created')) refresh();
        },
        'invite-phone': async () => {
            const number = await prompt({ title: 'Text an invite', lead: 'They get a text with the invite code. Only works if they are in the city right now.', placeholder: 'Phone number', confirm: 'Send', type: 'tel', maxLength: 20 });
            if (number) await act('invitePhone', { circleId: circle().id, number }, 'Invite sent');
        },
        'leave-circle': async () => {
            const c = circle();
            const yes = await confirmSheet({ title: `Leave ${c.name}?`, lead: 'You will stop sharing your location with this circle. You can rejoin with an invite code.', confirm: 'Leave', danger: true });
            if (yes && await act('leaveCircle', { circleId: c.id }, `You left ${c.name}`)) { state.circleId = null; setView('map'); refresh(); }
        },
        'delete-circle': async () => {
            const c = circle();
            const yes = await confirmSheet({ title: `Delete ${c.name}?`, lead: 'This removes the circle, its places and its history for everyone. This cannot be undone.', confirm: 'Delete', danger: true });
            if (yes && await act('deleteCircle', { circleId: c.id }, `${c.name} deleted`)) { state.circleId = null; setView('map'); refresh(); }
        },
    };

    document.addEventListener('click', (e) => {
        const tab = e.target.closest('.tab');
        if (tab) return setView(tab.dataset.view);
        const el = e.target.closest('[data-action]');
        if (!el) return;
        const fn = actions[el.dataset.action];
        if (fn) { e.preventDefault(); fn(el); }
    });
    $('backdrop').addEventListener('click', closeSheet);

    $('toggle-sharing').addEventListener('change', async (e) => {
        const value = e.target.checked;
        const ok = await act('setFlag', { circleId: circle().id, flag: 'sharing', value }, value ? 'Sharing your location' : 'Location paused for this circle');
        if (!ok) e.target.checked = !value;
        refresh();
    });
    $('toggle-notify').addEventListener('change', async (e) => {
        const value = e.target.checked;
        const ok = await act('setFlag', { circleId: circle().id, flag: 'notify', value }, value ? 'Notifications on' : 'Notifications off');
        if (!ok) e.target.checked = !value;
        refresh();
    });

    // ------------------------------------------------------------------
    // Data loop
    // ------------------------------------------------------------------
    let appVisible = true; // flipped by the phone bridge's app:opened / app:closed events
    let refreshing = false;
    let pollTimer = null;

    async function refresh() {
        if (refreshing) return;
        refreshing = true;
        try {
            const res = await nui('getState', { circleId: state.circleId, force: !state.data });
            if (res?.closed) return; // phone is closed, nothing to update
            if (!res || !res.ok) {
                if (!state.data) {
                    showScreen('loading');
                    $('loading-msg').textContent = res?.error || 'Could not reach the server.';
                }
                return;
            }
            clockSkew = res.now - Date.now() / 1000;
            state.data = res;
            if (res.circle && res.circle.id !== state.circleId) {
                state.circleId = res.circle.id;
                store('circle', String(res.circle.id));
            }
            render();
        } finally {
            refreshing = false;
        }
    }

    function schedule() {
        clearTimeout(pollTimer);
        const ms = state.data?.settings?.refreshMs || 3000;
        pollTimer = setTimeout(async () => {
            if (!document.hidden && appVisible) await refresh();
            schedule();
        }, ms);
    }

    document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });

    // ------------------------------------------------------------------
    // Optional Quasar bridge: theme + "app opened" refresh
    // ------------------------------------------------------------------
    function setTheme(mode) {
        const m = typeof mode === 'string' ? mode : mode?.mode || mode?.theme;
        if (m === 'light' || m === 'dark') document.documentElement.dataset.theme = m;
    }

    function setupBridge() {
        if (!window.QSPhoneBridge) return;
        try {
            const { bridge, api } = window.QSPhoneBridge.create({
                appId: 'bdev-hearth', // keep in sync with Config.App.name
                targetOrigin: 'https://cfx-nui-qs-smartphone',
            });
            const init = () => Promise.resolve(api.getThemeMode?.()).then(setTheme).catch(() => {});
            if (api.onReady) api.onReady(init); else init();
            bridge.onEvent?.((event, data) => {
                if (event === 'phone.theme.changed') setTheme(data);
                if (event === 'app:opened') { appVisible = true; refresh(); }
                if (event === 'app:closed') appVisible = false;
            });
        } catch (e) {
            console.warn('[hearth] phone bridge unavailable', e);
        }
    }

    if (!IN_GAME && matchMedia('(prefers-color-scheme: light)').matches) setTheme('light');
    setupBridge();
    setupSOS();
    refresh().then(schedule);
})();
