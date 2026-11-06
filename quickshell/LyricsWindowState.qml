pragma Singleton
import QtQuick
import Quickshell

// The one Lyrics window (popups/LyricsWindow.qml). `qs ipc call lyrics toggle|open|close` (the IpcHandler in shell.qml)
// and the Spotify drawer's "..." menu use it. The window is created when opened and destroyed when closed (Esc,
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
        const comp = Qt.createComponent(Qt.resolvedUrl("popups/LyricsWindow.qml"));
        if (comp.status !== Component.Ready) {
            console.warn("Lyrics window: " + comp.errorString());
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
