pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Win95-style screensaver (settings.screensaver: enabled, minutes, style). An IdleMonitor (respects idle inhibitors, so
// caffeine pauses it) fires after `minutes`, which must stay below idle.dimMinutes and idle.lockMinutes so it comes
// first. No screensaver while Idle.videoAwake (a fullscreen video or game) or Idle.caffeine. When it runs there is one
// ScreensaverWindow per screen (popups/ScreensaverWindow.qml). Any key, click, wheel or a mouse move after the grace
// period (graceMs, so the cursor's own jitter does not close it), or the monitor leaving idle, closes them all at once;
// the wake key is eaten by the window, not forwarded. `qs ipc call screensaver start|stop|preview`.
// Not started when QS_NO_APPLY is set (the test harness). The step functions are pure: they take the random function
// (rnd, 0..1) as an argument so tests are deterministic. A missing settings.screensaver group counts as the defaults.
Singleton {
    id: root

    readonly property var defaults: ({ enabled: true, minutes: 3, style: "starfield" })
    readonly property var cfg: Config.settings["screensaver"] || root.defaults
    readonly property bool active: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    readonly property var styles: ["starfield", "pipes", "mystify"]
    readonly property int graceMs: 500

    // "pipes3d" is xscreensaver's real 3D pipes, run as an XWayland window under our transparent catcher (which still
    // takes the wake input). Only offered when the binary exists; it is never part of "random". The hack's window is
    // made fullscreen by a rule in hypr/windowrules.lua (screensaver-pipes3d). Untested live: see FEATURES.md.
    readonly property string pipes3dPath: "/usr/lib/xscreensaver/pipes"
    property bool hasPipes3d: false
    Process {
        running: true
        command: ["test", "-x", root.pipes3dPath]
        onExited: code => root.hasPipes3d = (code === 0)
    }
    Process {
        id: pipes3dProc
        running: root.running && root.runStyle === "pipes3d"
        command: [root.pipes3dPath, "--window", "--no-fps", "--delay", "20000"]
    }

    property bool running: false
    property bool viaIdle: false          // started by the idle monitor (so leaving idle stops it); a preview is not
    property string runStyle: "starfield"
    property real startedAt: 0

    // --- pure helpers ---

    // The style for this run: a known name, "random" picks one, anything else is starfield
    function pickStyle(setting, rnd) {
        if (root.styles.indexOf(setting) >= 0 || (setting === "pipes3d" && root.hasPipes3d))
            return setting;
        if (setting === "random")
            return root.styles[Math.min(root.styles.length - 1, Math.floor(rnd() * root.styles.length))];
        return "starfield";
    }

    // Does this input wake the screensaver? Keys, clicks and the wheel always; a mouse move only after the grace period
    // (kind: "key" | "press" | "wheel" | "move").
    function wakeDecision(kind, now, startedAt, graceMs) {
        if (kind === "key" || kind === "press" || kind === "wheel")
            return true;
        if (kind === "move")
            return now - startedAt >= graceMs;
        return false;
    }

    // Is the screensaver wanted right now? (enabled, a positive time, no caffeine, no fullscreen video)
    function allowed(enabled, minutes, caffeine, videoAwake) {
        return enabled === true && minutes > 0 && !caffeine && !videoAwake;
    }

    // Starfield: x, y in -1..1 (direction), z in 0..1 (distance, 1 = far). A star flies at the screen as z falls.
    function initStars(n, rnd) {
        const out = [];
        for (let i = 0; i < n; i++)
            out.push({ x: rnd() * 2 - 1, y: rnd() * 2 - 1, z: 0.05 + rnd() * 0.95 });
        return out;
    }
    function starStep(stars, dt, rnd, speed) {
        return stars.map(s => {
            const z = s.z - dt * speed;
            if (z <= 0.04)
                return { x: rnd() * 2 - 1, y: rnd() * 2 - 1, z: 1 };
            return { x: s.x, y: s.y, z: z };
        });
    }
    // Screen position and size of a star on a w x h screen; "streak" is where it was (a short line behind it)
    function starProject(s, w, h, dt, speed) {
        const k = Math.max(w, h) / 2;
        const at = z => ({ x: Math.round(w / 2 + s.x / z * k * 0.15), y: Math.round(h / 2 + s.y / z * k * 0.15) });
        const p = at(s.z), q = at(Math.min(1, s.z + dt * speed));
        return { x: p.x, y: p.y, px: q.x, py: q.y, r: Math.max(1, Math.round((1 - s.z) * 3)), bright: 1 - s.z };
    }

    // Pipes: a cols x rows grid. Each head grows one cell per step, going straight or turning, never into a used cell or
    // off the grid. A stuck head dies and a new one starts on a free cell in the next colour (0..2); a nearly full
    // grid starts over. segs: [{ x1, y1, x2, y2, c }] in cell units.
    function initPipes(cols, rows, heads, rnd) {
        const used = new Array(cols * rows).fill(false);
        const hs = [];
        for (let i = 0; i < heads; i++) {
            const h = root.freshHead(cols, rows, used, i % 3, rnd);
            if (h)
                hs.push(h);
        }
        return { cols: cols, rows: rows, used: used, heads: hs, segs: [], resets: 0 };
    }
    function freshHead(cols, rows, used, c, rnd) {
        const n = cols * rows;
        const start = Math.min(n - 1, Math.floor(rnd() * n));
        for (let k = 0; k < n; k++) {
            const i = (start + k) % n;
            if (!used[i]) {
                used[i] = true;
                const d = [[1, 0], [-1, 0], [0, 1], [0, -1]][Math.min(3, Math.floor(rnd() * 4))];
                return { x: i % cols, y: Math.floor(i / cols), dx: d[0], dy: d[1], c: c };
            }
        }
        return null;
    }
    function pipeStep(st, rnd) {
        const cols = st.cols, rows = st.rows;
        const used = st.used.slice();
        const segs = st.segs.slice();
        const heads = [];
        let resets = st.resets;
        for (const h of st.heads) {
            const straight = [h.dx, h.dy], a = [h.dy, h.dx], b = [-h.dy, -h.dx];
            const perps = rnd() < 0.5 ? [a, b] : [b, a];
            const order = rnd() < 0.25 ? perps.concat([straight]) : [straight].concat(perps);
            let moved = null;
            for (const d of order) {
                const nx = h.x + d[0], ny = h.y + d[1];
                if (nx >= 0 && ny >= 0 && nx < cols && ny < rows && !used[ny * cols + nx]) {
                    moved = { x: nx, y: ny, dx: d[0], dy: d[1], c: h.c };
                    break;
                }
            }
            if (moved) {
                used[moved.y * cols + moved.x] = true;
                segs.push({ x1: h.x, y1: h.y, x2: moved.x, y2: moved.y, c: h.c });
                heads.push(moved);
            } else {
                const f = root.freshHead(cols, rows, used, (h.c + 1) % 3, rnd);
                if (f)
                    heads.push(f);
            }
        }
        let full = 0;
        for (const u of used)
            if (u)
                full++;
        if (heads.length === 0 || full > used.length * 0.8) {
            const fresh = root.initPipes(cols, rows, st.heads.length, rnd);
            fresh.resets = resets + 1;
            return fresh;
        }
        return { cols: cols, rows: rows, used: used, heads: heads, segs: segs, resets: resets };
    }

    // Mystify: polygons whose corners move and bounce off the screen edges; trail = the last positions, newest first.
    function initPolys(count, corners, w, h, rnd) {
        const out = [];
        for (let i = 0; i < count; i++) {
            const pts = [];
            for (let j = 0; j < corners; j++)
                pts.push({ x: rnd() * w, y: rnd() * h, vx: (rnd() < 0.5 ? -1 : 1) * (60 + rnd() * 120), vy: (rnd() < 0.5 ? -1 : 1) * (60 + rnd() * 120) });
            out.push({ pts: pts, trail: [], c: i % 2 === 0 ? 0 : 2 });
        }
        return out;
    }
    function polyStep(poly, w, h, dt, trailLen) {
        const snapshot = poly.pts.map(p => ({ x: p.x, y: p.y }));
        const pts = poly.pts.map(p => {
            let x = p.x + p.vx * dt, y = p.y + p.vy * dt, vx = p.vx, vy = p.vy;
            if (x < 0) { x = -x; vx = Math.abs(vx); }
            if (x > w) { x = 2 * w - x; vx = -Math.abs(vx); }
            if (y < 0) { y = -y; vy = Math.abs(vy); }
            if (y > h) { y = 2 * h - y; vy = -Math.abs(vy); }
            return { x: Math.max(0, Math.min(w, x)), y: Math.max(0, Math.min(h, y)), vx: vx, vy: vy };
        });
        return { pts: pts, trail: [snapshot].concat(poly.trail).slice(0, trailLen), c: poly.c };
    }

    // --- running ---

    function start() {
        root.begin(false);
    }
    function preview() {
        root.begin(false);
    }
    function begin(idle) {
        root.runStyle = root.pickStyle(root.cfg.style, Math.random);
        root.startedAt = Date.now();
        root.viaIdle = idle;
        root.running = true;
    }
    function stop() {
        root.running = false;
        root.viaIdle = false;
    }
    function toggle() {
        if (root.running)
            root.stop();
        else
            root.preview();
    }

    readonly property bool wanted: root.active && root.allowed(root.cfg.enabled, root.cfg.minutes, Idle.caffeine, Idle.videoAwake)
    // A fullscreen video or caffeine appearing while it runs ends it
    onWantedChanged: {
        if (!root.wanted && root.viaIdle)
            root.stop();
    }

    IdleMonitor {
        enabled: root.wanted
        respectInhibitors: true
        timeout: Math.max(1, root.cfg.minutes) * 60
        onIsIdleChanged: {
            if (isIdle && !root.running)
                root.begin(true);
            else if (!isIdle && root.viaIdle)
                root.stop();
        }
    }

    // One window per screen, created when it starts and destroyed when it stops (loaded by path: popups/qmldir is not mine)
    property var windows: []
    onRunningChanged: {
        if (root.running)
            root.openWindows();
        else
            root.closeWindows();
    }
    function openWindows() {
        const comp = Qt.createComponent(Qt.resolvedUrl("popups/ScreensaverWindow.qml"));
        if (comp.status !== Component.Ready) {
            console.warn("Screensaver: " + comp.errorString());
            root.running = false;
            return;
        }
        const list = [];
        for (const scr of Quickshell.screens) {
            const w = comp.createObject(root, { screen: scr, style: root.runStyle, startedAt: root.startedAt, graceMs: root.graceMs });
            if (w) {
                w.wake.connect(root.stop);
                list.push(w);
            }
        }
        root.windows = list;
    }
    function closeWindows() {
        const list = root.windows;
        root.windows = [];
        for (const w of list) {
            w.visible = false;
            w.destroy();
        }
    }
}
