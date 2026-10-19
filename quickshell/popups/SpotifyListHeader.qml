import QtQuick
import QtQuick.Layouts
import ".."

// The top of a song list or an artist's page, scrolling with the list: the name and "n songs" (or the
// discography summary) on one line, and [Play] [Shuffle]. panel.listHead says what it is for.
Item {
    id: head
    required property var panel
    readonly property var info: panel.listHead
    implicitHeight: MenuStyle.spotifyListHeader + MenuStyle.spotifyColumnGap

    // 1234 -> "1 234"
    function grouped(n) {
        return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: MenuStyle.pad
        anchors.rightMargin: MenuStyle.pad
        anchors.bottomMargin: MenuStyle.spotifyColumnGap
        spacing: MenuStyle.gap
        // One line: the name (16 px when name and count fit, else 12 bold, elided) and the dim count
        Item {
            id: titleArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property string countText: !head.info ? "" : head.info.songs ? (head.info.count > 0 ? head.grouped(head.info.count) + (head.info.count === 1 ? " song" : " songs") : "") : (head.info.summary || "")
            readonly property bool big: bigName.width + (countText !== "" ? countLabel.implicitWidth + MenuStyle.pad : 0) <= width
            TextMetrics {
                id: bigName
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.spotifyTitleSize
                text: head.info ? head.info.title : ""
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: MenuStyle.pad
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    textFormat: Text.PlainText
                    width: Math.min(implicitWidth, titleArea.width - (titleArea.countText !== "" ? countLabel.implicitWidth + MenuStyle.pad : 0))
                    elide: Text.ElideRight
                    font.family: titleArea.big ? MenuStyle.bodyFont : MenuStyle.titleFont
                    font.pixelSize: titleArea.big ? MenuStyle.spotifyTitleSize : MenuStyle.fontSize
                    font.bold: !titleArea.big
                    color: Config.colors.text
                    text: head.info ? head.info.title : ""
                }
                Text {
                    id: countLabel
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    textFormat: Text.PlainText
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: MenuStyle.bevelDark
                    text: titleArea.countText
                }
            }
        }
        BevelButton {
            implicitHeight: MenuStyle.spotifyCompactRow
            text: "Play"
            glyph: "\ue037"
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.play(head.info.uri)
            SpotifyHint { panel: head.panel; text: "Play from the start" }
        }
        BevelButton {
            visible: head.info !== null && head.info.songs
            implicitHeight: MenuStyle.spotifyCompactRow
            text: "Shuffle"
            glyph: "\ue043"
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.playShuffled(head.info.uri)
            SpotifyHint { panel: head.panel; text: "Play in random order" }
        }
    }
}
