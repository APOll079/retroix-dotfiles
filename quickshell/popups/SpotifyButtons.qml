import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// Previous / play / next (+ shuffle / repeat when full, + Play here on another device).
// full: false is the slim strip under the lyrics.
RowLayout {
    property bool full: true
    spacing: MenuStyle.gap
    BevelButton {
        Layout.fillWidth: true
        visible: parent.full
        glyph: "\ue043"
        checked: SpotifyState.player !== null && SpotifyState.player.shuffle
        enabled: SpotifyState.player !== null
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.toggleShuffle()
    }
    BevelButton {
        Layout.fillWidth: true
        glyph: "\ue045"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.previous()
    }
    BevelButton {
        Layout.fillWidth: true
        glyph: SpotifyState.player && SpotifyState.player.playing ? "\ue034" : "\ue037"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.togglePlay()
    }
    BevelButton {
        Layout.fillWidth: true
        glyph: "\ue044"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.next()
    }
    BevelButton {
        Layout.fillWidth: true
        visible: parent.full
        glyph: SpotifyState.player && SpotifyState.player.repeat === "track" ? "\ue041" : "\ue040"
        checked: SpotifyState.player !== null && SpotifyState.player.repeat !== "off"
        enabled: SpotifyState.player !== null
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.cycleRepeat()
    }
    BevelButton {
        visible: !parent.full && SpotifyState.player !== null && !SpotifyState.local
        text: "Play here"
        glyph: "\ue30a"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.playHere()
    }
}
