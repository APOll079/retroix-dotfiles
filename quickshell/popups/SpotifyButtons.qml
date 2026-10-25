import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// The transport row: [shuffle] [previous] [play / pause] [next] [repeat] as equal columns across the full width,
// all spotifyButton tall with spotifyButtonGlyph icons (the one non-square button shape in the drawer).
// Shuffle and repeat show their state: sunken face and an accent glyph while on; repeat-one swaps in the glyph
// with the 1. compact: the lyrics view's row: previous / play / next only (+ Play here on another device).
RowLayout {
    id: buttons
    required property var panel
    property bool compact: false
    spacing: MenuStyle.gap
    readonly property bool shuffleOn: SpotifyState.player !== null && SpotifyState.player.shuffle
    readonly property string repeatMode: SpotifyState.player ? SpotifyState.player.repeat : "off"
    readonly property bool playing: SpotifyState.player !== null && SpotifyState.player.playing

    // One column: the button fills it; a disabled one says why through the host
    component Cell: SpotifyReasonHost {
        panel: buttons.panel
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        Layout.horizontalStretchFactor: 1
        implicitWidth: MenuStyle.spotifyButton
        implicitHeight: MenuStyle.spotifyButton
    }

    Cell {
        visible: !buttons.compact
        reason: SpotifyState.player === null ? "Shuffle: nothing is playing" : ""
        BevelButton {
            anchors.fill: parent
            glyph: "\ue043"
            glyphSize: MenuStyle.spotifyButtonGlyph
            glyphColor: buttons.shuffleOn ? MenuStyle.barOnGlyph : "transparent"
            checked: buttons.shuffleOn
            enabled: SpotifyState.player !== null
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.toggleShuffle()
            SpotifyHint { panel: buttons.panel; text: buttons.shuffleOn ? "Shuffle: on" : "Shuffle: off" }
        }
    }
    Cell {
        BevelButton {
            anchors.fill: parent
            glyph: "\ue045"
            glyphSize: MenuStyle.spotifyButtonGlyph
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.previous()
            SpotifyHint { panel: buttons.panel; text: "Previous (Ctrl+Left)" }
        }
    }
    Cell {
        BevelButton {
            anchors.fill: parent
            glyph: buttons.playing ? "\ue034" : "\ue037"
            glyphSize: MenuStyle.spotifyButtonGlyph
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.togglePlay()
            SpotifyHint { panel: buttons.panel; text: buttons.playing ? "Pause (Space)" : "Play (Space)" }
        }
    }
    Cell {
        BevelButton {
            anchors.fill: parent
            glyph: "\ue044"
            glyphSize: MenuStyle.spotifyButtonGlyph
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.next()
            SpotifyHint { panel: buttons.panel; text: "Next (Ctrl+Right)" }
        }
    }
    Cell {
        visible: !buttons.compact
        reason: SpotifyState.player === null ? "Repeat: nothing is playing" : ""
        BevelButton {
            anchors.fill: parent
            glyph: buttons.repeatMode === "track" ? "\ue041" : "\ue040"
            glyphSize: MenuStyle.spotifyButtonGlyph
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
    }
    Cell {
        visible: buttons.compact && SpotifyState.player !== null && !SpotifyState.local
        BevelButton {
            anchors.fill: parent
            text: "Play here"
            glyph: "\ue30a"
            glyphSize: MenuStyle.spotifyButtonGlyph
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.playHere()
        }
    }
}
