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
    property bool nasWatch: NasWatch.active
    property bool phoneBattery: PhoneBattery.active
    property bool screensaver: ScreensaverState.active
    property var miniPlayerState: MiniPlayerState
    property var overviewState: OverviewState
    property bool securityAudit: SecurityAudit.active
    property bool mouseState: MouseState.active
    property bool downloadWatch: DownloadWatch.active
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
    // Keys / Network / Services windows (ToolWindows.qml): `qs ipc call keys toggle` (also open, close). The old per-monitor
    // names (cheatsheet_<mon>, network_<mon>, services_<mon>) still toggle, for binds that name a monitor.
    IpcHandler {
        target: "keys"
        function toggle(): void { ToolWindows.toggle("keys"); }
        function open(): void { ToolWindows.open("keys"); }
        function close(): void { ToolWindows.close("keys"); }
    }
    IpcHandler {
        target: "network"
        function toggle(): void { ToolWindows.toggle("network"); }
        function open(): void { ToolWindows.open("network"); }
        function close(): void { ToolWindows.close("network"); }
    }
    IpcHandler {
        target: "services"
        function toggle(): void { ToolWindows.toggle("services"); }
        function open(): void { ToolWindows.open("services"); }
        function close(): void { ToolWindows.close("services"); }
    }
    Variants {
        model: Quickshell.screens
        Scope {
            required property var modelData
            IpcHandler {
                target: "cheatsheet_" + modelData.name
                function toggle(): void { ToolWindows.toggle("keys"); }
            }
            IpcHandler {
                target: "network_" + modelData.name
                function toggle(): void { ToolWindows.toggle("network"); }
            }
            IpcHandler {
                target: "services_" + modelData.name
                function toggle(): void { ToolWindows.toggle("services"); }
            }
        }
    }
    // A failed-service toast's Details: the Services window, on that service's log
    Connections {
        target: ServiceWatch
        function onDetailsRequested(name) { ToolWindows.showServiceDetails(name); }
    }
    // Lyrics window (popups/LyricsWindow.qml): `qs ipc call lyrics toggle`
    IpcHandler {
        target: "lyrics"
        function toggle(): void { LyricsWindowState.toggle(); }
        function open(): void { LyricsWindowState.open(); }
        function close(): void { LyricsWindowState.close(); }
    }
    // Screensaver: `qs ipc call screensaver start|stop|preview`; Mini player: `qs ipc call miniplayer toggle|open|close`
    IpcHandler {
        target: "screensaver"
        function start(): void { ScreensaverState.start(); }
        function stop(): void { ScreensaverState.stop(); }
        function preview(): void { ScreensaverState.preview(); }
    }
    IpcHandler {
        target: "miniplayer"
        function toggle(): void { MiniPlayerState.toggle(); }
        function open(): void { MiniPlayerState.open(); }
        function close(): void { MiniPlayerState.close(); }
    }
    // Find window (popups/FindWindow.qml): `qs ipc call find toggle`
    IpcHandler {
        target: "find"
        function toggle(): void { FindWindowState.toggle(); }
        function open(): void { FindWindowState.open(""); }
        function close(): void { FindWindowState.close(); }
    }
    Variants {
        model: Quickshell.screens
        IdleDim {}
    }
}
