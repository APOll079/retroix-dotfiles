// Tests for popups/MiniPlayer.qml and MiniPlayerState.qml: the pure functions (time format, marquee offset, seek mapping,
// volume source) and what the window shows for fixture data. The window takes `hasPlayer`, `playing`, `track`, `position`,
// `length`, `volume` and `canSeek` as plain properties (bound to Media / SpotifyState in the shell); here they are set to
// fixtures, so no player is touched. The window is loaded by path (the runner copies this file next to popups/).
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

    Component.onCompleted: starter.start()
    Timer { id: starter; interval: 300; onTriggered: shell.run() }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }

    function run() {
        const comp = Qt.createComponent("popups/MiniPlayer.qml");
        if (comp.status !== Component.Ready) {
            check("MiniPlayer.qml loads: " + comp.errorString(), false);
            console.log("TEST done failures=" + failures);
            quitTimer.start();
            return;
        }
        const w = comp.createObject(shell, { visible: false, hasPlayer: true, playing: true, track: "Artist - Song", position: 65, length: 187, volume: 40, canSeek: true });
        check("the window is titled Mini player", w.title === "Mini player");

        // time format
        check("time: 0 and junk are 0:00", w.formatTime(0) === "0:00" && w.formatTime(-5) === "0:00" && w.formatTime(NaN) === "0:00" && w.formatTime(undefined) === "0:00" && w.formatTime("7") === "0:00");
        check("time: seconds pad", w.formatTime(5) === "0:05" && w.formatTime(65) === "1:05" && w.formatTime(187.9) === "3:07");
        check("time: over an hour has hours", w.formatTime(3723) === "1:02:03");
        check("time: 59:59 stays minutes", w.formatTime(3599) === "59:59");

        // marquee offset
        const sp = 44, hold = 1500, gap = 24;
        check("marquee: a line that fits never moves", w.marqueeOffset(100, 200, 123456, sp, hold, gap) === 0 && w.marqueeOffset(200, 200, 5000, sp, hold, gap) === 0);
        check("marquee: a long line waits at the start", w.marqueeOffset(400, 200, 0, sp, hold, gap) === 0 && w.marqueeOffset(400, 200, 1499, sp, hold, gap) === 0);
        check("marquee: then slides left at the speed", w.marqueeOffset(400, 200, hold + 1000, sp, hold, gap) === -44);
        const travel = (400 + gap) / sp * 1000;
        check("marquee: it never passes one copy plus the gap", w.marqueeOffset(400, 200, hold + travel - 1, sp, hold, gap) >= -(400 + gap));
        check("marquee: it starts over after one cycle", w.marqueeOffset(400, 200, hold + travel + 10, sp, hold, gap) === 0 && w.marqueeOffset(400, 200, 3 * (hold + travel) + hold + 1000, sp, hold, gap) === -44);
        check("marquee: a zero speed does not move", w.marqueeOffset(400, 200, 99999, 0, hold, gap) === 0);
        check("marquee: never positive", [0, 1000, 5000, 20000, 77777].every(t => w.marqueeOffset(400, 200, t, sp, hold, gap) <= 0));

        // seek mapping
        check("seek: the middle of a 200 s song is 100 s", w.seekTarget(0.5, 200) === 100);
        check("seek: ends clamp", w.seekTarget(-1, 200) === 0 && w.seekTarget(2, 200) === 200);
        check("seek: no length gives 0", w.seekTarget(0.5, 0) === 0 && w.seekTarget(0.5, undefined) === 0);
        check("seek: knob fraction", w.seekFraction(50, 200) === 0.25 && w.seekFraction(500, 200) === 1 && w.seekFraction(5, 0) === 0 && w.seekFraction(-3, 10) === 0);

        // volume source
        check("volume: the player's own wins (percent, rounded)", w.volumeOf(true, 0.456, true, 90) === 46);
        check("volume: clamped", w.volumeOf(true, 1.5, false, -1) === 100 && w.volumeOf(true, -1, false, -1) === 0);
        check("volume: a local Spotify without MPRIS volume uses its stream", w.volumeOf(false, 0, true, 33) === 33);
        check("volume: none when neither", w.volumeOf(false, 0, true, -1) === -1 && w.volumeOf(false, 0, false, 80) === -1);

        // what the window shows
        check("shows the elapsed time big", w.digitsItem.text === "1:05" && w.digitsItem.font.pixelSize === 32);
        check("shows the track line as plain text", w.marqueeItem.text === "Artist - Song" && w.marqueeItem.textFormat === Text.PlainText);
        w.track = "<b>x</b> & $(id)";
        check("hostile track text stays plain", w.marqueeItem.text === "<b>x</b> & $(id)");
        w.track = "Artist - Song";
        check("digits are accent coloured, the face outline coloured", String(w.digitsItem.color) === String(Config.colors.accent));
        check("the three transport buttons are the same size", w.prevButton.implicitWidth === w.playButton.implicitWidth && w.playButton.implicitWidth === w.nextButton.implicitWidth
              && w.prevButton.implicitHeight === w.playButton.implicitHeight && w.playButton.implicitHeight === w.nextButton.implicitHeight);
        check("playing: the play button shows pause", w.playButton.glyph === "\ue034");
        w.playing = false;
        check("paused: the play button shows play", w.playButton.glyph === "\ue037");
        check("seek is on with a song and a seekable player", w.seekItem.enabled === true && w.seekItem.to === 187);
        w.canSeek = false;
        check("not seekable: the seek slider is off", w.seekItem.enabled === false);
        w.canSeek = true;
        check("volume slider follows the volume", w.volumeItem.enabled && w.volumeItem.value === 40);
        w.volume = -1;
        check("no volume: the slider is off", w.volumeItem.enabled === false);
        w.volume = 40;
        w.track = ""; w.length = 0; w.position = 0;
        check("a player with no song: nothing playing, seek off, buttons on", w.marqueeItem.text === "Nothing playing" && w.seekItem.enabled === false && w.playButton.enabled === true && w.digitsItem.text === "0:00");
        w.hasPlayer = false;
        check("no player: its own line, buttons off", w.marqueeItem.text === "No player running" && w.playButton.enabled === false && w.prevButton.enabled === false && w.nextButton.enabled === false);
        check("actions with no player do nothing (no crash)", (() => { w.togglePlay(); w.next(); w.previous(); w.seekTo(5); w.setVolume(10); return true; })());
        w.hasPlayer = true; w.track = "A - B"; w.length = 100;
        check("it fits: no scrolling", w.scrolling === false);
        w.track = "A very long artist name - and a very long song title that cannot possibly fit in the small LCD line";
        check("it does not fit: it scrolls (unless reduce motion)", w.scrolling === !MenuStyle.reduceMotion && w.scrolling === true);
        check("fixed size: the window is exactly as wide as a medium menu", w.implicitWidth === MenuStyle.widthMedium && w.implicitHeight > 0);
        check("size is " + w.implicitWidth + "x" + w.implicitHeight, true);
        w.destroy();

        // MiniPlayerState: open makes one window, a second open keeps it, toggle closes it
        MiniPlayerState.open();
        const first = MiniPlayerState.win;
        check("state: open creates the window", MiniPlayerState.visible && first !== null && first.title === "Mini player");
        MiniPlayerState.open();
        check("state: opening again keeps the same window", MiniPlayerState.win === first);
        MiniPlayerState.toggle();
        check("state: toggle closes it", !MiniPlayerState.visible && MiniPlayerState.win === null);
        MiniPlayerState.toggle();
        check("state: toggle opens it again", MiniPlayerState.visible);
        MiniPlayerState.close();
        MiniPlayerState.close();
        check("state: close twice is harmless", !MiniPlayerState.visible);
        console.log("TEST done failures=" + failures);
        quitTimer.start();
    }
}
