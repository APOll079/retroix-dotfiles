import QtQuick
import ".."

// The status bar's "..." menu: the shared PopupMenuBody over the drawer, closed by a click anywhere else.
// Log out and Change client ID ask first (in the status bar); Reload library asks Spotify again.
// Keys: Up / Down, Enter picks, Escape closes only this menu.
Item {
    id: menu
    required property var panel
    anchors.fill: parent
    visible: panel.menuOpen
    z: 10

    // The menu takes the keyboard when it opens (Up / Down, Enter, Escape closes only it) and hands it back
    onVisibleChanged: {
        if (menu.visible) {
            body.currentIndex = 0;
            body.forceActiveFocus();
        } else if (!panel.confirming) {
            panel.focusKeys();
        }
    }

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
                { text: "Lyrics window", glyph: "\uec0b", key: "lyrics" },
                { text: "Log out", glyph: "\ue9ba", key: "logout" }
            ]
            onEscaped: panel.menuOpen = false
            onPicked: (index, entry) => {
                panel.menuOpen = false;
                if (entry.key === "reload") {
                    SpotifyState.reloadLibrary();
                    panel.note = "Reloading...";
                } else if (entry.key === "lyrics") {
                    LyricsWindowState.toggle();
                } else if (entry.key === "client") {
                    panel.confirmClient = true;
                } else {
                    panel.confirmLogout = true;
                }
            }
        }
    }
}
