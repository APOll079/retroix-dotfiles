pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Download-finished toast, for browser downloads only. Every 5 s scripts/downloads.sh lists the file names and sizes
// directly in ~/Downloads (hidden files and unfinished *.part / *.crdownload / *.tmp skipped; a file is never opened)
// and the browser partial files (*.part from Zen / Firefox, *.crdownload from Chromium-type apps). A file that was not
// there at start toasts only when it is "armed": a partial file seen in the last `partialPolls` polls has gone (the
// browser finished and renamed it), so uploads, unzips, copies and app saves into the folder never toast. A download
// that starts and ends between two polls shows no partial and does not toast (accepted). An armed file whose size
// stayed the same for two polls in a row raises one toast with Open and Show in folder:
// `notify-send -a Downloads -A default=Open -A folder="Show in folder" "Download finished" "<name>"`, run through sh so the
// chosen action can be read (name and folder are positional parameters, never script text).
// Settings group (missing = on): settings.downloads { enabled, intervalSeconds }.
// step() is a pure function of (state, files), so tests can drive it. Not started when QS_NO_APPLY is set.
Singleton {
    id: root

    readonly property var cfg: Config.settings.downloads || ({ enabled: true, intervalSeconds: 5 })
    readonly property bool active: Config.settingsLoaded && cfg.enabled !== false && !Quickshell.env("QS_NO_APPLY")
    readonly property int interval: Math.max(2, cfg.intervalSeconds > 0 ? cfg.intervalSeconds : 5) * 1000
    readonly property int stablePolls: 2          // equal sizes in a row before "finished"
    readonly property int partialPolls: 3         // how many polls a vanished partial file keeps arming new files
    readonly property string folder: Quickshell.env("HOME") + "/Downloads"

    property var tracked: newState()

    // ---- pure helpers ----

    function newState() { return { started: false, files: {}, partials: [] }; }

    // files: [{ name, size }] and partials: [names] from one poll. Returns { fire: [names], state }.
    // The first poll only records what is already there (those names never toast). After that a name's record is
    // { size, stable, toasted, base, armed }: the same size again adds one to `stable`, another size resets it,
    // `stable` reaching stablePolls toasts once, but only when `armed`. `armed` is set while a partial file from the
    // last partialPolls polls is gone now (a browser download just finished) and stays set; a rewrite of a toasted
    // file re-arms only from a new partial. A name that vanished is forgotten (it can toast again as a new download).
    function step(state, files, stablePolls, partials) {
        const first = !state.started;
        const prev = state.files;
        const now = (Array.isArray(partials) ? partials : []).filter(p => typeof p === "string");
        const hist = Array.isArray(state.partials) ? state.partials : [];
        let recentDone = false;
        for (const list of hist)
            for (const p of list)
                if (now.indexOf(p) < 0)
                    recentDone = true;
        const nextHist = [now].concat(hist).slice(0, root.partialPolls);
        const next = {};
        const fire = [];
        for (const f of files) {
            if (!f || typeof f.name !== "string" || f.name === "" || typeof f.size !== "number")
                continue;
            const old = prev[f.name];
            if (first) {
                next[f.name] = { size: f.size, stable: 0, toasted: false, base: true, armed: false };
                continue;
            }
            if (!old) {
                next[f.name] = { size: f.size, stable: 0, toasted: false, base: false, armed: recentDone };
                continue;
            }
            if (old.base) {
                // there before we started: never toasts, whatever happens to it, until the name vanishes
                next[f.name] = { size: f.size, stable: 0, toasted: false, base: true, armed: false };
                continue;
            }
            const rewritten = old.toasted && old.size !== f.size;
            const rec = { size: f.size, stable: old.size === f.size ? old.stable + 1 : 0, toasted: old.size === f.size ? old.toasted : false, base: false, armed: rewritten ? recentDone : (old.armed || recentDone) };
            if (rec.armed && !rec.toasted && rec.stable >= stablePolls && f.size > 0) {
                rec.toasted = true;
                fire.push(f.name);
            }
            next[f.name] = rec;
        }
        return { fire: fire, state: { started: true, files: next, partials: nextHist } };
    }

    // downloads.sh output -> [{ name, size }], null when it is not a listing (the poll failed). Takes the
    // { files, partials } object, and the old plain list (a stale script: no partials, so nothing toasts)
    function parseFiles(text) {
        try {
            const d = JSON.parse(text);
            const list = Array.isArray(d) ? d : (d && Array.isArray(d.files) ? d.files : null);
            return list ? list.filter(f => f && typeof f.name === "string" && typeof f.size === "number") : null;
        } catch (e) {
            return null;
        }
    }

    // downloads.sh output -> the partial file names ([] for the old plain list or anything unexpected)
    function parsePartials(text) {
        try {
            const d = JSON.parse(text);
            return d && !Array.isArray(d) && Array.isArray(d.partials) ? d.partials.filter(p => typeof p === "string") : [];
        } catch (e) {
            return [];
        }
    }

    // sh -c script: the chosen action id decides what opens; title, name and folder are positional parameters
    function toastCommand(name, folder) {
        return ["sh", "-c", 'a=$(notify-send -a Downloads -A default=Open -A folder="Show in folder" -- "$1" "$2"); case "$a" in default) xdg-open "$3/$2" ;; folder) xdg-open "$3" ;; esac', "sh", "Download finished", name, folder];
    }

    // ---- live part ----

    function toast(name) {
        Quickshell.execDetached(root.toastCommand(name, root.folder));
    }

    function poll() {
        if (!root.active || listProc.running)
            return;
        listProc.running = true;
    }

    Process {
        id: listProc
        command: ["sh", Quickshell.shellDir + "/scripts/downloads.sh", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = root.parseFiles(text);
                if (files === null)
                    return;                       // the listing failed: change nothing (an empty answer would make every old file look new)
                const r = root.step(root.tracked, files, root.stablePolls, root.parsePartials(text));
                root.tracked = r.state;
                for (const n of r.fire)
                    root.toast(n);
            }
        }
    }

    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }
}
