// Tests for the Network page (popups/NetworkPage.qml + NetworkState.qml): the parsers and texts with fixtures, then the page with
// real clicks. The page is a real window (a FloatingWindow) owned by the ToolWindows singleton, so it is created straight from the
// shell files; the test opens it through ToolWindows. QS_NO_APPLY is set: no ip, ping or curl runs; NetworkState records the
// processes it would start in `launched`, and the test hands it the answers.
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function asVar(o: var): var {
        return o;
    }
    function js(v) { return JSON.stringify(v); }

    TestCase { id: tc; name: "sim"; when: false }

    readonly property string lanJson: JSON.stringify({
        addrs: [
            { ifname: "eth0", addr: "192.168.1.20", family: "ipv4", prefix: 24 },
            { ifname: "eth0", addr: "2001:db8::2", family: "ipv6", prefix: 64 }
        ],
        gateway: { addr: "192.168.1.1", dev: "eth0" },
        neigh: [
            { addr: "192.168.1.9", mac: "aa:bb:cc:00:00:09", state: "REACHABLE", dev: "eth0", name: "nas" },
            { addr: "192.168.1.30", mac: "aa:bb:cc:00:00:30", state: "STALE", dev: "eth0", name: "" },
            { addr: "fe80::2", mac: "aa:bb:cc:00:00:02", state: "DELAY", dev: "eth0", name: "" }
        ],
        error: ""
    })

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const N = NetworkState;
            const TW = ToolWindows;
            const panel = shell.asVar(TW.win("network"));
            shell.check("the Network window exists, is titled Network and starts closed", panel !== null && panel.title === "Network" && !panel.visible && !TW.networkVisible);

            // ---- pure functions ----
            const lan = N.parseLan(shell.lanJson);
            shell.check("parseLan: addresses, gateway, devices", lan.addrs.length === 2 && lan.addrs[0].prefix === 24 && lan.addrs[1].family === "ipv6" && lan.gateway.addr === "192.168.1.1" && lan.neigh.length === 3 && lan.neigh[0].name === "nas" && lan.error === "");
            shell.check("parseLan: junk gives an error line, not an exception", N.parseLan("oops").error !== "" && N.parseLan("").error !== "" && N.parseLan("5").error !== "" && N.parseLan("{}").addrs.length === 0);
            shell.check("parseLan: wrong shapes are dropped", N.parseLan(JSON.stringify({ addrs: [null, { addr: 5 }, { addr: "10.0.0.2" }], neigh: "x", gateway: { addr: "" } })).addrs.length === 1);
            shell.check("parseLan: the script's own error line comes through", N.parseLan(JSON.stringify({ addrs: [], gateway: null, neigh: [], error: "ip not installed" })).error === "ip not installed");
            shell.check("parsePing: ms, no answer, junk", N.parsePing(JSON.stringify({ ok: true, ms: 12.3 })).ms === 12.3 && N.parsePing(JSON.stringify({ ok: false, ms: null, error: "no answer" })).ok === false && N.parsePing("").error === "no answer");
            shell.check("pingText", N.pingText(N.parsePing(JSON.stringify({ ok: true, ms: 12.34 }))) === "12 ms" && N.pingText(N.parsePing(JSON.stringify({ ok: true, ms: 0.84 }))) === "0.8 ms"
                && N.pingText(N.parsePing(JSON.stringify({ ok: false, error: "ping not installed" }))) === "ping not installed" && N.pingText(N.idle()) === "" && N.pingText(Object.assign(N.idle(), { running: true })) === "pinging...");
            shell.check("parseSpeed and speedText: 93.2 Mbit/s, partial, error, running", N.speedText(N.parseSpeed(JSON.stringify({ ok: true, mbit: 93.2, partial: false }))) === "93.2 Mbit/s"
                && N.speedText(N.parseSpeed(JSON.stringify({ ok: true, mbit: 40, partial: true }))) === "40.0 Mbit/s (stopped after 20 s)"
                && N.speedText(N.parseSpeed(JSON.stringify({ ok: false, error: "curl not installed" }))) === "curl not installed" && N.speedText(N.parseSpeed("x")) === "the speed test failed"
                && N.speedText(Object.assign(N.idle(), { running: true })) === "Testing..." && N.speedText(N.idle()) === "");
            shell.check("speedUrlFrom: default, the setting, a bad setting", N.speedUrlFrom(null) === "https://speed.cloudflare.com/__down?bytes=25000000" && N.speedUrlFrom({}) === N.defaultUrl
                && N.speedUrlFrom({ networkPage: { speedTestUrl: " https://example.test/10mb.bin " } }) === "https://example.test/10mb.bin"
                && N.speedUrlFrom({ networkPage: { speedTestUrl: "ftp://example.test/x" } }) === N.defaultUrl && N.speedUrlFrom({ networkPage: { speedTestUrl: "https://a b" } }) === N.defaultUrl);
            shell.check("hostOf", N.hostOf("https://speed.cloudflare.com/__down?bytes=1") === "speed.cloudflare.com" && N.hostOf("nonsense") === "");
            shell.check("commands: every value is its own argument", shell.js(N.pingCommand("/l.sh", "1.1.1.1")) === shell.js(["sh", "/l.sh", "ping", "1.1.1.1"]) && shell.js(N.speedCommand("/s.sh", "https://x/y?a=1&b=2")) === shell.js(["sh", "/s.sh", "https://x/y?a=1&b=2"]));

            // ---- the page: nothing runs by itself ----
            const n0 = N.launched.length;
            TW.open("network");
            tc.wait(150);
            shell.check("ToolWindows.open shows the window", panel.visible && TW.isOpen("network") && TW.networkVisible);
            shell.check("opening reads the addresses once and starts nothing else", N.launched.length === n0 + 1 && shell.js(N.launched[n0].slice(1)).indexOf("lan.sh") > 0 && N.launched[n0].length === 2);
            shell.check("the page shows Reading... and the device list says so", N.loading && panel.emptyDevices.visible && panel.emptyDevices.text === "Reading...");
            shell.check("the speed button says Speed test, Refresh is off while reading", panel.speedButton.text === "Speed test" && panel.speedButton.enabled && !panel.refreshButton.enabled);
            shell.check("the ping buttons are off without a gateway", !panel.pingGw.enabled && panel.pingCf.enabled);

            // ---- the answer ----
            N.gotLan(shell.lanJson);
            tc.wait(100);
            shell.check("devices listed, the empty text hidden, Refresh on again", panel.deviceList.count === 3 && !panel.emptyDevices.visible && panel.refreshButton.enabled);
            shell.check("the gateway ping works now", panel.pingGw.enabled);

            // ---- pings: one press, one echo ----
            const n1 = N.launched.length;
            tc.mouseClick(panel.pingGw);
            tc.wait(100);
            shell.check("Ping at the gateway: `lan.sh ping 192.168.1.1`, button off while it runs", N.launched.length === n1 + 1 && shell.js(N.launched[n1].slice(2)) === shell.js(["ping", "192.168.1.1"]) && !panel.pingGw.enabled);
            tc.mouseClick(panel.pingGw);
            shell.check("a second press while it runs does nothing", N.launched.length === n1 + 1);
            N.gotPing("gw", JSON.stringify({ host: "192.168.1.1", ok: true, ms: 12.3 }));
            tc.wait(50);
            shell.check("the answer is shown in ms and the button is back", N.pingText(N.pings.gw) === "12 ms" && panel.pingGw.enabled);
            tc.mouseClick(panel.pingCf);
            tc.wait(50);
            shell.check("Ping at 1.1.1.1", shell.js(N.launched[n1 + 1].slice(2)) === shell.js(["ping", "1.1.1.1"]));
            N.gotPing("cf", JSON.stringify({ host: "1.1.1.1", ok: false, ms: null, error: "no answer" }));
            shell.check("no answer shows as that", N.pingText(N.pings.cf) === "no answer");

            // ---- speed test: only on the button ----
            const n2 = N.launched.length;
            shell.check("no speed test has run so far", N.launched.every(a => a[1].indexOf("speedtest.sh") < 0));
            tc.mouseClick(panel.speedButton);
            tc.wait(100);
            shell.check("Speed test starts speedtest.sh with the default URL, the button says Testing... and is off", N.launched.length === n2 + 1 && N.launched[n2][1].indexOf("speedtest.sh") > 0 && N.launched[n2][2] === N.defaultUrl
                && panel.speedButton.text === "Testing..." && !panel.speedButton.enabled);
            N.gotSpeed(JSON.stringify({ ok: true, bytesPerSec: 11650000, mbit: 93.2, partial: false, error: "" }));
            tc.wait(50);
            shell.check("the result reads 93.2 Mbit/s and the button is back", N.speedText(N.speed) === "93.2 Mbit/s" && panel.speedButton.text === "Speed test" && panel.speedButton.enabled);
            tc.mouseClick(panel.speedButton);
            N.gotSpeed(JSON.stringify({ ok: false, mbit: 0, error: "curl not installed" }));
            shell.check("a missing curl is a line, not a dialog", N.speedText(N.speed) === "curl not installed");

            // ---- a missing ip is a line ----
            N.refresh();
            N.gotLan(JSON.stringify({ addrs: [], gateway: null, neigh: [], error: "ip not installed" }));
            tc.wait(100);
            shell.check("ip missing: the status line says so and the lists are empty", N.error === "ip not installed" && panel.deviceList.count === 0 && panel.emptyDevices.visible);

            // ---- closing ----
            const n3 = N.launched.length;
            TW.open("network");
            shell.check("opening an open window only focuses it: still visible, nothing re-read", panel.visible && N.launched.length === n3);
            tc.keyClick(Qt.Key_Escape);
            shell.check("Escape closes the window", !panel.visible && !TW.isOpen("network"));
            TW.toggle("network");
            shell.check("toggle opens it again, reading again", panel.visible && N.loading);
            TW.toggle("network");
            shell.check("toggle closes it", !panel.visible);
            TW.close("network");
            shell.check("close on a closed window is harmless", !panel.visible);
            shell.check("a window needs no bar: size from the tokens, a minimum size", panel.implicitWidth === MenuStyle.windowWidth && panel.implicitHeight === MenuStyle.windowHeight && panel.minimumSize.width <= panel.implicitWidth);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 100; onTriggered: Qt.quit() }
}
