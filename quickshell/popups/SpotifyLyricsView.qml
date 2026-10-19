import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// The lyrics: the current line sits on the accent bar, kept at the reading spot; click a line to jump there.
// Also shows why there are none (another device, no player, no synced lyrics).
Item {
    required property var panel
    readonly property var view: lyricsView
    anchors.fill: parent
    Text {
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        textFormat: Text.PlainText
        anchors.centerIn: parent
        width: parent.width - 2 * MenuStyle.pad
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: panel.lyricsMode && (Lyrics.lines.length === 0 || panel.remote)
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        color: MenuStyle.bevelDark
        text: panel.remote ? "Playing on " + panel.deviceName() + ". Lyrics show while this PC plays: press Play here below."
            : (Media.spotify === null ? "Lyrics follow this PC's player (the Spotify app or spotifyd); neither is running." : "No synced lyrics for this song")
    }

    // Lyrics: the current line sits on the accent bar, kept at the reading spot; click a line to jump there
    ListView {
        id: lyricsView
        anchors.fill: parent
        visible: panel.lyricsMode && !panel.remote
        model: Lyrics.lines
        // Set from Lyrics.onIndexChanged below: a plain binding gets overwritten when the
        // model changes, and then the view stops following the song
        Connections {
            target: Lyrics
            function onIndexChanged() {
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
        highlightMoveDuration: MenuStyle.animScroll
        highlightFollowsCurrentItem: true
        // Room above and below so the first and last lines can reach the reading spot too
        header: Item { width: 1; height: lyricsView.height * MenuStyle.lyricsAnchor - MenuStyle.rowHeight }
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
                ColorAnimation { duration: MenuStyle.animHover }
            }
            Text {
                id: lyricText
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                x: MenuStyle.pad
                width: parent.width - 2 * MenuStyle.pad
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.lyricsFontSize
                color: lyricRow.current ? MenuStyle.selectText : (lyricRow.index < Lyrics.index ? MenuStyle.bevelDark : Config.colors.text)
                text: lyricRow.modelData.text === "" ? "♪" : lyricRow.modelData.text
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.seekLyric(lyricRow.modelData.t)
            }
        }
    }
}
