// The Win95 login screen: a Quickshell greeter for greetd (see greeter/hypr-greeter.lua and install.sh "Login screen").
// Runs in its own throwaway Hyprland as the `greeter` user, from /etc/greetd/qs-greeter/ (install.sh copies this file next to
// copies of Config.qml, MenuStyle.qml and popups/; nothing is read from your home). Every screen shows the dithered
// background, the focused one the "Locked"-style panel (here "Welcome") and the logon box (popups/LoginDialog.qml in
// greeter mode), with Shut down / Restart under it. Logic: Greetd.createSession(user) -> authMessage -> respond(password)
// -> readyToLaunch -> Greetd.launch(["start-hyprland"]). A wrong password says so and starts over.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import "popups" as Popups

ShellRoot {
    id: root

    property string status: ""
    property bool statusIsError: false
    property bool busy: false
    property int failures: 0
    property string pendingPassword: ""
    property string pendingUser: ""
    property string confirming: ""                 // "", "Shut down" or "Restart"

    // the user name to prefill: the owner who ran install.sh (user.txt next to this file), nothing if it is missing
    FileView {
        id: lastUser
        path: Qt.resolvedUrl("./user.txt")
        blockLoading: true
    }
    readonly property string defaultUser: (lastUser.text() || "").trim()

    function login(user, password) {
        if (root.busy || !Greetd.available)
            return;
        root.busy = true;
        root.status = "";
        root.statusIsError = false;
        root.pendingUser = user;
        root.pendingPassword = password;
        Greetd.createSession(user);
    }

    function failed(message) {
        root.busy = false;
        root.pendingPassword = "";
        root.failures += 1;
        root.status = message + " (" + root.failures + ")";
        root.statusIsError = true;
        Greetd.cancelSession();
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pendingPassword);
                root.pendingPassword = "";
            }
        }
        function onAuthFailure(message) {
            root.failed("Wrong user name or password");
        }
        function onReadyToLaunch() {
            Greetd.launch(["start-hyprland"]);
        }
        function onError(error) {
            root.failed("Login failed: " + error);
        }
        function onLaunched() {
            Qt.quit();
        }
    }

    Process {
        id: power
    }
    function runPower(which) {
        power.command = which === "Restart" ? ["loginctl", "reboot"] : ["loginctl", "poweroff"];
        power.running = true;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            color: Config.colors.outline
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // the same dither as the lock screen (no wallpaper here: the greeter user can't read your home)
            Canvas {
                anchors.fill: parent
                antialiasing: false
                visible: Config.settings.ui.dither !== false
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Config.colors.base;
                    ctx.fillRect(0, 0, width, height);
                    ctx.fillStyle = ctx.createPattern(Config.colors.shadow, Qt.Dense4Pattern);
                    ctx.fillRect(0, 0, width, height);
                }
            }
            Rectangle {
                anchors.fill: parent
                visible: Config.settings.ui.dither === false
                color: Config.colors.base
            }

            MouseArea {
                anchors.fill: parent
                onClicked: dialog.focusInput()
            }

            Column {
                anchors.centerIn: parent
                spacing: MenuStyle.space12
                // the focused screen (the first one when none says so)
                visible: Quickshell.screens.length > 0 && win.modelData.name === Quickshell.screens[0].name

                Popups.LoginDialog {
                    id: dialog
                    mode: "greeter"
                    blockCaret: true
                    keyIcon: Qt.resolvedUrl("./key.png")
                    user: root.defaultUser
                    busy: root.busy
                    status: root.status
                    statusIsError: root.statusIsError
                    onAccepted: (user, password) => root.login(user, password)
                    Component.onCompleted: focusTimer.start()
                }

                // Shut down / Restart: confirm in place (ConfirmBar), like every power action in the shell
                Item {
                    width: MenuStyle.lockWidth
                    height: root.confirming === "" ? MenuStyle.rowHeight + MenuStyle.gap : confirmBar.implicitHeight

                    Row {
                        visible: root.confirming === ""
                        anchors.right: parent.right
                        spacing: MenuStyle.pad
                        Popups.BevelButton {
                            text: "Restart"
                            onClicked: root.confirming = "Restart"
                        }
                        Popups.BevelButton {
                            text: "Shut down"
                            onClicked: root.confirming = "Shut down"
                        }
                    }
                    Popups.ConfirmBar {
                        id: confirmBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: root.confirming !== ""
                        message: root.confirming === "Restart" ? "Restart the computer?" : "Shut down the computer?"
                        verb: root.confirming
                        onAccepted: {
                            const w = root.confirming;
                            root.confirming = "";
                            root.runPower(w);
                        }
                        onCanceled: {
                            root.confirming = "";
                            dialog.focusInput();
                        }
                    }
                }

                Timer {
                    id: focusTimer
                    interval: 150
                    onTriggered: dialog.focusInput()
                }
            }
        }
    }
}
