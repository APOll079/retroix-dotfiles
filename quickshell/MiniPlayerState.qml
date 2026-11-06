pragma Singleton
import QtQuick
import Quickshell

// The one Mini player window (popups/MiniPlayer.qml). `qs ipc call miniplayer toggle|open|close` (the IpcHandler in
// shell.qml) uses it. The window is created when opened and destroyed when closed (Esc,
// Super+Q, toggle); opening it again while it is open just focuses it, never a second window.
Singleton {
    id: root

    property var win: null
    readonly property bool visible: root.win !== null

    function open() {
        if (root.win) {
            root.win.focusSelf();
            return;
        }
        const comp = Qt.createComponent(Qt.resolvedUrl("popups/MiniPlayer.qml"));
        if (comp.status !== Component.Ready) {
            console.warn("Mini player: " + comp.errorString());
            return;
        }
        root.win = comp.createObject(root);
        if (root.win)
            root.win.closeRequested.connect(root.close);
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
            root.open();
    }
}
