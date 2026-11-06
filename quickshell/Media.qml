pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Media state for the bar and the side panel, read straight from MPRIS (no playerctl).
// - spotify: the Spotify player, or null.
// - barPlayer: what the bar centre shows: Spotify when it runs (exactly as before), else a playing other player (YouTube
//   in a browser, VLC...), kept dimmed while that one is paused; null when neither.
// - player: what the panel controls act on: whatever is playing (Spotify wins if it plays),
//   else a paused Spotify (so play resumes it), else null. Pausing a video while Spotify sits
//   paused hits the video, not Spotify.
// Lyrics (later) hook in here: spotify.position / spotify.length plus the current track.
Singleton {
    id: root

    // The Spotify app or spotifyd (the background player the Spotify panel uses without the app)
    function isSpotify(p) {
        return /^spotifyd?$/i.test(p.desktopEntry) || /^spotifyd?/i.test(p.identity);
    }

    function trackOf(p) {
        if (!p || p.trackTitle === "")
            return "";
        return p.trackArtist === "" ? p.trackTitle : p.trackArtist + " - " + p.trackTitle;
    }

    // Both may run at once: the one that plays wins
    readonly property var spotify: Mpris.players.values.find(p => root.isSpotify(p) && p.isPlaying)
        || Mpris.players.values.find(p => root.isSpotify(p)) || null
    readonly property var player: (spotify && spotify.isPlaying ? spotify : null)
        || Mpris.players.values.find(p => p.isPlaying)
        || spotify
        || null

    // --- Panel (controls follow `player`) ---
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string label: {
        const t = root.trackOf(root.player);
        if (t === "")
            return root.player ? "Nothing playing" : "No player running";
        return root.playing ? t : t + " (paused)";
    }

    // --- Bar centre ---
    // Pure: which player the bar shows. Spotify first (a playing one, else any, so its paused text stays), then a
    // playing player, then `previous` (the other player shown last) while it still exists so a paused video stays
    // dimmed on the bar, else null.
    function pickBarPlayer(players, previous) {
        const list = Array.from(players || []);
        const sp = list.find(p => root.isSpotify(p) && p.isPlaying) || list.find(p => root.isSpotify(p));
        if (sp)
            return sp;
        const playing = list.find(p => p.isPlaying);
        if (playing)
            return playing;
        return previous && list.indexOf(previous) >= 0 ? previous : null;
    }
    // qmllint disable missing-property
    readonly property var allPlayers: Mpris.players.values
    // qmllint enable missing-property
    readonly property var otherPlaying: root.allPlayers.find(p => !root.isSpotify(p) && p.isPlaying) || null
    property var lastOther: null
    onOtherPlayingChanged: {
        if (root.otherPlaying)
            root.lastOther = root.otherPlaying;
    }
    readonly property var barPlayer: root.pickBarPlayer(root.allPlayers, root.lastOther)

    // Shown while the bar player has a track, dimmed when paused. Spotify briefly reports an empty
    // title between tracks, so going empty waits barHideDelay before the text disappears.
    readonly property string barTrack: trackOf(barPlayer)
    readonly property bool barPaused: barPlayer !== null && !barPlayer.isPlaying
    property string text: ""
    property bool paused: false

    onBarTrackChanged: {
        sync();
        root.noteTrack();
    }
    onBarPausedChanged: sync()
    Component.onCompleted: sync()

    function sync() {
        if (root.barTrack !== "") {
            hideTimer.stop();
            root.text = root.barTrack;
            root.paused = root.barPaused;
        } else {
            hideTimer.restart();
        }
    }

    // --- Track toast (settings spotifyExtras.trackToast, off by default) ---
    // A themed "Now playing" toast on every song change of the bar player. Pure: given the last known track and the
    // current one ({ title, artist }), decides whether to toast. Never at start (no previous track), never for an
    // empty title (Spotify reports one between songs), never while the Spotify drawer is open, at most one per minGap ms.
    // The track is remembered either way, so a suppressed toast does not fire later.
    function trackToastDecision(prev, cur, enabled, drawerOpen, now, lastToast, minGap) {
        const none = { fire: false, remember: cur && cur.title !== "" ? cur : prev };
        if (!enabled || !cur || cur.title === "")
            return none;
        if (!prev || (prev.title === cur.title && prev.artist === cur.artist))
            return none;
        if (drawerOpen || now - lastToast < minGap)
            return none;
        return { fire: true, remember: cur };
    }
    // Pure: a cover usable as notify-send's image-path (a local file); web URLs are not, so no hint
    function coverPath(url) {
        const u = String(url || "");
        if (u.indexOf("file://") === 0)
            return decodeURIComponent(u.slice(7));
        return u.charAt(0) === "/" ? u : "";
    }
    // Pure: the notify-send argument list for a toast
    function trackToastArgs(cur, cover) {
        const args = ["notify-send", "-a", "Now playing"];
        if (cover !== "")
            args.push("-h", "string:image-path:" + cover);
        return args.concat(["--", cur.title, cur.artist]);
    }
    property var lastTrack: null
    property real lastToastAt: -100000
    readonly property bool toastLive: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    function noteTrack() {
        const p = root.barPlayer;
        const cur = p ? { title: p.trackTitle, artist: p.trackArtist } : null;
        const now = Date.now();
        const d = root.trackToastDecision(root.lastTrack, cur, Config.settings.spotifyExtras.trackToast === true, SpotifyState.active, now, root.lastToastAt, 2000);
        root.lastTrack = d.remember;
        if (d.fire && root.toastLive) {
            root.lastToastAt = now;
            Quickshell.execDetached(root.trackToastArgs(cur, root.coverPath(p.trackArtUrl)));
        }
    }

    // --- Like from the bar (right-click on the centre text; Bar.qml owns the button) ---
    // Pure: the menu for the current song. loggedIn / hasTrack false give one disabled note.
    function likeMenuModel(hasTrack, loggedIn, liked, onToggle, onAdd) {
        if (!loggedIn)
            return [{ text: "Log in to Spotify first", enabled: false }];
        if (!hasTrack)
            return [{ text: "Nothing playing", enabled: false }];
        return [
            { text: liked ? "Unlike" : "Like", glyph: liked ? "\ue87d" : "\ue87e", action: onToggle },
            { text: "Add to playlist...", glyph: "\ue03b", action: onAdd }
        ];
    }
    // Like or unlike the song Spotify plays now; done(ok) after the answer
    function likeCurrent(liked, done) {
        const t = SpotifyState.track;
        if (!t || !t.uri)
            return;
        if (liked)
            SpotifyState.unlikeSong(t.uri, done);
        else
            SpotifyState.likeSong(t.uri, done);
    }
    // Asks Spotify whether the current song is liked, then calls ready(model) with the menu. onAdd() is the caller's:
    // it opens the Spotify drawer and calls spotifyPanel.toggleAddMode().
    function likeMenu(onAdd, ready) {
        const t = SpotifyState.track;
        if (!SpotifyState.loggedIn || !t || !t.uri) {
            ready(root.likeMenuModel(!!t && !!t.uri, SpotifyState.loggedIn, false, null, null));
            return;
        }
        SpotifyState.isLiked(t.uri, liked => ready(root.likeMenuModel(true, true, liked, () => root.likeCurrent(liked), onAdd)));
    }

    Timer {
        id: hideTimer
        interval: MenuStyle.barHideDelay
        onTriggered: {
            root.text = "";
            root.paused = false;
        }
    }
}
