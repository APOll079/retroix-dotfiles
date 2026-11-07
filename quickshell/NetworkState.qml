pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Data of the Network page (popups/NetworkPage.qml, a window ToolWindows.qml opens). Nothing runs by itself: refresh() (the window calls it when it opens)
// runs scripts/lan.sh once (your addresses, the gateway and the LAN devices the system already knows: `ip -j addr / route /
// neigh`, no scanning, no DNS); ping(which) runs one echo (`lan.sh ping <ip>`) at the gateway or at 1.1.1.1; speedTest()
// runs scripts/speedtest.sh <url> (a download to /dev/null, 20 s at most) and only when its button is pressed. The URL is
// settings.networkPage.speedTestUrl (default below). One Process of each kind at a time; a second request while one runs
// is ignored. A missing tool is a line of text (`error`, a ping's `error`, the speed test's `error`), never a dialog.
// The parsers and the texts are pure functions so tests can drive them. Not started when QS_NO_APPLY is set (the test harness):
// the requests are recorded in `launched` and tests hand the answers to gotLan / gotPing / gotSpeed.
Singleton {
    id: root

    readonly property bool active: !Quickshell.env("QS_NO_APPLY")
    readonly property string defaultUrl: "https://speed.cloudflare.com/__down?bytes=25000000"
    readonly property string lanScript: Quickshell.shellDir + "/scripts/lan.sh"
    readonly property string speedScript: Quickshell.shellDir + "/scripts/speedtest.sh"
    readonly property string pingTarget: "1.1.1.1"

    property var addrs: []                 // [{ ifname, addr, family, prefix }]
    property var gateway: null             // { addr, dev } or null
    property var neigh: []                 // [{ addr, mac, state, dev, name }]
    property string error: ""              // "" or one line ("ip not installed")
    property bool loaded: false            // a lan.sh answer has arrived
    property bool loading: false
    // ping results: key "gw" or "cf" -> { running, done, ok, ms, error }
    property var pings: ({ gw: root.idle(), cf: root.idle() })
    // speed test: { running, done, ok, mbit, partial, error }
    property var speed: root.idle()
    property var launched: []              // argv lists of every process asked for (tests read this)

    // ---- pure helpers ----

    function idle() { return { running: false, done: false, ok: false, ms: null, mbit: 0, partial: false, error: "" }; }

    // settings.networkPage.speedTestUrl, or the default when it is missing or not an http(s) address
    function speedUrlFrom(settings) {
        const g = settings ? settings["networkPage"] : null;
        const u = g && typeof g.speedTestUrl === "string" ? g.speedTestUrl.trim() : "";
        return root.validUrl(u) ? u : root.defaultUrl;
    }

    function validUrl(u) {
        return typeof u === "string" && /^https?:\/\/[^\s\u0000-\u001f\u007f]{1,500}$/.test(u);
    }

    // "https://speed.cloudflare.com/__down?bytes=25000000" -> "speed.cloudflare.com"
    function hostOf(u) {
        const m = /^https?:\/\/([^\/?#:]+)/.exec(String(u));
        return m ? m[1] : "";
    }

    // lan.sh output -> { addrs, gateway, neigh, error }; anything else -> an error line
    function parseLan(text) {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return { addrs: [], gateway: null, neigh: [], error: "The network information could not be read" };
        }
        if (!d || typeof d !== "object")
            return { addrs: [], gateway: null, neigh: [], error: "The network information could not be read" };
        const str = v => typeof v === "string" ? v : "";
        const addrs = (Array.isArray(d.addrs) ? d.addrs : []).filter(a => a && str(a.addr) !== "").map(a => ({ ifname: str(a.ifname), addr: str(a.addr), family: a.family === "ipv6" ? "ipv6" : "ipv4", prefix: typeof a.prefix === "number" ? a.prefix : -1 }));
        const gw = d.gateway && str(d.gateway.addr) !== "" ? { addr: str(d.gateway.addr), dev: str(d.gateway.dev) } : null;
        const neigh = (Array.isArray(d.neigh) ? d.neigh : []).filter(n => n && str(n.addr) !== "").map(n => ({ addr: str(n.addr), mac: str(n.mac), state: str(n.state), dev: str(n.dev), name: str(n.name) }));
        return { addrs: addrs, gateway: gw, neigh: neigh, error: str(d.error) };
    }

    // lan.sh ping output -> { running: false, done: true, ok, ms, error }
    function parsePing(text) {
        const r = root.idle();
        r.done = true;
        try {
            const d = JSON.parse(text);
            r.ok = d.ok === true && typeof d.ms === "number";
            r.ms = r.ok ? d.ms : null;
            r.error = r.ok ? "" : (typeof d.error === "string" && d.error !== "" ? d.error : "no answer");
        } catch (e) {
            r.error = "no answer";
        }
        return r;
    }

    // speedtest.sh output -> { running: false, done: true, ok, mbit, partial, error }
    function parseSpeed(text) {
        const r = root.idle();
        r.done = true;
        try {
            const d = JSON.parse(text);
            r.ok = d.ok === true && typeof d.mbit === "number" && d.mbit > 0;
            r.mbit = r.ok ? d.mbit : 0;
            r.partial = r.ok && d.partial === true;
            r.error = r.ok ? "" : (typeof d.error === "string" && d.error !== "" ? d.error : "the speed test failed");
        } catch (e) {
            r.error = "the speed test failed";
        }
        return r;
    }

    // "12 ms", "no answer", "pinging..." or "" before the first ping
    function pingText(p) {
        if (!p)
            return "";
        if (p.running)
            return "pinging...";
        if (!p.done)
            return "";
        return p.ok ? (p.ms < 10 ? p.ms.toFixed(1) : String(Math.round(p.ms))) + " ms" : p.error;
    }

    // "93.2 Mbit/s" (a cut-short test says so), "Testing...", or the error line; "" before the first test
    function speedText(s) {
        if (!s)
            return "";
        if (s.running)
            return "Testing...";
        if (!s.done)
            return "";
        return s.ok ? s.mbit.toFixed(1) + " Mbit/s" + (s.partial ? " (stopped after 20 s)" : "") : s.error;
    }

    function lanCommand(script) { return ["sh", script]; }
    function pingCommand(script, addr) { return ["sh", script, "ping", addr]; }
    function speedCommand(script, url) { return ["sh", script, url]; }

    // ---- state ----

    function refresh() {
        if (root.loading)
            return;
        root.loading = true;
        const argv = root.lanCommand(root.lanScript);
        root.launched = root.launched.concat([argv]);
        if (root.active) {
            lanProc.command = argv;
            lanProc.running = true;
        }
    }

    function gotLan(text) {
        const d = root.parseLan(text);
        root.addrs = d.addrs;
        root.gateway = d.gateway;
        root.neigh = d.neigh;
        root.error = d.error;
        root.loaded = true;
        root.loading = false;
    }

    // which: "gw" (the gateway) or "cf" (1.1.1.1); a gateway-less machine can't ping it
    function ping(which) {
        const addr = which === "gw" ? (root.gateway ? root.gateway.addr : "") : which === "cf" ? root.pingTarget : "";
        if (addr === "" || root.pings[which].running)
            return;
        const next = Object.assign({}, root.pings);
        next[which] = Object.assign(root.idle(), { running: true });
        root.pings = next;
        const argv = root.pingCommand(root.lanScript, addr);
        root.launched = root.launched.concat([argv]);
        if (root.active) {
            const p = which === "gw" ? pingGw : pingCf;
            p.command = argv;
            p.running = true;
        }
    }

    function gotPing(which, text) {
        const next = Object.assign({}, root.pings);
        next[which] = root.parsePing(text);
        root.pings = next;
    }

    function speedTest(settings) {
        if (root.speed.running)
            return;
        root.speed = Object.assign(root.idle(), { running: true });
        const argv = root.speedCommand(root.speedScript, root.speedUrlFrom(settings));
        root.launched = root.launched.concat([argv]);
        if (root.active) {
            speedProc.command = argv;
            speedProc.running = true;
        }
    }

    function gotSpeed(text) {
        root.speed = root.parseSpeed(text);
    }

    // A fresh page: forget the old ping and speed results (the addresses stay until refresh() replaces them)
    function resetResults() {
        if (!root.pings.gw.running && !root.pings.cf.running)
            root.pings = ({ gw: root.idle(), cf: root.idle() });
        if (!root.speed.running)
            root.speed = root.idle();
    }

    Process {
        id: lanProc
        stdout: StdioCollector {
            onStreamFinished: root.gotLan(text)
        }
        onExited: code => {
            // a script that could not start at all (no sh): the page still gets a line
            if (code !== 0 && root.loading)
                root.gotLan("");
        }
    }
    // (an onExited with the page still waiting means the script never answered: it gets a line instead of waiting forever)
    Process {
        id: pingGw
        stdout: StdioCollector {
            onStreamFinished: root.gotPing("gw", text)
        }
        onExited: { if (root.pings.gw.running) root.gotPing("gw", ""); }
    }
    Process {
        id: pingCf
        stdout: StdioCollector {
            onStreamFinished: root.gotPing("cf", text)
        }
        onExited: { if (root.pings.cf.running) root.gotPing("cf", ""); }
    }
    Process {
        id: speedProc
        stdout: StdioCollector {
            onStreamFinished: root.gotSpeed(text)
        }
        onExited: { if (root.speed.running) root.gotSpeed(""); }
    }
}
