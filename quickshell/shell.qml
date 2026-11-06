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
    property bool serviceWatch: ServiceWatch.active
    property bool diskWatch: DiskWatch.active
    property bool usbWatch: UsbState.active
    property bool networkWatch: NetworkWatch.active
    property bool vpnState: VpnState.active
    property var updateState: UpdateState
    property var cleanupState: CleanupState
    // keeps the recorder state alive (picks up a recording that survived a reload)
    property bool recorder: RecordState.recording
    // keeps the audio state alive (output toast, remembered app volumes)
    property bool audioState: AudioState.live
    // the colour picker bind reports what it picked: `qs ipc call colors add "#rrggbb"`
    IpcHandler {
        target: "colors"
        function add(hex: string): void { ColorHistory.add(hex); }
    }
    Taskbar.Bar {}
    Popups.OsdPopup {}
    Popups.NotificationDaemon {}
    // Task Manager window (TaskWindow.qml): Ctrl+Shift+Esc runs `qs ipc call taskmanager open`
    IpcHandler {
        target: "taskmanager"
        function open(): void { TaskWindow.open(""); }
        function performance(): void { TaskWindow.open("performance"); }
    }
    // Lyrics window (popups/LyricsWindow.qml): `qs ipc call lyrics toggle`
    IpcHandler {
        target: "lyrics"
        function toggle(): void { LyricsWindowState.toggle(); }
        function open(): void { LyricsWindowState.open(); }
        function close(): void { LyricsWindowState.close(); }
    }
    Variants {
        model: Quickshell.screens
        IdleDim {}
    }
}
