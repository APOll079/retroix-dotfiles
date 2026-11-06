pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Login time report (Start > Login report). hypr/autostart.lua appends "<epoch-ms> <name>" lines to
// $XDG_RUNTIME_DIR/qs-login-times as the session starts; scripts/loginreport.py turns that into
// [{ name, ms, since_previous_ms }], slowest step first. load() runs it when the panel opens; nothing else runs it.
// Under QS_NO_APPLY (the test harness) no tool is started. parse / totalMs / msText / fraction are pure.
Singleton {
    id: root

    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    readonly property string script: Quickshell.shellDir + "/scripts/loginreport.py"

    property var rows: []                 // [{ name, ms, since }] slowest first
    property bool loaded: false
    readonly property int totalMs: root.totalOf(root.rows)
    readonly property int slowestMs: root.rows.length > 0 ? root.rows[0].since : 0

    // ---- pure helpers ----
    // loginreport.py output -> rows; junk gives []
    function parse(text) {
        try {
            const a = JSON.parse(text);
            if (!Array.isArray(a))
                return [];
            return a.filter(r => r && typeof r.name === "string" && r.name !== "" && typeof r.ms === "number" && typeof r.since_previous_ms === "number")
                .map(r => ({ name: r.name, ms: r.ms, since: r.since_previous_ms }));
        } catch (e) {
            return [];
        }
    }

    // Time from the first step to the last: the largest ms
    function totalOf(rows) {
        let m = 0;
        for (const r of rows)
            m = Math.max(m, r.ms);
        return m;
    }

    // "850 ms", "4.2 s", "1 min 12 s"
    function msText(ms) {
        if (typeof ms !== "number" || !(ms >= 0))
            return "?";
        if (ms < 1000)
            return Math.round(ms) + " ms";
        if (ms < 60000)
            return (ms / 1000).toFixed(1) + " s";
        return Math.floor(ms / 60000) + " min " + Math.round((ms % 60000) / 1000) + " s";
    }

    // Bar length 0..1 of a step against the slowest one
    function fraction(since, slowest) {
        return slowest > 0 ? Math.max(0, Math.min(1, since / slowest)) : 0;
    }

    function take(text) {
        root.rows = root.parse(text);
        root.loaded = true;
    }

    // ---- live part ----
    function load() {
        if (!root.live || proc.running)
            return;
        proc.running = true;
    }

    Process {
        id: proc
        command: ["python3", "-I", root.script]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
    }
}
