pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cursor and icon themes for the Themes menu. scripts/appearance.sh does the work (it lists the installed themes, reads
// and sets them through gsettings and hyprctl; a missing tool is skipped there). refresh() reads the lists and the current
// values once (the Themes menu calls it when it opens); setCursor() / setIcons() run the script with the name as one
// argument after the same name check the script does. Nothing runs when QS_NO_APPLY is set (the test harness): the calls
// are only recorded in `log`. The parsing and the checks are pure functions so tests can drive them without any tool.
Singleton {
    id: root

    readonly property bool active: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    readonly property string script: Quickshell.shellDir + "/scripts/appearance.sh"
    readonly property var sizes: [24, 32, 48]

    property var cursors: []
    property var icons: []
    property string cursorTheme: ""
    property int cursorSize: 24
    property string iconTheme: ""
    property var log: []    // argument lists handed to the script under QS_NO_APPLY (tests)

    // ---- pure helpers ----
    function validName(n) {
        return typeof n === "string" && /^[A-Za-z0-9._-]+$/.test(n) && n[0] !== "." && n[0] !== "-";
    }

    function validSize(s) {
        return root.sizes.indexOf(s) !== -1;
    }

    // list-cursors / list-icons output -> array of valid names, or null when it is not a list
    function parseList(text) {
        let data = null;
        try { data = JSON.parse(text); } catch (e) { return null; }
        return Array.isArray(data) ? data.filter(n => root.validName(n)) : null;
    }

    // get-cursor output -> { theme, size } (theme "" and size 24 when unusable), or null
    function parseCursor(text) {
        let d = null;
        try { d = JSON.parse(text); } catch (e) { return null; }
        if (!d || typeof d !== "object")
            return null;
        return { theme: root.validName(d.theme) ? d.theme : "", size: root.validSize(d.size) ? d.size : 24 };
    }

    function parseIcons(text) {
        let d = null;
        try { d = JSON.parse(text); } catch (e) { return null; }
        if (!d || typeof d !== "object")
            return null;
        return { theme: root.validName(d.theme) ? d.theme : "" };
    }

    // The label on the Themes menu button
    function cursorLabel() {
        return "Cursor: " + (root.cursorTheme !== "" ? root.cursorTheme : "default");
    }
    function iconsLabel() {
        return "Icons: " + (root.iconTheme !== "" ? root.iconTheme : "default");
    }

    // The Themes menu's two dropdowns (PopupMenu models): the themes, then for the cursor the three sizes; a check marks
    // the current ones. A pick keeps the Themes menu open.
    function cursorModel() {
        const m = root.cursors.map(n => ({
            text: n,
            checked: n === root.cursorTheme,
            action: () => root.setCursor(n, root.cursorSize)
        }));
        if (m.length === 0)
            return [{ text: "No cursor themes found", enabled: false }];
        m.push({ separator: true });
        for (const s of root.sizes)
            m.push({
                text: "Size " + s,
                checked: s === root.cursorSize,
                enabled: root.cursorTheme !== "",
                action: () => root.setSize(s)
            });
        return m;
    }

    function iconsModel() {
        const m = root.icons.map(n => ({
            text: n,
            checked: n === root.iconTheme,
            action: () => root.setIcons(n)
        }));
        return m.length === 0 ? [{ text: "No icon themes found", enabled: false }] : m;
    }

    // ---- live part ----
    function refresh() {
        if (!root.active)
            return;
        curList.running = true;
        icoList.running = true;
        curGet.running = true;
        icoGet.running = true;
    }

    function setCursor(name, size) {
        if (!root.validName(name) || !root.validSize(size))
            return false;
        root.cursorTheme = name;
        root.cursorSize = size;
        return root.run(["set-cursor", name, String(size)]);
    }

    function setSize(size) {
        return root.cursorTheme === "" ? false : root.setCursor(root.cursorTheme, size);
    }

    function setIcons(name) {
        if (!root.validName(name))
            return false;
        root.iconTheme = name;
        return root.run(["set-icons", name]);
    }

    function run(args) {
        if (!root.active) {
            root.log = root.log.concat([args]);
            return true;
        }
        Quickshell.execDetached(["sh", root.script].concat(args));
        return true;
    }

    Process {
        id: curList
        command: ["sh", root.script, "list-cursors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = root.parseList(text);
                if (l !== null)
                    root.cursors = l;
            }
        }
    }
    Process {
        id: icoList
        command: ["sh", root.script, "list-icons"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = root.parseList(text);
                if (l !== null)
                    root.icons = l;
            }
        }
    }
    Process {
        id: curGet
        command: ["sh", root.script, "get-cursor"]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = root.parseCursor(text);
                if (c !== null) {
                    root.cursorTheme = c.theme;
                    root.cursorSize = c.size;
                }
            }
        }
    }
    Process {
        id: icoGet
        command: ["sh", root.script, "get-icons"]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = root.parseIcons(text);
                if (c !== null)
                    root.iconTheme = c.theme;
            }
        }
    }
}
