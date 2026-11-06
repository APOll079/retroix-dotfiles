pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The last 20 colours picked with the colour picker bind (scripts/colorpick.sh runs `hyprpicker -a`, which also copies
// the colour; the bind then calls `qs ipc call colors add <#rrggbb>`). Newest first, each once (picking a colour again
// moves it to the top). Saved in color-history.json (state dir, a GuardedFileView). Shown by popups/ColorHistoryPanel.qml.
// The parse / format / list functions are pure so tests can drive them. Under QS_NO_APPLY (the test harness) nothing is
// copied: copy() only records the hex in copyLog. shell.qml must reference it once (the IpcHandler "colors" does).
Singleton {
    id: root

    readonly property int maxItems: 20
    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    property var copyLog: []             // hexes passed to copy() under QS_NO_APPLY

    // [{ hex: "#rrggbb", rgb: "rgb(r, g, b)" }], newest first
    readonly property var list: root.clean(Array.from(adapter.colors || []))

    // ---- pure helpers ----

    // "#A1B2C3", "a1b2c3", "#abc" -> "#a1b2c3"; anything else -> null
    function parseHex(text) {
        let t = String(text === undefined || text === null ? "" : text).trim().toLowerCase();
        if (t[0] === "#")
            t = t.substring(1);
        if (/^[0-9a-f]{3}$/.test(t))
            t = t[0] + t[0] + t[1] + t[1] + t[2] + t[2];
        return /^[0-9a-f]{6}$/.test(t) ? "#" + t : null;
    }

    // "#a1b2c3" -> "rgb(161, 178, 195)"
    function rgbText(hex) {
        const h = root.parseHex(hex);
        if (h === null)
            return "";
        return "rgb(" + parseInt(h.substring(1, 3), 16) + ", " + parseInt(h.substring(3, 5), 16) + ", " + parseInt(h.substring(5, 7), 16) + ")";
    }

    function entryFor(hex) {
        const h = root.parseHex(hex);
        return h === null ? null : { hex: h, rgb: root.rgbText(h) };
    }

    // Saved entries -> valid ones (hex and rgb rebuilt from the hex), duplicates dropped, at most maxItems
    function clean(entries) {
        const out = [];
        const seen = {};
        for (const e of entries) {
            const x = root.entryFor(e && typeof e === "object" ? e.hex : e);
            if (x !== null && !seen[x.hex]) {
                seen[x.hex] = true;
                out.push(x);
            }
        }
        return out.slice(0, root.maxItems);
    }

    // `entries` with `hex` at the top (an older copy of it removed), at most maxItems. An invalid hex changes nothing.
    function withColor(entries, hex) {
        const x = root.entryFor(hex);
        if (x === null)
            return root.clean(entries);
        return root.clean([x].concat(entries));
    }

    // wl-copy arguments for a hex (only a valid colour; one argument, never part of script text)
    function copyCommand(hex) {
        const h = root.parseHex(hex);
        return h === null ? [] : ["wl-copy", h];
    }

    // ---- live part ----

    function add(hex) {
        if (root.parseHex(hex) === null)
            return false;
        adapter.colors = root.withColor(root.list, hex);
        return true;
    }

    function copy(hex) {
        const cmd = root.copyCommand(hex);
        if (cmd.length === 0)
            return false;
        if (root.live)
            Quickshell.execDetached(cmd);
        else
            root.copyLog = root.copyLog.concat([cmd[1]]);
        return true;
    }

    function clear() {
        adapter.colors = [];
    }

    GuardedFileView {
        path: Quickshell.statePath("color-history.json")
        printErrors: false
        JsonAdapter {
            id: adapter
            property var colors: []
        }
    }
}
