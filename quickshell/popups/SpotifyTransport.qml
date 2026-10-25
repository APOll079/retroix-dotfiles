import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// The main view's seek row (SpotifySeek) and transport row (SpotifyButtons); hidden in the lyrics view, which
// has its own rows built from the same two components. Like, add-to-playlist and the volume live in the header.
ColumnLayout {
    id: transport
    required property var panel
    spacing: MenuStyle.spotifyColumnGap
    visible: !panel.lyricsMode

    SpotifySeek {
        Layout.fillWidth: true
        panel: transport.panel
    }

    SpotifyButtons {
        Layout.fillWidth: true
        panel: transport.panel
    }
}
