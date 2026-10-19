import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local

// Tabs, the library chips / opened item's header, the artist summary and the one filter / search box.
// Keys typed in the box go to panel.listView (the shared cursor) and the panel's functions.
ColumnLayout {
    required property var panel
    readonly property var box: filterInput
    spacing: MenuStyle.pad

    // Tabs
    RowLayout {
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        visible: !panel.addMode
        Repeater {
            model: [
                { key: "library", text: "Library" },
                { key: "liked", text: "Liked" },
                { key: "search", text: "Search" },
                { key: "lyrics", text: "Lyrics" }
            ]
            BevelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: modelData.text
                checked: panel.tab === modelData.key
                focusPolicy: Qt.NoFocus
                onClicked: panel.showTab(modelData.key)
            }
        }
    }

    // Library chips, or an opened item's header (Back, title, Play) / the playlist picker's;
    // the view toggle sits at the end of whichever row is showing
    RowLayout {
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        visible: panel.addMode || panel.stack.length > 0 || panel.tab === "library" || panel.searchMode
        Repeater {
            model: !panel.addMode && panel.stack.length === 0 && panel.tab === "library" ? [
                { key: "all", text: "All" },
                { key: "playlist", text: "Playlists" },
                { key: "artist", text: "Artists" },
                { key: "album", text: "Albums" }
            ] : []
            BevelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: modelData.text
                checked: panel.libraryKind === modelData.key
                focusPolicy: Qt.NoFocus
                onClicked: {
                    panel.libraryKind = modelData.key;
                    panel.setCursor(0);
                    panel.focusKeys();
                }
            }
        }
        // Search chips: narrow the results to one type
        Repeater {
            model: panel.searchMode ? [
                { key: "all", text: "All" },
                { key: "track", text: "Songs" },
                { key: "album", text: "Albums" },
                { key: "artist", text: "Artists" },
                { key: "playlist", text: "Playlists" }
            ] : []
            BevelButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: modelData.text
                checked: panel.searchKind === modelData.key
                focusPolicy: Qt.NoFocus
                onClicked: {
                    panel.searchKind = modelData.key;
                    panel.setCursor(0);
                    panel.focusKeys();
                }
            }
        }
        BevelButton {
            visible: panel.addMode || panel.stack.length > 0
            text: panel.addMode ? "Cancel" : "Back"
            glyph: "\ue5c4"
            focusPolicy: Qt.NoFocus
            onClicked: {
                panel.goBack();
                panel.focusKeys();
            }
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            textFormat: Text.PlainText
            Layout.fillWidth: true
            visible: panel.addMode || panel.stack.length > 0
            elide: Text.ElideRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: panel.addMode ? "Add " + (panel.addTarget ? panel.addTarget.name : "") + " to:" : (panel.view ? panel.view.title : "")
        }
        BevelButton {
            visible: !panel.addMode && panel.view !== null && panel.view.kind !== "folder" && panel.view.kind !== "artist"
            text: "Play"
            glyph: "\ue037"
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.play(panel.view.uri)
        }
        BevelButton {
            visible: panel.showViewToggle
            glyph: SpotifyState.grid ? "\ue8ef" : "\ue9b0"
            focusPolicy: Qt.NoFocus
            onClicked: {
                SpotifyState.grid = !SpotifyState.grid;
                panel.focusKeys();
            }
        }
    }

    // An artist: one big Play (their songs in Spotify), then the discography summary
    ColumnLayout {
        Layout.fillWidth: true
        visible: !panel.addMode && panel.view !== null && panel.view.kind === "artist"
        spacing: MenuStyle.gap
        BevelButton {
            Layout.fillWidth: true
            text: panel.view ? "Play " + panel.view.title : ""
            glyph: "\ue037"
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.play(panel.view.uri)
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            textFormat: Text.PlainText
            Layout.fillWidth: true
            visible: text !== ""
            elide: Text.ElideRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: MenuStyle.bevelDark
            text: panel.view && panel.view.summary ? panel.view.summary : ""
        }
    }

    SearchBox {
        id: filterInput
        Layout.fillWidth: true
        implicitHeight: MenuStyle.rowHeight + MenuStyle.gap
        visible: !panel.lyricsMode
        placeholder: panel.searchMode ? "Search Spotify (Enter)" : "Filter"
        onEdited: panel.setCursor(0)
        onEscaped: {
            if (!panel.goBack())
                panel.closeCallback();
        }
        // Up / Down (and Left / Right in the grid) move, Enter opens, Shift+Enter plays,
        // Space plays / pauses while the filter is empty
        onKeyPressed: event => {
            const cols = panel.useGrid ? MenuStyle.spotifyGridColumnsLibrary : 1;
            const empty = filterInput.text === "";
            const cur = panel.listView.currentIndex;
            if (event.key === Qt.Key_Down) {
                panel.setCursor(Math.min(panel.items.length - 1, cur + cols));
            } else if (event.key === Qt.Key_Up) {
                panel.setCursor(Math.max(0, cur - cols), -1);
            } else if (panel.useGrid && empty && event.key === Qt.Key_Right) {
                panel.setCursor(Math.min(panel.items.length - 1, cur + 1));
            } else if (panel.useGrid && empty && event.key === Qt.Key_Left) {
                panel.setCursor(Math.max(0, cur - 1), -1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                const typed = filterInput.text.trim();
                // Search tab: a new query (or one with no results yet) goes to Spotify;
                // Enter on the same query opens the selected result
                // (Shift+Enter with an unsent query searches too: it must not play an old row)
                if (panel.searchMode && typed !== ""
                        && (typed !== panel.searchQuery || (!(event.modifiers & Qt.ShiftModifier) && panel.searchResults.length === 0)))
                    panel.runSearch();
                else if (event.modifiers & Qt.ShiftModifier)
                    panel.playItem(panel.items[cur]);
                else
                    panel.activate(panel.items[cur], true);
            } else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                const it = panel.items[cur];
                if (it && it.kind === "track")
                    panel.songMenu = it;
            } else if (event.key === Qt.Key_Space && empty) {
                SpotifyState.togglePlay();
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
