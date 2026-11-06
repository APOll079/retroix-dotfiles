pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Network toasts. Every 10 s scripts/net-check.sh --link reads the NetworkManager state (the command the bar's ETH
// indicator uses) and, when settings.networkWatch.hosts is not empty, scripts/net-check.sh <hosts> pings each one.
// "Network is down" / "Network is back" for the wired link, "<host> is down" / "<host> is back" per host.
// Debounce: a value must hold for `need` polls in a row before it counts; the first value that holds only sets the
// baseline (no toast at startup). One toast per change; the same toast key is also rate limited to one per
// cooldownSeconds (the state still updates, so a flapping link cannot flood). The decisions are pure functions, so
// tests can drive them. Not started when QS_NO_APPLY is set (the test harness), so tests never exec real tools.
Singleton {
    id: root

    readonly property var cfg: Config.settings.networkWatch
    readonly property bool active: Config.settingsLoaded && cfg.enabled && !Quickshell.env("QS_NO_APPLY")
    readonly property int interval: 10000
    readonly property int need: 2
    readonly property string script: Quickshell.shellDir + "/scripts/net-check.sh"

    property var linkState: newState()
    property var hostStates: ({})
    property var lastToast: ({})

    // ---- pure helpers (no Date.now, no globals) ----
    function newState() { return { stable: null, cand: null, n: 0 }; }

    // Feeds one observation (true / false; null = no usable reading, ignored).
    // Returns { fire: "down" | "up" | null, state }.
    function observe(state, value, need) {
        const s = { stable: state.stable, cand: state.cand, n: state.n };
        if (value !== true && value !== false)
            return { fire: null, state: s };
        if (value === s.stable) {
            s.cand = null;
            s.n = 0;
            return { fire: null, state: s };
        }
        if (value === s.cand)
            s.n++;
        else {
            s.cand = value;
            s.n = 1;
        }
        if (s.n < need)
            return { fire: null, state: s };
        const first = s.stable === null;
        s.stable = value;
        s.cand = null;
        s.n = 0;
        return { fire: first ? null : (value ? "up" : "down"), state: s };
    }

    // true when a toast with this key may go out (last = ms of the previous one, or undefined)
    function rateOk(last, now, gapMs) {
        return last === undefined || now - last >= gapMs;
    }

    // `nmcli -t -f STATE g` words: connected* -> true, disconnected / asleep -> false, anything else -> null
    function linkUp(word) {
        const w = String(word);
        if (/^connected/.test(w))
            return true;
        if (w === "disconnected" || w === "asleep")
            return false;
        return null;
    }

    // net-check.sh --link output -> true / false / null
    function parseLink(text) {
        try {
            const o = JSON.parse(text);
            return typeof o.state === "string" ? linkUp(o.state) : null;
        } catch (e) {
            return null;
        }
    }

    function validHost(h) {
        return typeof h === "string" && /^[A-Za-z0-9.:][A-Za-z0-9.:-]*$/.test(h);
    }

    // net-check.sh <hosts> output -> { host: up } (invalid entries and junk are dropped; null on unparseable text)
    function parseHosts(text) {
        try {
            const out = {};
            for (const e of JSON.parse(text)) {
                if (e && root.validHost(e.host) && e.invalid !== true && typeof e.up === "boolean")
                    out[e.host] = e.up;
            }
            return out;
        } catch (e) {
            return null;
        }
    }

    // configured hosts: strings that pass validHost, no duplicates
    function cleanHosts(list) {
        const out = [];
        for (const h of (list || [])) {
            if (root.validHost(h) && out.indexOf(h) < 0)
                out.push(h);
        }
        return out;
    }

    function title(key, fire) {
        if (key === "link")
            return fire === "down" ? "Network is down" : "Network is back";
        return key + (fire === "down" ? " is down" : " is back");
    }

    // ---- live part ----
    function toast(key, fire) {
        const now = Date.now();
        const last = lastToast[key];
        if (!rateOk(last, now, cfg.cooldownSeconds * 1000))
            return;
        const t = Object.assign({}, lastToast);
        t[key] = now;
        lastToast = t;
        // the link and the pinged hosts are different app names, so a host toast never replaces the link toast
        const args = ["notify-send", "-a", key === "link" ? "Network" : "Ping", title(key, fire)];
        if (key !== "link" && fire === "down")
            args.push("No answer to ping");
        Quickshell.execDetached(args);
    }

    function applyLink(value) {
        const r = observe(linkState, value, need);
        linkState = r.state;
        if (r.fire)
            toast("link", r.fire);
    }

    function applyHosts(map) {
        const next = {};
        for (const h of cleanHosts(cfg.hosts)) {
            const r = observe(hostStates[h] || newState(), map[h], need);
            next[h] = r.state;
            if (r.fire)
                toast(h, r.fire);
        }
        hostStates = next;
    }

    Process {
        id: linkProc
        command: ["sh", root.script, "--link"]
        stdout: StdioCollector {
            onStreamFinished: root.applyLink(root.parseLink(text))
        }
    }

    Process {
        id: hostProc
        command: ["sh", root.script].concat(root.cleanHosts(root.cfg.hosts))
        stdout: StdioCollector {
            onStreamFinished: {
                const m = root.parseHosts(text);
                if (m !== null)
                    root.applyHosts(m);
            }
        }
    }

    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!linkProc.running)
                linkProc.running = true;
            if (root.cleanHosts(root.cfg.hosts).length > 0 && !hostProc.running)
                hostProc.running = true;
        }
    }
}
