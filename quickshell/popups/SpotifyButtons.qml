import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Shuffle (small square), previous, PLAY / PAUSE (the wide one), next, repeat (small square). Shuffle and
// repeat show their state: sunken face and an accent glyph while on; repeat-one swaps in the glyph with the 1.
// full: false is the slim strip under the lyrics (previous / play / next, + Play here on another device).
RowLayout {
    id: buttons
    required property var panel
    property bool full: true
    spacing: MenuStyle.gap
    readonly property bool shuffleOn: SpotifyState.player !== null && SpotifyState.player.shuffle
    readonly property string repeatMode: SpotifyState.player ? SpotifyState.player.repeat : "off"
    BevelButton {
        visible: buttons.full
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: "\ue043"
        glyphColor: buttons.shuffleOn ? MenuStyle.barOnGlyph : "transparent"
        checked: buttons.shuffleOn
        enabled: SpotifyState.player !== null
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.toggleShuffle()
        SpotifyHint {
            panel: buttons.panel
            text: buttons.shuffleOn ? "Shuffle: on" : "Shuffle: off"
        }
    }
    BevelButton {
        Layout.fillWidth: true
        Layout.horizontalStretchFactor: 1
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: "\ue045"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.previous()
        SpotifyHint { panel: buttons.panel; text: "Previous" }
    }
    BevelButton {
        Layout.fillWidth: true
        Layout.horizontalStretchFactor: 2
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: SpotifyState.player && SpotifyState.player.playing ? "\ue034" : "\ue037"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.togglePlay()
        SpotifyHint { panel: buttons.panel; text: SpotifyState.player && SpotifyState.player.playing ? "Pause" : "Play" }
    }
    BevelButton {
        Layout.fillWidth: true
        Layout.horizontalStretchFactor: 1
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: "\ue044"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.next()
        SpotifyHint { panel: buttons.panel; text: "Next" }
    }
    BevelButton {
        visible: buttons.full
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: buttons.repeatMode === "track" ? "\ue041" : "\ue040"
        glyphColor: buttons.repeatMode !== "off" ? MenuStyle.barOnGlyph : "transparent"
        checked: buttons.repeatMode !== "off"
        enabled: SpotifyState.player !== null
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.cycleRepeat()
        SpotifyHint {
            panel: buttons.panel
            text: buttons.repeatMode === "off" ? "Repeat: off" : (buttons.repeatMode === "track" ? "Repeat: one song" : "Repeat: all")
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
