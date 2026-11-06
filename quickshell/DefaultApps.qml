pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Default applications (Start > Default apps): the current default web browser, image viewer, video player, file manager and
// text editor, and the installed applications that could take over. scripts/defaultapps.sh does the reading (xdg-settings /
// xdg-mime query, the .desktop files) and the only writing (xdg-settings set / xdg-mime default), and only runs after the panel's
// "Make default" click. Under QS_NO_APPLY (the test harness) no tool is started; makeDefault() only records in `setLog`.
// parse / flatRows / validId are pure so tests can drive them.
Singleton {
    id: root

    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    readonly property string script: Quickshell.shellDir + "/scripts/defaultapps.sh"

    property var categories: []           // [{ key, label, current, candidates: [{ id, name }] }]
    property bool loaded: false
    property bool busy: false
    property string result: ""            // the last Make default's message
    property bool resultOk: true
    property var setLog: []               // [{ key, id }] recorded under QS_NO_APPLY
    readonly property var rows: root.flatRows(root.categories)

    // ---- pure helpers ----
    function validId(id) {
        return typeof id === "string" && /^[A-Za-z0-9_][A-Za-z0-9._-]*\.desktop$/.test(id);
    }

    function validKey(key) {
        return ["browser", "image", "video", "files", "editor"].indexOf(key) >= 0;
    }

    // defaultapps.sh list output -> categories; junk gives []. Names come from .desktop files: control characters become spaces.
    function parse(text) {
        try {
            const a = JSON.parse(text);
            if (!Array.isArray(a))
                return [];
            return a.filter(c => c && root.validKey(c.key) && typeof c.label === "string" && Array.isArray(c.candidates)).map(c => ({
                key: c.key,
                label: c.label,
                current: root.validId(c.current) ? c.current : "",
                candidates: c.candidates.filter(x => x && root.validId(x.id)).map(x => ({ id: x.id, name: root.cleanName(x.name, x.id) }))
            }));
        } catch (e) {
            return [];
        }
    }

    function cleanName(name, id) {
        let t = "";
        for (const ch of String(name === null || name === undefined ? "" : name)) {
            const c = ch.charCodeAt(0);
            t += (c < 32 || (c >= 127 && c < 160)) ? " " : ch;
        }
        t = t.replace(/\s+/g, " ").trim();
        if (t === "")
            t = String(id).replace(/\.desktop$/, "");
        return t.length > 40 ? t.slice(0, 37) + "..." : t;
    }

    // What the current default is called: its Name= when it is among the candidates, else the id, else "none set"
    function currentName(cat) {
        if (cat.current === "")
            return "none set";
        const c = cat.candidates.find(x => x.id === cat.current);
        return c ? c.name : cat.current.replace(/\.desktop$/, "");
    }

    // The list the panel shows: a head row per kind, then one row per candidate
    //   { head: true, key, text, sub }   |   { head: false, key, id, text, isDefault }
    function flatRows(cats) {
        const out = [];
        for (const c of cats) {
            out.push({ head: true, key: c.key, id: "", text: c.label, sub: "now: " + root.currentName(c), isDefault: false });
            for (const x of c.candidates)
                out.push({ head: false, key: c.key, id: x.id, text: x.name, sub: x.id, isDefault: x.id === c.current });
            if (c.candidates.length === 0)
                out.push({ head: false, key: c.key, id: "", text: "No installed application offers this", sub: "", isDefault: false, none: true });
        }
        return out;
    }

    // Row indexes the cursor can stand on (an application that is not already the default)
    function pickable(rows) {
        const out = [];
        rows.forEach((r, i) => { if (!r.head && !r.none && !r.isDefault) out.push(i); });
        return out;
    }

    function clearResult() {
        root.result = "";
        root.resultOk = true;
    }

    function take(text) {
        root.categories = root.parse(text);
        root.loaded = true;
    }

    // ---- live part ----
    function load() {
        if (!root.live || listProc.running)
            return;
        listProc.running = true;
    }

    // Make `id` the default for `key`; both are checked here and again by the script. Reloads the list when it is done.
    function makeDefault(key, id) {
        if (!root.validKey(key) || !root.validId(id) || root.busy)
            return false;
        root.result = "";
        if (!root.live) {
            root.setLog = root.setLog.concat([{ key: key, id: id }]);
            return true;
        }
        root.busy = true;
        setProc.command = ["sh", root.script, "set", key, id];
        setProc.running = true;
        return true;
    }

    Process {
        id: listProc
        command: ["sh", root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
    }

    Process {
        id: setProc
        stderr: StdioCollector {
            id: setErr
        }
        onExited: code => {
            root.busy = false;
            root.resultOk = code === 0;
            root.result = code === 0 ? "Default changed" : (setErr.text.trim() !== "" ? setErr.text.trim().split("\n")[0] : "Could not change the default (exit " + code + ")");
            root.load();
        }
    }
}
