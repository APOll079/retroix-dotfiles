pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Games for the Games menu. The list comes from scripts/games.py (Steam library, Steam shortcuts,
// the Flatpak ids in settings.games.flatpakApps that are installed, and the "custom" entries below); the user's own entries and the hidden ids live in
// games.json in Quickshell's state dir (not the repo). The helper re-runs on open and whenever
// that file is saved, so adding or removing an entry shows up at once.
Singleton {
    id: root

    property var games: []                 // [{ id, title, source, launch, cwd, dir, art, lastPlayed }]
    property bool loaded: false
    property bool rerun: false

    readonly property var hidden: adapter.hidden
    readonly property var custom: adapter.custom
    readonly property string file: Quickshell.statePath("games.json")

    function refresh() {
        if (proc.running)
            root.rerun = true;
        else
            proc.running = true;
    }

    function isHidden(id) {
        return adapter.hidden.indexOf(id) !== -1;
    }

    function setHidden(id, hide) {
        const rest = adapter.hidden.filter(h => h !== id);
        adapter.hidden = hide ? rest.concat([id]) : rest;
    }

    // Add an entry of the user's own: { name, command, dir, cover }. A name that is taken gets
    // " (2)", " (3)", ... so an older entry is never replaced.
    function addCustom(entry) {
        let name = entry.name;
        for (let n = 2; adapter.custom.some(e => e.name === name); n++)
            name = entry.name + " (" + n + ")";
        adapter.custom = adapter.custom.concat([Object.assign({ lastPlayed: 0 }, entry, { name: name })]);
    }

    function removeCustom(name) {
        adapter.custom = adapter.custom.filter(e => e.name !== name);
    }

    // The command and environment a game is started with; pure. With MangoHud on (settings.games.mangohud):
    //   Steam and Steam shortcuts  steam steam://rungameid/<id> with MANGOHUD=1 in the environment (the game inherits it from Steam,
    //                              so it only takes effect when this start also starts Steam; a running Steam keeps its own environment)
    //   Flatpak games              flatpak run --env=MANGOHUD=1 <id>  (needs the MangoHud Flatpak extension)
    //   your own entries           the command line with `mangohud` put in front (skipped when it already starts with mangohud)
    function launchCommand(game, mangohud) {
        const cmd = Array.isArray(game.launch) ? Array.from(game.launch) : [String(game.launch)];
        if (!mangohud)
            return { command: cmd, environment: {} };
        if (game.source === "steam" || game.source === "shortcut")
            return { command: cmd, environment: { MANGOHUD: "1" } };
        if (game.source === "flatpak" && cmd[0] === "flatpak" && cmd[1] === "run")
            return { command: ["flatpak", "run", "--env=MANGOHUD=1"].concat(cmd.slice(2)), environment: {} };
        if (cmd[0] === "mangohud" || cmd.length === 0)
            return { command: cmd, environment: {} };
        return { command: ["mangohud"].concat(cmd), environment: {} };
    }

    function launch(game) {
        const c = root.launchCommand(game, Config.settings.games.mangohud === true);
        const spec = { command: c.command };
        if (c.environment.MANGOHUD)
            spec.environment = c.environment;
        if (game.cwd)
            spec.workingDirectory = game.cwd;
        Quickshell.execDetached(spec);
        // Own entries remember when they were last started (Steam keeps its own record)
        if (game.source === "custom")
            adapter.custom = adapter.custom.map(e => e.name === game.title ? Object.assign({}, e, { lastPlayed: Math.floor(Date.now() / 1000) }) : e);
    }

    // A scan that hangs (stale mount) is stopped after 30 s; onExited then starts any pending rerun
    Timer {
        id: watchdog
        interval: 30000
        running: proc.running
        onTriggered: {
            console.warn("scripts/games.py did not finish in 30 s; stopping it");
            proc.running = false;
        }
    }

    Process {
        id: proc
        command: ["python3", "-I", Quickshell.shellDir + "/scripts/games.py", "--custom", root.file, "--cache", Quickshell.statePath("games-cache.json"), "--flatpak", Array.from(Config.settings.games.flatpakApps).join(",")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.games = JSON.parse(text);
                } catch (e) {
                    console.warn("scripts/games.py gave no valid JSON: " + e);
                }
                root.loaded = true;
            }
        }
        // A refresh asked for during the run starts here: at stream end the process may still be
        // running, and setting running = true then did nothing (the rerun was lost)
        onExited: {
            if (root.rerun) {
                root.rerun = false;
                proc.running = true;
            }
        }
    }

    // GuardedFileView: a games.json that doesn't parse is kept as .bad-<time> and never overwritten
    GuardedFileView {
        path: root.file
        printErrors: false
        onSaved: root.refresh()
        JsonAdapter {
            id: adapter
            property var custom: []
            property var hidden: []
        }
    }
}
