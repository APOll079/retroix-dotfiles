import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// Status: errors / notes, the song's actions (right-click), and Log out (with a confirm).
RowLayout {
    required property var panel
    Layout.fillWidth: true
    spacing: MenuStyle.gap
    Text {
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        textFormat: Text.PlainText
        Layout.fillWidth: true
        elide: Text.ElideRight
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        color: panel.statusError !== "" && !panel.songMenu ? Config.colors.urgent : (panel.songMenu ? Config.colors.text : MenuStyle.bevelDark)
        text: panel.songMenu ? panel.songMenu.name
            : panel.confirmLogout ? "Log out of Spotify here?"
            : panel.statusError !== "" ? panel.statusError
            : panel.note !== "" ? panel.note
            : (!panel.lyricsMode && SpotifyState.volume < 0 ? "Volume shows once this PC plays" : "")
    }
    BevelButton {
        visible: panel.songMenu !== null
        text: "Queue"
        glyph: "\ue03c"
        focusPolicy: Qt.NoFocus
        onClicked: {
            const s = panel.songMenu;
            panel.songMenu = null;
            SpotifyState.queue(s.uri, ok => panel.note = ok ? s.name + " plays next" : "Couldn't queue " + s.name);
        }
    }
    BevelButton {
        visible: panel.songMenu !== null
        glyph: "\ue03b"
        focusPolicy: Qt.NoFocus
        onClicked: {
            const s = panel.songMenu;
            panel.toggleAddMode({ uri: s.uri, name: s.name });
        }
    }
    BevelButton {
        visible: panel.songMenu !== null
        glyph: "\ue87d"
        glyphColor: MenuStyle.likedColor
        focusPolicy: Qt.NoFocus
        onClicked: {
            const s = panel.songMenu;
            panel.songMenu = null;
            SpotifyState.likeSong(s.uri, ok => panel.note = ok ? "Liked " + s.name : "Couldn't like " + s.name);
        }
    }
    BevelButton {
        visible: panel.songMenu !== null
        glyph: "\ue5cd"
        focusPolicy: Qt.NoFocus
        onClicked: panel.songMenu = null
    }
    BevelButton {
        visible: panel.confirmLogout && !panel.songMenu
        text: "Log out"
        focusPolicy: Qt.NoFocus
        onClicked: {
            panel.confirmLogout = false;
            SpotifyState.logout();
        }
    }
    BevelButton {
        visible: panel.confirmLogout && !panel.songMenu
        text: "Cancel"
        focusPolicy: Qt.NoFocus
        onClicked: panel.confirmLogout = false
    }
    BevelButton {
        visible: !panel.confirmLogout && !panel.songMenu
        text: "Log out"
        focusPolicy: Qt.NoFocus
        onClicked: panel.confirmLogout = true
    }
}
