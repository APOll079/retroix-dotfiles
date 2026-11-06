import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// The lyrics: sung lines in the shadow colour, the current line on the accent bar (kept at the reading spot),
// the coming ones in normal text. Scrolling by hand pauses the following for a few seconds; click a line
// to jump there (the status bar says so). Also shows why there are none (another device, no player,
// no synced lyrics).
Item {
    id: lyricsRoot
    required property var panel
    readonly property var view: lyricsView
    anchors.fill: parent
    Local.EmptyState {
        anchors.centerIn: parent
        width: parent.width - 2 * MenuStyle.pad
        visible: panel.lyricsMode && (Lyrics.lines.length === 0 || panel.remote)
        glyph: "\uec0b"
        text: panel.remote ? "Playing on " + panel.deviceName() + ". Lyrics show while this PC plays: press Play here below."
            : (Media.spotify === null ? "Lyrics follow this PC's player (the Spotify app or spotifyd); neither is running." : "No synced lyrics for this song")
    }

    // Lyrics: the current line sits on the accent bar, kept at the reading spot; click a line to jump there
    ListView {
        id: lyricsView
        anchors.fill: parent
        visible: panel.lyricsMode && !panel.remote
        model: Lyrics.lines
        // Scrolled by hand: stop following for spotifyLyricsHold, then carry on from the current line
        property bool follow: true
        onMovementStarted: {
            follow = false;
            resume.restart();
        }
        Timer {
            id: resume
            interval: MenuStyle.spotifyLyricsHold
            onTriggered: {
                lyricsView.follow = true;
                lyricsView.currentIndex = Lyrics.index;
            }
        }
        // Set from Lyrics.onIndexChanged below: a plain binding gets overwritten when the
        // model changes, and then the view stops following the song
        Connections {
            target: Lyrics
            function onIndexChanged() {
                if (lyricsView.follow)
                    lyricsView.currentIndex = Lyrics.index;
            }
            function onLinesChanged() {
                lyricsView.currentIndex = Lyrics.index;
            }
        }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: height * MenuStyle.lyricsAnchor - MenuStyle.rowHeight
        preferredHighlightEnd: height * MenuStyle.lyricsAnchor + MenuStyle.rowHeight
        highlightMoveDuration: MenuStyle.animNormal
        highlightFollowsCurrentItem: true
        spacing: MenuStyle.lyricsLineGap
        // No room above the first line: at the start of a song the first lines sit at the top and the current one
        // walks down to the reading spot (the view can't scroll above its first line). Room below, so the last
        // lines can still reach the reading spot.
        footer: Item { width: 1; height: lyricsView.height * (1 - MenuStyle.lyricsAnchor) - MenuStyle.rowHeight }
        delegate: Rectangle {
            id: lyricRow
            required property int index
            required property var modelData
            readonly property bool current: index === Lyrics.index
            width: lyricsView.width
            height: lyricText.implicitHeight + MenuStyle.gap
            color: current ? MenuStyle.selectBar : Qt.rgba(MenuStyle.selectBar.r, MenuStyle.selectBar.g, MenuStyle.selectBar.b, 0)
            Behavior on color {
                ColorAnimation { duration: MenuStyle.animFast }
            }
            Text {
                id: lyricText
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                x: MenuStyle.pad
                width: parent.width - 2 * MenuStyle.pad
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                horizontalAlignment: Text.AlignHCenter
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.lyricsFontSize
                color: lyricRow.current ? MenuStyle.selectText : (lyricRow.index < Lyrics.index ? Config.colors.shadow : Config.colors.text)
                text: lyricRow.modelData.text === "" ? "♪" : lyricRow.modelData.text
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.seekLyric(lyricRow.modelData.t)
                SpotifyHint { panel: lyricsRoot.panel; text: "Click to jump to this line"; tooltip: false }
            }
        }
    }
}
