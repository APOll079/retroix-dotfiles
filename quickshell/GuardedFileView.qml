import QtQuick
import Quickshell
import Quickshell.Io

// A FileView for a hand-editable JSON state file (put a JsonAdapter inside it, as with FileView) that
// never overwrites a file it could not read. If the JSON on disk is invalid (or the read fails for any
// reason but "not found"), the file is copied to <path>.bad-<timestamp>, the adapter keeps its defaults
// in memory, and writing is skipped (`broken`) until a later load parses again, i.e. until you save a
// valid edit (reload happens at start, or on fileChanged where the file sets watchChanges).
// A missing file is created from the defaults. Changes made from QML are saved by this type
// (adapterUpdated -> writeAdapter), so users must NOT add their own onAdapterUpdated; they may still
// use onLoaded / onLoadFailed (the guard is a Connections, so handlers stack). A file that does not use
// the adapter calls save(text) instead of setText().
FileView {
    id: root

    property bool broken: false

    // setText that respects the guard; false when the write was skipped
    function save(text) {
        if (root.broken)
            return false;
        root.setText(text);
        return true;
    }

    function markBroken(why) {
        if (root.broken)
            return;
        root.broken = true;
        const file = String(root.path).replace(/^file:\/\//, "");
        const copy = file + ".bad-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        Quickshell.execDetached(["cp", "--", file, copy]);
        console.warn("[GuardedFileView] " + file + ": " + why + "; kept a copy as " + copy + ", running on defaults, not overwriting it");
    }

    // (a property, not a child: FileView's default property is the adapter)
    property QtObject guard: Connections {
        target: root

        function onLoaded() {
            let why = "";
            try {
                const t = root.text().trim();
                if (t !== "")
                    JSON.parse(t);
            } catch (e) {
                why = String(e);
            }
            if (why === "")
                root.broken = false;
            else
                root.markBroken("invalid JSON (" + why + ")");
        }

        function onLoadFailed(error) {
            if (error == FileViewError.FileNotFound) {
                root.broken = false;
                root.writeAdapter();
            } else {
                root.markBroken("could not be read");
            }
        }

        function onAdapterUpdated() {
            if (!root.broken)
                root.writeAdapter();
        }
    }
}
