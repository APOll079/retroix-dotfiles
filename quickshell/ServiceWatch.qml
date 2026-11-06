pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Failed-service toast (user dinit scope only). Polls `dinitctl --user list` every 10 s (one Process at a
// time), diffs the snapshots and raises one notify-send toast for each service that went from running to
// stopped or failed: "<name> stopped" with Restart / Details actions. Restart runs `dinitctl --user restart`;
// Details emits detailsRequested(name) (Bar.qml connects it to the Services panel's showDetails).
// Not newly seen services, and not ones the panel stopped on purpose (ServicesPanel calls expect(name) before
// Start / Stop / Restart). One toast per incident: re-armed when the service runs again or after 30 minutes.
// dinitctl missing = one quiet "unavailable" state, no polling. Not started when QS_NO_APPLY is set.
// parseList / diff / step / evaluate are pure, so tests can drive them without dinit.
Singleton {
    id: root

    readonly property bool active: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    readonly property int interval: 10000
    readonly property int rearmMs: 30 * 60000
    readonly property int expectMs: 60000

    property bool unavailable: false       // dinitctl isn't installed (or can't be started)
    property var prev: null                // last snapshot (null = none yet)
    property var gates: ({})               // name -> { armed, last }
    property var expected: ({})            // name -> ms when the panel acted on it

    signal detailsRequested(string name)

    // ---- pure helpers ----

    // `dinitctl list` text -> [{ name, state: running|stopped|other, failed, info }] sorted by name.
    // Expected as "[{+}     ] name (pid: 123)" per line. scope is accepted for the day the scopes differ.
    function parseList(text, scope) {
        const out = [];
        for (const line of String(text).split("\n")) {
            if (line.length < 11 || line[0] !== "[")
                continue;
            const flags = line.slice(1, 9);
            const rest = line.slice(10).trim();
            const sp = rest.search(/\s/);
            const name = sp < 0 ? rest : rest.slice(0, sp);
            const info = sp < 0 ? "" : rest.slice(sp).trim().replace(/^\(|\)$/g, "");
            if (name === "")
                continue;
            out.push({
                name: name,
                state: flags.includes("+") ? "running" : flags.includes("-") ? "stopped" : "other",
                failed: /fail|exit status/i.test(info),
                info: info
            });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }

    // Services that were running in prev and are stopped or failed in next: [{ name, failed }].
    // Services missing from prev (newly seen) or from next never count.
    function diff(prev, next) {
        const was = {};
        for (const s of prev || [])
            was[s.name] = s;
        const out = [];
        for (const s of next || []) {
            const p = was[s.name];
            if (p && p.state === "running" && !p.failed && (s.state === "stopped" || s.failed))
                out.push({ name: s.name, failed: s.failed });
        }
        return out;
    }

    // Drops the services the panel acted on in the last ttlMs. expected: name -> ms.
    function dropExpected(list, expected, now, ttlMs) {
        return list.filter(d => !(expected[d.name] !== undefined && now - expected[d.name] < ttlMs));
    }

    // One service's incident gate. down: it just went down; running: it is running now.
    // Returns { fire, state }; fire at most once per incident.
    function step(state, down, running, cooldownMs, now) {
        const s = { armed: state.armed, last: state.last };
        if (!s.armed && (running || now - s.last >= cooldownMs))
            s.armed = true;
        if (s.armed && down) {
            s.armed = false;
            s.last = now;
            return { fire: true, state: s };
        }
        return { fire: false, state: s };
    }

    function toastBody(failed) {
        return failed ? "It failed. Details shows its log." : "It is not running any more.";
    }
    function toastTitle(name, failed) {
        return name + (failed ? " failed" : " stopped");
    }

    // notify-send argument array (the service name only ever lands in the title, never in a script)
    function toastCommand(name, failed) {
        return ["notify-send", "-a", "Services", "-A", "restart=Restart", "-A", "details=Details", toastTitle(name, failed), toastBody(failed)];
    }

    // One poll: { fired: [{name, failed}], gates, expected }, no side effects.
    function evaluate(prev, next, gates, expected, now) {
        const g = {};
        for (const k in gates)
            g[k] = gates[k];
        const e = {};
        for (const k in expected)
            e[k] = expected[k];
        const down = root.dropExpected(root.diff(prev, next), e, now, root.expectMs);
        const downNames = {};
        for (const d of down)
            downNames[d.name] = d;
        const fired = [];
        for (const s of next) {
            const isUp = s.state === "running" && !s.failed;
            const r = root.step(g[s.name] || { armed: true, last: 0 }, downNames[s.name] !== undefined, isUp, root.rearmMs, now);
            g[s.name] = r.state;
            if (r.fire)
                fired.push(downNames[s.name]);
        }
        // expectations only expire by time: a poll between the click and the stop must not cancel one
        for (const k in e) {
            if (now - e[k] >= root.expectMs)
                delete e[k];
        }
        return { fired: fired, gates: g, expected: e };
    }

    function safeName(name) {
        return /^[A-Za-z0-9][A-Za-z0-9@._:+-]*$/.test(name);
    }

    // ---- live part ----

    // The panel is about to start / stop / restart `name`: its next stop is on purpose.
    function expect(name) {
        const e = {};
        for (const k in expected)
            e[k] = expected[k];
        e[name] = Date.now();
        expected = e;
    }

    function handleSnapshot(text) {
        const next = root.parseList(text, "user");
        if (next.length === 0)
            return;
        const r = root.evaluate(root.prev, next, root.gates, root.expected, Date.now());
        root.prev = next;
        root.gates = r.gates;
        root.expected = r.expected;
        for (const d of r.fired)
            root.raise(d.name, d.failed);
    }

    function raise(name, failed) {
        if (!root.safeName(name))
            return;
        toastComp.createObject(root, { command: root.toastCommand(name, failed), svc: name, running: true });
    }

    Component {
        id: toastComp
        Process {
            id: tp
            property string svc: ""
            stdout: StdioCollector {
                onStreamFinished: {
                    const a = text.trim();
                    if (a === "restart") {
                        root.expect(tp.svc);
                        Quickshell.execDetached(["dinitctl", "--user", "restart", tp.svc]);
                    } else if (a === "details") {
                        root.detailsRequested(tp.svc);
                    }
                }
            }
            onExited: tp.destroy(1000)
        }
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v dinitctl >/dev/null 2>&1"]
        onExited: code => {
            root.unavailable = code !== 0;
            if (!root.unavailable && !poll.running)
                poll.running = true;
        }
    }

    Process {
        id: poll
        command: ["dinitctl", "--user", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.handleSnapshot(text)
        }
    }

    onActiveChanged: {
        if (active)
            probe.running = true;
    }
    Component.onCompleted: {
        if (active)
            probe.running = true;
    }

    Timer {
        interval: root.interval
        running: root.active && !root.unavailable
        repeat: true
        onTriggered: {
            if (!poll.running)
                poll.running = true;
        }
    }
}
