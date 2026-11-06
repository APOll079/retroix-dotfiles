import QtQuick
import ".."

// The song's options (right-click, or Menu / Shift+F10): the shared ContextMenuBody over the drawer, right under the
// row (above it when there is no room). Up / Down move, Enter runs, Escape or a click outside closes.
// Like shows the real state (asked when it opens).
Item {
    id: menu
    required property var panel
    readonly property var request: panel.rowMenu
    readonly property var song: request ? request.song : null
    property int cur: 0
    property var liked: null
    anchors.fill: parent
    visible: song !== null
    z: 11

    readonly property var entries: {
        if (menu.song === null)
            return [];
        const list = [
            { key: "play", text: "Play", glyph: "\ue037" },
            { key: "queue", text: "Add to queue", glyph: "\ue03c" },
            { key: "add", text: "Add to playlist...", glyph: "\ue03b" },
            { key: "like", text: menu.liked === true ? "Remove from Liked Songs" : "Like", glyph: menu.liked === true ? "\ue87d" : "\ue87e" }
        ];
        if (menu.song.album_uri)
            list.push({ key: "album", text: "Go to album", glyph: "\ue019" });
        if (menu.song.artist_uri)
            list.push({ key: "artist", text: "Go to artist", glyph: "\ue7fd" });
        return list;
    }

    onSongChanged: {
        menu.cur = 0;
        menu.liked = null;
        if (menu.song === null)
            return;
        const uri = menu.song.uri;
        SpotifyState.isLiked(uri, v => {
            if (menu.song !== null && menu.song.uri === uri)
                menu.liked = v;
        });
        menu.forceActiveFocus();
    }

    function close() {
        menu.panel.rowMenu = null;
        menu.panel.focusKeys();
    }

    function run(key) {
        const s = menu.song;
        menu.panel.rowMenu = null;
        if (key === "play") {
            menu.panel.activate(s, true);
        } else if (key === "queue") {
            menu.panel.queueSong(s);
        } else if (key === "add") {
            menu.panel.toggleAddMode({ uri: s.uri, name: s.name });
            return;
        } else if (key === "like") {
            if (menu.liked === true)
                SpotifyState.unlikeSong(s.uri, ok => menu.panel.note = ok ? "Removed " + s.name + " from Liked Songs" : "Couldn't update Liked Songs");
            else
                SpotifyState.likeSong(s.uri, ok => menu.panel.note = ok ? "Liked " + s.name : "Couldn't like " + s.name);
        } else if (key === "album") {
            menu.panel.openUri("album", s.album_uri, s.album_name, s.image);
            return;
        } else if (key === "artist") {
            menu.panel.openUri("artist", s.artist_uri, s.artist_name, "");
            return;
        }
        menu.panel.focusKeys();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            menu.close();
        } else if (event.key === Qt.Key_Down) {
            menu.cur = (menu.cur + 1) % menu.entries.length;
        } else if (event.key === Qt.Key_Up) {
            menu.cur = (menu.cur + menu.entries.length - 1) % menu.entries.length;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            menu.run(menu.entries[menu.cur].key);
        } else {
            return;
        }
        event.accepted = true;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: menu.close()
    }
    Item {
        id: box
        readonly property real below: menu.request ? menu.request.bottom : 0
        readonly property real above: menu.request ? menu.request.top - height : 0
        width: parent.width - 4 * MenuStyle.pad
        height: body.implicitHeight
        x: 2 * MenuStyle.pad
        y: below + height <= parent.height - MenuStyle.spotifyStatusHeight - MenuStyle.pad ? below : Math.max(MenuStyle.pad, above)
        MouseArea { anchors.fill: parent }
        ContextMenuBody {
            id: body
            width: parent.width
            model: menu.entries
            currentIndex: menu.cur
            onCurrentIndexChanged: menu.cur = currentIndex
            onPicked: (index, entry) => menu.run(entry.key)
            onEscaped: menu.close()
        }
    }
}
