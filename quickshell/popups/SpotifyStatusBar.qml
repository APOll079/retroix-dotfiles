import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// The status bar (18 px): left, what is going on: errors (until the next good poll), short messages (a few
// seconds), a confirm, a hover hint, else "Playing on This PC" (the state on an accent bar while another
// device plays); right, the "..." menu. A right-clicked song's actions (queue, add, like) take the bar over
// until the row menu replaces them.
Item {
    id: bar
    required property var panel
    Layout.fillWidth: true
    implicitHeight: panel.songMenu !== null ? MenuStyle.spotifyCompactRow + 2 : MenuStyle.spotifyStatusHeight

    readonly property bool confirming: panel.confirmLogout || panel.confirmClient
    readonly property string message: panel.confirmLogout ? "Log out of Spotify here?"
        : panel.confirmClient ? "Log out and change the client ID?"
        : panel.statusError !== "" ? panel.statusError
        : panel.note !== "" ? panel.note
        : panel.hint
    readonly property bool isState: message === ""
    readonly property string stateText: SpotifyState.player
        ? (SpotifyState.player.playing ? "Playing" : "Paused") + " on " + panel.deviceName()
        : "Nothing playing"

    RowLayout {
        anchors.fill: parent
        visible: panel.songMenu === null
        spacing: MenuStyle.gap
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: bar.isState && panel.remote ? MenuStyle.selectBar : "transparent"
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                anchors.fill: parent
                anchors.leftMargin: MenuStyle.gap
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: bar.isState ? (panel.remote ? MenuStyle.selectText : MenuStyle.bevelDark)
                    : (panel.statusError !== "" && !bar.confirming ? Config.colors.urgent : Config.colors.text)
                text: bar.isState ? bar.stateText : bar.message
            }
        }
        BevelButton {
            visible: bar.confirming
            implicitHeight: MenuStyle.spotifyStatusHeight
            text: panel.confirmClient ? "Change" : "Log out"
            focusPolicy: Qt.NoFocus
            onClicked: {
                if (panel.confirmClient) {
                    panel.confirmClient = false;
                    SpotifyState.logout();
                    panel.editClient = true;
                } else {
                    panel.confirmLogout = false;
                    SpotifyState.logout();
                }
            }
        }
        BevelButton {
            visible: bar.confirming
            implicitHeight: MenuStyle.spotifyStatusHeight
            text: "Cancel"
            focusPolicy: Qt.NoFocus
            onClicked: {
                panel.confirmLogout = false;
                panel.confirmClient = false;
            }
        }
        BevelButton {
            visible: !bar.confirming
            implicitHeight: MenuStyle.spotifyStatusHeight
            glyph: "\ue5d3"
            checked: panel.menuOpen
            focusPolicy: Qt.NoFocus
            onClicked: panel.menuOpen = !panel.menuOpen
            SpotifyHint { panel: bar.panel; text: "More: log out, client ID, reload" }
        }
    }

    // A right-clicked song's actions
    RowLayout {
        anchors.fill: parent
        visible: panel.songMenu !== null
        spacing: MenuStyle.gap
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            textFormat: Text.PlainText
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: panel.songMenu ? panel.songMenu.name : ""
        }
        BevelButton {
            implicitHeight: MenuStyle.spotifyCompactRow
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
            implicitHeight: MenuStyle.spotifyCompactRow
            glyph: "\ue03b"
            focusPolicy: Qt.NoFocus
            onClicked: {
                const s = panel.songMenu;
                panel.toggleAddMode({ uri: s.uri, name: s.name });
            }
        }
        BevelButton {
            implicitHeight: MenuStyle.spotifyCompactRow
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
            implicitHeight: MenuStyle.spotifyCompactRow
            glyph: "\ue5cd"
            focusPolicy: Qt.NoFocus
            onClicked: panel.songMenu = null
        }
    }
}
