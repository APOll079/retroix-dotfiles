import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Seek bar, transport buttons and the volume row (hidden in the lyrics view, where a slim SpotifyButtons
// strip stays). Like and add-to-playlist live in the header with the other track actions.
// Seek and volume are the same slider (RetroSlider): the knob follows the song / the volume, dragging shows
// the target time, and the mouse wheel on a row steps it (seek 5 s, volume 5 %).
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
    TextMetrics {
        id: pctWidth
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        text: "100%"
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

    // Volume: the speaker mutes (sunken while muted); the wheel steps 5 %
    RowLayout {
        id: volumeRow
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        BevelButton {
            implicitHeight: MenuStyle.spotifyCompactRow
            glyph: SpotifyState.volume === 0 ? "\ue04f" : "\ue050"
            checked: SpotifyState.volume === 0
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
            SpotifyHint {
                panel: transport.panel
                text: SpotifyState.volume < 0 ? "Volume shows once this PC plays" : "Volume (the wheel: 5 %)"
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
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (SpotifyState.volume < 0)
                    return;
                const step = event.angleDelta.y > 0 ? MenuStyle.spotifyWheelStep : -MenuStyle.spotifyWheelStep;
                SpotifyState.setVolume(Math.max(0, Math.min(100, SpotifyState.volume + step)));
            }
        }
    }
}
