pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Disk clean-up state for the Clean up panel and the Start menu's "Empty Trash (size)" row. scripts/cleanup.sh
// measures (`sizes`, read-only) and is the only thing that deletes (`run <id>`). Root items (package cache,
// orphans) are not run by the script: it prints the doas command line and this opens it in the configured terminal
// (same shape as ServicesPanel.dialogCommand), so the password prompt is the real one.
// Nothing runs on its own: load() measures when the panel opens, run(id) only after the panel's confirm.
// Under QS_NO_APPLY (the test harness) no tool is started; run(id) only records the id in `runLog`.
Singleton {
    id: root

    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    readonly property string script: Quickshell.shellDir + "/scripts/cleanup.sh"
    readonly property int shotDays: 30            // screenshots older than this are offered for the Trash
    readonly property var knownIds: ["pacman-cache", "orphans", "flatpak-unused", "shots", "trash"]

    property var rows: []                 // [{ id, label, bytes, count, needsRoot, note }] from `sizes`
    property bool loading: false
    property string result: ""            // the last run's message
    property bool resultOk: true
    property var runLog: []               // ids passed to run() under QS_NO_APPLY

    readonly property var trashRow: rows.find(r => r.id === "trash") || null
    readonly property real trashBytes: trashRow && typeof trashRow.bytes === "number" ? trashRow.bytes : 0
    readonly property string trashLabel: trashBytes > 0 ? "Empty Trash (" + formatBytes(trashBytes) + ")" : "Empty Trash"
    readonly property real totalBytes: total(rows)

    signal terminalOpened()

    // ---- pure helpers ----

    // Decimal units: "0 B", "512 B", "1.5 KB", "1.2 GB". null / negative / NaN: "?"
    function formatBytes(n) {
        if (typeof n !== "number" || !(n >= 0))
            return "?";
        if (n < 1000)
            return Math.round(n) + " B";
        const units = ["KB", "MB", "GB", "TB"];
        let v = n / 1000, i = 0;
        while (v >= 999.95 && i < units.length - 1) {
            v /= 1000;
            i++;
        }
        return v.toFixed(1) + " " + units[i];
    }

    // Sum of the known sizes (null counts as 0)
    function total(rows) {
        let n = 0;
        for (const r of rows)
            if (typeof r.bytes === "number" && r.bytes > 0)
                n += r.bytes;
        return n;
    }

    // Something to clean: a size above zero, or a count above zero when the size is unknown
    function cleanable(r) {
        if (typeof r.bytes === "number")
            return r.bytes > 0;
        return typeof r.count === "number" && r.count > 0;
    }

    function visibleRows(rows) {
        return rows.filter(cleanable);
    }

    // The size column: "1.2 GB", "3 items (size unknown)", "not installed"
    function sizeText(r) {
        if (typeof r.bytes === "number")
            return formatBytes(r.bytes);
        if (r.note === "not installed")
            return "not installed";
        if (typeof r.count === "number")
            return r.count + (r.count === 1 ? " item" : " items") + " (size unknown)";
        return "unknown";
    }

    // The second line of a row: the count, and the doas hint for root items
    function detailText(r) {
        const parts = [];
        if (typeof r.count === "number" && r.id !== "flatpak-unused")
            parts.push(r.count + (r.count === 1 ? " item" : " items"));
        if (r.needsRoot)
            parts.push("(asks for doas in a terminal)");
        return parts.join(" ");
    }

    function confirmVerb(r) {
        return r.id === "trash" ? "Empty Trash" : "Clean up";
    }

    // The question, naming the size
    function confirmText(r) {
        const size = sizeText(r);
        if (r.id === "trash")
            return "Empty the Trash? " + size + " will be gone for good.";
        if (r.id === "shots")
            return "Move " + size + " of old screenshots to the Trash?";
        if (r.needsRoot)
            return "Clean up " + r.label + " (" + size + ")? A terminal opens and asks for doas.";
        return "Clean up " + r.label + " (" + size + ")?";
    }

    // sizes output -> rows, [] for anything that is not the expected JSON
    function parseSizes(text) {
        try {
            const d = JSON.parse(text);
            if (!Array.isArray(d))
                return [];
            return d.filter(r => r && typeof r.id === "string" && root.knownIds.indexOf(r.id) >= 0 && typeof r.label === "string").map(r => ({
                id: r.id,
                label: r.label,
                bytes: typeof r.bytes === "number" ? r.bytes : null,
                count: typeof r.count === "number" ? r.count : null,
                needsRoot: r.needsRoot === true,
                note: typeof r.note === "string" ? r.note : ""
            }));
        } catch (e) {
            return [];
        }
    }

    // run output -> { terminal } | { ok, message } | null
    function parseRun(text) {
        try {
            const d = JSON.parse(text);
            if (d && typeof d.terminal === "string" && d.terminal !== "")
                return { terminal: d.terminal };
            if (d && typeof d.ok === "boolean")
                return { ok: d.ok, message: typeof d.message === "string" ? d.message : "" };
        } catch (e) {
        }
        return null;
    }

    // [terminal, classFlag, "qs-dialog", "fish", "-c", "<cmd>; echo; read ..."]; classFlag "" = don't name the window
    function terminalCommand(terminal, classFlag, cmd) {
        return [terminal].concat(classFlag !== "" ? [classFlag, "qs-dialog"] : []).concat(["fish", "-c", cmd + "; echo; read -P 'Press Enter to close'"]);
    }

    // ---- live part ----

    function clearResult() {
        root.result = "";
        root.resultOk = true;
    }

    function load() {
        if (!root.live || sizesProc.running)
            return;
        root.loading = true;
        sizesProc.running = true;
    }

    // Deletes (or opens the terminal for) one item. The panel calls this only after its confirm.
    function run(id) {
        if (root.knownIds.indexOf(id) < 0)
            return;
        if (!root.live) {
            root.runLog = root.runLog.concat([id]);
            return;
        }
        if (runProc.running)
            return;
        root.result = "";
        runProc.command = ["sh", root.script, "run", id, String(root.shotDays)];
        runProc.running = true;
    }

    Process {
        id: sizesProc
        command: ["sh", root.script, "sizes", String(root.shotDays)]
        stdout: StdioCollector {
            onStreamFinished: root.rows = root.parseSizes(text)
        }
        onExited: root.loading = false
    }

    Process {
        id: runProc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root.parseRun(text);
                if (r === null) {
                    root.resultOk = false;
                    root.result = "The clean-up script gave no answer";
                } else if (r.terminal !== undefined) {
                    termProc.command = root.terminalCommand(Config.settings.execCommands.terminal, Config.settings.execCommands.terminalClassFlag, r.terminal);
                    termProc.running = true;
                    root.terminalOpened();
                } else {
                    root.resultOk = r.ok;
                    root.result = r.message;
                }
            }
        }
        onExited: root.load()
    }

    Process {
        id: termProc
        onExited: root.load()
    }
}
