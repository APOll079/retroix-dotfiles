import QtQuick
import QtQuick.Layouts
import ".."

// Recent: the 3 newest covers in ONE row of squares (about 120 px, so text printed on album art stays readable),
// no captions: hovering names one (status bar + tooltip). Only on the Library tab with nothing typed and
// nothing opened. Its own "Recent" line has the collapse arrow ("Hide" / "Show", remembered, open by
// default). A click opens, the play button on a hovered cover plays.
ColumnLayout {
    id: recent
    required property var panel
    spacing: 0
    visible: panel.tab === "library" && panel.view === null && !panel.addMode && !panel.lyricsMode
        && panel.filterInput.text.trim() === "" && SpotifyState.recent.length > 0
    readonly property int cell: Math.floor((width - (MenuStyle.spotifyRecentCount - 1) * MenuStyle.gap) / MenuStyle.spotifyRecentCount)

    // the "Recent" line: a label and a clearly labelled arrow that collapses / expands the strip
    Item {
        Layout.fillWidth: true
        implicitHeight: MenuStyle.spotifyStatusHeight
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            anchors.verticalCenter: parent.verticalCenter
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            font.bold: true
            color: Config.colors.text
            text: "Recent"
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                anchors.verticalCenter: parent.verticalCenter
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: MenuStyle.bevelDark
                text: SpotifyState.recentOpen ? "Hide" : "Show"
            }
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                anchors.verticalCenter: parent.verticalCenter
                font.family: MenuStyle.iconFont
                font.pixelSize: MenuStyle.iconSize
                color: MenuStyle.bevelDark
                text: SpotifyState.recentOpen ? "\ue5ce" : "\ue5cf"
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: SpotifyState.recentOpen = !SpotifyState.recentOpen
            SpotifyHint { panel: recent.panel; text: SpotifyState.recentOpen ? "Hide Recent" : "Show Recent" }
        }
    }

    // the strip
    Row {
        visible: SpotifyState.recentOpen
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        Repeater {
            model: SpotifyState.recent.slice(0, MenuStyle.spotifyRecentCount)
            Item {
                id: tile
                required property var modelData
                readonly property bool lit: hover.hovered
                readonly property bool playing: recent.panel.isPlaying(modelData)
                width: recent.cell
                height: recent.cell
                SunkenField {
                    anchors.fill: parent
                    padding: MenuStyle.spotifyInset
                    Image {
                        id: img
                        anchors.fill: parent
                        source: tile.modelData.image || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        anchors.centerIn: parent
                        visible: img.status !== Image.Ready
                        font.family: MenuStyle.iconFont
                        font.pixelSize: MenuStyle.iconSize
                        color: MenuStyle.bevelDark
                        text: recent.panel.kindGlyph(tile.modelData.kind)
                    }
                }
                // hover / now-playing frame
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: MenuStyle.selectBar
                    visible: tile.lit || tile.playing
                }
                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                SpotifyHint { panel: recent.panel; text: tile.modelData.name }
                TapHandler {
                    onTapped: recent.panel.clickItem(-1, tile.modelData, false)
                }
                BevelButton {
                    visible: tile.lit
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    implicitHeight: MenuStyle.spotifyButton
                    glyphSize: MenuStyle.spotifyButtonGlyph
                    glyph: "\ue037"
                    focusPolicy: Qt.NoFocus
                    onClicked: SpotifyState.play(tile.modelData.kind === "liked" ? "liked" : tile.modelData.uri)
                }
            }
        }
    }
}
