pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's calculator history: the last 10 results that were copied (a calculation or a unit conversion), each
// the value that went to the clipboard and the query that made it. Kept in calc-history.json in Quickshell's state
// dir (a GuardedFileView: a broken file is kept as .bad-<time> and never overwritten). Typing `=` alone (or `hist`)
// in the launcher lists them; Enter or a click copies the value again.
// clean / added are pure functions of the list, so tests can drive them.
Singleton {
    id: root

    readonly property int max: 10
    property alias entries: adapter.entries          // [{ value, query }], newest first

    // Anything that came out of the file -> a valid list: objects with a non-empty string value, the query a string,
    // the same value + query pair only once, at most `max` entries
    function clean(list, max) {
        const out = [];
        if (!Array.isArray(list))
            return out;
        for (const e of list) {
            if (!e || typeof e.value !== "string" || e.value.trim() === "")
                continue;
            const q = typeof e.query === "string" ? e.query : "";
            if (out.some(x => x.value === e.value && x.query === q))
                continue;
            out.push({ value: e.value, query: q });
        }
        return out.slice(0, max > 0 ? max : 10);
    }

    // The list with one more result on top: an older entry with the same value and query moves up instead of repeating,
    // the oldest fall off past `max`. An empty value changes nothing.
    function added(list, value, query, max) {
        const v = typeof value === "string" ? value.trim() : "";
        if (v === "")
            return root.clean(list, max);
        const q = typeof query === "string" ? query.trim() : "";
        return root.clean([{ value: v, query: q }].concat(Array.isArray(list) ? list : []), max);
    }

    function add(value, query) {
        adapter.entries = root.added(adapter.entries, value, query, root.max);
    }

    // First run has no file yet; GuardedFileView creates it
    GuardedFileView {
        path: Quickshell.statePath("calc-history.json")
        printErrors: false
        JsonAdapter {
            id: adapter
            property var entries: []
        }
    }
}
