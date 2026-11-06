pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Logitech mouse battery through Solaar. Once at start and every 5 minutes scripts/solaar.sh prints
// {present, name, percent, charging}; the bar shows a button while `present` and a percent is known.
//   percent  0..100, or -1 when there is nothing to show
//   label    "80%" ("80%+" while charging), "" when absent
//   tooltip  "MX Master 3: 80%, charging", "" when absent
// settings.mouse.enabled = false turns the polling off. Not started when QS_NO_APPLY is set (the test harness).
// parse / labelFor / tooltipFor are pure functions so tests can drive them without Solaar.
Singleton {
    id: root

    readonly property bool active: Config.settingsLoaded && Config.settings.mouse.enabled && !Quickshell.env("QS_NO_APPLY")
    readonly property int pollInterval: 300000

    property bool present: false
    property string name: ""
    property int percent: -1
    property bool charging: false
    readonly property bool visibleInBar: root.present && root.percent >= 0
    readonly property string label: root.labelFor(root.visibleInBar, root.percent, root.charging)
    readonly property string tooltip: root.tooltipFor(root.visibleInBar, root.name, root.percent, root.charging)

    // ---- pure helpers ----
    // solaar.sh output -> { present, name, percent (-1 = none), charging }; anything odd is "not present"
    function parse(text) {
        const none = { present: false, name: "", percent: -1, charging: false };
        try {
            const o = JSON.parse(text);
            if (!o || o.present !== true || typeof o.percent !== "number" || !(o.percent >= 0 && o.percent <= 100))
                return none;
            return { present: true, name: root.cleanName(o.name), percent: Math.round(o.percent), charging: o.charging === true };
        } catch (e) {
            return none;
        }
    }

    // Names come from the device: control characters become spaces, long ones are cut
    function cleanName(s) {
        let t = "";
        for (const ch of String(s === null || s === undefined ? "" : s)) {
            const c = ch.charCodeAt(0);
            t += (c < 32 || (c >= 127 && c < 160)) ? " " : ch;
        }
        t = t.replace(/\s+/g, " ").trim();
        return t.length > 40 ? t.slice(0, 37) + "..." : t;
    }

    function labelFor(show, percent, charging) {
        return show ? percent + "%" + (charging ? "+" : "") : "";
    }

    function tooltipFor(show, name, percent, charging) {
        if (!show)
            return "";
        return (name !== "" ? name : "Mouse") + ": " + percent + "%" + (charging ? ", charging" : "");
    }

    function take(text) {
        const s = root.parse(text);
        root.present = s.present;
        root.name = s.name;
        root.percent = s.percent;
        root.charging = s.charging;
    }

    // ---- live part ----
    Process {
        id: poll
        command: ["sh", Quickshell.shellDir + "/scripts/solaar.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
    }

    Timer {
        interval: root.pollInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!poll.running) poll.running = true; }
    }

    onActiveChanged: {
        if (!root.active)
            root.take("");
    }
}
