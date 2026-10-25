import QtQuick
import ".."

// Recent: the top of the list / grid's own scroll area (the list's header), so it shares the content box and
// lines up with the grid below: the same 3 columns, the cover at the same place in each cell. The 3 newest, one
// row, no captions (hovering names one: status bar + tooltip). Its "Recent" heading (the same style as "Pinned")
// has Hide / Show at the right end (remembered, open by default). A click opens, the play button on a hovered
// cover plays. The panel only puts it there on the Library tab with nothing typed and nothing opened.
Column {
    id: recent
    required property var panel
    readonly property real cellWidth: width / MenuStyle.spotifyGridColumnsLibrary

    SpotifyHeading {
        width: recent.width
        panel: recent.panel
        label: "Recent"
        actionText: SpotifyState.recentOpen ? "Hide" : "Show"
        actionGlyph: SpotifyState.recentOpen ? "\ue5ce" : "\ue5cf"
        actionHint: SpotifyState.recentOpen ? "Hide Recent" : "Show Recent"
        onActionClicked: SpotifyState.recentOpen = !SpotifyState.recentOpen
    }

    Row {
        visible: SpotifyState.recentOpen
        Repeater {
            model: SpotifyState.recent.slice(0, MenuStyle.spotifyRecentCount)
            Item {
                id: tile
                required property var modelData
                readonly property bool lit: hover.hovered
                readonly property bool playing: recent.panel.isPlaying(modelData)
                width: recent.cellWidth
                height: recent.cellWidth - MenuStyle.gap
                // the same square as a grid tile's cover (CoverTile: gap in from the cell's corner)
                SunkenField {
                    id: cover
                    x: MenuStyle.gap
                    y: MenuStyle.gap
                    width: recent.cellWidth - 2 * MenuStyle.gap
                    height: width
                    padding: MenuStyle.spotifyInset
                    Rectangle {
                        anchors.fill: parent
                        visible: img.status !== Image.Ready
                        color: Config.colors.shadow
                    }
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
                        font.pixelSize: MenuStyle.spotifyTileIcon
                        color: Config.colors.text
                        text: recent.panel.kindGlyph(tile.modelData.kind)
                    }
                }
                // hover / now-playing frame
                Rectangle {
                    anchors.fill: cover
                    color: "transparent"
                    border.width: 2
                    border.color: MenuStyle.selectBar
                    visible: tile.lit || tile.playing
                }
                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                // no caption: the name is a tooltip too
                SpotifyHint { panel: recent.panel; text: tile.modelData.name; tooltip: true }
                TapHandler {
                    onTapped: recent.panel.clickItem(-1, tile.modelData, false)
                }
                BevelButton {
                    visible: tile.lit
                    anchors.right: cover.right
                    anchors.bottom: cover.bottom
                    anchors.margins: MenuStyle.gap
                    implicitHeight: MenuStyle.spotifyButton
                    glyphSize: MenuStyle.spotifyButtonGlyph
                    glyph: "\ue037"
                    focusPolicy: Qt.NoFocus
                    onClicked: recent.panel.playItem(tile.modelData)
                }
            }
        }
    }
    // a little air between Recent and the grid
    Item {
        width: 1
        height: MenuStyle.gap
        visible: SpotifyState.recentOpen
    }
}
