import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import ".."

// The Lyrics window: a small real window (an xdg toplevel Hyprland floats and pins, see windowrules.lua) with the
// current line large and the next line quieter. Opened and closed by LyricsWindowState.qml (`qs ipc call lyrics toggle`);
// it exists only while open. The text comes ONLY from the Lyrics singleton (lines, index) and Media.spotify: there is no
// second fetcher. While it is open Lyrics.fast is on so the line follows the song closely.
// `playing`, `lines`, `index` and `header` are plain properties bound to those singletons; tests set them to fixtures.
// The decisions are in viewOf(), a pure function.
FloatingWindow {
    id: root

    // Hyprland matches this title (windowrules.lua "lyrics-window")
    title: "Lyrics"


    implicitWidth: MenuStyle.lyricsWindowWidth
    implicitHeight: MenuStyle.lyricsWindowHeight
    minimumSize: Qt.size(MenuStyle.lyricsMinWidth, MenuStyle.lyricsMinHeight)
    color: Config.colors.base

    // Closed by Hyprland (Super+Q, the close dispatcher) or Esc: the state singleton drops the window
    signal closeRequested()
    onClosed: root.closeRequested()

    property bool playing: Media.spotify !== null
    property var lines: Lyrics.lines              // [{ t, text }]
    property int index: Lyrics.index              // position of the current line, -1 before the first
    property string header: Media.trackOf(Media.spotify)

    // "nothing" | "none" | "lyrics"; current is "" in a gap or before the first line; next is "" at the last line
    function viewOf(playing, lines, index) {
        if (!playing)
            return { state: "nothing", current: "", next: "", gap: false };
        if (!Array.isArray(lines) || lines.length === 0)
            return { state: "none", current: "", next: "", gap: false };
        const at = (i) => (i >= 0 && i < lines.length && typeof lines[i].text === "string") ? lines[i].text : "";
        const i = (index >= 0 && index < lines.length) ? index : -1;
        const cur = at(i);
        return { state: "lyrics", current: cur, next: at(i + 1), gap: cur === "" };
    }

    // (through a var so the singleton's member is not a lint error)
    readonly property var lyr: Lyrics
    readonly property var view: root.viewOf(root.playing, root.lines, root.index)
    readonly property Item currentItem: currentText
    readonly property Item nextItem: nextText
    readonly property Item gapItem: gapGlyph
    readonly property Item emptyItem: empty

    // Lyrics.fast is also set by the Spotify drawer; if that turns it off while we are open, turn it back on
    Component.onCompleted: { if (root.visible) root.lyr.fast = true; }
    Component.onDestruction: root.lyr.fast = false
    onVisibleChanged: root.lyr.fast = root.visible
    Connections {
        target: Lyrics
        function onFastChanged() {
            if (root.visible && !root.lyr.fast)
                root.lyr.fast = true;
        }
    }

    // Our own toplevel: this title, this process (the address form TaskManager uses)
    function focusSelf() {
        const t = Hyprland.toplevels.values.find(w => w.title === root.title && w.lastIpcObject && w.lastIpcObject.pid === Quickshell.processId);
        if (t)
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + t.address + "\" })");
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()

        PopupWindowFrame {
            windowTitle: root.title
            // Dragging the title bar moves the window, like any Win95 window
            titleDrag: true
            onTitlePressed: root.startSystemMove()

            ColumnLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                // What is playing, quietly
                RetroText {
                    Layout.fillWidth: true
                    visible: root.header !== ""
                    elide: Text.ElideRight
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: MenuStyle.bevelDark
                    text: root.header
                }

                EmptyState {
                    id: empty
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.view.state !== "lyrics"
                    glyph: "\ue405"
                    text: root.view.state === "nothing" ? "Nothing playing" : "No synced lyrics for this song"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.view.state === "lyrics"
                    clip: true

                    ColumnLayout {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: MenuStyle.space12

                        // The current line, large; wraps, never shrinks. In a gap or instrumental part: a dim note
                        RetroText {
                            id: currentText
                            Layout.fillWidth: true
                            visible: !root.view.gap
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.spotifyTitleSize
                            color: Config.colors.text
                            text: root.view.current
                        }
                        RetroText {
                            id: gapGlyph
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.view.gap
                            font.family: MenuStyle.iconFont
                            font.pixelSize: MenuStyle.iconSizeLarge
                            color: MenuStyle.bevelDark
                            text: "\ue405"
                        }
                        // The next line, quieter
                        RetroText {
                            id: nextText
                            Layout.fillWidth: true
                            visible: root.view.next !== ""
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: MenuStyle.bevelDark
                            text: root.view.next
                        }
                    }
                }
            }
        }
    }
}
