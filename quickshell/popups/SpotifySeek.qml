import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// The seek row (the main view and the lyrics view use the same one): times at both ends in a fixed width, the
// RetroSlider between; dragging shows the target time on the left and jumps on release; the wheel steps 5 s.
RowLayout {
    id: seekRow
    required property var panel
    spacing: MenuStyle.gap

    // widest time ("00:00"), so the slider never shifts when the digits change
    TextMetrics {
        id: timeWidth
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        text: "00:00"
    }
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
        dim: SpotifyState.track === null
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
        SpotifyHint { panel: seekRow.panel; text: "Seek (the wheel: 5 s)" }
    }
    // a disabled slider gets no hover: the row says why
    SpotifyHint { panel: seekRow.panel; text: SpotifyState.track === null ? "Seek: nothing is playing" : "" }
    Text {
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        Layout.preferredWidth: timeWidth.width
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        color: Config.colors.text
        // nothing playing: the last played song's length (the bar itself is disabled and empty)
        text: panel.clock(SpotifyState.track ? SpotifyState.track.duration : (panel.lastTrack ? panel.lastTrack.duration : 0))
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
