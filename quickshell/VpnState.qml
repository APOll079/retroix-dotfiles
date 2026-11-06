pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// VPN status for the bar. Every 15 s scripts/vpn-status.sh reports the active NetworkManager vpn / wireguard
// connections. `up` is true while at least one is active, `label` is the first name (the host elides it).
// disconnect() runs `nmcli connection down <name>` for the names of the last status only, so a stale or invented
// name never reaches nmcli. Not started when QS_NO_APPLY is set (the test harness).
Singleton {
    id: root

    readonly property bool active: Config.settingsLoaded && Config.settings.networkWatch.vpn && !Quickshell.env("QS_NO_APPLY")
    readonly property string script: Quickshell.shellDir + "/scripts/vpn-status.sh"

    property var names: []
    readonly property bool up: names.length > 0
    readonly property string label: names.length > 0 ? names[0] : ""

    // ---- pure helpers ----
    // vpn-status.sh output -> array of names, or null when the text is not a status
    function parse(text) {
        try {
            const o = JSON.parse(text);
            if (!o || !Array.isArray(o.names))
                return null;
            const out = [];
            for (const n of o.names) {
                if (typeof n === "string" && n !== "" && out.indexOf(n) < 0)
                    out.push(n);
            }
            return out;
        } catch (e) {
            return null;
        }
    }

    // The argv for taking `name` down, or null when it was not in the last status (or starts with "-")
    function downCommand(known, name) {
        if (typeof name !== "string" || name === "" || name[0] === "-" || known.indexOf(name) < 0)
            return null;
        return ["nmcli", "connection", "down", name];
    }

    function tooltip(names) {
        return names.length === 0 ? "" : "VPN: " + names.join(", ") + " (click to disconnect)";
    }

    // ---- live part ----
    // Disconnects the VPN `name` (default: the first); returns false when nothing was run
    function disconnect(name) {
        const n = name === undefined ? label : name;
        const cmd = downCommand(names, n);
        if (cmd === null || !root.active)
            return false;
        Quickshell.execDetached(cmd);
        recheck.restart();
        return true;
    }

    function refresh() {
        if (!status.running)
            status.running = true;
    }

    Process {
        id: status
        command: ["sh", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = root.parse(text);
                if (n !== null)
                    root.names = n;
            }
        }
    }

    // look again soon after a disconnect so the bar button goes away promptly
    Timer {
        id: recheck
        interval: 2000
        onTriggered: root.refresh()
    }

    Timer {
        interval: 15000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
