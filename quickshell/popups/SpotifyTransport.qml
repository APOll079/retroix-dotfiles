import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// Seek bar, transport buttons and the volume row (hidden in the lyrics view, where a slim SpotifyButtons
// strip stays). Like and add-to-playlist live in the header with the other track actions.
ColumnLayout {
    id: transport
    required property var panel
    spacing: MenuStyle.spotifyColumnGap
    visible: !panel.lyricsMode

    // Seek bar (same height as the volume slider below): click to jump
    RowLayout {
        Layout.fillWidth: true
        visible: !panel.lyricsMode
        spacing: MenuStyle.gap
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: panel.clock(SpotifyState.progress)
        }
        SegmentBar {
            id: seekBar
            Layout.fillWidth: true
            implicitHeight: MenuStyle.spotifyCompactRow
            value: SpotifyState.track && SpotifyState.track.duration > 0 ? SpotifyState.progress / SpotifyState.track.duration : 0
            // Glides between the once-a-second ticks instead of jumping
            Behavior on value {
                NumberAnimation { duration: MenuStyle.spotifyTickMs }
            }
            MouseArea {
                anchors.fill: parent
                enabled: SpotifyState.track !== null
                cursorShape: Qt.PointingHandCursor
                onReleased: mouse => SpotifyState.seek(Math.max(0, Math.min(1, mouse.x / width)) * SpotifyState.track.duration)
            }
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: panel.clock(SpotifyState.track ? SpotifyState.track.duration : 0)
        }
    }

    SpotifyButtons {
        Layout.fillWidth: true
        full: true
        panel: transport.panel
    }

    // Volume: the speaker mutes
    RowLayout {
        Layout.fillWidth: true
        visible: !panel.lyricsMode
        spacing: MenuStyle.gap
        BevelButton {
            implicitHeight: MenuStyle.spotifyCompactRow
            glyph: SpotifyState.volume === 0 ? "\ue04f" : "\ue050"
            enabled: SpotifyState.volume >= 0
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.toggleMute()
            SpotifyHint {
                panel: transport.panel
                text: SpotifyState.volume < 0 ? "Volume shows once this PC plays" : (SpotifyState.volume === 0 ? "Unmute" : "Mute")
            }
        }
        RetroSlider {
            id: volumeSlider
            Layout.fillWidth: true
            from: 0
            to: 100
            stepSize: 1
            implicitHeight: MenuStyle.spotifyCompactRow
            enabled: SpotifyState.volume >= 0
            // Every change (drag, click, release) goes straight to SpotifyState, which decides
            // where it goes (PipeWire here, Spotify for another device) and what to show
            onMoved: SpotifyState.setVolume(value)
            onPressedChanged: {
                if (!pressed)
                    SpotifyState.setVolume(value);
            }
            // Shows SpotifyState.volume, except while your hand is on the knob.
            // RestoreNone: switching this off must never move the knob.
            Binding on value {
                when: !volumeSlider.pressed
                value: Math.max(0, SpotifyState.volume)
                restoreMode: Binding.RestoreNone
            }
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.preferredWidth: pctWidth.width
            horizontalAlignment: Text.AlignRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: SpotifyState.volume >= 0 ? SpotifyState.volume + "%" : ""
            TextMetrics {
                id: pctWidth
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                text: "100%"
            }
        }
    }
}
