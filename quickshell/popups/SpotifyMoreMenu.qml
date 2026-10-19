import QtQuick
import QtQuick.Layouts
import ".."

// The status bar's "..." menu: a small frame over the drawer, closed by a click anywhere else.
// Log out and Change client ID ask first (in the status bar); Reload library asks Spotify again.
Item {
    id: menu
    required property var panel
    anchors.fill: parent
    visible: panel.menuOpen
    z: 10

    MouseArea {
        anchors.fill: parent
        onClicked: panel.menuOpen = false
    }
    Item {
        id: box
        width: 200
        height: MenuStyle.chromeTop + rows.implicitHeight + MenuStyle.chromeBottom
        anchors.right: parent.right
        anchors.rightMargin: MenuStyle.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: MenuStyle.spotifyStatusHeight + 2 * MenuStyle.pad
        MouseArea { anchors.fill: parent }
        PopupWindowFrame {
            windowTitle: "Spotify"
            ColumnLayout {
                id: rows
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0
                MenuRow {
                    Layout.fillWidth: true
                    text: "Reload library"
                    glyph: "\ue5d5"
                    onClicked: {
                        panel.menuOpen = false;
                        SpotifyState.reloadLibrary();
                        panel.note = "Reloading...";
                    }
                }
                MenuRow {
                    Layout.fillWidth: true
                    text: "Change client ID"
                    glyph: "\ue890"
                    onClicked: {
                        panel.menuOpen = false;
                        panel.confirmClient = true;
                    }
                }
                MenuRow {
                    Layout.fillWidth: true
                    text: "Log out"
                    glyph: "\ue9ba"
                    onClicked: {
                        panel.menuOpen = false;
                        panel.confirmLogout = true;
                    }
                }
            }
        }
    }
}
