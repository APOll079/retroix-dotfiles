pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "utils/WallpaperJobs.js" as Jobs

// Wallpapers for the wallpaper browser. The images are the files in settings.json "wallpaper.folder"
// (default ~/Pictures/wallpapers, top level only). Picking one sets it live through hyprpaper's IPC
// (`hyprctl hyprpaper wallpaper 'MON,PATH,FIT'`) and saves it to wallpaper.json in Quickshell's
// state dir; at start the saved choice is set again (hyprpaper.conf is never touched, so the
// conf's wallpaper shows until then). QS_WALLPAPER_HYPRCTL replaces hyprctl (tests: a fake).
Singleton {
    id: root

    property var files: []                 // file names in the folder, sorted
    property bool loaded: false
    property bool folderMissing: false
    property bool folderSlow: false        // the folder listing timed out (dead mount?)
    property string status: ""             // last error from hyprpaper or the colour step, "" when fine
    // Transient, not urgent: what a Set is doing / just did (cleared a few seconds after it finishes)
    property string setInfo: ""
    property string colourInfo: ""
    readonly property string info: root.colourInfo !== "" ? root.colourInfo : root.setInfo

    readonly property string folder: {
        const f = (Config.settings.wallpaper && Config.settings.wallpaper.folder) || "~/Pictures/wallpapers";
        return f.startsWith("~/") ? Quickshell.env("HOME") + f.slice(1) : f;
    }
    readonly property var monitors: adapter.monitors   // { "DP-2": { path, fit } }
    readonly property string file: Quickshell.statePath("wallpaper.json")
    readonly property string hyprctl: Quickshell.env("QS_WALLPAPER_HYPRCTL") || "hyprctl"
    readonly property int maxTries: 30     // at start hyprpaper may not listen yet (or know a monitor yet): retry once a second
    readonly property int setTries: 4      // a Set from the browser: a few tries, then say which monitor failed

    property bool rerun: false
    property bool switchAfter: false
    property int tries: 0
    property int triesTotal: 1
    property var pending: []               // [[monitor, path, fit], ...] being set
    property var applied: ({})             // monitors hyprpaper accepted since start
    property bool restoring: false         // the current send is the start-up restore (quiet about unplugged outputs)
    property var setNames: []              // what the current user Set covers, for the feedback line
    property string setFit: ""
    property string setFile: ""

    function refresh() {
        if (lister.running)
            root.rerun = true;
        else
            lister.running = true;
    }
    // settings.json loads after this: list the right folder once it is known, and after a change
    onFolderChanged: root.refresh()

    function pathOf(name) {
        return root.folder + "/" + name;
    }

    // Monitors (output names) currently showing this file
    function shownOn(path) {
        return Object.keys(adapter.monitors).filter(m => adapter.monitors[m].path === path);
    }

    // Set `path` on each of `outputs` (names) with fit cover | contain | fill | tile, and remember it.
    // colours = also make the "wallpaper" theme from it and switch to it (done anyway while that
    // theme is the active one, so it keeps following the picture)
    function setWallpaper(path, outputs, fit, colours) {
        const next = Object.assign({}, adapter.monitors);
        for (const m of outputs)
            next[m] = { path: path, fit: fit };
        adapter.monitors = next;
        root.writeLock();
        root.restoring = false;
        root.setNames = outputs.slice();
        root.setFit = fit;
        root.setFile = path.split("/").pop();
        root.setInfo = "Setting " + root.setFile + " on " + outputs.join(", ") + "...";
        infoTimer.stop();
        root.send(outputs.map(m => [m, path, fit]), root.setTries);
        if (colours || Config.settings.currentTheme === "wallpaper")
            root.makeColours(path, colours === true);
    }

    function makeColours(path, switchTheme) {
        root.switchAfter = switchTheme;
        root.colourInfo = "Making colours...";
        colourInfoTimer.stop();
        colourer.command = ["python3", "-I", Quickshell.shellDir + "/theme/wallcolors.py", path, "--out", Config.wallPalette];
        colourer.running = false;
        colourer.running = true;
    }

    // hyprlock shows the same picture per monitor: hypr/hyprlock-wallpaper.conf holds one variable per
    // output ($wallpaper_DP_2 = /path), sourced by hyprlock.conf, which keeps wallpaper.png as the
    // fallback. Written (atomically) on every Set and at start. A "#" is doubled, hyprlang's escape.
    readonly property string lockFile: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/hyprlock-wallpaper.conf"
    function writeLock() {
        const args = [];
        for (const m of Object.keys(adapter.monitors)) {
            if (m === "" || !adapter.monitors[m].path)
                continue;
            args.push("$wallpaper_" + m.replace(/[^A-Za-z0-9]/g, "_") + " = " + adapter.monitors[m].path.replace(/#/g, "##"));
        }
        if (args.length === 0)
            return;
        lockWriter.command = ["sh", "-c", 'f=$1; shift; mkdir -p "$(dirname "$f")" && { echo "# Generated by Quickshell (WallpaperState.qml); sourced by hyprlock.conf"; printf "%s\\n" "$@"; } > "$f.tmp" && mv "$f.tmp" "$f"', "sh", root.lockFile].concat(args);
        lockWriter.running = false;
        lockWriter.running = true;
    }
    Process { id: lockWriter }

    // At start every saved monitor is tried, whatever Quickshell.screens says: right after login the
    // list can be incomplete (DP-1 there, DP-2 a moment later), and filtering by it once dropped DP-2 for
    // good. An output that is really unplugged just never answers; it burns its tries quietly (see
    // Jobs.reportable). A screen that shows up later is handled by onScreensChanged below.
    function restore() {
        root.writeLock();
        root.started = true;
        root.applied = {};
        const jobs = Jobs.restoreJobs(adapter.monitors, root.applied, [], [], true);
        console.log("[wallpaper] restore: " + (jobs.map(j => j[0]).join(", ") || "nothing saved") + " (screens now: " + root.screenList().join(", ") + ")");
        if (jobs.length > 0) {
            root.restoring = true;
            root.send(jobs, root.maxTries);
        }
    }

    function screenList() {
        return Quickshell.screens.map(s => s.name);
    }

    // A screen appeared after the restore started: set the saved wallpaper on it too
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!root.started)
                return;
            const jobs = Jobs.restoreJobs(adapter.monitors, root.applied, root.pending.map(j => j[0]), root.screenList(), false);
            console.log("[wallpaper] screens changed: " + root.screenList().join(", ") + (jobs.length > 0 ? " -> setting " + jobs.map(j => j[0]).join(", ") : ""));
            if (jobs.length > 0) {
                root.restoring = true;
                root.send(root.pending.concat(jobs), root.maxTries);
            }
        }
    }
    property bool started: false

    function send(jobs, tries) {
        retry.stop();
        root.pending = jobs;
        root.tries = tries;
        root.triesTotal = tries;
        root.status = "";
        console.log("[wallpaper] try 1/" + tries + ": " + jobs.map(j => j[0]).join(", "));
        setter.running = false;
        setter.running = true;
    }

    // Lists the folder: images only, top level, sorted by name
    Process {
        id: lister
        command: ["timeout", "10", "find", "-L", root.folder, "-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")",
            "-printf", "%f\\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(n => n !== "").sort((a, b) => a.localeCompare(b));
                root.loaded = true;
            }
        }
        onExited: code => {
            // 124 = timeout: a folder on a dead mount must not hang the listing
            root.folderSlow = code === 124;
            root.folderMissing = code !== 0 && code !== 124 && root.files.length === 0;
            if (root.rerun) {
                root.rerun = false;
                lister.running = true;
            }
        }
    }

    // One hyprctl call per monitor, all of them every time (a monitor that fails never blocks the
    // others), ~0.3 s apart: hyprpaper can answer "Invalid monitor" while it is still busy with the
    // first image or doesn't know the second monitor yet. Each failure comes back as "MON|message";
    // only those monitors are tried again. hyprctl splits the argument on every comma (no escape), so
    // a path with a comma goes through a comma-free symlink in Quickshell's cache dir.
    Process {
        id: setter
        command: ["sh", "-c", "hc=$1; lk=$2; shift 2; rc=0; first=1; while [ $# -ge 3 ]; do [ $first = 1 ] || sleep 0.3; first=0; p=$2; case $p in *,*) mkdir -p \"$lk\"; l=\"$lk/$(printf %s \"$p\" | md5sum | cut -c1-16).${p##*.}\"; ln -sfn \"$p\" \"$l\"; p=$l;; esac; out=$(\"$hc\" hyprpaper wallpaper \"$1,$p,$3\" 2>&1); st=$?; case $out in *rror*|*ouldn*|*ailed*) st=1;; esac; if [ $st -ne 0 ]; then printf '%s|%s\\n' \"$1\" \"$(printf %s \"$out\" | tr '\\n' ' ')\"; rc=1; fi; shift 3; done; exit $rc",
            "sh", root.hyprctl, Quickshell.cachePath("wallpaper-links")].concat([].concat(...root.pending))
        stdout: StdioCollector { id: setterOut }
        onExited: code => {
            const attempt = root.triesTotal - root.tries + 1;
            if (code === 0) {
                for (const j of root.pending)
                    root.markApplied(j[0], attempt, "ok");
                root.pending = [];
                root.finishSet();
                return;
            }
            // "DP-2|error: failed to set wallpaper: Invalid monitor" lines -> { "DP-2": "message" }
            const failed = Jobs.parseFailures(setterOut.text);
            const names = Object.keys(failed);
            for (const j of root.pending) {
                if (names.indexOf(j[0]) === -1)
                    root.markApplied(j[0], attempt, "ok");
                else
                    console.log("[wallpaper] " + j[0] + ": " + failed[j[0]] + " (try " + attempt + "/" + root.triesTotal + ")");
            }
            if (names.length > 0)
                root.pending = root.pending.filter(j => names.indexOf(j[0]) !== -1);
            else
                console.log("[wallpaper] hyprctl failed without a monitor message: hyprpaper not running? (try " + attempt + "/" + root.triesTotal + ")");
            if (root.tries > 1) {
                root.tries--;
                retry.restart();
            } else {
                const shown = Jobs.reportable(names, root.screenList(), root.restoring);
                console.log("[wallpaper] gave up on " + (names.join(", ") || "all") + " after " + root.triesTotal + " tries" + (shown.length < names.length ? " (not plugged in, quiet)" : ""));
                root.setInfo = "";
                if (names.length === 0)
                    root.status = "hyprpaper: not running";
                else if (shown.length > 0)
                    root.status = shown.map(n => n + ": " + failed[n].replace(/^error:\s*/i, "")).join("   ") + " (gave up after " + root.triesTotal + " tries)";
            }
        }
    }
    function markApplied(m, attempt, result) {
        const next = Object.assign({}, root.applied);
        next[m] = true;
        root.applied = next;
        console.log("[wallpaper] " + m + ": " + result + " (try " + attempt + "/" + root.triesTotal + ")");
    }
    // All pending monitors accepted: say so for a few seconds (not after the quiet start-up restore)
    function finishSet() {
        if (root.restoring || root.setNames.length === 0)
            return;
        const f = root.setFit;
        root.setInfo = "Set on " + root.setNames.join(", ") + " (" + f.charAt(0).toUpperCase() + f.slice(1) + ")";
        infoTimer.restart();
    }
    Timer {
        id: infoTimer
        interval: 3000
        onTriggered: root.setInfo = ""
    }
    Timer {
        id: colourInfoTimer
        interval: 3000
        onTriggered: root.colourInfo = ""
    }
    // Palette from the picture (theme/wallcolors.py); then Config reads it and, if asked, the theme switches
    Process {
        id: colourer
        stderr: StdioCollector { id: colourerErr }
        onExited: code => {
            if (code !== 0) {
                root.colourInfo = "";
                root.status = "colours: " + (colourerErr.text.trim().split("\n").pop() || "failed");
                return;
            }
            Config.reloadWallTheme();
            if (root.switchAfter)
                Config.settings.currentTheme = "wallpaper";
            root.colourInfo = "Theme: wallpaper";
            colourInfoTimer.restart();
        }
    }
    Timer {
        id: retry
        interval: 1000
        onTriggered: setter.running = true
    }

    // A wallpaper.json that doesn't parse is kept as .bad-<time> and never overwritten (GuardedFileView)
    GuardedFileView {
        path: root.file
        printErrors: false
        onLoaded: root.restore()
        JsonAdapter {
            id: adapter
            property var monitors: ({})
        }
    }
}
