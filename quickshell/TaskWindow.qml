pragma Singleton
import QtQuick
import Quickshell
import "popups" as Popups

// The one Task Manager window (popups/TaskManager.qml) for every monitor. Opened by Ctrl+Shift+Esc
// (`qs ipc call taskmanager open`, the IpcHandler in shell.qml), the bar's CPU button (a toggle) and the SysMon
// popup. Opening it again focuses the open window instead of making a second one.
Singleton {
    // tab: "apps" | "processes" | "performance", or "" for the one it had
    function open(tab) {
        win.open(tab || "");
    }

    readonly property bool visible: win.visible

    // The bar's CPU button: a click shows the window, the next one hides it (like every other bar button)
    function toggle(tab) {
        if (win.visible)
            win.closeMenu();
        else
            win.open(tab || "");
    }

    Popups.TaskManager {
        id: win
    }
}
