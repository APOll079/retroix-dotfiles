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
    readonly property var gridView: grid
    readonly property var lyricsView: lyrics.view
    // The list fades in when the tab or the opened item changes
    Connections {
        target: panel
        function onTabChanged() { listFade.restart(); }
        function onStackChanged() { listFade.restart(); }
    }
    id: listArea
    flat: true      // the page around it is the one frame
    Layout.fillWidth: true
    Layout.fillHeight: true
    padding: MenuStyle.spotifyInset
    clip: true

    // A divider row: a dim bold label (may be empty) and an etched line to the right
    component HeadingRow: Item {
        property string label: ""
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
            text: parent.label
        }
        Local.MenuSeparator {
            anchors.left: headingText.right
            anchors.leftMargin: parent.label === "" ? 0 : MenuStyle.pad
            anchors.right: parent.right
            anchors.rightMargin: MenuStyle.pad
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    NumberAnimation { id: listFade; target: listArea; property: "opacity"; from: 0; to: 1; duration: MenuStyle.animFade }

    SpotifyLyricsView {
        id: lyrics
        panel: listArea.panel
    }

    // Rows and tiles that are still on their way: dim placeholder bars instead of "Loading..."
    Column {
        anchors.fill: parent
        anchors.topMargin: panel.listHead !== null ? MenuStyle.spotifyListHeader + MenuStyle.spotifyColumnGap : 0
        visible: !panel.lyricsMode && panel.loadingList
        Repeater {
            model: Math.ceil(listArea.height / MenuStyle.spotifyRowHeight)
            Item {
                required property int index
                width: listArea.width - 2 * MenuStyle.spotifyInset
                height: MenuStyle.spotifyRowHeight
                Rectangle {
                    x: MenuStyle.pad
                    anchors.verticalCenter: parent.verticalCenter
                    width: MenuStyle.spotifyThumb
                    height: MenuStyle.spotifyThumb
                    color: Config.colors.shadow
                    opacity: 0.35
                }
                Rectangle {
                    x: MenuStyle.pad + MenuStyle.spotifyThumb + MenuStyle.pad
                    y: parent.height / 2 - MenuStyle.rowHeight / 2 + 2
                    width: (parent.width - 3 * MenuStyle.pad - MenuStyle.spotifyThumb) * (0.5 + 0.12 * ((index * 5) % 4))
                    height: MenuStyle.gap + 2
                    color: Config.colors.shadow
                    opacity: 0.35
                }
                Rectangle {
                    x: MenuStyle.pad + MenuStyle.spotifyThumb + MenuStyle.pad
                    y: parent.height / 2 + MenuStyle.gap
                    width: (parent.width - 3 * MenuStyle.pad - MenuStyle.spotifyThumb) * (0.3 + 0.1 * ((index * 3) % 3))
                    height: MenuStyle.gap + 2
                    color: Config.colors.shadow
                    opacity: 0.2
                }
            }
        }
    }

    Text {
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        anchors.centerIn: parent
        width: parent.width - 2 * MenuStyle.pad
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: !panel.lyricsMode && panel.items.length === 0 && !panel.loadingList
        font.family: MenuStyle.bodyFont
        font.pixelSize: text.length <= MenuStyle.spotifyEmptyBigChars ? MenuStyle.spotifyTitleSize : MenuStyle.fontSize
        color: MenuStyle.bevelDark
        text: panel.emptyText()
    }

    // The list header (name, count, Play, Shuffle) for song lists and an artist's page
    Component {
        id: headComp
        SpotifyListHeader {
            panel: listArea.panel
            width: parent ? parent.width : 0
        }
    }

    // Rows: the accent bar spans the whole row; the play button sits inside it, on hover
    // or when selected. A song plays on click (no play button); right-click / the Menu key opens its
    // options, middle-click queues it.
    ListView {
        id: listView
        anchors.fill: parent
        visible: !panel.lyricsMode && !panel.useGrid
        model: panel.items
        header: panel.listHead !== null ? headComp : null
        currentIndex: 0
        // Results of an older query (a new one is typed or on its way) look old
        opacity: panel.searchMode && panel.searchResults.length > 0 && (panel.searchLoading || panel.filterInput.text.trim() !== panel.searchQuery) ? 0.5 : 1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // A click right after a scroll or flick only stops it (songs and tiles ignore it)
        property real lastMoved: 0
        // (a function, not a binding: a binding on Date.now() is only re-read when `moving` changes, so it
        // stayed "just moved" for good after the first scroll and every click was swallowed)
        function justMoved() {
            return moving || Date.now() - lastMoved < MenuStyle.spotifyFlickGuard;
        }
        onMovingChanged: {
            if (!moving)
                lastMoved = Date.now();
        }
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: Item {
            id: row
            required property int index
            required property var modelData
            readonly property bool isTrack: modelData.kind === "track"
            readonly property bool isHeading: modelData.kind === "heading"
            readonly property bool sel: index === listView.currentIndex
            readonly property bool playing: panel.isPlaying(modelData)
            // The title is cut off: the full name (and artist) shows on hover
            readonly property real titleRoom: width - 4 * MenuStyle.pad - (isTrack ? MenuStyle.spotifyThumb + clockWidth.width + MenuStyle.pad : MenuStyle.iconSize + MenuStyle.iconSize)
            readonly property bool elided: !isHeading && titleWidth.width > titleRoom
            readonly property bool showPlay: !panel.addMode && !isTrack && !isHeading && modelData.kind !== "more" && modelData.kind !== "searchrow" && modelData.kind !== "folder" && (rowHover.hovered || sel)
            width: listView.width
            height: isHeading ? MenuStyle.rowHeight : MenuStyle.spotifyRowHeight
            TextMetrics {
                id: titleWidth
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                text: row.modelData.name || ""
            }
            TextMetrics {
                id: clockWidth
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                text: "00:00"
            }
            SpotifyHint {
                panel: listArea.panel
                text: row.elided ? row.modelData.name + (row.modelData.sub ? "  -  " + row.modelData.sub : "") : ""
            }

            // A divider row (search groups, "Pinned"): a plain dim heading with an etched line
            HeadingRow {
                anchors.fill: parent
                visible: row.isHeading
                label: row.isHeading ? row.modelData.name : ""
            }

            HoverHandler {
                id: rowHover
            }
            // Right-click a song: its options menu at the row
            TapHandler {
                acceptedButtons: Qt.RightButton
                enabled: row.isTrack && !panel.addMode
                onTapped: {
                    panel.setCursor(row.index);
                    panel.openSongMenu(row.modelData, row);
                }
            }
            // Middle-click a song: it plays next
            TapHandler {
                acceptedButtons: Qt.MiddleButton
                enabled: row.isTrack && !panel.addMode
                onTapped: panel.queueSong(row.modelData)
            }
            MenuRow {
                anchors.fill: parent
                visible: !row.isHeading
                focusPolicy: Qt.NoFocus
                rightPadding: row.showPlay ? MenuStyle.pad + playButton.width + MenuStyle.gap : MenuStyle.pad
                selected: row.sel
                text: row.modelData.name
                // Songs: a thumbnail (a speaker while playing), the title in accent while playing, the
                // length as a dim right-hand column. Containers: the pin / speaker sign.
                iconBox: row.isTrack ? MenuStyle.spotifyThumb : MenuStyle.iconSize
                accentTitle: row.isTrack && row.playing
                trailing: row.isTrack ? panel.clock(row.modelData.duration) : ""
                trailingDim: true
                marked: !row.isTrack && (row.playing || (row.modelData.pinned === true && panel.pinsMixed))
                markGlyph: row.playing ? "\ue050" : "\uf10d"
                subtext: row.modelData.sub
                iconSource: row.isTrack && row.playing ? "" : (row.modelData.image || "")
                glyph: row.isTrack && row.playing ? "\ue050" : panel.kindGlyph(row.modelData.kind)
                onClicked: panel.clickItem(row.index, row.modelData, row.isTrack && listView.justMoved())
            }
            // A song: "Add to queue" on hover (it covers the duration; middle-click does the same)
            BevelButton {
                anchors.right: parent.right
                anchors.rightMargin: MenuStyle.pad
                anchors.verticalCenter: parent.verticalCenter
                visible: row.isTrack && !panel.addMode && panel.tab !== "queue" && (rowHover.hovered || row.sel)
                implicitHeight: MenuStyle.spotifyButton
                glyphSize: MenuStyle.spotifyButtonGlyph
                glyph: "\ue03c"
                focusPolicy: Qt.NoFocus
                onClicked: panel.queueSong(row.modelData)
                SpotifyHint { panel: listArea.panel; text: "Add to queue (middle-click)" }
            }
            BevelButton {
                id: playButton
                anchors.right: parent.right
                anchors.rightMargin: MenuStyle.pad
                anchors.verticalCenter: parent.verticalCenter
                visible: row.showPlay
                implicitHeight: MenuStyle.spotifyButton
                glyphSize: MenuStyle.spotifyButtonGlyph
                glyph: "\ue037"
                focusPolicy: Qt.NoFocus
                onClicked: panel.playItem(row.modelData)
            }
        }
        ScrollIndicator.vertical: ScrollIndicator {
            active: listView.moving
        }
    }

    // The same items as cover tiles: a list of rows of tiles, so a divider row can sit between groups
    ListView {
        id: grid
        anchors.fill: parent
        visible: !panel.lyricsMode && panel.useGrid
        model: panel.gridRows
        header: panel.listHead !== null ? headComp : null
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property real cellWidth: width / MenuStyle.spotifyGridColumnsLibrary
        property real lastMoved: 0
        function justMoved() {
            return moving || Date.now() - lastMoved < MenuStyle.spotifyFlickGuard;
        }
        onMovingChanged: {
            if (!moving)
                lastMoved = Date.now();
        }
        // keep the cursor's tile row in view
        Connections {
            target: listView
            function onCurrentIndexChanged() {
                const r = panel.gridRowOf(listView.currentIndex);
                if (r >= 0)
                    grid.positionViewAtIndex(r, ListView.Contain);
            }
        }
        CoverTile {
            id: gridProbe
            visible: false
            width: grid.cellWidth
        }
        delegate: Item {
            id: gridRow
            required property var modelData
            width: grid.width
            height: modelData.tiles === undefined ? MenuStyle.rowHeight : gridProbe.implicitHeight
            HeadingRow {
                anchors.fill: parent
                visible: gridRow.modelData.tiles === undefined
                label: gridRow.modelData.heading ? gridRow.modelData.heading.name : ""
            }
            Row {
                visible: gridRow.modelData.tiles !== undefined
                Repeater {
                    model: gridRow.modelData.tiles || []
                    CoverTile {
                        required property var modelData
                        width: grid.cellWidth
                        height: gridProbe.implicitHeight
                        entry: modelData.item
                        hideSub: modelData.item.kind === "artist"
                        selected: modelData.index === listView.currentIndex
                        canPlay: !panel.addMode && modelData.item.kind !== "folder" && modelData.item.kind !== "searchrow"
                        onActivated: panel.clickItem(modelData.index, modelData.item, grid.justMoved())
                        onPlayRequested: panel.playItem(modelData.item)
                    }
                }
            }
        }
        ScrollIndicator.vertical: ScrollIndicator {
            active: grid.moving
        }
    }
}
