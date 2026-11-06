pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Low-memory toast. RAM: SysMon.memPercent above settings.memoryWatch.ramPercent names the biggest process group
// (scripts/procs.py --once) and raises one notify-send toast. /tmp: when it is a tmpfs (RAM-backed), `df` is read
// every 60 s and a size above tmpGb raises one. One toast per crossing: it re-arms only after the value fell
// `ramMargin` points (RAM) or `tmpMarginPct` percent of the threshold (/tmp) below the threshold AND cooldownMinutes
// passed since the last toast. The decisions are pure functions of (state, value, time) so tests can drive them.
// Not started when QS_NO_APPLY is set (the test harness), so tests never exec real tools.
Singleton {
    id: root

    readonly property var cfg: Config.settings.memoryWatch
    readonly property bool active: Config.settingsLoaded && cfg.enabled && !Quickshell.env("QS_NO_APPLY")
    readonly property int ramMargin: 5          // percent points
    readonly property int tmpMarginPct: 10      // percent of the tmpGb threshold
    readonly property int tmpInterval: 60000
    readonly property real gb: 1e9

    property var ramState: newState()
    property var tmpState: newState()
    property int pendingPercent: 0

    // ---- pure helpers (no Date.now, no globals) ----
    function newState() { return { armed: true, low: false, last: 0 }; }

    // True when `state` would raise a toast for `value` at time `now` (ms). Does not change the state.
    function shouldToast(state, value, threshold, rearmAt, cooldownMs, now) {
        return step(state, value, threshold, rearmAt, cooldownMs, now).fire;
    }

    // Returns { fire, state }. rearmAt: the value at or below which the watcher counts as "dropped".
    function step(state, value, threshold, rearmAt, cooldownMs, now) {
        const s = { armed: state.armed, low: state.low, last: state.last };
        if (!s.armed) {
            if (value <= rearmAt)
                s.low = true;
            if (s.low && now - s.last >= cooldownMs) {
                s.armed = true;
                s.low = false;
            }
        }
        if (s.armed && value > threshold) {
            s.armed = false;
            s.low = false;
            s.last = now;
            return { fire: true, state: s };
        }
        return { fire: false, state: s };
    }

    // "7.2 GB", "512 MB" (decimal units)
    function formatBytes(n) {
        if (!(n >= 0))
            return "?";
        if (n >= 1e9)
            return (n / 1e9).toFixed(1) + " GB";
        return Math.round(n / 1e6) + " MB";
    }

    // Output of `df --output=fstype,used -B1 /tmp` -> { fstype, used } or null for anything else
    function parseDf(text) {
        const lines = String(text).trim().split("\n");
        if (lines.length < 2)
            return null;
        const parts = lines[lines.length - 1].trim().split(/\s+/);
        if (parts.length !== 2 || !/^\d+$/.test(parts[1]))
            return null;
        return { fstype: parts[0], used: Number(parts[1]) };
    }

    // procs.py --once output -> its biggest group by mem as { name, mem }, or null
    function biggestGroup(text) {
        try {
            let best = null;
            for (const g of JSON.parse(text).groups) {
                if (typeof g.name === "string" && g.name !== "" && g.mem > 0 && (best === null || g.mem > best.mem))
                    best = { name: g.name, mem: g.mem };
            }
            return best;
        } catch (e) {
            return null;
        }
    }

    function ramBody(percent, big) {
        return "RAM " + percent + "%" + (big ? " - biggest: " + big.name + " (" + formatBytes(big.mem) + ")" : "");
    }

    function tmpTitle(used) {
        return "/tmp is using " + formatBytes(used) + " of RAM";
    }

    // ---- live part ----
    function toast(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Memory", title, body]);
    }

    function checkRam() {
        if (!root.active)
            return;
        const pct = SysMon.memPercent;
        const r = step(ramState, pct, cfg.ramPercent, cfg.ramPercent - ramMargin, cfg.cooldownMinutes * 60000, Date.now());
        ramState = r.state;
        if (r.fire) {
            pendingPercent = pct;
            procs.running = true;
        }
    }

    Connections {
        target: SysMon
        function onMemPercentChanged() { root.checkRam(); }
    }
    Connections {
        target: root
        function onActiveChanged() { root.checkRam(); }
    }

    Process {
        id: procs
        command: ["python3", "-I", Quickshell.shellDir + "/scripts/procs.py", "--once"]
        stdout: StdioCollector {
            // empty or broken output (procs failed) gives biggestGroup null: toast without the name
            onStreamFinished: root.toast("Memory is almost full", root.ramBody(root.pendingPercent, root.biggestGroup(text)))
        }
    }

    Process {
        id: df
        command: ["df", "--output=fstype,used", "-B1", "/tmp"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parseDf(text);
                if (!d || d.fstype !== "tmpfs")
                    return;
                const th = root.cfg.tmpGb * root.gb;
                const r = root.step(root.tmpState, d.used, th, th * (100 - root.tmpMarginPct) / 100, root.cfg.cooldownMinutes * 60000, Date.now());
                root.tmpState = r.state;
                if (r.fire)
                    root.toast(root.tmpTitle(d.used), "");
            }
        }
    }

    Timer {
        interval: root.tmpInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!df.running) df.running = true; }
    }
}
