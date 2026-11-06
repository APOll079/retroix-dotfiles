pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The phone's battery for the bar: KDE Connect through scripts/phone.sh battery (the Phone tab keeps no state of its
// own, it only lists devices on demand, so this is a second small reader). Polled every 60 s while `active`.
//  - connected  a paired phone is reachable and reported a level
//  - percent    0..100
//  - charging
//  - label      "78%" (the bar button text), tooltip  "Pixel 8: 78%, charging"
// Not started when QS_NO_APPLY is set (the test harness), so tests never exec real tools. The reading is a pure
// function of the script's output (parse), tested with fixtures.
Singleton {
    id: root

    readonly property bool active: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    readonly property int interval: 60000

    property bool connected: false
    property int percent: 0
    property bool charging: false
    property string name: ""
    readonly property string label: root.connected ? root.percent + "%" : ""
    readonly property string tooltip: root.connected ? root.tooltipFor(root.name, root.percent, root.charging) : ""

    // scripts/phone.sh output -> { connected, percent, charging, name }; anything else is "not connected"
    function parse(text) {
        const off = { connected: false, percent: 0, charging: false, name: "" };
        try {
            const j = JSON.parse(String(text).trim());
            if (j.connected !== true)
                return off;
            const p = Number(j.percent);
            if (!(p >= 0 && p <= 100) || Math.floor(p) !== p)
                return off;
            return { connected: true, percent: p, charging: j.charging === true, name: typeof j.name === "string" ? j.name : "" };
        } catch (e) {
            return off;
        }
    }

    function tooltipFor(name, percent, charging) {
        return (name !== "" ? name + ": " : "Phone: ") + percent + "%" + (charging ? ", charging" : "");
    }

    function apply(r) {
        root.connected = r.connected;
        root.percent = r.percent;
        root.charging = r.charging;
        root.name = r.name;
    }

    function refresh() {
        if (root.active && !reader.running)
            reader.running = true;
    }

    Process {
        id: reader
        command: ["sh", Quickshell.shellDir + "/scripts/phone.sh", "battery"]
        stdout: StdioCollector {
            onStreamFinished: root.apply(root.parse(text))
        }
    }

    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
