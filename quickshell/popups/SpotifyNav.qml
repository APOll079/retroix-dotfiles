import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// The bar under the tabs: the library chips (All / Playlists / Albums / Artists) with the grid / list toggle,
// or, inside something, a Back row (an opened item with Play, the Spotify search results, the playlist
// picker). Search results add their own chips (+ Songs). Chips size to their text.
ColumnLayout {
    id: nav
    required property var panel
    spacing: MenuStyle.spotifyColumnGap

    component Chip: BevelButton {
        property bool on: false
        signal picked()
        implicitHeight: MenuStyle.spotifyChipHeight
        implicitWidth: implicitContentWidth + leftPadding + rightPadding
        checked: on
        focusPolicy: Qt.NoFocus
        onClicked: picked()
    }

    // Back row: an opened item / the search results / the playlist picker
    RowLayout {
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        visible: panel.addMode || panel.view !== null
        BevelButton {
            implicitHeight: MenuStyle.spotifyCompactRow
            text: panel.addMode ? "Cancel" : "Back"
            glyph: "\ue5c4"
            focusPolicy: Qt.NoFocus
            onClicked: {
                panel.goBack();
                panel.focusKeys();
            }
            SpotifyHint { panel: nav.panel; text: "Back (Esc)" }
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            textFormat: Text.PlainText
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: panel.addMode ? "Add " + (panel.addTarget ? panel.addTarget.name : "") + " to:"
                : (panel.searchMode ? "Search: " + panel.searchQuery : (panel.view ? panel.view.title : ""))
        }
        BevelButton {
            visible: !panel.addMode && panel.view !== null && panel.view.kind !== "folder" && panel.view.kind !== "artist" && panel.view.kind !== "search"
            implicitHeight: MenuStyle.spotifyCompactRow
            text: "Play"
            glyph: "\ue037"
            focusPolicy: Qt.NoFocus
            onClicked: SpotifyState.play(panel.view.uri)
        }
        BevelButton {
            visible: panel.showViewToggle && panel.view !== null
            implicitHeight: MenuStyle.spotifyCompactRow
            glyph: SpotifyState.grid ? "\ue8ef" : "\ue9b0"
            focusPolicy: Qt.NoFocus
            onClicked: {
                SpotifyState.grid = !SpotifyState.grid;
                panel.focusKeys();
            }
            SpotifyHint { panel: nav.panel; text: SpotifyState.grid ? "Show as rows" : "Show as covers" }
        }
    }

    // Chips: the library's, or the search results'
    RowLayout {
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        visible: (!panel.addMode && panel.view === null && panel.tab === "library") || panel.searchMode
        Repeater {
            model: panel.searchMode ? [
                { key: "all", text: "All" },
                { key: "playlist", text: "Playlists" },
                { key: "album", text: "Albums" },
                { key: "artist", text: "Artists" },
                { key: "track", text: "Songs" }
            ] : [
                { key: "all", text: "All" },
                { key: "playlist", text: "Playlists" },
                { key: "album", text: "Albums" },
                { key: "artist", text: "Artists" }
            ]
            Chip {
                required property var modelData
                text: modelData.text
                on: (panel.searchMode ? panel.searchKind : panel.libraryKind) === modelData.key
                onPicked: {
                    if (panel.searchMode)
                        panel.searchKind = modelData.key;
                    else
                        panel.libraryKind = modelData.key;
                    panel.setCursor(0);
                    panel.focusKeys();
                }
            }
        }
        Item { Layout.fillWidth: true }
        BevelButton {
            visible: panel.showViewToggle && panel.view === null
            implicitHeight: MenuStyle.spotifyChipHeight
            glyph: SpotifyState.grid ? "\ue8ef" : "\ue9b0"
            focusPolicy: Qt.NoFocus
            onClicked: {
                SpotifyState.grid = !SpotifyState.grid;
                panel.focusKeys();
            }
            SpotifyHint { panel: nav.panel; text: SpotifyState.grid ? "Show as rows" : "Show as covers" }
        }
    }

    // An artist: one big Play (their songs in Spotify), then the discography summary
    ColumnLayout {
        Layout.fillWidth: true
        visible: !panel.addMode && panel.view !== null && panel.view.kind === "artist"
        spacing: MenuStyle.gap
        BevelButton {
            Layout.fillWidth: true
            implicitHeight: MenuStyle.spotifyCompactRow
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
}
