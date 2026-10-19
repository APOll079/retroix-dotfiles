import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// Previous / play / next (+ shuffle / repeat when full, + Play here on another device).
// full: false is the slim strip under the lyrics.
RowLayout {
    id: buttons
    required property var panel
    property bool full: true
    spacing: MenuStyle.gap
    BevelButton {
        Layout.fillWidth: true
        visible: buttons.full
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: "\ue043"
        checked: SpotifyState.player !== null && SpotifyState.player.shuffle
        enabled: SpotifyState.player !== null
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.toggleShuffle()
        SpotifyHint {
            panel: buttons.panel
            text: SpotifyState.player && SpotifyState.player.shuffle ? "Shuffle: on" : "Shuffle: off"
        }
    }
    BevelButton {
        Layout.fillWidth: true
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: "\ue045"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.previous()
        SpotifyHint { panel: buttons.panel; text: "Previous" }
    }
    BevelButton {
        Layout.fillWidth: true
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: SpotifyState.player && SpotifyState.player.playing ? "\ue034" : "\ue037"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.togglePlay()
        SpotifyHint { panel: buttons.panel; text: SpotifyState.player && SpotifyState.player.playing ? "Pause" : "Play" }
    }
    BevelButton {
        Layout.fillWidth: true
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: "\ue044"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.next()
        SpotifyHint { panel: buttons.panel; text: "Next" }
    }
    BevelButton {
        Layout.fillWidth: true
        visible: buttons.full
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: SpotifyState.player && SpotifyState.player.repeat === "track" ? "\ue041" : "\ue040"
        checked: SpotifyState.player !== null && SpotifyState.player.repeat !== "off"
        enabled: SpotifyState.player !== null
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.cycleRepeat()
        SpotifyHint {
            panel: buttons.panel
            text: !SpotifyState.player || SpotifyState.player.repeat === "off" ? "Repeat: off" : (SpotifyState.player.repeat === "track" ? "Repeat: one song" : "Repeat: all")
        }
    }
    BevelButton {
        visible: !buttons.full && SpotifyState.player !== null && !SpotifyState.local
        implicitHeight: MenuStyle.spotifyCompactRow
        text: "Play here"
        glyph: "\ue30a"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.playHere()
    }
}
