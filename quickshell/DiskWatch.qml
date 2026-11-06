pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Disk warnings. Every 5 min scripts/disk-usage.sh reads `df` for each of settings.diskWatch.mounts (~ = HOME, each
// with a 3 s timeout, so a hung NFS mount reports "unreachable" instead of freezing anything) and a mount above
// `percent` used raises one notify-send toast; it re-arms 5 points below the threshold AND after cooldownMinutes.
// An unreachable mount gets at most one quiet toast per cooldown; a missing one (not mounted) stays silent.
// SMART: scripts/disk-health.sh runs `smartctl -H -j` once a day (and at start); a failed disk raises a critical
// toast. smartctl normally needs root: "permission" sets smartNeedsPermission and raises one toast per session
// pointing at docs/desktop.md. smartctl not installed: silent.
// Only df output is read, never a file or directory. Not started when QS_NO_APPLY is set (the test harness).
// step / parse / plan functions are pure, so tests can drive them.
Singleton {
    id: root

    readonly property var cfg: Config.settings.diskWatch
    readonly property bool active: Config.settingsLoaded && cfg.enabled && !Quickshell.env("QS_NO_APPLY")
    readonly property int usageInterval: 5 * 60000
    readonly property int healthInterval: 24 * 3600000
    readonly property int rearmPoints: 5           // percent points below the threshold that re-arm

    property bool smartNeedsPermission: false
    property bool permissionToasted: false
    property var states: ({})                  // mount -> { armed, low, last }
    property var unreachableAt: ({})           // mount -> ms of the last "not responding" toast
    property var usage: []                     // last parsed disk-usage.sh result

    // ---- pure helpers ----
    function newState() { return { armed: true, low: false, last: 0 }; }

    // Same re-arm logic as MemoryWatch.step (copied): { fire, state }
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

    // At most one "not responding" toast per cooldown: true when `last` (0 = never) is old enough.
    function unreachableDue(last, cooldownMs, now) {
        return !last || now - last >= cooldownMs;
    }

    // ["/", "~", "~/x"] + home -> absolute, deduplicated, non-strings and empties dropped
    function expandMounts(mounts, home) {
        const out = [];
        for (const m of mounts || []) {
            if (typeof m !== "string" || m === "")
                continue;
            const p = m === "~" ? home : m.startsWith("~/") ? home + m.slice(1) : m;
            if (p !== "" && !out.includes(p))
                out.push(p);
        }
        return out;
    }

    // disk-usage.sh JSON -> [{ mount, usedPercent, size, used, status }] with bad entries dropped, or []
    function parseUsage(text) {
        try {
            const out = [];
            for (const e of JSON.parse(text)) {
                if (typeof e.mount !== "string" || !["ok", "unreachable", "missing"].includes(e.status))
                    continue;
                if (e.status === "ok" && !(Number.isFinite(e.usedPercent) && Number.isFinite(e.size) && Number.isFinite(e.used)))
                    continue;
                out.push({ mount: e.mount, usedPercent: e.usedPercent, size: e.size, used: e.used, status: e.status });
            }
            return out;
        } catch (e) {
            return [];
        }
    }

    // disk-health.sh JSON -> [{ dev, passed, status }], or []
    function parseHealth(text) {
        try {
            const out = [];
            for (const e of JSON.parse(text)) {
                if (typeof e.dev !== "string" || !/^[a-z0-9]+$/.test(e.dev) || !["ok", "failed", "permission", "missing"].includes(e.status))
                    continue;
                out.push({ dev: e.dev, passed: e.passed === true ? true : e.passed === false ? false : null, status: e.status });
            }
            return out;
        } catch (e) {
            return [];
        }
    }

    // "930 GB", "1.8 TB", "512 MB" (decimal units)
    function formatBytes(n) {
        if (!(n >= 0))
            return "?";
        if (n >= 1e12)
            return (n / 1e12).toFixed(1) + " TB";
        if (n >= 1e9)
            return Math.round(n / 1e9) + " GB";
        return Math.round(n / 1e6) + " MB";
    }

    // One usage round: { toasts: [{ args }], states, unreachableAt } from the parsed result. No side effects.
    // Toast args are notify-send argument arrays (mount names are data, never part of a script).
    function plan(results, states, unreachableAt, percent, cooldownMs, now) {
        const st = {};
        for (const k in states)
            st[k] = states[k];
        const un = {};
        for (const k in unreachableAt)
            un[k] = unreachableAt[k];
        const toasts = [];
        for (const r of results) {
            if (r.status === "ok") {
                const res = root.step(st[r.mount] || root.newState(), r.usedPercent, percent, percent - root.rearmPoints, cooldownMs, now);
                st[r.mount] = res.state;
                if (res.fire)
                    toasts.push(["notify-send", "-a", "Disk usage", r.mount + " is " + r.usedPercent + "% full", root.formatBytes(r.used) + " of " + root.formatBytes(r.size) + " used"]);
            } else if (r.status === "unreachable" && root.unreachableDue(un[r.mount], cooldownMs, now)) {
                un[r.mount] = now;
                toasts.push(["notify-send", "-a", "Disk offline", "-u", "low", r.mount + " is not responding", "It did not answer within 3 seconds."]);
            }
        }
        return { toasts: toasts, states: st, unreachableAt: un };
    }

    // One health round: { toasts, needsPermission } (the once-per-session permission toast is the caller's)
    function planHealth(results) {
        const toasts = [];
        let needs = false;
        for (const r of results) {
            if (r.status === "failed")
                toasts.push(["notify-send", "-a", "Disk health", "-u", "critical", r.dev + " reports SMART failure", "Back up the disk and replace it."]);
            else if (r.status === "permission")
                needs = true;
        }
        return { toasts: toasts, needsPermission: needs };
    }

    readonly property var permissionToast: ["notify-send", "-a", "Disk health", "SMART needs permission", "See docs/desktop.md"]

    // ---- live part ----
    function run(args) {
        Quickshell.execDetached(args);
    }

    function checkUsage() {
        if (!root.active || usageProc.running)
            return;
        const mounts = root.expandMounts(cfg.mounts, Quickshell.env("HOME") || "");
        if (mounts.length === 0)
            return;
        usageProc.command = ["sh", Quickshell.shellDir + "/scripts/disk-usage.sh"].concat(mounts);
        usageProc.running = true;
    }

    function checkHealth() {
        if (!root.active || healthProc.running)
            return;
        healthProc.running = true;
    }

    Process {
        id: usageProc
        stdout: StdioCollector {
            onStreamFinished: {
                const results = root.parseUsage(text);
                root.usage = results;
                const p = root.plan(results, root.states, root.unreachableAt, root.cfg.percent, root.cfg.cooldownMinutes * 60000, Date.now());
                root.states = p.states;
                root.unreachableAt = p.unreachableAt;
                for (const t of p.toasts)
                    root.run(t);
            }
        }
    }

    Process {
        id: healthProc
        command: ["sh", Quickshell.shellDir + "/scripts/disk-health.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = root.planHealth(root.parseHealth(text));
                for (const t of p.toasts)
                    root.run(t);
                root.smartNeedsPermission = p.needsPermission;
                if (p.needsPermission && !root.permissionToasted) {
                    root.permissionToasted = true;
                    root.run(root.permissionToast);
                }
            }
        }
    }

    Timer {
        interval: root.usageInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkUsage()
    }

    Timer {
        interval: root.healthInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkHealth()
    }
}
