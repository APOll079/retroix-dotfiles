import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import ".."

// The Mini player: a small real window (an xdg toplevel Hyprland floats and pins, see the mini-player rule in
// windowrules.lua) in the Winamp spirit. A dark LCD (outline colour) shows the elapsed time big in accent-coloured digits
// and a marquee line "Artist - Title" (it scrolls only when it does not fit; with reduce motion it stays still and is
// cut with "..."). Below: a seek slider, then previous / play-pause / next (same size) and a small volume slider.
// Opened and closed by MiniPlayerState.qml (`qs ipc call miniplayer toggle|open|close`); it exists only while open.
// All data comes from Media.player (MPRIS) and, for the volume of a local Spotify, SpotifyState: no second fetcher,
// nothing new is polled. `hasPlayer`, `playing`, `track`, `position`, `length` (seconds), `volume` (percent, -1 = none)
// and `canSeek` are plain properties; tests set them to fixtures. The decisions are pure functions.
FloatingWindow {
    id: root

    // Hyprland matches this title (windowrules.lua "mini-player")
    title: "Mini player"

    implicitWidth: MenuStyle.widthMedium
    implicitHeight: MenuStyle.chromeTop + MenuStyle.chromeBottom + column.implicitHeight
    minimumSize: Qt.size(MenuStyle.widthMedium, implicitHeight)
    maximumSize: Qt.size(MenuStyle.widthMedium, implicitHeight)
    color: Config.colors.base

    signal closeRequested()
    onClosed: root.closeRequested()

    readonly property var mpr: Media.player
    property bool hasPlayer: Media.player !== null
    property bool playing: Media.playing
    property string track: Media.trackOf(Media.player)
    property real position: 0                     // seconds
    property real length: Media.player ? Media.player.length : 0
    property int volume: root.volumeOf(Media.player ? Media.player.volumeSupported : false, Media.player ? Media.player.volume : 0,
                                       Media.player ? Media.isSpotify(Media.player) : false, SpotifyState.volume)
    property bool canSeek: Media.player ? Media.player.canSeek && Media.player.positionSupported : false
    readonly property bool hasTrack: root.hasPlayer && root.track !== ""
    // the marquee clock (ms), moved by its timer
    property real phaseMs: 0
    readonly property int marqueeSpeed: MenuStyle.rowHeight * 2       // px per second
    readonly property int marqueeHold: 1500                           // ms the start of a long line stays put
    readonly property int marqueeTickMs: MenuStyle.lyricsFastTick

    // ---- pure helpers ----

    // "3:07", "1:02:03"; anything that is not a positive number is "0:00"
    function formatTime(sec) {
        const s = (typeof sec === "number" && isFinite(sec) && sec > 0) ? Math.floor(sec) : 0;
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? h + ":" + pad(m) + ":" + pad(r) : m + ":" + pad(r);
    }

    // The x of a marquee line (0 or negative). A line that fits stays at 0. A long one waits `hold` ms, then slides left
    // at `speed` px/s until a full copy plus `gap` has passed (a second copy follows it at +textW+gap, so the wrap-around
    // is seamless), then starts over.
    function marqueeOffset(textW, viewW, phaseMs, speed, hold, gap) {
        if (!(textW > viewW) || !(speed > 0))
            return 0;
        const travelMs = (textW + gap) / speed * 1000;
        const t = phaseMs % (hold + travelMs);
        return t < hold ? 0 : -Math.round((t - hold) / 1000 * speed);
    }

    // The slider's value for a click at fraction `frac` of the bar, in seconds; clamped to the song
    function seekTarget(frac, length) {
        if (!(length > 0))
            return 0;
        return Math.max(0, Math.min(1, frac)) * length;
    }
    // Where the knob sits (0..1)
    function seekFraction(position, length) {
        if (!(length > 0))
            return 0;
        return Math.max(0, Math.min(1, position / length));
    }

    // The volume to show, in percent, -1 = none: the player's own (MPRIS) if it has one, else a local Spotify's
    // PipeWire volume (SpotifyState.volume, -1 when it has no stream)
    function volumeOf(supported, mprisVolume, isSpotify, spotifyVolume) {
        if (supported)
            return Math.max(0, Math.min(100, Math.round(mprisVolume * 100)));
        return isSpotify && spotifyVolume >= 0 ? spotifyVolume : -1;
    }

    // ---- actions (the player's own calls, as the bar and the drawer make them) ----

    function togglePlay() {
        if (root.mpr && root.mpr.canTogglePlaying)
            root.mpr.togglePlaying();
    }
    function previous() {
        if (root.mpr && root.mpr.canGoPrevious)
            root.mpr.previous();
    }
    function next() {
        if (root.mpr && root.mpr.canGoNext)
            root.mpr.next();
    }
    function seekTo(sec) {
        if (root.mpr && root.canSeek) {
            root.mpr.position = sec;
            root.position = sec;
        }
    }
    function setVolume(pct) {
        const v = Math.max(0, Math.min(100, Math.round(pct)));
        if (root.mpr && root.mpr.volumeSupported)
            root.mpr.volume = v / 100;
        else if (root.mpr && Media.isSpotify(root.mpr))
            SpotifyState.setVolume(v);
    }

    readonly property Item digitsItem: digits
    readonly property Item marqueeItem: marqueeText
    readonly property Item playButton: playBtn
    readonly property Item prevButton: prevBtn
    readonly property Item nextButton: nextBtn
    readonly property Item seekItem: seek
    readonly property Item volumeItem: volumeSlider
    readonly property bool scrolling: !MenuStyle.reduceMotion && marqueeMetrics.width > marqueeView.width

    // Our own toplevel: this title, this process (the address form the Lyrics window uses)
    function focusSelf() {
        const t = Hyprland.toplevels.values.find(w => w.title === root.title && w.lastIpcObject && w.lastIpcObject.pid === Quickshell.processId);
        if (t)
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + t.address + "\" })");
    }

    // MPRIS position does not update on its own: read it a few times a second while playing and visible
    Timer {
        interval: MenuStyle.lyricsTick
        repeat: true
        running: root.visible && root.playing && root.mpr !== null
        triggeredOnStart: true
        onTriggered: {
            if (!seek.pressed && root.mpr)
                root.position = root.mpr.position;
        }
    }
    onMprChanged: {
        if (root.mpr)
            root.position = root.mpr.position;
    }
    onTrackChanged: root.phaseMs = 0

    Timer {
        interval: root.marqueeTickMs
        repeat: true
        running: root.visible && root.scrolling
        onTriggered: root.phaseMs += interval
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()
        Keys.onSpacePressed: root.togglePlay()

        PopupWindowFrame {
            windowTitle: root.title
            // Dragging the title bar moves the window, like any Win95 window
            titleDrag: true
            onTitlePressed: root.startSystemMove()

            ColumnLayout {
                id: column
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: MenuStyle.pad

                // The LCD: dark face, sunken, accent digits
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: digits.implicitHeight + marqueeView.height + 3 * MenuStyle.gap
                    color: Config.colors.outline

                    Bevel {
                        anchors.fill: parent
                        raised: false
                    }

                    Text {
                        id: digits
                        x: MenuStyle.pad
                        y: MenuStyle.gap
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        textFormat: Text.PlainText
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.spotifyTitleSize * 2
                        color: Config.colors.accent
                        opacity: root.hasTrack ? 1 : MenuStyle.spotifyIdleOpacity
                        text: root.formatTime(root.position)
                    }
                    // the song length, quiet, at the right of the digits
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: MenuStyle.pad
                        anchors.baseline: digits.baseline
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        textFormat: Text.PlainText
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: Config.colors.accent
                        opacity: MenuStyle.spotifyIdleOpacity
                        visible: root.hasTrack && root.length > 0
                        text: root.formatTime(root.length)
                    }

                    // The marquee: clipped, one copy still or two sliding
                    Item {
                        id: marqueeView
                        x: MenuStyle.pad
                        y: digits.y + digits.implicitHeight + MenuStyle.gap
                        width: parent.width - 2 * MenuStyle.pad
                        height: MenuStyle.rowHeight
                        clip: true

                        TextMetrics {
                            id: marqueeMetrics
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            text: marqueeText.text
                        }
                        readonly property real offset: root.marqueeOffset(marqueeMetrics.width, marqueeView.width, root.phaseMs, root.marqueeSpeed, root.marqueeHold, MenuStyle.space12 * 2)

                        Text {
                            id: marqueeText
                            x: root.scrolling ? marqueeView.offset : 0
                            width: root.scrolling ? implicitWidth : marqueeView.width
                            height: marqueeView.height
                            verticalAlignment: Text.AlignVCenter
                            elide: root.scrolling ? Text.ElideNone : Text.ElideRight
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            textFormat: Text.PlainText
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.accent
                            text: root.hasTrack ? root.track : (root.hasPlayer ? "Nothing playing" : "No player running")
                        }
                        // the second copy follows the first, so the end meets the start
                        Text {
                            x: marqueeText.x + marqueeText.implicitWidth + MenuStyle.space12 * 2
                            height: marqueeView.height
                            visible: root.scrolling
                            verticalAlignment: Text.AlignVCenter
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            textFormat: Text.PlainText
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.accent
                            text: marqueeText.text
                        }
                    }
                }

                // Seek
                RetroSlider {
                    id: seek
                    Layout.fillWidth: true
                    from: 0
                    to: root.length > 0 ? root.length : 1
                    enabled: root.hasTrack && root.canSeek && root.length > 0
                    dim: !enabled
                    onPressedChanged: {
                        if (!pressed)
                            root.seekTo(value);
                    }
                    Binding on value {
                        when: !seek.pressed
                        value: Math.min(root.position, seek.to)
                        restoreMode: Binding.RestoreNone
                    }
                }

                // Transport: three equal buttons, then the volume
                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap

                    BevelButton {
                        id: prevBtn
                        glyph: "\ue045"
                        glyphSize: MenuStyle.spotifyButtonGlyph
                        implicitHeight: MenuStyle.spotifyButton
                        implicitWidth: MenuStyle.spotifyButton * 2
                        enabled: root.hasPlayer
                        focusPolicy: Qt.NoFocus
                        onClicked: root.previous()
                    }
                    BevelButton {
                        id: playBtn
                        glyph: root.playing ? "\ue034" : "\ue037"
                        glyphSize: MenuStyle.spotifyButtonGlyph
                        implicitHeight: MenuStyle.spotifyButton
                        implicitWidth: MenuStyle.spotifyButton * 2
                        enabled: root.hasPlayer
                        focusPolicy: Qt.NoFocus
                        onClicked: root.togglePlay()
                    }
                    BevelButton {
                        id: nextBtn
                        glyph: "\ue044"
                        glyphSize: MenuStyle.spotifyButtonGlyph
                        implicitHeight: MenuStyle.spotifyButton
                        implicitWidth: MenuStyle.spotifyButton * 2
                        enabled: root.hasPlayer
                        focusPolicy: Qt.NoFocus
                        onClicked: root.next()
                    }
                    RetroText {
                        Layout.leftMargin: MenuStyle.pad
                        font.family: MenuStyle.iconFont
                        font.pixelSize: MenuStyle.iconSize
                        color: root.volume < 0 ? MenuStyle.bevelDark : Config.colors.text
                        text: root.volume === 0 ? "\ue04f" : "\ue050"
                    }
                    RetroSlider {
                        id: volumeSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        stepSize: 1
                        enabled: root.volume >= 0
                        dim: !enabled
                        onMoved: root.setVolume(value)
                        Binding on value {
                            when: !volumeSlider.pressed
                            value: Math.max(0, root.volume)
                            restoreMode: Binding.RestoreNone
                        }
                    }
                }
            }
        }
    }
}
