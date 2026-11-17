pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Game mode, the Quickshell half. The Hyprland half (side-button binds, animations, the auto switch for steam_app windows)
// is in hypr/inputs.lua; it calls `qs ipc call gamemode set <true|false>`. Turning it on: caffeine on, Do Not Disturb on
// (critical toasts still show), and the programs in settings gameMode.pause are paused (SIGSTOP); turning it off puts caffeine
// and DND back to what they were BEFORE (a caffeine that was already on stays on) and resumes the paused programs.
// The state survives a Quickshell restart (qs-gamemode.json in XDG_RUNTIME_DIR, cleared at logout). The bar shows GAME while on.
// Under QS_NO_APPLY (tests) nothing is signalled: the argv lists are recorded in `signalLog`.
Singleton {
    id: root

    readonly property var cfg: Config.settings.gameMode
    property bool on: false
    property bool prevCaffeine: false
    property bool prevDnd: false
    property var paused: []                 // names that were really stopped, so they are resumed
    property var signalLog: []

    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || ""

    // ---- pure helpers ----

    // a program name safe to hand to pkill -x (comm names are at most 15 characters)
    function safeProgram(name) {
        return typeof name === "string" && /^[A-Za-z0-9][A-Za-z0-9._+-]{0,14}$/.test(name);
    }
    function programs(list) {
        const out = [];
        for (const n of Array.isArray(list) ? list : [])
            if (root.safeProgram(n) && out.indexOf(n) < 0)
                out.push(n);
        return out;
    }
    // what to put back when leaving: exactly what was saved when entering
    function restoreOf(saved) {
        return { caffeine: saved.caffeine === true, dnd: saved.dnd === true };
    }

    // ---- live part ----

    function set(want) {
        want = want === true;
        if (want === root.on)
            return;
        if (want) {
            root.prevCaffeine = Idle.caffeine;
            root.prevDnd = Config.settings.notifications.dnd === true;
            Idle.caffeine = true;
            Config.settings.notifications.dnd = true;
            const names = root.programs(root.cfg.pause);
            for (const n of names)
                root.signal("STOP", n);
            root.paused = names;
        } else {
            const back = root.restoreOf({ caffeine: root.prevCaffeine, dnd: root.prevDnd });
            Idle.caffeine = back.caffeine;
            Config.settings.notifications.dnd = back.dnd;
            for (const n of root.paused)
                root.signal("CONT", n);
            root.paused = [];
        }
        root.on = want;
        root.save();
    }
    function toggle() { root.set(!root.on); }

    function signal(sig, name) {
        const cmd = ["pkill", "-" + sig, "-x", name];
        if (Quickshell.env("QS_NO_APPLY"))
            root.signalLog = root.signalLog.concat([cmd.join(" ")]);
        else
            Quickshell.execDetached(cmd);
    }

    function save() {
        if (root.runDir === "")
            return;
        saved.on = root.on;
        saved.prevCaffeine = root.prevCaffeine;
        saved.prevDnd = root.prevDnd;
        saved.paused = JSON.stringify(root.paused);
    }

    GuardedFileView {
        id: store
        path: root.runDir !== "" ? root.runDir + "/qs-gamemode.json" : ""
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.on = saved.on;
            root.prevCaffeine = saved.prevCaffeine;
            root.prevDnd = saved.prevDnd;
            try { root.paused = root.programs(JSON.parse(saved.paused)); } catch (e) { root.paused = []; }
        }
        JsonAdapter {
            id: saved
            property bool on: false
            property bool prevCaffeine: false
            property bool prevDnd: false
            property string paused: "[]"
        }
    }
}
