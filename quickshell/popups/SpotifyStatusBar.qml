import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// The drawer's status bar on the shared StatusBar: left, what is going on: errors (until the next good
// poll), short messages (a few seconds), a confirm, a hover hint, else "Playing on This PC" (the state on
// an accent bar while another device plays); right, the "..." menu.
StatusBar {
    id: bar
    required property var panel

    readonly property bool confirming: panel.confirmLogout || panel.confirmClient
    readonly property string message: panel.confirmLogout ? "Log out of Spotify here?"
        : panel.confirmClient ? "Log out and change the client ID?"
        : panel.statusError !== "" ? panel.statusError
        : panel.note !== "" ? panel.note
        : panel.hint
    readonly property bool isState: message === ""
    readonly property string stateText: SpotifyState.player
        ? (SpotifyState.player.playing ? "Playing" : "Paused") + " on " + panel.deviceName()
        : (panel.lastTrack ? "Last played" : "Nothing playing")

    text: bar.isState ? bar.stateText : bar.message
    kind: bar.isState ? "state" : (panel.statusError !== "" && !bar.confirming ? "error" : "message")
    highlighted: bar.isState && panel.remote

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
