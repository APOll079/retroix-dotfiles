import QtQuick
import ".."

// The status bar's "..." menu: the shared PopupMenuBody over the drawer, closed by a click anywhere else.
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
        width: body.implicitWidth
        height: body.implicitHeight
        anchors.right: parent.right
        anchors.rightMargin: MenuStyle.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: MenuStyle.spotifyStatusHeight + 2 * MenuStyle.pad
        MouseArea { anchors.fill: parent }
        PopupMenuBody {
            id: body
            width: parent.width
            model: [
                { text: "Reload library", glyph: "\ue5d5", key: "reload" },
                { text: "Change client ID", glyph: "\ue890", key: "client" },
                { text: "Log out", glyph: "\ue9ba", key: "logout" }
            ]
            onPicked: (index, entry) => {
                panel.menuOpen = false;
                if (entry.key === "reload") {
                    SpotifyState.reloadLibrary();
                    panel.note = "Reloading...";
                } else if (entry.key === "client") {
                    panel.confirmClient = true;
                } else {
                    panel.confirmLogout = true;
                }
            }
        }
    }
}
