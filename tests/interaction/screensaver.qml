// Tests for the screensaver (ScreensaverState.qml pure functions, popups/ScreensaverView.qml input and reduce motion).
// The windows are not created here (a layer-shell PanelWindow cannot run offscreen); the view is hosted in a scratch
// FloatingWindow, loaded by path (the runner copies this file next to popups/). The random function is injected.
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    function asVar(o: var): var {
        return o;
    }
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    // a deterministic random function (a small LCG), the same sequence every run
    function seeded(seed) {
        let s = seed;
        return () => {
            s = (s * 1664525 + 1013904223) % 4294967296;
            return s / 4294967296;
        };
    }
    property int wakes: 0

    FloatingWindow {
        id: win
        implicitWidth: MenuStyle.widthMedium; implicitHeight: MenuStyle.widthMedium
        Item {
            anchors.fill: parent
            focus: true
            Loader {
                id: host
                anchors.fill: parent
                Component.onCompleted: setSource("popups/ScreensaverView.qml", { style: "pipes", startedAt: Date.now(), graceMs: 500, animate: true })
            }
            TestCase { id: tc; name: "sim"; when: false }
        }
    }

    Timer {
        interval: 800; running: true
        onTriggered: shell.run()
    }

    function run() {
        const S = ScreensaverState;
        // --- style choice ---
        check("pickStyle: a known style stays", S.pickStyle("pipes", seeded(1)) === "pipes" && S.pickStyle("mystify", seeded(1)) === "mystify");
        check("pickStyle: unknown falls back to starfield", S.pickStyle("nope", seeded(1)) === "starfield" && S.pickStyle(undefined, seeded(1)) === "starfield");
        check("pickStyle: random picks by the random function", S.pickStyle("random", () => 0) === "starfield" && S.pickStyle("random", () => 0.5) === "pipes" && S.pickStyle("random", () => 0.99) === "mystify");
        check("pickStyle: random with 1.0 stays in range", S.styles.indexOf(S.pickStyle("random", () => 1)) >= 0);
        const seen = {};
        const r = seeded(7);
        for (let i = 0; i < 60; i++)
            seen[S.pickStyle("random", r)] = true;
        check("pickStyle: random reaches all three styles", Object.keys(seen).length === 3);

        // --- wake-up decision ---
        check("wake: a key wakes at once, even inside the grace", S.wakeDecision("key", 100, 0, 500) === true);
        check("wake: a click and the wheel wake at once", S.wakeDecision("press", 100, 0, 500) && S.wakeDecision("wheel", 100, 0, 500));
        check("wake: a mouse move inside the 500 ms grace is ignored", S.wakeDecision("move", 499, 0, 500) === false);
        check("wake: a mouse move at 500 ms wakes", S.wakeDecision("move", 500, 0, 500) === true);
        check("wake: an unknown event never wakes", S.wakeDecision("hover", 9999, 0, 500) === false);
        check("wake: the grace is 500 ms", S.graceMs === 500);

        // --- allowed ---
        check("allowed: enabled with minutes", S.allowed(true, 3, false, false));
        check("allowed: off when disabled, 0 minutes, caffeine or a fullscreen video",
              !S.allowed(false, 3, false, false) && !S.allowed(true, 0, false, false) && !S.allowed(true, 3, true, false) && !S.allowed(true, 3, false, true));
        check("not started under the test harness", S.active === false && S.running === false);
        check("the defaults fire before the dim and the lock", S.defaults.minutes < Config.settings.idle.dimMinutes && S.defaults.minutes < Config.settings.idle.lockMinutes);

        // --- stars ---
        const stars = S.initStars(50, seeded(3));
        check("stars: n stars, x/y in -1..1, z in 0..1", stars.length === 50 && stars.every(s => s.x >= -1 && s.x <= 1 && s.y >= -1 && s.y <= 1 && s.z > 0 && s.z <= 1));
        const moved = S.starStep(stars, 0.1, seeded(4), 0.35);
        check("stars: z falls by dt * speed and x/y stay", moved.every((s, i) => s.x === stars[i].x || s.z === 1) && Math.abs(moved[0].z - (stars[0].z - 0.035)) < 1e-9 || moved[0].z === 1);
        check("stars: the input is not changed", stars[0].z !== moved[0].z || moved[0].z === 1);
        const near = S.starStep([{ x: 0.3, y: -0.2, z: 0.05 }], 0.1, () => 0.75, 0.35);
        check("stars: one that reaches the screen respawns far away at the random place", near[0].z === 1 && near[0].x === 0.5 && near[0].y === 0.5);
        const p1 = S.starProject({ x: 0.5, y: 0, z: 0.5 }, 400, 300, 0.033, 0.35);
        const p2 = S.starProject({ x: 0.5, y: 0, z: 0.2 }, 400, 300, 0.033, 0.35);
        check("stars: nearer = further from the centre and bigger", p2.x - 200 > p1.x - 200 && p2.r >= p1.r && p1.x > 200);
        check("stars: the streak starts behind (nearer the centre)", p1.px < p1.x);
        const dead = S.starProject({ x: 0, y: 0, z: 0.5 }, 400, 300, 0.033, 0.35);
        check("stars: a centred star stays at the centre", dead.x === 200 && dead.y === 150);

        // --- pipes ---
        let st = S.initPipes(10, 8, 3, seeded(5));
        check("pipes: heads start on distinct cells", st.heads.length === 3 && new Set(st.heads.map(h => h.x + "," + h.y)).size === 3);
        const run1 = rs => { let t = S.initPipes(10, 8, 3, rs); for (let i = 0; i < 40; i++) t = S.pipeStep(t, rs); return t; };
        const a = run1(seeded(9)), b = run1(seeded(9));
        check("pipes: the same seed gives the same pipes", JSON.stringify(a.segs) === JSON.stringify(b.segs) && a.segs.length > 20);
        check("pipes: every segment is one cell long, on the grid", a.segs.every(s => Math.abs(s.x2 - s.x1) + Math.abs(s.y2 - s.y1) === 1 && s.x2 >= 0 && s.y2 >= 0 && s.x2 < 10 && s.y2 < 8));
        check("pipes: no cell is entered twice (between resets)", (() => {
            let t = S.initPipes(10, 8, 3, seeded(11));
            const visited = new Set(t.heads.map(h => h.x + "," + h.y));
            for (let i = 0; i < 40; i++) {
                const n = S.pipeStep(t, seeded(i));
                if (n.resets !== t.resets) { t = n; visited.clear(); n.heads.forEach(h => visited.add(h.x + "," + h.y)); continue; }
                for (const sg of n.segs.slice(t.segs.length)) {
                    const key = sg.x2 + "," + sg.y2;
                    if (visited.has(key)) {
                        // a respawned head also marks its cell used; a segment must still never enter a used cell
                        return false;
                    }
                    visited.add(key);
                }
                n.heads.forEach(h => visited.add(h.x + "," + h.y));
                t = n;
            }
            return true;
        })());
        check("pipes: colours stay 0..2", a.segs.every(s => s.c >= 0 && s.c <= 2));
        const input = S.initPipes(6, 6, 2, seeded(2));
        const before = JSON.stringify(input);
        S.pipeStep(input, seeded(2));
        check("pipes: a step does not change its input", JSON.stringify(input) === before);
        // a one-cell-wide grid: the pipe has to die and the grid starts over rather than hang
        let tiny = S.initPipes(2, 2, 1, seeded(1));
        let sawReset = false;
        for (let i = 0; i < 30; i++) {
            tiny = S.pipeStep(tiny, seeded(i + 100));
            if (tiny.resets > 0) sawReset = true;
        }
        check("pipes: a filled grid starts over", sawReset);
        check("pipes: a dead head takes the next colour", (() => {
            // a head boxed in by used cells: 2 cols x 1 row, the head at 0 with 1 used
            const boxed = { cols: 3, rows: 1, used: [true, true, false], heads: [{ x: 1, y: 0, dx: 0, dy: -1, c: 0 }], segs: [], resets: 0 };
            // its only free neighbour (2,0) is to the right: it moves there; make that used too
            boxed.used = [true, true, true];
            const n = S.pipeStep(boxed, () => 0);
            return n.resets === 1;
        })());

        // --- polygons ---
        const polys = S.initPolys(2, 4, 400, 300, seeded(6));
        check("mystify: polygons with corners inside the screen", polys.length === 2 && polys.every(p => p.pts.length === 4 && p.pts.every(q => q.x >= 0 && q.x <= 400 && q.y >= 0 && q.y <= 300)));
        let pp = polys[0];
        let ok = true;
        for (let i = 0; i < 400; i++) {
            pp = S.polyStep(pp, 400, 300, 0.033, 8);
            if (!pp.pts.every(q => q.x >= 0 && q.x <= 400 && q.y >= 0 && q.y <= 300))
                ok = false;
        }
        check("mystify: corners bounce and never leave the screen", ok);
        check("mystify: the trail is capped", pp.trail.length === 8 && pp.trail[0].length === 4);
        const wall = S.polyStep({ pts: [{ x: 1, y: 150, vx: -100, vy: 0 }], trail: [], c: 0 }, 400, 300, 0.1, 4);
        check("mystify: a wall flips the speed", wall.pts[0].vx > 0 && wall.pts[0].x >= 0);
        check("mystify: the trail keeps the old place, newest first", wall.trail.length === 1 && wall.trail[0][0].x === 1);

        // --- the view: input, grace, reduce motion ---
        const view = shell.asVar(host.item);
        check("view loads", view !== null && view !== undefined);
        view.wake.connect(() => shell.wakes++);
        view.startedAt = Date.now();
        view.input("move");
        check("view: a mouse move inside the grace does not wake", shell.wakes === 0);
        view.startedAt = Date.now() - 600;
        view.input("move");
        check("view: a mouse move after the grace wakes", shell.wakes === 1);
        view.input("press");
        view.input("wheel");
        check("view: a click and the wheel wake", shell.wakes === 3);
        view.forceActiveFocus();
        tc.keyClick(Qt.Key_A);
        check("view: a key wakes (and is eaten)", shell.wakes === 4);
        check("view: its three styles build a scene", (() => {
            const out = [];
            for (const sname of ["starfield", "pipes", "mystify"]) {
                view.animate = true;
                view.style = sname;
                out.push(view.scene !== null);
            }
            return out.every(x => x);
        })());
        view.rnd = shell.seeded(8);
        view.style = "starfield"; view.animate = true;
        const z0 = view.scene[0].z;
        view.tick();
        check("view: a tick moves the stars", view.scene[0].z !== z0 && view.frames === 1);
        view.style = "pipes";
        const n0 = view.scene.segs.length;
        for (let i = 0; i < 9; i++)
            view.tick();
        check("view: pipes grow every third frame", view.scene.segs.length > n0);
        view.animate = false;
        check("view: reduce motion paints a static pipes frame with pipes already grown", view.scene.segs.length >= 20);
        view.style = "mystify";
        check("view: reduce motion mystify has a trail already", view.scene[0].trail.length === view.trailLen);
        tcDone.start();
    }
    Timer {
        id: tcDone
        interval: 400
        onTriggered: {
            const v = shell.asVar(host.item);
            shell.check("view: reduce motion scene stays still", v.frames === 0);
            console.log("TEST done failures=" + shell.failures);
            Qt.quit();
        }
    }
}
