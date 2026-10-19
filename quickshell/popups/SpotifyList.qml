import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// The list area: rows or cover tiles (or the lyrics), with the empty / loading text. The one sunken field
// the drawer's content lives in; panel.items is the model, listView holds the shared cursor.
SunkenField {
    required property var panel
    readonly property var view: listView
    readonly property var lyricsView: lyrics.view
    // The list fades in when the tab or the opened item changes
    Connections {
        target: panel
        function onTabChanged() { listFade.restart(); }
        function onStackChanged() { listFade.restart(); }
    }
    id: listArea
    Layout.fillWidth: true
    Layout.fillHeight: true
    padding: MenuStyle.spotifyInset
    clip: true

    NumberAnimation { id: listFade; target: listArea; property: "opacity"; from: 0; to: 1; duration: MenuStyle.animFade }

    SpotifyLyricsView {
        id: lyrics
        panel: listArea.panel
    }

    Text {
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        anchors.centerIn: parent
        width: parent.width - 2 * MenuStyle.pad
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: !panel.lyricsMode && panel.items.length === 0
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        color: MenuStyle.bevelDark
        text: panel.emptyText()
    }

    // Rows: the accent bar spans the whole row; the play button sits inside it, on hover
    // or when selected (songs play on click, so they have none)
    ListView {
        id: listView
        anchors.fill: parent
        visible: !panel.lyricsMode && !panel.useGrid
        model: panel.items
        currentIndex: 0
        // Results of an older query (a new one is typed or on its way) look old
        opacity: panel.searchMode && panel.searchResults.length > 0 && (panel.searchLoading || panel.filterInput.text.trim() !== panel.searchQuery) ? 0.5 : 1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: Item {
            id: row
            required property int index
            required property var modelData
            readonly property bool isTrack: modelData.kind === "track"
            readonly property bool isHeading: modelData.kind === "heading"
            readonly property bool sel: index === listView.currentIndex
            readonly property bool playing: panel.isPlaying(modelData)
            readonly property bool showPlay: !panel.addMode && !isTrack && !isHeading && modelData.kind !== "more" && modelData.kind !== "searchrow" && modelData.kind !== "folder" && (rowHover.hovered || sel)
            width: listView.width
            height: isHeading ? MenuStyle.rowHeight : MenuStyle.spotifyRowHeight

            // Search results: a plain dim heading over each group, with an etched line
            Item {
                anchors.fill: parent
                visible: row.isHeading
                Text {
                    id: headingText
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    anchors.left: parent.left
                    anchors.leftMargin: MenuStyle.pad
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    font.bold: true
                    color: MenuStyle.bevelDark
                    text: row.isHeading ? row.modelData.name : ""
                }
                Local.MenuSeparator {
                    anchors.left: headingText.right
                    anchors.leftMargin: MenuStyle.pad
                    anchors.right: parent.right
                    anchors.rightMargin: MenuStyle.pad
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            HoverHandler {
                id: rowHover
            }
            // Right-click a song: its actions (queue, add to playlist, like) in the status line
            TapHandler {
                acceptedButtons: Qt.RightButton
                enabled: row.isTrack && !panel.addMode
                onTapped: {
                    panel.setCursor(row.index);
                    panel.songMenu = row.modelData;
                }
            }
            MenuRow {
                anchors.fill: parent
                visible: !row.isHeading
                focusPolicy: Qt.NoFocus
                rightPadding: row.showPlay ? MenuStyle.pad + playButton.width + MenuStyle.gap : MenuStyle.pad
                selected: row.sel
                text: row.modelData.name
                marked: row.playing || row.modelData.pinned === true
                markGlyph: row.playing ? "\ue050" : "\uf10d"
                subtext: row.isTrack ? row.modelData.sub + "  " + panel.clock(row.modelData.duration) : row.modelData.sub
                iconSource: row.modelData.image || ""
                glyph: panel.kindGlyph(row.modelData.kind)
                onClicked: {
                    panel.setCursor(row.index);
                    panel.activate(row.modelData);
                }
            }
            BevelButton {
                id: playButton
                anchors.right: parent.right
                anchors.rightMargin: MenuStyle.pad
                anchors.verticalCenter: parent.verticalCenter
                visible: row.showPlay
                glyph: "\ue037"
                focusPolicy: Qt.NoFocus
                onClicked: panel.playItem(row.modelData)
            }
        }
        ScrollIndicator.vertical: ScrollIndicator {
            active: listView.moving
        }
    }

    // The same items as cover tiles
    GridView {
        id: grid
        anchors.fill: parent
        visible: !panel.lyricsMode && panel.useGrid
        model: panel.items
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: width / MenuStyle.spotifyGridColumnsLibrary
        cellHeight: gridProbe.implicitHeight
        currentIndex: listView.currentIndex
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
        CoverTile {
            id: gridProbe
            visible: false
            width: grid.cellWidth
        }
        delegate: CoverTile {
            required property int index
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight
            entry: modelData
            selected: index === listView.currentIndex
            canPlay: !panel.addMode && modelData.kind !== "folder" && modelData.kind !== "searchrow"
            onActivated: {
                panel.setCursor(index);
                panel.activate(modelData);
            }
            onPlayRequested: panel.playItem(modelData)
        }
        ScrollIndicator.vertical: ScrollIndicator {
            active: grid.moving
        }
    }
}
