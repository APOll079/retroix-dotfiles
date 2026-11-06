// Media.qml pure parts: the bar player choice (Spotify first, then a playing player, then the last other one while it
// exists), the track toast decision / cover / notify-send arguments, and the like menu model. Fixture players only;
// no MPRIS is read and nothing is sent (the toast needs the live gate, off under QS_NO_APPLY).
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

    function pl(identity, playing, entry) {
        return { identity: identity, desktopEntry: entry || "", isPlaying: playing, trackTitle: "t", trackArtist: "a" };
    }

    function run() {
        const M = Media;
        const sp = pl("Spotify", true, "spotify"), spPaused = pl("Spotify", false, "spotify");
        const zen = pl("Zen", true, "zen"), vlc = pl("VLC", false, "vlc");

        // ---- player choice ----
        check("pick: Spotify playing wins over another playing player", M.pickBarPlayer([zen, sp], null) === sp);
        check("pick: a paused Spotify still wins (its dimmed text stays, as before)", M.pickBarPlayer([zen, spPaused], null) === spPaused);
        check("pick: a playing Spotify wins over a paused one", M.pickBarPlayer([spPaused, sp], null) === sp);
        check("pick: without Spotify a playing player", M.pickBarPlayer([vlc, zen], null) === zen);
        check("pick: nothing playing and no history is null", M.pickBarPlayer([vlc], null) === null && M.pickBarPlayer([], null) === null);
        check("pick: the last other player stays (paused, dimmed) while it exists", M.pickBarPlayer([vlc], vlc) === vlc);
        check("pick: a vanished last player is dropped", M.pickBarPlayer([], vlc) === null && M.pickBarPlayer([zen], vlc) === zen);
        check("pick: spotifyd counts as Spotify", M.pickBarPlayer([zen, pl("spotifyd", false, "")], null).identity === "spotifyd");
        check("trackOf: Artist - Title, or the title alone", M.trackOf({ trackTitle: "Song", trackArtist: "Band" }) === "Band - Song" && M.trackOf({ trackTitle: "Video", trackArtist: "" }) === "Video" && M.trackOf({ trackTitle: "", trackArtist: "x" }) === "");
        check("the bar text is empty with no player (offscreen)", M.text === "" && M.barPlayer === null);

        // ---- track toast ----
        const A = { title: "One", artist: "X" }, B = { title: "Two", artist: "X" };
        const D = (prev, cur, en, drawer, now, last) => M.trackToastDecision(prev, cur, en, drawer, now, last, 2000);
        check("toast: a song change fires", D(A, B, true, false, 10000, 0).fire === true && D(A, B, true, false, 10000, 0).remember === B);
        check("toast: off by default setting does not fire", D(A, B, false, false, 10000, 0).fire === false);
        check("toast: no previous track (start) does not fire but remembers", D(null, A, true, false, 10000, 0).fire === false && D(null, A, true, false, 10000, 0).remember === A);
        check("toast: the same track does not fire", D(A, { title: "One", artist: "X" }, true, false, 10000, 0).fire === false);
        check("toast: same title, other artist fires", D(A, { title: "One", artist: "Y" }, true, false, 10000, 0).fire === true);
        check("toast: an empty title (between songs) does not fire and keeps the old track", D(A, { title: "", artist: "" }, true, false, 10000, 0).fire === false && D(A, { title: "", artist: "" }, true, false, 10000, 0).remember === A);
        check("toast: no current track", D(A, null, true, false, 10000, 0).fire === false && D(A, null, true, false, 10000, 0).remember === A);
        check("toast: not while the Spotify drawer is open, but the track is remembered", D(A, B, true, true, 10000, 0).fire === false && D(A, B, true, true, 10000, 0).remember === B);
        check("toast: rate limited to one per 2 s", D(A, B, true, false, 11000, 10000).fire === false && D(A, B, true, false, 12000, 10000).fire === true);
        check("cover: a local path and a file URL are usable", M.coverPath("/tmp/a.png") === "/tmp/a.png" && M.coverPath("file:///tmp/a%20b.png") === "/tmp/a b.png");
        check("cover: web URLs and junk give no hint", M.coverPath("https://i.scdn.co/x") === "" && M.coverPath("") === "" && M.coverPath(undefined) === "");
        check("args: with a cover", JSON.stringify(M.trackToastArgs(A, "/tmp/c.png")) === '["notify-send","-a","Now playing","-h","string:image-path:/tmp/c.png","--","One","X"]');
        check("args: without a cover, a title starting with a dash stays an argument", JSON.stringify(M.trackToastArgs({ title: "-rf", artist: "" }, "")) === '["notify-send","-a","Now playing","--","-rf",""]');
        M.noteTrack();
        check("noteTrack with no player does nothing", M.lastTrack === null);
        check("the setting exists, default false", Config.settings.spotifyExtras.trackToast === false);

        // ---- like menu ----
        let toggled = 0, added = 0;
        const m1 = M.likeMenuModel(true, true, false, () => toggled++, () => added++);
        check("like menu: Like and Add to playlist", m1.length === 2 && m1[0].text === "Like" && m1[1].text === "Add to playlist...");
        m1[0].action();
        m1[1].action();
        check("like menu: the entries call back", toggled === 1 && added === 1);
        check("like menu: a liked song offers Unlike", M.likeMenuModel(true, true, true, null, null)[0].text === "Unlike");
        check("like menu: not logged in gives one disabled note", M.likeMenuModel(true, false, false, null, null).length === 1 && M.likeMenuModel(true, false, false, null, null)[0].enabled === false);
        check("like menu: no track gives one disabled note", M.likeMenuModel(false, true, false, null, null)[0].text === "Nothing playing");
        let got = null;
        M.likeMenu(() => {}, model => { got = model; });
        check("likeMenu without a track or login answers at once with a note", got !== null && got.length === 1 && got[0].enabled === false);
        console.log("TEST done failures=" + shell.failures);
        Qt.quit();
    }
}
