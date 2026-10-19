import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Now playing: the cover (opens the album), title / artist / album (the artist and the album open them),
// the track actions [like] [add to playlist] [lyrics], and, only while ANOTHER device plays, an accent
// line "Playing on <device>" with Play here. In the lyrics view it shrinks to a compact header with Close.
RowLayout {
    id: header
    required property var panel
    readonly property bool compact: panel.lyricsMode
    readonly property var track: SpotifyState.track
    readonly property string titleText: header.track ? header.track.name : (panel.lastTrack ? "Last played: " + panel.lastTrack.name : "Nothing playing")
    readonly property int coverSize: compact ? MenuStyle.spotifyLyricsCover : MenuStyle.spotifyCoverSize
    Layout.fillWidth: true
    Layout.preferredHeight: coverSize
    Layout.maximumHeight: coverSize
    spacing: MenuStyle.pad

    // A name that opens something (underlined and pointing on hover); plain text without a target
    component LinkText: Text {
        id: link
        property bool linked: false
        signal activated()
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        textFormat: Text.PlainText
        elide: Text.ElideRight
        Layout.fillWidth: false
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        font.underline: link.linked && linkHover.hovered
        color: link.linked && linkHover.hovered ? Config.colors.text : MenuStyle.bevelDark
        HoverHandler {
            id: linkHover
            enabled: link.linked
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            enabled: link.linked
            onTapped: link.activated()
        }
    }

    SunkenField {
        Layout.preferredWidth: header.coverSize
        Layout.preferredHeight: header.coverSize
        padding: MenuStyle.spotifyInset
        // The cover crossfades: the new one loads invisible over the old one and fades in when it is ready
        readonly property string wanted: SpotifyState.track ? SpotifyState.track.image : (panel.lastTrack ? panel.lastTrack.image : "")
        onWantedChanged: {
            coverBack.source = wanted === "" ? "" : cover.source;
            cover.opacity = 0;
            cover.source = wanted;
        }
        Component.onCompleted: cover.source = wanted
        Image {
            id: coverBack
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Image {
            id: cover
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0
            onStatusChanged: {
                if (status === Image.Ready)
                    coverFade.restart();
            }
            NumberAnimation {
                id: coverFade
                target: cover
                property: "opacity"
                from: 0
                to: 1
                duration: MenuStyle.spotifyCrossfade
            }
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready && coverBack.status !== Image.Ready
            font.family: MenuStyle.iconFont
            font.pixelSize: header.compact ? MenuStyle.iconSize : MenuStyle.spotifyTileIcon
            color: MenuStyle.bevelDark
            text: "\ue405"
        }
        // The cover opens the album
        MouseArea {
            anchors.fill: parent
            enabled: !header.compact && header.track !== null && header.track.album_uri !== ""
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.openUri("album", header.track.album_uri, header.track.album, header.track.image)
            SpotifyHint { panel: header.panel; text: "Open the album" }
        }
    }

    // Full header: title / artist / album, where it plays, the track actions
    ColumnLayout {
        id: column
        visible: !header.compact
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0
        // The biggest text in the drawer: 16 when the title fits on one line, else 12 bold (elided)
        TextMetrics {
            id: bigTitle
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.spotifyTitleSize
            text: header.titleText
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            textFormat: Text.PlainText
            Layout.fillWidth: true
            elide: Text.ElideRight
            readonly property bool big: bigTitle.width <= column.width
            font.family: big ? MenuStyle.bodyFont : MenuStyle.titleFont
            font.pixelSize: big ? MenuStyle.spotifyTitleSize : MenuStyle.fontSize
            font.bold: !big
            color: Config.colors.text
            text: header.titleText
        }
        LinkText {
            Layout.maximumWidth: column.width
            linked: header.track !== null && header.track.artist_uri !== ""
            text: header.track ? header.track.artists : (panel.lastTrack ? panel.lastTrack.sub : "Pick something below")
            onActivated: panel.openUri("artist", header.track.artist_uri, header.track.artists.split(", ")[0], "")
            SpotifyHint { panel: header.panel; text: "Open the artist" }
        }
        LinkText {
            Layout.maximumWidth: column.width
            linked: header.track !== null && header.track.album_uri !== ""
            text: header.track ? header.track.album : ""
            onActivated: panel.openUri("album", header.track.album_uri, header.track.album, header.track.image)
            SpotifyHint { panel: header.panel; text: "Open the album" }
        }
        // Only while another device plays: where, and a button to bring it here
        Rectangle {
            visible: panel.remote
            Layout.fillWidth: true
            Layout.topMargin: MenuStyle.gap / 2
            implicitHeight: MenuStyle.spotifyStatusHeight
            color: MenuStyle.selectBar
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: MenuStyle.gap
                spacing: MenuStyle.gap
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: MenuStyle.selectText
                    text: "Playing on " + panel.deviceName()
                }
                BevelButton {
                    implicitHeight: MenuStyle.spotifyStatusHeight
                    text: "Play here"
                    glyph: "\ue30a"
                    focusPolicy: Qt.NoFocus
                    onClicked: SpotifyState.playHere()
                }
            }
        }
        Item { Layout.fillHeight: true }
        // Track actions
        RowLayout {
            Layout.fillWidth: true
            spacing: MenuStyle.gap
            SpotifyReasonHost {
                Layout.alignment: Qt.AlignVCenter
                panel: header.panel
                reason: SpotifyState.track === null ? "Like: nothing is playing" : ""
                BevelButton {
                    implicitHeight: MenuStyle.spotifyCompactRow
                    glyph: SpotifyState.liked ? "\ue87d" : "\ue87e"
                    glyphColor: SpotifyState.liked ? MenuStyle.likedColor : "transparent"
                    enabled: SpotifyState.track !== null
                    focusPolicy: Qt.NoFocus
                    onClicked: SpotifyState.toggleLike()
                    SpotifyHint { panel: header.panel; text: SpotifyState.liked ? "Remove from Liked Songs (Ctrl+S)" : "Like this song (Ctrl+S)" }
                }
            }
            SpotifyReasonHost {
                panel: header.panel
                reason: SpotifyState.track === null ? "Add to playlist: nothing is playing" : ""
                BevelButton {
                    implicitHeight: MenuStyle.spotifyCompactRow
                    glyph: "\ue03b"
                    checked: panel.addMode
                    enabled: SpotifyState.track !== null
                    focusPolicy: Qt.NoFocus
                    onClicked: panel.toggleAddMode()
                    SpotifyHint { panel: header.panel; text: "Add this song to a playlist" }
                }
            }
            BevelButton {
                implicitHeight: MenuStyle.spotifyCompactRow
                glyph: "\uec0b"
                checked: panel.lyricsOn
                focusPolicy: Qt.NoFocus
                onClicked: panel.toggleLyrics()
                SpotifyHint { panel: header.panel; text: "Lyrics (Ctrl+L)" }
            }
            // right: speaker (mute), the slider filling what is left, the percent
            Item { Layout.preferredWidth: MenuStyle.gap }
            SpotifyVolume {
                Layout.fillWidth: true
                panel: header.panel
            }
        }
    }

    // Compact header (lyrics view): "Title · Artist" on one line and Close
    RowLayout {
        visible: header.compact
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: MenuStyle.pad
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
            text: header.track ? header.track.name + " · " + header.track.artists : "Nothing playing"
        }
        BevelButton {
            implicitHeight: MenuStyle.spotifyCompactRow
            glyph: "\ue5cd"
            focusPolicy: Qt.NoFocus
            onClicked: panel.toggleLyrics()
            SpotifyHint { panel: header.panel; text: "Close the lyrics (Ctrl+L)" }
        }
    }
}
