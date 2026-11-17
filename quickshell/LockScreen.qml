pragma Singleton
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pam
import "popups" as Popups

// The lock screen. settings.ui.lockScreen picks it: "win95" (default) locks with
// Quickshell's own WlSessionLock ("hyprlock" runs hyprlock as before): every screen shows its wallpaper (WallpaperState), the monitor that had focus when it
// locked shows the "Welcome to ..." password box (popups/LoginDialog.qml). The password goes to PAM through the
// hyprlock PAM file (/etc/pam.d/hyprlock, already there), so it unlocks with the same rules hyprlock uses.
// lockNow() is the one entry point (Start / launcher / side panel Lock via Session.qml, idle via Idle.qml, IPC
// `qs ipc call lockscreen lock`). If Quickshell dies while locked, Hyprland keeps the screen locked (red screen):
// recovery is in MAINTENANCE.md. Never locks under QS_NO_APPLY (tests).
Singleton {
    id: root

    readonly property bool useWin95: (Config.settings.ui.lockScreen || "win95") === "win95"
    property bool locked: false
    property bool busy: false
    property string status: ""
    property bool statusIsError: false
    property int failures: 0
    property string dialogScreen: ""            // output name that shows the password box
    property string pending: ""                 // the typed password, only until PAM asks for it
    readonly property string user: Quickshell.env("USER") || ""

    signal unlockFailed()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function lockNow() {
        if (!root.useWin95) {
            Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock"]);
            return;
        }
        if (Quickshell.env("QS_NO_APPLY") || root.locked)
            return;
        root.status = "";
        root.statusIsError = false;
        root.failures = 0;
        root.busy = false;
        root.dialogScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        root.locked = true;
    }

    // true for the one screen that carries the password box (the focused one; the first screen if that name is gone)
    function isDialogScreen(name) {
        const names = Quickshell.screens.map(s => s.name);
        if (names.indexOf(root.dialogScreen) < 0)
            return names.length > 0 && name === names[0];
        return name === root.dialogScreen;
    }

    function wallpaperFor(name) {
        const m = WallpaperState.monitors ? WallpaperState.monitors[name] : null;
        return m && m.path ? "file://" + m.path : "";
    }

    function tryUnlock(password) {
        if (root.busy || password === "")
            return;
        root.pending = password;
        root.busy = true;
        root.status = "";
        root.statusIsError = false;
        pam.start();
    }

    PamContext {
        id: pam
        config: "hyprlock"
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.pending);
                root.pending = "";
            }
        }
        onCompleted: result => {
            root.busy = false;
            root.pending = "";
            if (result === PamResult.Success) {
                root.status = "";
                root.locked = false;
                return;
            }
            root.failures += 1;
            root.status = "Wrong password (" + root.failures + ")";
            root.statusIsError = true;
            root.unlockFailed();
        }
        onError: error => {
            root.busy = false;
            root.pending = "";
            root.status = "The password check failed (" + PamError.toString(error) + ")";
            root.statusIsError = true;
            root.unlockFailed();
        }
    }

    WlSessionLock {
        locked: root.locked

        WlSessionLockSurface {
            id: surface
            color: Config.colors.outline

            Image {
                anchors.fill: parent
                source: surface.screen ? root.wallpaperFor(surface.screen.name) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            // Win95's "Shut Down" screen: a 50 % checkerboard of the outline colour over everything behind the boxes
            // (Qt's Dense4Pattern, one fill); with ui.dither off a flat half-transparent outline tint instead
            Canvas {
                anchors.fill: parent
                antialiasing: false
                visible: Config.settings.ui.dither !== false
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = ctx.createPattern(Config.colors.outline, Qt.Dense4Pattern);
                    ctx.fillRect(0, 0, width, height);
                }
            }
            Rectangle {
                anchors.fill: parent
                visible: Config.settings.ui.dither === false
                color: Config.colors.outline
                opacity: 0.5
            }

            // a click anywhere puts the keyboard back in the password field
            MouseArea {
                anchors.fill: parent
                onClicked: dialog.focusInput()
            }

            // focus once the surface really has the keyboard (at creation it doesn't yet, so a focus call then is lost)
            Timer {
                interval: 100
                running: root.locked && surface.screen !== null && root.isDialogScreen(surface.screen.name)
                onTriggered: dialog.focusInput()
            }
            Connections {
                target: surface
                function onVisibleChanged() {
                    if (surface.visible)
                        dialog.focusInput();
                }
            }

            // Fusion with hyprlock.conf's look: its "Locked" panel (avatar, big clock, date) on top, the Win95 logon box
            // below it as one whole; same width, one gap between.
            Column {
                anchors.centerIn: parent
                spacing: MenuStyle.space12
                visible: surface.screen ? root.isDialogScreen(surface.screen.name) : false

            Popups.LockHeader {
                date: clock.date
            }

            Popups.LoginDialog {
                id: dialog
                mode: "lock"
                blockCaret: true
                user: root.user
                busy: root.busy
                status: root.status
                statusIsError: root.statusIsError
                onAccepted: (user, password) => root.tryUnlock(password)

                Connections {
                    target: root
                    function onUnlockFailed() { dialog.clear(); }
                }
            }
            }
        }
    }
}
