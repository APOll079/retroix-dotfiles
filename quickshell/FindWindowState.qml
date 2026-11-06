pragma Singleton
import QtQuick
import Quickshell

// The one Find window (popups/FindWindow.qml, "Find: Files or Folders"). `qs ipc call find toggle|open|close` (the
// IpcHandler in shell.qml) and the launcher's "Open in Find window" row use it: open(name) shows the window and, with a
// name, starts that search. The window is created when opened and destroyed when closed (Esc, Super+Q, toggle); opening
// it again while it is open just focuses it (and takes the new name), never a second window.
Singleton {
    id: root

    property var win: null
    readonly property bool visible: root.win !== null

    function open(name) {
        const q = typeof name === "string" ? name : "";
        if (root.win) {
            root.win.focusSelf();
            if (q !== "")
                root.win.startWith(q);
            return;
        }
        const comp = Qt.createComponent(Qt.resolvedUrl("popups/FindWindow.qml"));
        if (comp.status !== Component.Ready) {
            console.warn("Find window: " + comp.errorString());
            return;
        }
        root.win = comp.createObject(root);
        if (root.win) {
            root.win.closeRequested.connect(root.close);
            if (q !== "")
                root.win.startWith(q);
        }
    }

    function close() {
        if (!root.win)
            return;
        const w = root.win;
        root.win = null;
        w.visible = false;
        w.destroy();
    }

    function toggle() {
        if (root.visible)
            root.close();
        else
            root.open("");
    }
}
