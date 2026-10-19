import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// The status bar (18 px): left, what is going on: errors (until the next good poll), short messages (a few
// seconds), a confirm, a hover hint, else "Playing on This PC" (the state on an accent bar while another
// device plays); right, the "..." menu.
Item {
    id: bar
    required property var panel
    Layout.fillWidth: true
    implicitHeight: MenuStyle.spotifyStatusHeight

    readonly property bool confirming: panel.confirmLogout || panel.confirmClient
    readonly property string message: panel.confirmLogout ? "Log out of Spotify here?"
        : panel.confirmClient ? "Log out and change the client ID?"
        : panel.statusError !== "" ? panel.statusError
        : panel.note !== "" ? panel.note
        : panel.hint
    readonly property bool isState: message === ""
    readonly property string stateText: SpotifyState.player
        ? (SpotifyState.player.playing ? "Playing" : "Paused") + " on " + panel.deviceName()
        : "Nothing playing"

    RowLayout {
        anchors.fill: parent
        spacing: MenuStyle.gap
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: bar.isState && panel.remote ? MenuStyle.selectBar : "transparent"
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                anchors.fill: parent
                anchors.leftMargin: MenuStyle.gap
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: bar.isState ? (panel.remote ? MenuStyle.selectText : MenuStyle.bevelDark)
                    : (panel.statusError !== "" && !bar.confirming ? Config.colors.urgent : Config.colors.text)
                text: bar.isState ? bar.stateText : bar.message
            }
        }
        BevelButton {
            visible: bar.confirming
            implicitHeight: MenuStyle.spotifyStatusHeight
            text: panel.confirmClient ? "Change" : "Log out"
            focusPolicy: Qt.NoFocus
            onClicked: {
                if (panel.confirmClient) {
                    panel.confirmClient = false;
                    SpotifyState.logout();
                    panel.editClient = true;
                } else {
                    panel.confirmLogout = false;
                    SpotifyState.logout();
                }
            }
        }
        BevelButton {
            visible: bar.confirming
            implicitHeight: MenuStyle.spotifyStatusHeight
            text: "Cancel"
            focusPolicy: Qt.NoFocus
            onClicked: {
                panel.confirmLogout = false;
                panel.confirmClient = false;
            }
        }
        BevelButton {
            visible: !bar.confirming
            implicitHeight: MenuStyle.spotifyStatusHeight
            glyph: "\ue5d3"
            checked: panel.menuOpen
            focusPolicy: Qt.NoFocus
            onClicked: panel.menuOpen = !panel.menuOpen
            SpotifyHint { panel: bar.panel; text: "More: log out, client ID, reload" }
        }
    }
}
