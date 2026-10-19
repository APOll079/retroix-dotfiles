import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// [shuffle] [previous] [PLAY / PAUSE] [next] [repeat], centred. Play is the main button: twice the width of
// previous / next (which are squares) and taller, with a big glyph. Shuffle and repeat are small squares at
// the ends and show their state: sunken face and an accent glyph while on; repeat-one swaps in the glyph with
// the 1. full: false is the slim strip under the lyrics (previous / play / next fill the width, + Play here on
// another device).
RowLayout {
    id: buttons
    required property var panel
    property bool full: true
    spacing: MenuStyle.gap
    readonly property bool shuffleOn: SpotifyState.player !== null && SpotifyState.player.shuffle
    readonly property string repeatMode: SpotifyState.player ? SpotifyState.player.repeat : "off"
    readonly property bool playing: SpotifyState.player !== null && SpotifyState.player.playing

    Item { Layout.fillWidth: true; visible: buttons.full }
    SpotifyReasonHost {
        visible: buttons.full
        Layout.alignment: Qt.AlignVCenter
        panel: buttons.panel
        reason: SpotifyState.player === null ? "Shuffle: nothing is playing" : ""
        BevelButton {
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
    }
    BevelButton {
        Layout.fillWidth: !buttons.full
        Layout.preferredWidth: buttons.full ? MenuStyle.spotifyTransportSide : -1
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: buttons.full ? MenuStyle.spotifyTransportSide : MenuStyle.spotifyCompactRow
        glyph: "\ue045"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.previous()
        SpotifyHint { panel: buttons.panel; text: "Previous (Ctrl+Left)" }
    }
    BevelButton {
        Layout.fillWidth: !buttons.full
        Layout.horizontalStretchFactor: 2
        Layout.preferredWidth: buttons.full ? 2 * MenuStyle.spotifyTransportSide : -1
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: buttons.full ? MenuStyle.spotifyPlayHeight : MenuStyle.spotifyCompactRow
        glyph: buttons.playing ? "\ue034" : "\ue037"
        glyphSize: buttons.full ? MenuStyle.spotifyPlayGlyph : MenuStyle.iconSize
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.togglePlay()
        SpotifyHint { panel: buttons.panel; text: buttons.playing ? "Pause (Space)" : "Play (Space)" }
    }
    BevelButton {
        Layout.fillWidth: !buttons.full
        Layout.preferredWidth: buttons.full ? MenuStyle.spotifyTransportSide : -1
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: buttons.full ? MenuStyle.spotifyTransportSide : MenuStyle.spotifyCompactRow
        glyph: "\ue044"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.next()
        SpotifyHint { panel: buttons.panel; text: "Next (Ctrl+Right)" }
    }
    SpotifyReasonHost {
        visible: buttons.full
        Layout.alignment: Qt.AlignVCenter
        panel: buttons.panel
        reason: SpotifyState.player === null ? "Repeat: nothing is playing" : ""
        BevelButton {
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
    }
    Item { Layout.fillWidth: true; visible: buttons.full }
    BevelButton {
        visible: !buttons.full && SpotifyState.player !== null && !SpotifyState.local
        implicitHeight: MenuStyle.spotifyCompactRow
        text: "Play here"
        glyph: "\ue30a"
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.playHere()
    }
}
