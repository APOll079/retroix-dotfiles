import QtQuick
import QtQuick.Layouts
import ".."

// The one filter / search box. Typing filters the current list (the list's top row, "Search Spotify for ...",
// takes the text to Spotify); Enter on that row, or Enter again inside the results, searches. Keys:
// Up / Down (and Left / Right in the grid) move, Enter opens, Shift+Enter plays, Menu / Shift+F10 the song's
// actions, Ctrl+L the lyrics, Space plays / pauses while the box is empty, Escape clears, steps back, closes.
SearchBox {
    id: search
    required property var panel
    Layout.fillWidth: true
    implicitHeight: MenuStyle.spotifyCompactRow
    visible: !panel.lyricsMode
    placeholder: panel.searchMode ? "Edit, then Enter to search again"
        : (panel.view ? "Filter" : (panel.tab === "liked" ? "Filter Liked Songs" : panel.tab === "queue" ? "Filter the queue" : "Filter library")) + " · Enter searches Spotify"
    // typing puts the visible cursor on the first result (Enter then acts on it, as in the launcher)
    // (the first match, not the "Search Spotify for ..." row above it; that row when nothing matches)
    onEdited: {
        const first = panel.items.findIndex(i => i.kind !== "searchrow" && i.kind !== "heading");
        panel.setCursor(first >= 0 ? first : 0);
        panel.cursorShown = search.text !== "";
    }
    onEscaped: {
        if (!panel.goBack())
            panel.closeCallback();
    }
    onKeyPressed: event => {
        if (panel.globalKey(event)) {
            event.accepted = true;
            return;
        }
        const empty = search.text === "";
        const cur = panel.listView.currentIndex;
        // the first arrow press only shows the cursor (where it is), the next ones move it
        const arrow = event.key === Qt.Key_Down || event.key === Qt.Key_Up
            || (panel.useGrid && empty && (event.key === Qt.Key_Left || event.key === Qt.Key_Right));
        if (arrow && !panel.cursorShown) {
            panel.cursorShown = true;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Down) {
            if (panel.useGrid)
                panel.gridMove(1);
            else
                panel.setCursor(Math.min(panel.items.length - 1, cur + 1));
        } else if (event.key === Qt.Key_Up) {
            if (panel.useGrid)
                panel.gridMove(-1);
            else
                panel.setCursor(Math.max(0, cur - 1), -1);
        } else if (panel.useGrid && empty && event.key === Qt.Key_Right) {
            panel.setCursor(Math.min(panel.items.length - 1, cur + 1));
        } else if (panel.useGrid && empty && event.key === Qt.Key_Left) {
            panel.setCursor(Math.max(0, cur - 1), -1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const typed = search.text.trim();
            // In the results: new text searches again (Shift+Enter with new text must not play an old row);
            // otherwise Enter opens the selected row. Elsewhere the top row ("Search Spotify for ...") is
            // what Enter lands on.
            if (panel.searchMode && typed !== ""
                    && (typed !== panel.searchQuery || (!(event.modifiers & Qt.ShiftModifier) && panel.searchResults.length === 0)))
                panel.runSearch();
            else if (!panel.cursorShown)
                ;   // no visible cursor: Enter does nothing (it would act on a row you can't see)
            else if (event.modifiers & Qt.ShiftModifier)
                panel.playItem(panel.items[cur]);
            else
                panel.activate(panel.items[cur], true);
        } else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            const it = panel.items[cur];
            if (it && it.kind === "track" && !panel.addMode && panel.cursorShown)
                panel.openSongMenu(it, panel.listView.itemAtIndex(cur));
        } else if (event.key === Qt.Key_Space && empty) {
            SpotifyState.togglePlay();
        } else {
            return;
        }
        event.accepted = true;
    }
}
