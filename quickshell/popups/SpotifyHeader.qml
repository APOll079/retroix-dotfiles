import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// Now playing: cover, then title / artist / album and where it plays (Play here on another device).
RowLayout {
    required property var panel
    Layout.fillWidth: true
    visible: !panel.lyricsMode
    Layout.preferredHeight: MenuStyle.spotifyCoverSize
    Layout.maximumHeight: MenuStyle.spotifyCoverSize
    spacing: MenuStyle.pad
    SunkenField {
        Layout.preferredWidth: MenuStyle.spotifyCoverSize
        Layout.preferredHeight: MenuStyle.spotifyCoverSize
        padding: MenuStyle.spotifyInset
        Image {
            id: cover
            anchors.fill: parent
            source: SpotifyState.track ? SpotifyState.track.image : (panel.lastTrack ? panel.lastTrack.image : "")
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            font.family: MenuStyle.iconFont
            font.pixelSize: MenuStyle.spotifyTileIcon
            color: MenuStyle.bevelDark
            text: "\ue405"
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0
        Repeater {
            model: SpotifyState.track
                ? [SpotifyState.track.name, SpotifyState.track.artists, SpotifyState.track.album]
                : (panel.lastTrack
                    ? ["Last played: " + panel.lastTrack.name, panel.lastTrack.sub, "Play carries on here"]
                    : ["Nothing playing", "Pick something below", ""])
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: index === 0 ? MenuStyle.titleFont : MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                font.bold: index === 0
                color: index === 0 ? Config.colors.text : MenuStyle.bevelDark
                text: modelData
            }
        }
        // Where it plays; on another device (the phone) a button moves it here
        RowLayout {
            Layout.fillWidth: true
            visible: SpotifyState.player !== null && SpotifyState.player.device !== ""
            spacing: MenuStyle.gap
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: MenuStyle.bevelDark
                text: "on " + panel.deviceName()
            }
            BevelButton {
                visible: panel.remote
                text: "Play here"
                glyph: "\ue30a"
                focusPolicy: Qt.NoFocus
                onClicked: SpotifyState.playHere()
            }
        }
        Item { Layout.fillHeight: true }
    }
}
