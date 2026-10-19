import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Seek bar and transport buttons (hidden in the lyrics view, where a slim SpotifyButtons strip stays). Like,
// add-to-playlist and the volume live in the header's bottom row.
// Seek and volume are the same slider (RetroSlider): the knob follows the song, dragging shows the target
// time, and the mouse wheel on the row steps it (5 s).
ColumnLayout {
    id: transport
    required property var panel
    spacing: MenuStyle.spotifyColumnGap
    visible: !panel.lyricsMode

    // widest time ("00:00"), so the slider never shifts when the digits change
    TextMetrics {
        id: timeWidth
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        text: "00:00"
    }
    // Seek: click or drag to jump; the left time is the target while dragging
    RowLayout {
        id: seekRow
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.preferredWidth: timeWidth.width
            horizontalAlignment: Text.AlignRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: panel.clock(seek.pressed ? seek.value : SpotifyState.progress)
        }
        RetroSlider {
            id: seek
            Layout.fillWidth: true
            implicitHeight: MenuStyle.spotifyCompactRow
            from: 0
            to: SpotifyState.track && SpotifyState.track.duration > 0 ? SpotifyState.track.duration : 1
            enabled: SpotifyState.track !== null
            // the jump happens on release, not at every pixel of the drag
            onPressedChanged: {
                if (!pressed)
                    SpotifyState.seek(value);
            }
            // Glides between the once-a-second ticks instead of jumping (not while you drag)
            Behavior on value {
                enabled: !seek.pressed
                NumberAnimation { duration: MenuStyle.spotifyTickMs }
            }
            Binding on value {
                when: !seek.pressed
                value: Math.min(SpotifyState.progress, seek.to)
                restoreMode: Binding.RestoreNone
            }
            SpotifyHint { panel: transport.panel; text: "Seek (the wheel: 5 s)" }
        }
        // a disabled slider gets no hover: the row says why
        SpotifyHint { panel: transport.panel; text: SpotifyState.track === null ? "Seek: nothing is playing" : "" }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.preferredWidth: timeWidth.width
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: panel.clock(SpotifyState.track ? SpotifyState.track.duration : 0)
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (!SpotifyState.track)
                    return;
                const step = event.angleDelta.y > 0 ? MenuStyle.spotifySeekStepMs : -MenuStyle.spotifySeekStepMs;
                SpotifyState.seek(Math.max(0, Math.min(SpotifyState.track.duration, SpotifyState.progress + step)));
            }
        }
    }

    SpotifyButtons {
        Layout.fillWidth: true
        full: true
        panel: transport.panel
    }
}
