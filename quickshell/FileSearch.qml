pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// File and folder NAME search for the launcher (its Files tab and "/ report" in Apps).
// search(q, folder) waits 250 ms after the last call (a newer query replaces the older one), then runs
// scripts/filesearch.sh <q> [folder] as the one and only Process (a running search is stopped first; the answer of a
// stopped one is dropped). The script picks fd, plocate or find, skips hidden files and folders, and prints up to 50 paths
// (a folder with a trailing slash). `results` is [{ path, name, dir, dirFull, isDir }] (dir has $HOME shown as ~).
// `error` is "" or "notool" (none of fd, plocate, find), "badfolder" (Look in is not a folder), "badquery".
// `searching` is true from search() until the answer arrives; `lastDone` once it has (an empty answer is an answer).
// parseResults / validQuery / command / homeShort are pure so tests can drive them. Not started when QS_NO_APPLY is set
// (the test harness): search() still debounces and records what it would have run in `launched`, but no Process starts;
// tests hand an answer to gotText() / gotExit().
Singleton {
    id: root

    readonly property bool active: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    readonly property int debounceMs: 250
    readonly property string script: Quickshell.shellDir + "/scripts/filesearch.sh"
    readonly property string home: Quickshell.env("HOME") || ""

    property var results: []
    property bool searching: false
    property bool lastDone: false
    property string error: ""
    property string query: ""              // what the current results / search are for
    property string folder: ""
    property var launched: []              // argv lists of every search started (tests read this)
    property int token: 0                  // bumped by every search() / stop(); an answer of an older token is dropped
    property string requested: ""          // "<name>\n<folder>" of the last search() (the same one again is ignored)
    property bool restart: false           // a search was running when a newer one came: start the newer one on exit

    // ---- pure helpers ----

    // A name to search for: 1 to 100 characters, no leading dash, no control characters (empty is allowed when `allowEmpty`). The script checks the same again.
    function validQuery(q, allowEmpty) {
        if (typeof q !== "string")
            return false;
        if (q === "")
            return allowEmpty === true;
        return q.length <= 100 && q[0] !== "-" && !/[\u0000-\u001f\u007f]/.test(q);
    }

    // "/home/me/docs" -> "~/docs", "/home/me" -> "~", anything else unchanged
    function homeShort(dir, home) {
        if (!home || home === "/")
            return dir;
        if (dir === home)
            return "~";
        return dir.startsWith(home + "/") ? "~" + dir.slice(home.length) : dir;
    }

    // Script output -> [{ path, name, dir, dirFull, isDir }]. A line that is not an absolute path is ignored; a trailing slash
    // marks a folder and is dropped from `path`. At most 50 rows.
    function parseResults(text, home) {
        const out = [];
        for (const line of String(text).split("\n")) {
            if (line.length < 2 || line[0] !== "/")
                continue;
            const isDir = line.endsWith("/");
            const path = isDir ? line.replace(/\/+$/, "") : line;
            if (path === "")
                continue;
            const cut = path.lastIndexOf("/");
            const dirFull = cut <= 0 ? "/" : path.slice(0, cut);
            out.push({ path: path, name: path.slice(cut + 1), dirFull: dirFull, dir: root.homeShort(dirFull, home), isDir: isDir });
            if (out.length >= 50)
                break;
        }
        return out;
    }

    // The argv for a search: the query and the folder are separate arguments, never part of a script text
    function command(script, q, folder) {
        const c = ["sh", script, q];
        if (folder)
            c.push(folder);
        return c;
    }

    // ---- state ----

    function search(q, dir) {
        const name = String(q === undefined ? "" : q).trim();
        const where = dir ? String(dir).trim() : "";
        const key = name + "\n" + where;
        // the same search again (the launcher rebuilds its list often): nothing to do
        if (key === root.requested)
            return;
        root.requested = key;
        root.query = name;
        root.folder = where;
        root.token++;
        root.results = [];
        root.lastDone = false;
        if (!root.validQuery(name, where !== "")) {
            debounce.stop();
            root.searching = false;
            root.error = "badquery";
            return;
        }
        root.error = "";
        root.searching = true;
        debounce.restart();
    }

    // Forget the running search (the launcher leaving the file search)
    function stop() {
        root.token++;
        debounce.stop();
        root.searching = false;
        root.restart = false;
        root.requested = "";
        if (proc.running)
            proc.running = false;
    }

    // Back to nothing (a new launcher open)
    function reset() {
        root.stop();
        root.results = [];
        root.query = "";
        root.folder = "";
        root.error = "";
        root.lastDone = false;
    }

    function launch() {
        const argv = root.command(root.script, root.query, root.folder);
        root.launched = root.launched.concat([argv]);
        if (!root.active)
            return;
        if (proc.running) {
            root.restart = true;           // onExited starts the newest query
            proc.running = false;
            return;
        }
        proc.job = root.token;
        proc.command = argv;
        proc.running = true;
    }

    // The answer of job `job` (a stopped or replaced search is ignored)
    function gotText(job, text) {
        if (job === root.token)
            root.results = root.parseResults(text, root.home);
    }

    function gotExit(job, code) {
        if (job !== root.token)
            return;
        root.error = code === 3 ? "notool" : code === 4 ? "badfolder" : code === 2 ? "badquery" : "";
        root.searching = false;
        root.lastDone = true;
    }

    Timer {
        id: debounce
        interval: root.debounceMs
        onTriggered: root.launch()
    }

    Process {
        id: proc
        property int job: 0
        stdout: StdioCollector {
            onStreamFinished: root.gotText(proc.job, text)
        }
        onExited: code => {
            if (root.restart) {
                root.restart = false;
                proc.job = root.token;
                proc.command = root.command(root.script, root.query, root.folder);
                proc.running = true;
                return;
            }
            root.gotExit(proc.job, code);
        }
    }
}
