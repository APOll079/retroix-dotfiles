import QtQuick
import QtQuick.Controls.Basic

import ".."

// One cover in a Spotify panel grid (the Recent row and the library grid share it): a sunken square
// cover (or an icon by type when there's no art), the name and, if showSub, a type line with the
// pin icon. Hover / selected = the accent bar with inverted text, the keyboard cursor adds the dotted
// focus rect, like MenuRow. A play button appears on hover or when selected (not for folders).
Item {
    id: root

    property var entry: ({})
    property bool selected: false
    property bool showSub: true
    property bool hideSub: false    // keep the caption's second line empty (artists on the Artists chip)
    // no subtitle (artists): the name may use the subtitle's line too
    readonly property bool twoLineName: root.showSub && (root.hideSub || !root.entry.sub)
    readonly property bool hasMosaic: root.entry.mosaic !== undefined && root.entry.mosaic.length > 0
    property bool canPlay: entry.kind !== "folder"
    signal activated()
    signal playRequested()

    // Hover from a HoverHandler: it stays hovered over the play button, where a MouseArea would lose
    // the pointer to the button, hide it, get the pointer back and show it again (flicker)
    readonly property bool lit: hover.hovered || root.selected
    // This album / playlist / artist is what plays right now
    readonly property bool playingNow: !!root.entry.uri && SpotifyState.player !== null && root.entry.uri === SpotifyState.player.context
    readonly property int coverSize: width - 2 * MenuStyle.gap

    implicitHeight: MenuStyle.gap + coverSize + MenuStyle.spotifyInset + MenuStyle.rowHeight * (showSub ? 2 : 1)

    Rectangle {
        anchors.fill: parent
        color: root.lit ? MenuStyle.selectBar : "transparent"
        FocusRect {
            anchors.fill: parent
            anchors.margins: 1
            visible: root.selected
            color: MenuStyle.selectText
        }
    }

    SunkenField {
        id: cover
        x: MenuStyle.gap
        y: MenuStyle.gap
        width: root.coverSize
        height: width
        padding: MenuStyle.spotifyInset
        // No art: a dim tile (the shadow colour) with the icon, never a bright square
        Rectangle {
            anchors.fill: parent
            visible: img.status !== Image.Ready
            color: Config.colors.shadow
        }
        Image {
            id: img
            anchors.fill: parent
            source: root.entry.image || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        // A folder: its first four playlist covers as a 2 x 2 mosaic
        Grid {
            anchors.fill: parent
            visible: root.hasMosaic
            columns: 2
            Repeater {
                model: root.hasMosaic ? root.entry.mosaic.slice(0, 4) : []
                Image {
                    required property string modelData
                    width: parent.width / 2
                    height: parent.height / 2
                    source: modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            anchors.centerIn: parent
            visible: img.status !== Image.Ready && !root.hasMosaic
            font.family: MenuStyle.iconFont
            font.pixelSize: MenuStyle.spotifyTileIcon
            color: Config.colors.text
            text: {
                switch (root.entry.kind) {
                case "folder": return "\ue2c7";
                case "artist": return "\ue7fd";
                case "album": return "\ue019";
                case "liked": return "\ue87d";
                case "track": return "\ue405";
                case "searchrow": return "\ue8b6";
                default: return "\ue03d";
                }
            }
        }
    }

    // Speaker in the cover's corner while this one plays
    Rectangle {
        anchors.left: cover.left
        anchors.top: cover.top
        anchors.margins: MenuStyle.gap
        visible: root.playingNow
        width: MenuStyle.iconSize + MenuStyle.gap
        height: width
        color: MenuStyle.selectBar
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            anchors.centerIn: parent
            font.family: MenuStyle.iconFont
            font.pixelSize: MenuStyle.iconSize
            color: MenuStyle.selectText
            text: "\ue050"
        }
    }

    // The caption: the name, then one line by type (playlist: n songs, album: the artist, folder: n playlists)
    Column {
        x: MenuStyle.gap
        anchors.top: cover.bottom
        anchors.topMargin: MenuStyle.spotifyInset
        width: root.coverSize
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            textFormat: Text.PlainText
            width: parent.width
            height: root.twoLineName ? 2 * MenuStyle.rowHeight : MenuStyle.rowHeight
            verticalAlignment: root.twoLineName ? Text.AlignTop : Text.AlignVCenter
            topPadding: root.twoLineName ? (MenuStyle.rowHeight - MenuStyle.fontSize) / 2 - 1 : 0
            wrapMode: root.twoLineName ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
            maximumLineCount: root.twoLineName ? 2 : 1
            elide: Text.ElideRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: root.lit ? MenuStyle.selectText : Config.colors.text
            text: root.entry.name || ""
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            textFormat: Text.PlainText
            visible: root.showSub && !root.twoLineName
            width: parent.width
            height: MenuStyle.rowHeight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: root.lit ? MenuStyle.selectText : MenuStyle.bevelDark
            text: root.hideSub ? "" : (root.entry.sub || "")
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.activated()
    }

    BevelButton {
        anchors.right: cover.right
        anchors.bottom: cover.bottom
        anchors.margins: MenuStyle.gap
        visible: root.lit && root.canPlay
        implicitHeight: MenuStyle.spotifyButton
        glyphSize: MenuStyle.spotifyButtonGlyph
        glyph: "\ue037"
        focusPolicy: Qt.NoFocus
        onClicked: root.playRequested()
    }
}
