import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// Spotify panel (Super+S, `qs ipc call spotify_<mon> toggle`): a drawer hanging off the bar on the
// left screen edge, full height, no title bar; only its right and bottom edges get a 1px outline.
// A layer-shell panel (like the bar), not a popup: popups get nudged 4px inside the screen edge.
//
// Top: now playing (cover, title / artist / album, like / add / lyrics, seek, transport, volume), then one
// filter / search box, then the tabs Library | Liked (Win95 tabs joined to the page below). The page holds:
// - Library: Spotify's Your Library (pins first) with chips All / Playlists / Albums / Artists, and the
//   Recent strip (collapsible); Playlists shows your folders in Spotify's order.
// - Liked: Liked Songs.
// Typing filters the list; its top row "Search Spotify for ..." (or Enter) shows Spotify's results in place
// (under a Back header, chips All / Playlists / Albums / Artists / Songs): chip All shows 4 per type
// (Artists first) and a "More ..." row; songs play in their album; playlists you don't own are play-only.
// The lyrics are a view the header button (or Ctrl+L) switches to: the whole drawer for synced lyrics, with
// a compact header and a slim transport strip. A status bar at the bottom shows the state, messages, errors
// and hover hints, and has the "..." menu (reload, change client ID, log out).
// Lists show as rows or cover tiles (the view button, remembered). A click opens (a folder, an
// album's / your playlist's songs, an artist's albums, Liked Songs); Back returns to where you were.
// The play button (hover / selected, or Shift+Enter) plays without opening.
// Keys: type to filter, arrows move (Left / Right too in the grid), Enter opens, Shift+Enter plays,
// Space plays / pauses (empty filter), Ctrl+L lyrics, Escape steps back, then closes.
// Data and control: SpotifyState.qml + scripts/spotify.py. First run asks for the client ID of your
// Spotify developer app, then logs in through the browser once.
PanelWindow {
    id: root

    property int screenHeight: 0
    property var closeCallback: function () {}

    property string tab: "library"         // library | liked
    property bool lyricsOn: false          // the lyrics view (the header button, Ctrl+L)
    property string libraryKind: "all"     // Library chip: all | playlist | artist | album
    property string searchQuery: ""        // the last query sent to Spotify
    property var searchResults: []         // its rows (spotify.py search)
    property string searchKind: "all"      // Search chip: all | track | album | artist | playlist
    property bool searchLoading: false
    property string searchError: ""
    property bool wantPlaying: false       // put the cursor on the playing song once the list has songs
    property var stack: []                 // opened items: { title, uri, kind, items, loading, blocked, fromIndex }
    property bool addMode: false           // picking a playlist for "add to playlist"
    property var addTarget: null           // the song being added: { uri, name }
    property var rowMenu: null             // the song options menu: { song, top, bottom } (row edges in drawer coordinates)
    property string note: ""               // short feedback line
    property bool confirmLogout: false
    property bool confirmClient: false     // log out and change the client ID (asked on the status bar)
    property bool menuOpen: false          // the status bar's "..." menu
    property string hint: ""               // what the control under the pointer does (the status bar shows it)
    property var tip: null                 // the tooltip: { text, item } (SpotifyHint sets it after a pause)
    property bool restored: false          // the remembered view was applied (once per start)
    property var pendingRestore: null      // { index, y }: the cursor and scroll position to put back once the list is there
    property bool editClient: false        // setup page: typing a new client ID
    property real openedAt: 0              // when something was last opened (double-click guard)
    property real shownAt: 0               // when the drawer opened (focus-change grace period)

    // The one place an error shows: the status line (a failed search keeps its own text when the
    // shared one was cleared by a good poll)
    readonly property string statusError: SpotifyState.error !== "" ? SpotifyState.error : (root.searchMode ? root.searchError : "")
    readonly property bool remote: SpotifyState.player !== null && !SpotifyState.local
    readonly property var lastTrack: SpotifyState.lastPlayed ? SpotifyState.lastPlayed.track : null
    readonly property bool lyricsMode: root.lyricsOn && !root.addMode
    // Spotify search results are shown in place, as the top of the view stack
    readonly property bool searchMode: root.view !== null && root.view.kind === "search" && !root.addMode
    // Items that moved into the component files; the logic below still uses them by these names
    readonly property var filterInput: search
    readonly property var clientInput: setup.input
    readonly property var listView: spotifyList.view
    readonly property var scroller: root.useGrid ? spotifyList.gridView : spotifyList.view
    readonly property var lyricsView: spotifyList.lyricsView
    readonly property var view: root.stack.length > 0 ? root.stack[root.stack.length - 1] : null
    readonly property var likedRow: ({ kind: "liked", uri: "liked", name: "Liked Songs", sub: "Playlist", image: "", openable: true })

    // Pinned URIs from Your Library, so every view (folders too) can show the pin
    readonly property var pinned: {
        const p = {};
        for (const it of (SpotifyState.libraryItems || []))
            if (it.pinned)
                p[it.uri] = true;
        return p;
    }

    readonly property var baseItems: {
        if (root.addMode)
            return (SpotifyState.lists.playlists || []).filter(p => p.openable);
        if (root.view)
            return root.view.kind === "liked" ? (SpotifyState.lists.liked || [])
                : root.view.kind === "search" ? root.searchRows() : (root.view.items || []);
        if (root.tab === "library")
            return root.libraryRows();
        if (root.tab === "liked")
            return SpotifyState.lists.liked || [];
        return [];
    }
    readonly property var items: {
        const text = filterInput.text.trim();
        const q = text.toLowerCase();
        const rows = root.baseItems
            .filter(i => root.searchMode || q === "" || (i.name + " " + i.sub).toLowerCase().includes(q))
            .map(i => root.pinned[i.uri] && !i.pinned ? Object.assign({}, i, { pinned: true }) : i);
        // Typed text: the top row takes it to Spotify's own search (results in place, Back returns)
        if (text !== "" && !root.addMode && !root.searchMode)
            rows.unshift({ kind: "searchrow", uri: "searchrow", query: text, name: "Search Spotify for '" + text + "'", sub: "", image: "" });
        return rows;
    }
    // What the list header shows: an opened album / playlist / Liked Songs / the Liked tab (name, n songs,
    // Play, Shuffle) or an artist's page (name, discography summary, Play); null elsewhere
    readonly property var listHead: {
        if (root.addMode || root.searchMode || root.lyricsMode)
            return null;
        const songs = root.baseItems.filter(i => i.kind === "track").length;
        if (!root.view)
            return root.tab === "liked" ? { title: "Liked Songs", uri: "liked", songs: true, count: songs } : null;
        const v = root.view;
        if (v.kind === "artist")
            return { title: v.title, uri: v.uri, songs: false, summary: v.summary || "" };
        if (v.kind === "liked" || v.kind === "album" || v.kind === "playlist")
            return { title: v.title, uri: v.uri, songs: true, count: songs };
        return null;
    }
    // The list is empty because it is still on its way: the list shows placeholder rows
    readonly property bool loadingList: root.items.length === 0 && !root.lyricsMode && ["Loading...", "Searching..."].includes(root.emptyText())
    readonly property bool songList: root.items.some(i => i.kind === "track") || (root.view !== null && root.view.kind === "liked") || (!root.view && root.tab === "liked")
    // Covers in a grid (remembered toggle) for anything but song lists and the playlist picker
    readonly property bool useGrid: SpotifyState.grid && !root.addMode && !root.songList && !root.searchMode
    readonly property bool showViewToggle: !root.addMode && !root.lyricsMode && !root.songList && !root.searchMode

    anchors {
        left: true
        top: true
        bottom: true
    }
    margins.top: MenuStyle.barHeight
    implicitWidth: MenuStyle.spotifyWidth
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-spotify"
    // On demand, not exclusive: an exclusive drawer could keep the click / focus from reaching
    // other windows. It still takes the keyboard when it opens (the filter box asks for focus).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    visible: false
    color: "transparent"

    onVisibleChanged: {
        SpotifyState.active = visible;
        Lyrics.fast = visible && root.lyricsMode;
        if (visible && MenuStyle.animOpen > 0)
            openFade.restart();
    }
    // Backup for click-outside: another window getting focus, or a workspace switch, closes the drawer
    Connections {
        target: Hyprland
        // (not in the first moment after opening: Hyprland's window info settling then isn't you clicking away)
        // Only on this drawer's monitor: focus follows the mouse, so just moving onto a window on
        // the other monitor focuses it, and that must not close the drawer (a click there does,
        // through that monitor's click catcher)
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel;
            if (t && t.workspace && t.workspace.monitor && t.workspace.monitor.name === root.screen.name)
                root.focusLeft();
        }
        function onFocusedWorkspaceChanged() {
            const w = Hyprland.focusedWorkspace;
            if (w && w.monitor && w.monitor.name === root.screen.name)
                root.focusLeft();
        }
    }
    // Logging in (or the status check finishing) after the drawer opened: load the tab now
    Connections {
        target: SpotifyState
        function onLoggedInChanged() {
            if (SpotifyState.loggedIn && root.visible)
                root.loadForTab(true);
            root.focusKeys();
        }
    }
    onLyricsModeChanged: {
        Lyrics.fast = root.visible && root.lyricsMode;
        if (root.lyricsMode)
            Qt.callLater(() => lyricsView.currentIndex = Lyrics.index);
        root.focusKeys();
    }
    onItemsChanged: Qt.callLater(root.afterItems)
    // A short message goes away by itself
    Timer {
        id: noteTimer
        interval: MenuStyle.spotifyNoteMs
        onTriggered: root.note = ""
    }
    Timer {
        id: restoreTimer
        interval: MenuStyle.spotifyRestoreMs
        onTriggered: root.pendingRestore = null
    }
    onNoteChanged: {
        if (root.note !== "")
            noteTimer.restart();
    }
    onStackChanged: root.rowMenu = null

    // Keys where there's no filter box to type in (the lyrics, the login page): the shared ones (globalKey), Escape, Space, Left / Right (seek, in the lyrics), "/" and Ctrl+F
    Item {
        id: keyCatcher
        Keys.onPressed: event => {
            if (SpotifyState.loggedIn && root.globalKey(event)) {
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                if (!root.goBack())
                    root.closeCallback();
            } else if (root.lyricsMode && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                root.seekBy(event.key === Qt.Key_Left ? -MenuStyle.spotifySeekStepMs : MenuStyle.spotifySeekStepMs);
            } else if (event.key === Qt.Key_Space && SpotifyState.loggedIn) {
                SpotifyState.togglePlay();
            } else if ((event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) && SpotifyState.loggedIn) {
                root.lyricsOn = false;      // leaving the lyrics hands the keyboard back to the box
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    // The drawer: base colour, open towards the bar (top) and the screen edge (left); the right and
    // bottom edges get a flat 1px outline like the bar's own edge (a bevel there fought the bar's)
    Rectangle {
        id: drawer
        anchors.fill: parent
        color: Config.colors.base

        NumberAnimation { id: openFade; target: drawer; property: "opacity"; from: 0; to: 1; duration: MenuStyle.animOpen; easing.type: Easing.OutCubic }

        Rectangle { x: parent.width - 1; y: 0; width: 1; height: parent.height; color: Config.colors.outline }
        Rectangle { x: 0; y: parent.height - 1; width: parent.width; height: 1; color: Config.colors.outline }

        SpotifySetup { id: setup; panel: root }

        // --- main ---
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: MenuStyle.pad
            visible: SpotifyState.loggedIn
            spacing: MenuStyle.spotifyColumnGap

            SpotifyHeader { panel: root }

            SpotifyTransport { Layout.fillWidth: true; panel: root }

            Local.MenuSeparator {
                Layout.fillWidth: true
                visible: !root.lyricsMode && !root.addMode
            }

            SpotifySearch { id: search; panel: root }

            // The tabs and the page they join: chips / Back row, Recent, the list
            SpotifyPage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                panel: root
                ColumnLayout {
                    anchors.fill: parent
                    spacing: MenuStyle.spotifyColumnGap
                    SpotifyNav {
                        Layout.fillWidth: true
                        visible: !root.lyricsMode && (root.addMode || root.view !== null || root.tab === "library")
                        panel: root
                    }
                    SpotifyRecent { Layout.fillWidth: true; panel: root }
                    SpotifyList { id: spotifyList; Layout.fillWidth: true; Layout.fillHeight: true; panel: root }
                }
            }

            // Lyrics: a slim transport strip stays, so the drawer is never a dead end
            SpotifyButtons {
                Layout.fillWidth: true
                visible: root.lyricsMode
                full: false
                panel: root
            }

            SpotifyStatusBar { Layout.fillWidth: true; panel: root }
        }

        SpotifyMoreMenu { panel: root }
        SpotifyRowMenu { id: rowMenuView; panel: root }
        SpotifyTooltip { panel: root }
    }


    // --- behaviour ---

    function focusLeft() {
        if (root.visible && Date.now() - root.shownAt > MenuStyle.spotifyClickGuard)
            root.closeCallback();
    }

    function deviceName() {
        if (!SpotifyState.player)
            return "";
        return SpotifyState.local ? "This PC" : SpotifyState.player.device;
    }

    function kindGlyph(kind) {
        switch (kind) {
        case "track": return "\ue405";
        case "artist": return "\ue7fd";
        case "album": return "\ue019";
        case "folder": return "\ue2c7";
        case "liked": return "\ue87d";
        case "searchrow": return "\ue8b6";
        default: return "\ue03d";
        }
    }

    // Lyric click: MPRIS seek when the app runs (instant), else the API
    function seekLyric(seconds) {
        const m = SpotifyState.mpris;
        if (m && m.canSeek)
            m.position = seconds;
        else
            SpotifyState.seek(seconds * 1000);
    }

    function clock(ms) {
        const s = Math.floor((ms || 0) / 1000);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    function kindPlural(kind) {
        return { track: "songs", album: "albums", artist: "artists", playlist: "playlists" }[kind] || "results";
    }

    // The song, or the album / playlist / artist, that plays right now
    function isPlaying(item) {
        if (!item || !item.uri)
            return false;
        if (item.kind === "track")
            return SpotifyState.track !== null && item.uri === SpotifyState.track.uri;
        return SpotifyState.player !== null && item.uri === SpotifyState.player.context;
    }

    // After the list changed: cursor onto the playing song once (an album / playlist / Liked just
    // opened), and off a heading when a new search replaced the rows (the view resets its cursor)
    function afterItems() {
        // (the list resets its cursor whenever its model is replaced, so the saved place is put back on every
        // change for a moment, until restoreTimer says the list has settled)
        if (root.pendingRestore && root.items.length > root.pendingRestore.index) {
            const r = root.pendingRestore;
            root.wantPlaying = false;
            root.setCursor(r.index);
            Qt.callLater(() => root.scroller.contentY = r.y);
            restoreTimer.restart();
            return;
        }
        if (root.wantPlaying && root.items.length > 0) {
            root.wantPlaying = false;
            const i = root.items.findIndex(x => x.kind === "track" && root.isPlaying(x));
            if (i >= 0) {
                root.setCursor(i);
                return;
            }
        }
        if (root.searchMode)
            root.setCursor(listView.currentIndex);
    }

    function emptyText() {
        if (filterInput.text.trim() !== "" && root.baseItems.length > 0)
            return "No matches";
        if (root.addMode)
            return SpotifyState.loading.playlists ? "Loading..." : "No playlists of your own";
        if (root.searchMode)
            return root.searchLoading ? "Searching..." : root.searchError !== "" ? "Search failed"
                : root.searchQuery === "" ? "Type, then press Enter"
                : root.searchKind !== "all" && root.searchResults.length > 0 ? "No " + root.kindPlural(root.searchKind)
                : "No results";
        if (root.view) {
            if (root.view.kind === "liked")
                return SpotifyState.loading.liked ? "Loading..." : "No liked songs";
            if (root.view.loading)
                return "Loading...";
            if (root.view.kind === "artist")
                return "Spotify didn't list this artist's albums. Play above still works.";
            // Not in the playlist list yet: it may still be one of yours, so no "you don't own it" yet
            if (root.view.blocked && root.view.kind === "playlist" && SpotifyState.loading.playlists)
                return "Loading...";
            if (root.view.blocked)
                return root.view.kind === "folder" ? "Open the Spotify app once (with this panel open) to load what's in this folder."
                    : "Spotify only lists the songs of playlists you own. Press Play to start it.";
            return "Empty";
        }
        if (root.tab === "liked")
            return SpotifyState.loading.liked ? "Loading..." : "No liked songs";
        const need = root.libraryKind === "all" ? ["playlists", "artists", "albums"] : [root.libraryKind + "s"];
        return need.some(k => SpotifyState.loading[k]) ? "Loading..." : "Empty";
    }

    // dir -1 when moving up: a heading row is skipped in the direction of travel (forwards from the top)
    function setCursor(i, dir) {
        const isHeading = j => root.items[j] && root.items[j].kind === "heading";
        let j = Math.max(0, i);
        while (isHeading(j))
            j += dir < 0 ? -1 : 1;
        if (j < 0)
            for (j = 0; isHeading(j); j++) {}
        listView.currentIndex = Math.max(0, Math.min(j, root.items.length - 1));
    }

    function seekBy(ms) {
        const t = SpotifyState.track;
        if (t)
            SpotifyState.seek(Math.max(0, Math.min(t.duration, SpotifyState.progress + ms)));
    }

    // The keys that work everywhere in the drawer (the filter box and the key catcher both ask first):
    // Alt+Left back, Ctrl+Tab the tabs, Ctrl+Left / Right previous / next, Ctrl+Shift+Left / Right seek,
    // Ctrl+Up / Down volume, Ctrl+S like, Ctrl+L lyrics. True when the key was one of them.
    function globalKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        if (alt && event.key === Qt.Key_Left) {
            root.goBack();
        } else if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
            root.showTab(root.tab === "library" ? "liked" : "library");
        } else if (ctrl && shift && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            root.seekBy(event.key === Qt.Key_Left ? -MenuStyle.spotifySeekStepMs : MenuStyle.spotifySeekStepMs);
        } else if (ctrl && event.key === Qt.Key_Left) {
            SpotifyState.previous();
        } else if (ctrl && event.key === Qt.Key_Right) {
            SpotifyState.next();
        } else if (ctrl && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            if (SpotifyState.volume >= 0)
                SpotifyState.setVolume(Math.max(0, Math.min(100, SpotifyState.volume + (event.key === Qt.Key_Up ? 1 : -1) * MenuStyle.spotifyWheelStep)));
            else
                root.note = "Volume shows once this PC plays";
        } else if (ctrl && event.key === Qt.Key_S) {
            if (SpotifyState.track)
                SpotifyState.toggleLike();
            else
                root.note = "Nothing is playing";
        } else if (ctrl && event.key === Qt.Key_L) {
            root.toggleLyrics();
        } else {
            return false;
        }
        return true;
    }

    // Keyboard goes to the filter box where there is one, else to the key catcher (Lyrics, login)
    function focusKeys() {
        if (!root.visible)
            return;
        if (SpotifyState.loggedIn && !root.lyricsMode)
            filterInput.focusInput();
        else if (!SpotifyState.loggedIn && clientInput.visible)
            clientInput.focusInput();
        else
            keyCatcher.forceActiveFocus();
    }

    function loadForTab(force) {
        if (root.tab === "library")
            ["playlists", "artists", "albums"].forEach(k => SpotifyState.loadList(k, force));
        else if (root.tab === "liked")
            SpotifyState.loadList("liked", force);
    }

    function showTab(key) {
        root.pendingRestore = null;
        root.tab = key;
        root.lyricsOn = false;
        root.stack = [];
        filterInput.text = "";
        root.setCursor(0);
        root.wantPlaying = key === "liked";
        Qt.callLater(root.afterItems);
        root.loadForTab(false);
        root.focusKeys();
    }

    // Pick a playlist for a song: `target` { uri, name }, or the one playing
    function toggleAddMode(target) {
        if (!root.addMode)
            root.addTarget = target || (SpotifyState.track ? { uri: SpotifyState.track.uri, name: SpotifyState.track.name } : null);
        root.rowMenu = null;
        root.addMode = !root.addMode;
        // (leaving the picker on the Search tab brings the query back)
        filterInput.text = !root.addMode && root.searchMode ? root.searchQuery : "";
        root.setCursor(0);
        if (root.addMode)
            SpotifyState.loadList("playlists");
        root.focusKeys();
    }

    function saveClient() {
        SpotifyState.setClient(clientInput.text.trim());
        root.editClient = false;
    }

    function plural(n, word) {
        return n + " " + word + (n === 1 ? "" : "s");
    }

    // "Album · Artist" -> "Artist" (the tile shows the type by its cover and chip, so the caption is the detail)
    function stripKind(sub) {
        return (sub || "").replace(/^(Playlist|Album|Artist|Single|EP)\s*·\s*/, "");
    }

    // The first four playlist covers inside a folder (nested folders included), for its mosaic
    function folderCovers(nodes) {
        const known = SpotifyState.lists.playlists || [];
        const out = [];
        const walk = list => {
            for (const x of list) {
                if (out.length >= 4)
                    return;
                if (x.type === "folder") {
                    walk(x.items);
                } else {
                    const k = known.find(p => p.uri === x.uri);
                    if (k && k.image)
                        out.push(k.image);
                }
            }
        };
        walk(nodes || []);
        return out;
    }

    function countPlaylists(nodes) {
        return (nodes || []).reduce((c, x) => c + (x.type === "folder" ? root.countPlaylists(x.items) : 1), 0);
    }

    // Library tab: Spotify's Your Library (pins first, the app's order) from the extension, else
    // built from the API lists (no pins, no folders). The chip narrows it to one kind.
    function libraryRows() {
        const known = SpotifyState.lists.playlists || [];
        // Playlists: your folders and playlists in Spotify's order (the folder tree), Liked Songs first
        // (with text in the filter box it's the flat list, so the search reaches inside folders)
        if (root.libraryKind === "playlist" && SpotifyState.folderTree && filterInput.text.trim() === "")
            return [root.likedRow].concat(root.folderRows(SpotifyState.folderTree, true));
        let rows;
        if (SpotifyState.libraryItems) {
            rows = SpotifyState.libraryItems.map(it => {
                const kind = it.type === "collection" ? "liked" : it.type;
                const row = { kind: kind, uri: kind === "liked" ? "liked" : it.uri, name: it.name, sub: it.sub, image: it.image, pinned: it.pinned, openable: true };
                row.sub = root.stripKind(it.sub);
                if (kind === "playlist") {
                    const k = known.find(p => p.uri === it.uri);
                    row.openable = k ? k.openable : false;
                    if (k)
                        row.sub = k.sub;
                    if (!row.image && k)
                        row.image = k.image;
                } else if (kind === "artist") {
                    row.sub = "Artist";
                } else if (kind === "folder") {
                    row.children = root.findFolder(SpotifyState.folderTree || [], it.uri);
                    if (row.children) {
                        row.sub = root.plural(root.countPlaylists(row.children), "playlist");
                        row.mosaic = root.folderCovers(row.children);
                    }
                }
                return row;
            });
        } else {
            rows = [root.likedRow].concat(known, SpotifyState.lists.artists || [], SpotifyState.lists.albums || []);
        }
        if (root.libraryKind !== "all")
            rows = rows.filter(r => r.kind === root.libraryKind || (root.libraryKind === "playlist" && (r.kind === "folder" || r.kind === "liked")));
        // pins first, otherwise keep Spotify's order
        return rows.filter(r => r.pinned).concat(rows.filter(r => !r.pinned));
    }

    function findFolder(nodes, uri) {
        for (const n of nodes) {
            if (n.type !== "folder")
                continue;
            if (n.uri === uri)
                return n.items;
            const inner = root.findFolder(n.items, uri);
            if (inner)
                return inner;
        }
        return null;
    }

    // Rows for one level of the folder tree. Playlists take their cover / owner / openable from the
    // API list; at the top level, playlists missing from the tree (new ones) are added at the end.
    function folderRows(nodes, top) {
        const known = SpotifyState.lists.playlists || [];
        const rows = [];
        for (const n of nodes) {
            if (n.type === "folder")
                rows.push({ kind: "folder", uri: n.uri, name: n.name, sub: root.plural(root.countPlaylists(n.items), "playlist"), image: "", mosaic: root.folderCovers(n.items), openable: true, children: n.items, pinned: root.pinned[n.uri] === true });
            else
                rows.push(known.find(p => p.uri === n.uri) || { kind: "playlist", uri: n.uri, name: n.name, sub: "", image: "", openable: false });
        }
        if (top) {
            const inTree = {};
            const walk = list => list.forEach(x => x.type === "folder" ? walk(x.items) : inTree[x.uri] = true);
            walk(nodes);
            for (const p of known)
                if (!inTree[p.uri])
                    rows.push(p);
        }
        return rows;
    }

    // Play without opening (the play buttons, Shift+Enter)
    function playItem(item) {
        if (!item || item.kind === "folder" || item.kind === "heading" || item.kind === "more" || item.kind === "searchrow")
            return;
        SpotifyState.play(item.kind === "liked" ? "liked" : item.uri);
    }

    // Click / Enter on a row or tile. fromKeys: Enter (the double-click guard only applies to clicks)
    function activate(item, fromKeys) {
        if (!item || item.kind === "heading")
            return;
        if (item.kind === "searchrow") {
            root.openSearch(item.query);
            return;
        }
        if (item.kind === "more") {
            // "More songs (10)": the same as clicking that chip
            root.searchKind = item.moreKind;
            root.setCursor(0);
            return;
        }
        if (!fromKeys && Date.now() - root.openedAt < MenuStyle.spotifyClickGuard)
            return;
        if (root.addMode) {
            if (!root.addTarget) {
                root.note = "Nothing playing to add";
            } else {
                const name = item.name, song = root.addTarget.name;
                SpotifyState.addToPlaylist(item.uri, root.addTarget.uri, ok => root.note = ok ? "Added " + song + " to " + name : "Couldn't add to " + name);
            }
            root.toggleAddMode();
            return;
        }
        if (item.kind === "track") {
            // (a search hit has no context of its own: it plays in its album)
            const ctx = root.searchMode ? "" : (root.view ? root.view.uri : (root.tab === "liked" ? "liked" : ""));
            if (ctx)
                SpotifyState.play(ctx, item.uri);
            else if (root.searchMode && item.album_uri)
                SpotifyState.play(item.album_uri, item.uri);    // a search hit plays in its album
            else
                SpotifyState.play(item.uri);
            return;
        }
        if (item.kind === "folder") {
            root.push({ title: item.name, uri: item.uri, kind: "folder", items: item.children ? root.folderRows(item.children, false) : [], loading: false, blocked: !item.children });
            return;
        }
        if (item.kind === "liked") {
            SpotifyState.loadList("liked");
            root.wantPlaying = true;
            root.push({ title: "Liked Songs", uri: "liked", kind: "liked", items: [], loading: false });
            return;
        }
        if (item.openable === false) {
            root.push({ title: item.name, uri: item.uri, kind: item.kind, items: [], loading: false, blocked: true });
            return;
        }
        root.wantPlaying = true;
        root.push({ title: item.name, uri: item.uri, kind: item.kind, items: [], loading: true });
        const depth = root.stack.length;
        const uri = item.uri;
        SpotifyState.open(uri, v => {
            // Only fill the view it was opened for (you may have gone back and opened something else)
            if (root.stack.length !== depth || root.stack[depth - 1].uri !== uri)
                return;
            const s = root.stack.slice();
            s[depth - 1] = Object.assign({}, s[depth - 1], { items: v ? v.items : [], summary: v && v.summary ? v.summary : "", loading: false });
            root.stack = s;
        });
    }

    // Search tab rows. With chip All: a heading before each type that has results (Artists first),
    // at most searchPerGroup rows each and then a "More songs (n)" row that switches to that chip.
    readonly property int searchPerGroup: 4     // TODO: move to MenuStyle
    function searchRows() {
        const groups = [["artist", "Artists"], ["track", "Songs"], ["album", "Albums"], ["playlist", "Playlists"]];
        const rows = [];
        for (const [kind, title] of groups) {
            if (root.searchKind !== "all" && root.searchKind !== kind)
                continue;
            const got = root.searchResults.filter(r => r.kind === kind);
            if (got.length === 0)
                continue;
            if (root.searchKind === "all") {
                rows.push({ kind: "heading", uri: "heading:" + kind, name: title, sub: "", image: "" });
                rows.push(...got.slice(0, root.searchPerGroup));
                if (got.length > root.searchPerGroup)
                    rows.push({ kind: "more", uri: "more:" + kind, moreKind: kind, name: "More " + title.toLowerCase() + " (" + got.length + ")", sub: "", image: "" });
            } else {
                rows.push(...got);
            }
        }
        return rows;
    }

    // "Search Spotify" (the list's top row): the results open in place on the view stack, with Back
    function openSearch(text) {
        const q = text.trim();
        if (q === "")
            return;
        root.push({ title: "Search: " + q, uri: "search:" + q, kind: "search", items: [], loading: false });
        filterInput.text = q;       // the box keeps the query: edit it and press Enter to search again
        root.runSearch();
    }

    // The song options menu at its row (right-click, Menu key)
    function openSongMenu(song, rowItem) {
        if (!song || !rowItem)
            return;
        const p = rowItem.mapToItem(rowMenuView, 0, 0);
        root.rowMenu = { song: song, top: p.y, bottom: p.y + rowItem.height };
    }

    // Middle-click / "Add to queue": plays next
    function queueSong(song) {
        SpotifyState.queue(song.uri, ok => root.note = ok ? song.name + " plays next" : "Couldn't queue " + song.name);
    }

    function toggleLyrics() {
        root.lyricsOn = !root.lyricsOn;
    }

    // Open an album / artist / playlist by uri (the names in the header)
    function openUri(kind, uri, name, image) {
        if (uri)
            root.activate({ kind: kind, uri: uri, name: name || "", sub: "", image: image || "", openable: true }, true);
    }

    // Enter inside the results: send what is typed; an answer for an older query is dropped
    function runSearch() {
        const q = filterInput.text.trim();
        const before = root.searchQuery;
        root.searchQuery = q;
        root.searchError = "";
        root.searchLoading = true;
        SpotifyState.search(q, (v, err) => {
            if (q !== root.searchQuery)
                return;
            root.searchLoading = false;
            // The helper stopped (the drawer closed): keep what was there, as if nothing was sent
            if (err === "helper stopped") {
                root.searchQuery = before;
                return;
            }
            root.searchResults = Array.isArray(v) ? v : [];
            root.searchError = err || "";
            root.setCursor(0);
        });
    }

    function push(entry) {
        root.pendingRestore = null;
        entry.fromIndex = listView.currentIndex;
        entry.fromFilter = filterInput.text;
        root.openedAt = Date.now();
        root.stack = root.stack.concat([entry]);
        filterInput.text = "";
        root.setCursor(0);
        root.focusKeys();
    }

    // Back one step (to the row you opened it from); false when there was nothing to go back from
    function goBack() {
        if (root.rowMenu) {
            root.rowMenu = null;
            return true;
        }
        if (root.addMode) {
            root.toggleAddMode();
            return true;
        }
        if (root.lyricsOn) {
            root.lyricsOn = false;
            return true;
        }
        if (root.stack.length > 0) {
            const top = root.stack[root.stack.length - 1];
            root.stack = root.stack.slice(0, -1);
            filterInput.text = top.fromFilter || "";
            Qt.callLater(() => root.setCursor(top.fromIndex || 0));
            return true;
        }
        return false;
    }

    function openMenu() {
        root.addMode = false;
        root.stack = [];
        root.note = "";
        root.hint = "";
        root.menuOpen = false;
        root.confirmLogout = false;
        root.confirmClient = false;
        root.editClient = false;
        filterInput.text = root.searchMode ? root.searchQuery : "";
        root.wantPlaying = root.tab === "liked";
        // The first time after a start: the tab, chip, filter text, selection and scroll position it was left at
        if (!root.restored) {
            root.restored = true;
            const p = SpotifyState.savedPlace || {};
            if (["library", "liked"].includes(p.tab))
                root.tab = p.tab;
            if (["all", "playlist", "album", "artist"].includes(p.kind))
                root.libraryKind = p.kind;
            filterInput.text = typeof p.filter === "string" ? p.filter : "";
            root.wantPlaying = root.tab === "liked";
            if (p.index > 0 || p.scrollY !== 0)
                root.pendingRestore = { index: Number(p.index) || 0, y: Number(p.scrollY) || 0 };
        }
        Qt.callLater(root.afterItems);
        root.shownAt = Date.now();
        root.visible = true;
        root.loadForTab(false);
        root.focusKeys();
    }

    function closeMenu() {
        // Remember where it was left (the filter, cursor and scroll only at the top level of a tab)
        if (root.restored && !root.addMode) {
            const top = root.stack.length === 0;
            SpotifyState.savedPlace = {
                tab: root.tab,
                kind: root.libraryKind,
                filter: top ? filterInput.text : "",
                index: top ? Math.max(0, listView.currentIndex) : 0,
                scrollY: top ? scroller.contentY : 0
            };
        }
        root.tip = null;
        root.rowMenu = null;
        root.visible = false;
        root.menuOpen = false;
        root.hint = "";
        // A search error is for this visit only; an answer still on its way is dropped
        root.searchError = "";
        root.searchLoading = false;
    }
}
