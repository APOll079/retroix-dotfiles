import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell

import ".."

// The Win95 "Welcome to Windows" password box, shared by the lock screen (LockScreen.qml, mode "lock") and the
// login screen (greeter/, mode "greeter"). Key left, the prompt, User name and Password fields, OK (the default
// button) on the right, one status line under the fields. No Cancel button (nothing to cancel on a lock; Escape clears).
// The host does the authentication: it gets accepted(user, password) and sets `busy` / `status` / `statusIsError`.
// Keys: Enter = OK, Escape clears the password (the lock never closes on it), Tab moves between fields.
// A FocusScope whose password field (greeter with no user: the user field) holds the focus by default, so the field is
// ready to type into as soon as the window gets the keyboard, no click needed.
FocusScope {
    id: root

    property string mode: "lock"                 // "lock" | "greeter"
    property string user: ""
    property bool busy: false                    // authenticating: fields and OK disabled
    property string status: ""
    property bool statusIsError: false
    property string keyIcon: Quickshell.iconPath("keyring-manager", true)   // the greeter points it at a copied file
    property bool blockCaret: false              // a solid block caret (the lock), else the normal thin one
    readonly property bool userEditable: root.mode === "greeter"
    readonly property string password: passField.text

    signal accepted(string user, string password)
    signal cancelled()

    function clear() {
        passField.text = "";
        root.focusInput();
    }
    function focusInput() {
        if (root.userEditable && userField.text === "")
            userField.forceActiveFocus();
        else
            passField.forceActiveFocus();
    }
    function submit() {
        if (root.busy || passField.text === "" || userField.text.trim() === "")
            return;
        root.accepted(userField.text.trim(), passField.text);
    }
    function cancel() {
        passField.text = "";
        root.cancelled();
        root.focusInput();
    }

    implicitWidth: MenuStyle.lockWidth
    implicitHeight: content.implicitHeight + MenuStyle.chromeTop + MenuStyle.chromeBottom
    width: implicitWidth
    height: implicitHeight

    Keys.onPressed: event => root.handleKey(event)
    function handleKey(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            root.submit();
        } else if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            root.cancel();
        }
    }

    PopupWindowFrame {
        // title case like "Locked" above it: "Welcome to Cherry"
        windowTitle: {
            const t = Config.settings.currentTheme || "windows";
            return "Welcome to " + t.charAt(0).toUpperCase() + t.slice(1);
        }

        RowLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: MenuStyle.space12

            // the key: the RetroismIcons pixel icon (16 px) drawn at 2x with no smoothing, crisp like Win95's logon icon
            Image {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: MenuStyle.loginGlyphSize
                Layout.preferredHeight: MenuStyle.loginGlyphSize
                source: root.keyIcon
                sourceSize.width: MenuStyle.loginGlyphSize / 2
                sourceSize.height: MenuStyle.loginGlyphSize / 2
                smooth: false
                mipmap: false
                fillMode: Image.PreserveAspectFit
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: MenuStyle.pad

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: Config.colors.text
                    text: root.userEditable ? "Type a user name and password to log on." : "Type your password to unlock this computer."
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: MenuStyle.pad
                    rowSpacing: MenuStyle.pad

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: Config.colors.text
                        text: "User name:"
                    }
                    SunkenField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: MenuStyle.rowHeight + MenuStyle.gap
                        color: root.userEditable ? Config.colors.highlight : Config.colors.base
                        TextField {
                            id: userField
                            anchors.fill: parent
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            selectionColor: Config.colors.shadow
                            selectedTextColor: Config.colors.text
                            readOnly: !root.userEditable || root.busy
                            activeFocusOnTab: root.userEditable
                            focus: root.userEditable && root.user === ""
                            text: root.user
                            padding: 0
                            verticalAlignment: Text.AlignVCenter
                            background: Item {}
                            Keys.onPressed: event => root.handleKey(event)
                        }
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: Config.colors.text
                        text: "Password:"
                    }
                    SunkenField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: MenuStyle.rowHeight + MenuStyle.gap
                        TextField {
                            id: passField
                            anchors.fill: parent
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            selectionColor: Config.colors.shadow
                            selectedTextColor: Config.colors.text
                            echoMode: TextInput.Password
                            focus: !(root.userEditable && root.user === "")
                            cursorDelegate: root.blockCaret ? blockCaretComp : null
                            passwordCharacter: "*"
                            readOnly: root.busy
                            activeFocusOnTab: true
                            padding: 0
                            verticalAlignment: Text.AlignVCenter
                            background: Item {}
                            Keys.onPressed: event => root.handleKey(event)
                        }
                    }
                }

                StatusBar {
                    Layout.fillWidth: true
                    kind: root.statusIsError ? "error" : "state"
                    text: root.busy ? "Checking..." : root.status
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: MenuStyle.pad

                BevelButton {
                    Layout.fillWidth: true
                    text: "OK"
                    isDefault: true
                    enabled: !root.busy
                    onClicked: root.submit()
                }
            }
        }
    }

    Component {
        id: blockCaretComp
        Rectangle {
            width: caretMetrics.advanceWidth
            color: Config.colors.text
            TextMetrics {
                id: caretMetrics
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                text: "M"
            }
        }
    }
}
