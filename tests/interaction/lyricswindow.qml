// Tests for popups/LyricsWindow.qml: what the window shows for fixture lyrics. The window takes `playing`, `lines`, `index`
// and `header` as plain properties (bound to Media / Lyrics in the shell); here they are set to fixtures, so the real
// fetcher never runs. The window is created hidden, and the Text items it exposes (currentItem, nextItem, gapItem,
// emptyItem) are read. The window is loaded by path (the runner copies this file next to popups/).
import QtQuick
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    readonly property var fixture: [
        { t: 5, text: "First line" },
        { t: 10, text: "" },
        { t: 15, text: "Middle line that is quite long indeed" },
        { t: 20, text: "Last line" }
    ]

    Component.onCompleted: starter.start()
    Timer { id: starter; interval: 300; onTriggered: shell.run() }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }

    function run() {
        const comp = Qt.createComponent("popups/LyricsWindow.qml");
        if (comp.status !== Component.Ready) {
            check("LyricsWindow.qml loads: " + comp.errorString(), false);
            console.log("TEST done failures=" + failures);
            quitTimer.start();
            return;
        }
        const w = comp.createObject(shell, { visible: false, playing: true, lines: fixture, index: 0, header: "Artist - Song" });
        // what the window shows for (playing, lines, index): "state|current|next|gap|shown items"
        function show(playing, lines, index) {
            w.playing = playing; w.lines = lines; w.index = index;
            const v = w.view;
            return [v.state, v.current, v.next, v.gap ? "gap" : "line",
                    w.currentItem.visible ? "C" : "-", w.nextItem.visible ? "N" : "-", w.gapItem.visible ? "G" : "-", w.emptyItem.visible ? "E" : "-"].join("|");
        }

        check("the window is titled Lyrics", w.title === "Lyrics");
        check("start: first line current, an empty next hides the next item", show(true, fixture, 0) === "lyrics|First line||line|C|-|-|-");
        check("start: the text items show the same text", w.currentItem.text === "First line" && w.nextItem.text === "");
        check("before the first line (index -1): a gap, the first line is next", show(true, fixture, -1) === "lyrics||First line|gap|-|N|G|-");
        check("a gap line: the note glyph shows, the current text hides, next is the following line", show(true, fixture, 1) === "lyrics||Middle line that is quite long indeed|gap|-|N|G|-");
        check("middle: current and next", show(true, fixture, 2) === "lyrics|Middle line that is quite long indeed|Last line|line|C|N|-|-");
        check("the next item shows the next text", w.nextItem.text === "Last line");
        check("last line: no next", show(true, fixture, 3) === "lyrics|Last line||line|C|-|-|-");
        check("an index past the end counts as before the start", show(true, fixture, 99).startsWith("lyrics||First line|gap"));
        check("no synced lyrics: only the empty state", show(true, [], -1) === "none|||line|-|-|-|E");
        check("no synced lyrics: its text", w.emptyItem.text === "No synced lyrics for this song");
        check("lines not an array counts as none", show(true, null, 0).startsWith("none|"));
        check("nothing playing: only the empty state", show(false, fixture, 2) === "nothing|||line|-|-|-|E");
        check("nothing playing: its text", w.emptyItem.text === "Nothing playing");
        check("nothing playing wins over lyrics left from the last song", show(false, fixture, 0).startsWith("nothing|"));
        check("hostile lyric text stays plain text", (() => {
            show(true, [{ t: 0, text: "<b>x</b> & $(id)" }], 0);
            return w.currentItem.text === "<b>x</b> & $(id)";
        })());
        check("a long line wraps instead of shrinking", (() => {
            show(true, [{ t: 0, text: "word ".repeat(80) }], 0);
            return w.currentItem.font.pixelSize === 16 && w.currentItem.wrapMode !== 0;
        })());
        check("header is shown through the property", w.header === "Artist - Song");
        check("a window created hidden leaves Lyrics.fast alone", Lyrics.fast === false);

        w.destroy();

        // LyricsWindowState: open makes one window, a second open keeps it, toggle closes it
        LyricsWindowState.open();
        const first = LyricsWindowState.win;
        check("state: open creates the window", LyricsWindowState.visible && first !== null && first.title === "Lyrics");
        check("state: Lyrics.fast is on while it is open", Lyrics.fast === true);
        LyricsWindowState.open();
        check("state: opening again keeps the same window", LyricsWindowState.win === first);
        LyricsWindowState.toggle();
        check("state: toggle closes it", !LyricsWindowState.visible && LyricsWindowState.win === null);
        LyricsWindowState.toggle();
        check("state: toggle opens it again", LyricsWindowState.visible);
        LyricsWindowState.close();
        LyricsWindowState.close();
        check("state: close twice is harmless", !LyricsWindowState.visible);
        fastCheck.start();
    }
    Timer {
        id: fastCheck
        interval: 300
        onTriggered: {
            shell.check("state: Lyrics.fast is off again after closing", Lyrics.fast === false);
            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
}
