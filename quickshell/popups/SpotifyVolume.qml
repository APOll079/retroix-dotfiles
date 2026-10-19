import QtQuick
import QtQuick.Layouts
import ".."

// The volume control in the header's bottom row: the speaker (a mute toggle, sunken while muted), the slider
// filling the width that is left, a fixed-width percent. The wheel anywhere on it steps 5 %.
RowLayout {
    id: volume
    required property var panel
    spacing: MenuStyle.gap

    // widest percent ("100%"), so the slider never shifts when the digits change
    TextMetrics {
        id: pctWidth
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        text: "100%"
    }
    BevelButton {
        implicitHeight: MenuStyle.spotifyCompactRow
        glyph: SpotifyState.volume === 0 ? "\ue04f" : "\ue050"
        checked: SpotifyState.volume === 0
        enabled: SpotifyState.volume >= 0
        focusPolicy: Qt.NoFocus
        onClicked: SpotifyState.toggleMute()
        SpotifyHint {
            panel: volume.panel
            text: SpotifyState.volume === 0 ? "Unmute" : "Mute"
        }
    }
    RetroSlider {
        id: slider
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
            when: !slider.pressed
            value: Math.max(0, SpotifyState.volume)
            restoreMode: Binding.RestoreNone
        }
        SpotifyHint { panel: volume.panel; text: "Volume (the wheel: 5 %, Ctrl+Up / Down)" }
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
    // a disabled slider gets no hover: the row says why
    SpotifyHint { panel: volume.panel; text: SpotifyState.volume < 0 ? "Volume shows once this PC plays" : "" }
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
