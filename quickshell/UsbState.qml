pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// USB drives. Every 5 s scripts/usb.sh list (one Process at a time) gives `drives` ([{ dev, label, size, mountpoint|null,
// removable }], removable / usb partitions only). The first successful poll only records what is already plugged in
// (those never toast); after that a new drive raises one notify-send toast with Open and Eject buttons.
//   Open  = usb.sh mount, then xdg-open on the mountpoint.   Eject = usb.sh eject, then a "can be removed" toast.
// A failure (busy drive, missing udisksctl) toasts the script's one error line. open(dev) / eject(dev) are also
// for the Start menu; `ejectable` is the mounted drives. Everything outside the repo goes through the script, with
// the device name passed as one argument after a name check. Not started when QS_NO_APPLY is set (the test harness).
// The decisions (diff, parse, labels, sizes) are pure functions so tests can drive them without any tool.
Singleton {
    id: root

    readonly property bool active: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    readonly property int pollInterval: 5000
    readonly property int labelMax: 32
    readonly property string script: Quickshell.shellDir + "/scripts/usb.sh"

    property var drives: []
    property bool baselined: false
    readonly property var ejectable: root.drives.filter(d => d.mountpoint !== null)

    // ---- pure helpers ----
    function validDev(dev) {
        return typeof dev === "string" && /^[a-z0-9]+$/.test(dev);
    }

    // "15.9 GB", "512 MB", "2.0 TB" (decimal units, like the rest of the shell)
    function formatSize(n) {
        if (!(n >= 0))
            return "?";
        if (n >= 1e12)
            return (n / 1e12).toFixed(1) + " TB";
        if (n >= 1e9)
            return (n / 1e9).toFixed(1) + " GB";
        return Math.round(n / 1e6) + " MB";
    }

    // Label text from outside: control characters and line breaks become spaces, long ones are cut
    function cleanLabel(s) {
        let t = "";
        for (const ch of String(s === null || s === undefined ? "" : s)) {
            const c = ch.charCodeAt(0);
            t += (c < 32 || (c >= 127 && c < 160) || c === 0x2028 || c === 0x2029) ? " " : ch;
        }
        t = t.replace(/\s+/g, " ").trim();
        return t.length > root.labelMax ? t.slice(0, root.labelMax - 3) + "..." : t;
    }

    // What a drive is called in a toast or menu: its label, or the device name when it has none
    function displayName(d) {
        const l = root.cleanLabel(d.label);
        return l !== "" ? l : d.dev;
    }

    function toastBody(d) {
        return root.displayName(d) + " (" + root.formatSize(d.size) + ")";
    }

    // usb.sh list output -> the drives array, or null when it is not a usable list (keep the old one then)
    function parse(text) {
        let data = null;
        try { data = JSON.parse(text); } catch (e) { return null; }
        if (!Array.isArray(data))
            return null;
        const out = [];
        for (const d of data) {
            if (!d || !root.validDev(d.dev))
                continue;
            out.push({
                dev: d.dev,
                label: root.cleanLabel(d.label),
                size: typeof d.size === "number" ? d.size : 0,
                mountpoint: typeof d.mountpoint === "string" && d.mountpoint !== "" ? d.mountpoint : null,
                removable: d.removable === true
            });
        }
        return out;
    }

    // { added, removed } by device name: added are in `next` only, removed in `prev` only
    function diff(prev, next) {
        const had = new Set(prev.map(d => d.dev)), has = new Set(next.map(d => d.dev));
        return { added: next.filter(d => !had.has(d.dev)), removed: prev.filter(d => !has.has(d.dev)) };
    }

    // One poll result: the new drives array, the drives to toast (none on the first poll), and the baseline flag
    function step(prev, baselined, next) {
        return { drives: next, toast: baselined ? root.diff(prev, next).added : [], baselined: true };
    }

    function find(dev) {
        return root.drives.find(d => d.dev === dev) || null;
    }

    // ---- live part ----
    function toast(title, body, actions) {
        const args = ["notify-send", "-a", "USB"];
        for (const a of actions || [])
            args.push("-A", a);
        args.push(title, body);
        return args;
    }

    function say(title, body) {
        Quickshell.execDetached(root.toast(title, body));
    }

    function open(dev) {
        if (!root.active || !root.validDev(dev))
            return;
        root.runJob("mount", dev);
    }

    function eject(dev) {
        if (!root.active || !root.validDev(dev))
            return;
        root.runJob("eject", dev);
    }

    function runJob(kind, dev) {
        const d = root.find(dev);
        jobComp.createObject(root, { kind: kind, dev: dev, name: d ? root.displayName(d) : dev });
    }

    // A just-plugged drive toast: waits for the button (notify-send -A prints the chosen id) and acts on it
    function announce(d) {
        toastComp.createObject(root, { dev: d.dev, title: "USB drive plugged in", body: root.toastBody(d) });
    }

    function poll() {
        if (!list.running)
            list.running = true;
    }

    Component {
        id: toastComp
        Process {
            id: t
            property string dev: ""
            property string title: ""
            property string body: ""
            command: root.toast(t.title, t.body, ["open=Open", "eject=Eject"])
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    const a = text.trim();
                    if (a === "open")
                        root.open(t.dev);
                    else if (a === "eject")
                        root.eject(t.dev);
                }
            }
            onExited: t.destroy()
        }
    }

    Component {
        id: jobComp
        Process {
            id: j
            property string kind: ""
            property string dev: ""
            property string name: ""
            command: ["sh", root.script, j.kind, j.dev]
            running: true
            stdout: StdioCollector { id: so }
            stderr: StdioCollector { id: se }
            onExited: code => {
                if (code === 0) {
                    if (j.kind === "mount") {
                        const mp = so.text.trim();
                        if (mp !== "")
                            Quickshell.execDetached(["xdg-open", mp]);
                    } else {
                        root.say(j.name + " can be removed", "");
                    }
                } else {
                    const err = se.text.trim().split("\n")[0];
                    root.say(j.kind === "mount" ? "Could not open " + j.name : "Could not eject " + j.name, err !== "" ? err : "Failed");
                }
                root.poll();
                j.destroy();
            }
        }
    }

    Process {
        id: list
        command: ["sh", root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = root.parse(text);
                if (next === null)
                    return;
                const r = root.step(root.drives, root.baselined, next);
                root.drives = r.drives;
                root.baselined = r.baselined;
                for (const d of r.toast)
                    root.announce(d);
            }
        }
    }

    Timer {
        interval: root.pollInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }
}
