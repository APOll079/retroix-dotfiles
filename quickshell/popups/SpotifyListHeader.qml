import QtQuick
import QtQuick.Layouts
import ".."

// The top of a song list or an artist's page, scrolling with the list: the name, "n songs" (or the
// discography summary) and [Play] [Shuffle]. panel.listHead says what it is for.
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
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: MenuStyle.titleFont
                font.pixelSize: MenuStyle.fontSize
                font.bold: true
                color: Config.colors.text
                text: head.info ? head.info.title : ""
            }
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: MenuStyle.bevelDark
                text: !head.info ? "" : head.info.songs ? (head.info.count > 0 ? head.grouped(head.info.count) + (head.info.count === 1 ? " song" : " songs") : "") : (head.info.summary || "")
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
