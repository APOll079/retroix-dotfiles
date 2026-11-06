pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The to-do list of the side panel's Calendar tab: a plain text file, todo.txt in the state dir, one task
// per line: `[ ] 2026-11-10 buy milk` or `[x] 2026-11-10 buy milk` (the date is optional). Blank lines and
// every line that is not a task (your own notes, comments) are kept verbatim in their place and written
// back unchanged; so are the line endings (LF or CRLF) and a missing or present final newline.
//
// parse / serialise and the edit helpers (toggled, added, removed) are pure functions of a parsed value
// { items: [{ done, due, text, raw, line }], lines: [string] }: serialise(parse(t)) === t for any t.
// `lines` is the text split on "\n" (a "\r" stays on its line), so joining it gives the file back.
//
// Safe loading follows GuardedFileView, but that type parses JSON on load, so this is a plain FileView with
// the same guard: a file that cannot be read (anything but "not found") is copied to todo.txt.bad-<timestamp>,
// the list runs empty in memory, nothing is written (`broken`) until a later load succeeds; a missing file is
// created by the first add. watchChanges picks up edits made elsewhere.
Singleton {
    id: root

    readonly property string path: Quickshell.statePath("todo.txt")
    property bool broken: false
    property var parsed: root.parse("")
    readonly property var items: root.parsed.items
    // yyyy-MM-dd -> true, for the days that have an open task due (the calendar marks them)
    readonly property var dueDays: root.dueDaysOf(root.items)
    // today as yyyy-MM-dd (overdue = open and due before it); refreshed every minute and by refreshToday()
    property string today: root.ymd(new Date())

    // ---- pure functions ----

    function pad2(n) {
        return (n < 10 ? "0" : "") + n;
    }
    // y, m (0-11), d -> "yyyy-MM-dd"; or one Date
    function ymd(y, m, d) {
        if (y instanceof Date)
            return y.getFullYear() + "-" + root.pad2(y.getMonth() + 1) + "-" + root.pad2(y.getDate());
        return y + "-" + root.pad2(m + 1) + "-" + root.pad2(d);
    }
    // a real calendar date written yyyy-MM-dd
    function validDate(s) {
        const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
        if (!m)
            return false;
        const y = Number(m[1]), mo = Number(m[2]), d = Number(m[3]);
        if (mo < 1 || mo > 12 || d < 1)
            return false;
        return d <= new Date(y, mo, 0).getDate();
    }
    // one line (without its "\r") -> { done, due, text } or null when it is not a task
    function parseLine(line) {
        const m = /^\[( |x|X)\] (.*)$/.exec(line);
        if (!m)
            return null;
        let rest = m[2], due = "";
        const d = /^(\d{4}-\d{2}-\d{2}) (.*)$/.exec(rest);
        if (d && root.validDate(d[1])) {
            due = d[1];
            rest = d[2];
        }
        if (rest.trim() === "")
            return null;
        return { done: m[1] !== " ", due: due, text: rest };
    }
    function parse(text) {
        const lines = String(text).split("\n");
        const items = [];
        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i];
            const t = root.parseLine(raw.endsWith("\r") ? raw.slice(0, -1) : raw);
            if (t)
                items.push({ done: t.done, due: t.due, text: t.text, raw: raw, line: i });
        }
        return { items: items, lines: lines };
    }
    function serialise(p) {
        return p.lines.join("\n");
    }
    // the line an item is written as; keeps the "\r" of a CRLF file
    function lineOf(it, cr) {
        return "[" + (it.done ? "x" : " ") + "] " + (it.due !== "" ? it.due + " " : "") + it.text + (cr ? "\r" : "");
    }
    function usesCrlf(p) {
        return p.lines.length > 1 && p.lines[0].endsWith("\r");
    }
    function reparse(lines) {
        return root.parse(lines.join("\n"));
    }
    // the list with item i switched done / open (its line is rewritten, the others stay byte for byte)
    function toggled(p, i) {
        const it = p.items[i];
        if (!it)
            return p;
        const lines = p.lines.slice();
        lines[it.line] = root.lineOf({ done: !it.done, due: it.due, text: it.text }, it.raw.endsWith("\r"));
        return root.reparse(lines);
    }
    // the list with a new open task at the end of the tasks' file (before a final newline)
    function added(p, text, due) {
        const t = String(text).replace(/[\r\n]+/g, " ").trim();
        if (t === "")
            return p;
        const d = root.validDate(due || "") ? due : "";
        const lines = p.lines.slice();
        const line = root.lineOf({ done: false, due: d, text: t }, root.usesCrlf(p));
        if (lines.length > 1 && lines[lines.length - 1] === "")
            lines.splice(lines.length - 1, 0, line);       // keep the final newline last
        else if (lines.length === 1 && lines[0] === "")
            lines.splice(0, 1, line, "");                  // an empty file becomes one line plus its newline
        else
            lines.push(line);
        return root.reparse(lines);
    }
    function removed(p, i) {
        const it = p.items[i];
        if (!it)
            return p;
        const lines = p.lines.slice();
        lines.splice(it.line, 1);
        if (lines.length === 0)
            lines.push("");
        return root.reparse(lines);
    }
    function dueDaysOf(items) {
        const out = {};
        for (const it of items)
            if (!it.done && it.due !== "")
                out[it.due] = true;
        return out;
    }
    // open and due before `today` (both yyyy-MM-dd)
    function isOverdue(it, today) {
        return !it.done && it.due !== "" && it.due < today;
    }
    // "2026-11-10 buy milk" -> { due, text }; no leading valid date -> due is "". Text is trimmed.
    function splitInput(s) {
        const m = /^\s*(\d{4}-\d{2}-\d{2})\s+(.*)$/.exec(String(s));
        if (m && root.validDate(m[1]))
            return { due: m[1], text: m[2].trim() };
        return { due: "", text: String(s).trim() };
    }

    // ---- state ----

    // Every change goes through here: memory first, then the file unless it is guarded
    function apply(p) {
        root.parsed = p;
        return root.write();
    }
    function write() {
        if (root.broken)
            return false;
        file.setText(root.serialise(root.parsed));
        return true;
    }
    function add(text, due) {
        const p = root.added(root.parsed, text, due);
        if (p === root.parsed)
            return false;
        return root.apply(p);
    }
    function toggle(i) {
        return root.apply(root.toggled(root.parsed, i));
    }
    function remove(i) {
        return root.apply(root.removed(root.parsed, i));
    }
    function reload() {
        file.reload();
    }
    function refreshToday() {
        root.today = root.ymd(new Date());
    }

    function markBroken(why) {
        if (root.broken)
            return;
        root.broken = true;
        const f = String(file.path).replace(/^file:\/\//, "");
        const copy = f + ".bad-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        Quickshell.execDetached(["cp", "--", f, copy]);
        console.warn("[TodoState] " + f + ": " + why + "; kept a copy as " + copy + ", running on an empty list, not overwriting it");
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.broken = false;
            const t = file.text();
            // our own write coming back: nothing to do
            if (t !== root.serialise(root.parsed))
                root.parsed = root.parse(t);
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                // created by the first add
                root.broken = false;
                root.parsed = root.parse("");
            } else {
                root.parsed = root.parse("");
                root.markBroken("could not be read");
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.refreshToday()
    }
}
