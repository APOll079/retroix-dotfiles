pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// NAS status. Every settings.nas.intervalSeconds, scripts/nas.sh reads the state of each mount in settings.nas.mounts:
// mounted, unmounted, or stale (listed in the mount table but a `timeout 3 stat` of it hangs or fails: a dead NFS
// server). Only the mount point itself is stat-ed, no directory is listed.
// For the bar: anyMounted / anyStale / summary (a BarButton shows while any mount is up or stale; a click calls
// remountStale()). remount(path) runs `mount <path>` through the script (the fstab lines are noauto,user); the path must
// be one of the configured mounts. One toast when a mount goes stale, re-armed after it recovered and cooldown passed
// (the MemoryWatch pattern). Not started when QS_NO_APPLY is set (the test harness), so tests never run a tool.
// Settings group (missing = off): settings.nas { enabled, mounts, intervalSeconds }.
Singleton {
    id: root

    readonly property var cfg: Config.settings.nas || ({ enabled: false, mounts: [], intervalSeconds: 30 })
    readonly property var mounts: root.cleanMounts(cfg.mounts)
    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    readonly property bool active: Config.settingsLoaded && cfg.enabled === true && root.mounts.length > 0 && root.live
    readonly property int interval: Math.max(5, cfg.intervalSeconds > 0 ? cfg.intervalSeconds : 30) * 1000
    readonly property int cooldownMs: 10 * 60000

    property var states: ({})                  // path -> "mounted" | "unmounted" | "stale"
    property var armed: ({})                   // path -> toast state { armed, low, last }
    property string remountError: ""
    property var remountLog: []                // paths passed to remount() under QS_NO_APPLY (tests)

    readonly property bool anyMounted: root.count(root.states, "mounted") > 0
    readonly property bool anyStale: root.count(root.states, "stale") > 0
    readonly property string summary: root.summaryText(root.states)

    // ---- pure helpers ----

    // The configured list -> absolute paths made of letters, digits and . _ - / only, no "..", no "/", each once
    function cleanMounts(list) {
        const out = [];
        if (!Array.isArray(list))
            return out;
        for (const p of list) {
            if (typeof p !== "string" || !/^\/[A-Za-z0-9._\/-]*$/.test(p) || p === "/" || p.split("/").indexOf("..") >= 0)
                continue;
            if (out.indexOf(p) < 0)
                out.push(p);
        }
        return out;
    }

    // nas.sh status output -> { path: state } for the configured paths only; {} for anything else
    function parseStatus(text, configured) {
        const out = {};
        try {
            const d = JSON.parse(text);
            if (!Array.isArray(d))
                return out;
            for (const r of d)
                if (r && typeof r.path === "string" && configured.indexOf(r.path) >= 0 && (r.state === "mounted" || r.state === "unmounted" || r.state === "stale"))
                    out[r.path] = r.state;
        } catch (e) {
        }
        return out;
    }

    function count(states, which) {
        let n = 0;
        for (const k in states)
            if (states[k] === which)
                n++;
        return n;
    }

    // "2 mounted", "1 mounted, 1 stale", "none mounted"
    function summaryText(states) {
        const up = root.count(states, "mounted"), stale = root.count(states, "stale");
        if (up === 0 && stale === 0)
            return "none mounted";
        const parts = [];
        if (up > 0)
            parts.push(up + " mounted");
        if (stale > 0)
            parts.push(stale + " stale");
        return parts.join(", ");
    }

    // Mounts that can be remounted by the bar button: the stale ones
    function stalePaths(states) {
        return Object.keys(states).filter(k => states[k] === "stale");
    }

    // A path may be remounted only when it is one of the configured mounts
    function canRemount(path, configured) {
        return typeof path === "string" && configured.indexOf(path) >= 0;
    }

    // Same re-arm logic as MemoryWatch.step: value 1 = stale, 0 = fine; { fire, state }
    function step(state, stale, cooldownMs, now) {
        const s = { armed: state.armed, low: state.low, last: state.last };
        if (!s.armed) {
            if (!stale)
                s.low = true;
            if (s.low && now - s.last >= cooldownMs) {
                s.armed = true;
                s.low = false;
            }
        }
        if (s.armed && stale) {
            s.armed = false;
            s.low = false;
            s.last = now;
            return { fire: true, state: s };
        }
        return { fire: false, state: s };
    }

    function newState() { return { armed: true, low: false, last: 0 }; }

    // New states in -> the paths that raise a toast now, and the updated toast states
    function plan(armed, states, cooldownMs, now) {
        const next = {}, fire = [];
        for (const p of Object.keys(states)) {
            const r = root.step(armed[p] || root.newState(), states[p] === "stale", cooldownMs, now);
            next[p] = r.state;
            if (r.fire)
                fire.push(p);
        }
        return { armed: next, fire: fire };
    }

    // ---- live part ----

    function toast(path) {
        Quickshell.execDetached(["notify-send", "-a", "NAS", "--", "NAS not responding", path + " is mounted but does not answer. Click the NAS button on the bar to remount."]);
    }

    function refresh() {
        if (!root.active || statusProc.running)
            return;
        statusProc.command = ["sh", Quickshell.shellDir + "/scripts/nas.sh", "status"].concat(root.mounts);
        statusProc.running = true;
    }

    // Runs `mount <path>` for one configured mount
    function remount(path) {
        if (!root.canRemount(path, root.mounts))
            return;
        if (!root.live) {
            root.remountLog = root.remountLog.concat([path]);
            return;
        }
        if (remountProc.running)
            return;
        root.remountError = "";
        remountProc.command = ["sh", Quickshell.shellDir + "/scripts/nas.sh", "remount", path].concat(root.mounts);
        remountProc.running = true;
    }

    // The bar button's click: remount every stale mount, else every unmounted one
    function remountStale() {
        const stale = root.stalePaths(root.states);
        const targets = stale.length > 0 ? stale : Object.keys(root.states).filter(k => root.states[k] === "unmounted");
        if (targets.length > 0)
            root.remount(targets[0]);
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                const s = root.parseStatus(text, root.mounts);
                if (Object.keys(s).length === 0)
                    return;
                const p = root.plan(root.armed, s, root.cooldownMs, Date.now());
                root.armed = p.armed;
                root.states = s;
                for (const path of p.fire)
                    root.toast(path);
            }
        }
    }

    Process {
        id: remountProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.remountError = d.ok === true ? "" : (typeof d.message === "string" ? d.message : "mount failed");
                } catch (e) {
                    root.remountError = "mount failed";
                }
            }
        }
        onExited: root.refresh()
    }

    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
