import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// The one-time setup / login page of the Spotify drawer: client ID, then the browser login.
// Shown while SpotifyState is not logged in (SpotifyPanel.qml).
ColumnLayout {
    required property var panel
    readonly property var input: clientInput
    anchors.fill: parent
    anchors.margins: MenuStyle.pad
    visible: !SpotifyState.loggedIn
    spacing: MenuStyle.pad

    Text {
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        color: Config.colors.text
        text: !SpotifyState.configured || panel.editClient
            ? "One-time setup:\n1. developer.spotify.com > Dashboard > Create app.\n2. Redirect URI: http://127.0.0.1:8898/callback\n3. Tick Web API, save, copy the Client ID here."
            : "Log in once in the browser. The login is kept in Quickshell's state folder."
    }
    SearchBox {
        id: clientInput
        Layout.fillWidth: true
        implicitHeight: MenuStyle.rowHeight + MenuStyle.gap
        visible: !SpotifyState.configured || panel.editClient
        showIcon: false
        placeholder: "Client ID"
        onEscaped: panel.closeCallback()
        onKeyPressed: event => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && clientInput.text.trim() !== "") {
                panel.saveClient();
                event.accepted = true;
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        BevelButton {
            visible: !SpotifyState.configured || panel.editClient
            text: "Save"
            enabled: clientInput.text.trim() !== ""
            focusPolicy: Qt.NoFocus
            onClicked: panel.saveClient()
        }
        BevelButton {
            visible: SpotifyState.configured && !panel.editClient
            text: SpotifyState.loggingIn ? "Waiting for the browser..." : "Log in"
            glyph: "\ue890"
            enabled: !SpotifyState.loggingIn
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.login()
        }
        Item { Layout.fillWidth: true }
        BevelButton {
            visible: SpotifyState.configured && !panel.editClient
            text: "Change client ID"
            focusPolicy: Qt.NoFocus
            onClicked: {
                panel.editClient = true;
                clientInput.text = "";
                clientInput.focusInput();
            }
        }
    }
    Text {
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        visible: SpotifyState.error !== ""
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        color: Config.colors.urgent
        text: SpotifyState.error
    }
    Item { Layout.fillHeight: true }
}
