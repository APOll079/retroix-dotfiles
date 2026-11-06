//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

/* NOTE: CHANGE THESE IF YOU WANT TO USE A DIFFERENT ICON THEME:*/
//@ pragma IconTheme RetroismIcons
//@ pragma Env QS_ICON_THEME=RetroismIcons

import QtQuick
import Quickshell
import Quickshell.Io

import "taskbar" as Taskbar
import "popups" as Popups

Scope {
    id: root
    // singletons are lazy: reading this keeps the low-memory watcher alive
    property bool memoryWatch: MemoryWatch.active
    Taskbar.Bar {}
    Popups.OsdPopup {}
    Popups.NotificationDaemon {}
    // Task Manager window (TaskWindow.qml): Ctrl+Shift+Esc runs `qs ipc call taskmanager open`
    IpcHandler {
        target: "taskmanager"
        function open(): void { TaskWindow.open(""); }
        function performance(): void { TaskWindow.open("performance"); }
    }
    Variants {
        model: Quickshell.screens
        IdleDim {}
    }
}
