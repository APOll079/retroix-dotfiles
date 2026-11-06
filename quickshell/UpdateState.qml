pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Pending updates (pacman, AUR, flatpak) and the newest Arch news, for the Start menu's "Updates (N)" row, the dot
// on the Start button and the Updates panel. scripts/updates.sh does the looking (read-only; a missing tool gives
// null); runUpdate() opens the configured terminal on `yay -Syu` (the same shape as ServicesPanel.dialogCommand).
// Checks once 60 s after start and then hourly. Not started when QS_NO_APPLY is set (the test harness), so tests never
// run a real tool. Nothing here installs anything: the update itself happens in the terminal, by hand.
Singleton {
    id: root

    readonly property bool active: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    readonly property int firstDelay: 60000
    readonly property int interval: 3600000
    readonly property string script: Quickshell.shellDir + "/scripts/updates.sh"

    property var pacman: null          // number, or null when the tool is missing / failed
    property var aur: null
    property var flatpak: null
    property string error: ""
    property var news: []              // [{ title, date }], newest first, at most 5
    property bool checking: false
    property var lastChecked: null     // a Date, or null before the first check
    property bool firstDone: false

    readonly property int total: sumCounts({ pacman: pacman, aur: aur, flatpak: flatpak })
    readonly property string summary: summaryText({ pacman: pacman, aur: aur, flatpak: flatpak })

    // ---- pure helpers ----

    // Sum of the counts; null / missing / negative count as 0
    function sumCounts(c) {
        let n = 0;
        for (const k of ["pacman", "aur", "flatpak"]) {
            const v = c[k];
            if (typeof v === "number" && v > 0)
                n += v;
        }
        return n;
    }

    // "12 updates: 8 pacman, 3 AUR, 1 flatpak"; "1 update: 1 pacman"; "Up to date" for none
    function summaryText(c) {
        const total = sumCounts(c);
        if (total === 0)
            return "Up to date";
        const parts = [];
        for (const p of [["pacman", "pacman"], ["aur", "AUR"], ["flatpak", "flatpak"]]) {
            const v = c[p[0]];
            if (typeof v === "number" && v > 0)
                parts.push(v + " " + p[1]);
        }
        return total + (total === 1 ? " update: " : " updates: ") + parts.join(", ");
    }

    // updates.sh output -> { pacman, aur, flatpak, error }, or null when it is not that JSON
    function parseCounts(text) {
        try {
            const d = JSON.parse(text);
            if (d === null || typeof d !== "object")
                return null;
            const num = v => (typeof v === "number" && v >= 0) ? Math.floor(v) : null;
            return { pacman: num(d.pacman), aur: num(d.aur), flatpak: num(d.flatpak), error: typeof d.error === "string" ? d.error : "" };
        } catch (e) {
            return null;
        }
    }

    // updates.sh news output -> [{ title, date }] (at most 5, strings only), [] for anything else
    function parseNews(text) {
        try {
            const d = JSON.parse(text);
            if (!Array.isArray(d))
                return [];
            return d.filter(i => i && typeof i.title === "string" && i.title !== "").slice(0, 5).map(i => ({ title: i.title, date: typeof i.date === "string" ? i.date : "" }));
        } catch (e) {
            return [];
        }
    }

    // The terminal command for an update: [terminal, classFlag, "qs-dialog", "fish", "-c", "<cmd>; echo; read ..."].
    // Pure. classFlag "" = don't name the window.
    function terminalCommand(terminal, classFlag, cmd) {
        return [terminal].concat(classFlag !== "" ? [classFlag, "qs-dialog"] : []).concat(["fish", "-c", cmd + "; echo; read -P 'Press Enter to close'"]);
    }

    function updateCommand(terminal, classFlag) {
        return terminalCommand(terminal, classFlag, "yay -Syu");
    }
    function flatpakCommand(terminal, classFlag) {
        return terminalCommand(terminal, classFlag, "flatpak update");
    }
    function allCommand(terminal, classFlag) {
        return terminalCommand(terminal, classFlag, "yay -Syu; flatpak update");
    }
    // kind: "system" (pacman + AUR through yay), "flatpak", or "all" (both, one after the other)
    function commandFor(kind, terminal, classFlag) {
        return kind === "flatpak" ? flatpakCommand(terminal, classFlag) : kind === "all" ? allCommand(terminal, classFlag) : updateCommand(terminal, classFlag);
    }
    // How many updates a kind covers (the buttons are off when it is 0)
    function countFor(kind) {
        const n = v => typeof v === "number" ? v : 0;
        return kind === "flatpak" ? n(root.flatpak) : kind === "system" ? n(root.pacman) + n(root.aur) : root.total;
    }

    // ---- live part ----

    // A refresh asked while one is running is not dropped (it would read the counts from before the update that
    // just finished): it runs again as soon as the first one is done
    property bool again: false
    function refresh() {
        if (!root.active)
            return;
        if (root.checking) {
            root.again = true;
            return;
        }
        root.checking = true;
        countsProc.running = true;
    }

    // Opens the terminal on an update (kind: "system" = yay -Syu, "flatpak", "all"); the counts are re-read when it closes
    function runUpdate(kind) {
        if (!root.active || termProc.running)
            return;
        termProc.command = root.commandFor(kind || "system", Config.settings.execCommands.terminal, Config.settings.execCommands.terminalClassFlag);
        termProc.running = true;
    }

    Process {
        id: countsProc
        command: ["sh", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = root.parseCounts(text);
                if (c === null) {
                    root.error = "Could not read the update counts";
                    return;
                }
                root.pacman = c.pacman;
                root.aur = c.aur;
                root.flatpak = c.flatpak;
                root.error = c.error;
            }
        }
        onExited: newsProc.running = true
    }

    Process {
        id: newsProc
        command: ["sh", root.script, "news"]
        stdout: StdioCollector {
            onStreamFinished: root.news = root.parseNews(text)
        }
        onExited: {
            root.checking = false;
            root.lastChecked = new Date();
            if (root.again) {
                root.again = false;
                root.refresh();
            }
        }
    }

    Process {
        id: termProc
        onExited: {
            root.refresh();
            settleTimer.restart();
        }
    }
    // checkupdates / yay read their own package databases: once more a little after the terminal closed, in case the
    // first read raced the last writes
    Timer {
        id: settleTimer
        interval: 4000
        onTriggered: root.refresh()
    }

    Timer {
        interval: root.firstDone ? root.interval : root.firstDelay
        running: root.active
        repeat: true
        onTriggered: {
            root.firstDone = true;
            root.refresh();
        }
    }
}
