// Pure-helper tests for UpdateState.qml (totals, summary text, JSON parsing, the terminal command). The runner sets
// QS_NO_APPLY, so the singleton's timer and Processes stay off and no tool runs. Run by scripts/run-interaction-tests.py.
import QtQuick
import Quickshell

ShellRoot {
    id: shell
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    Component.onCompleted: {
        const U = UpdateState;
        const J = JSON.stringify;
        shell.check("sumCounts adds the three sources", U.sumCounts({ pacman: 8, aur: 3, flatpak: 1 }) === 12);
        shell.check("sumCounts treats null and missing as 0", U.sumCounts({ pacman: null, aur: 2 }) === 2);
        shell.check("sumCounts of nothing is 0", U.sumCounts({}) === 0);
        shell.check("summary matches the spec line", U.summaryText({ pacman: 8, aur: 3, flatpak: 1 }) === "12 updates: 8 pacman, 3 AUR, 1 flatpak");
        shell.check("summary leaves out zero and null sources", U.summaryText({ pacman: 5, aur: 0, flatpak: null }) === "5 updates: 5 pacman");
        shell.check("summary of one says update", U.summaryText({ pacman: 0, aur: 1, flatpak: null }) === "1 update: 1 AUR");
        shell.check("summary of none says Up to date", U.summaryText({ pacman: 0, aur: null, flatpak: 0 }) === "Up to date");
        shell.check("no check yet: total 0 and Up to date", U.total === 0 && U.summary === "Up to date");

        const c = U.parseCounts('{"pacman": 3, "aur": null, "flatpak": 0, "error": ""}');
        shell.check("parseCounts keeps numbers and null", c !== null && c.pacman === 3 && c.aur === null && c.flatpak === 0 && c.error === "");
        shell.check("parseCounts rejects garbage", U.parseCounts("nope") === null && U.parseCounts("null") === null);
        shell.check("parseCounts turns a string count into null", U.parseCounts('{"pacman": "7"}').pacman === null);

        const n = U.parseNews(J([{ title: "A", date: "2026-06-01" }, { title: "", date: "x" }, { date: "y" }, { title: "B" }, 5, null]));
        shell.check("parseNews keeps titled items only", n.length === 2 && n[0].title === "A" && n[1].title === "B" && n[1].date === "");
        const nine = [];
        for (let i = 0; i < 9; i++)
            nine.push({ title: "t" + i, date: "d" });
        shell.check("parseNews caps at 5", U.parseNews(J(nine)).length === 5);
        shell.check("parseNews of garbage or a non-array is []", U.parseNews("<html>").length === 0 && U.parseNews('{"a":1}').length === 0);
        shell.check("a headline with markup stays the same string", U.parseNews(J([{ title: "<b>x</b> $(rm -rf ~)", date: "" }]))[0].title === "<b>x</b> $(rm -rf ~)");

        const script = "yay -Syu; echo; read -P 'Press Enter to close'";
        shell.check("updateCommand: kitty default", J(U.updateCommand("kitty", "--class")) === J(["kitty", "--class", "qs-dialog", "fish", "-c", script]));
        shell.check("updateCommand: foot", J(U.updateCommand("foot", "--app-id")) === J(["foot", "--app-id", "qs-dialog", "fish", "-c", script]));
        shell.check("updateCommand: empty flag leaves the window unnamed", J(U.updateCommand("foot", "")) === J(["foot", "fish", "-c", script]));
        shell.check("settings default to kitty --class", Config.settings.execCommands.terminal === "kitty" && Config.settings.execCommands.terminalClassFlag === "--class");
        U.refresh();
        shell.check("commandFor: system is yay -Syu, flatpak is flatpak update, all is both in one terminal",
            U.commandFor("system", "kitty", "--class").join("|").indexOf("yay -Syu;") > 0
            && U.commandFor("flatpak", "kitty", "--class").join("|").indexOf("flatpak update;") > 0
            && U.commandFor("all", "kitty", "--class").join("|").indexOf("yay -Syu; flatpak update;") > 0);
        shell.check("commandFor: an unknown kind is the system update, the window is named qs-dialog", U.commandFor("x", "kitty", "--class").join("|") === U.updateCommand("kitty", "--class").join("|") && U.commandFor("all", "kitty", "--class")[2] === "qs-dialog");
        U.pacman = 3; U.aur = 2; U.flatpak = 4;
        shell.check("countFor: system is pacman + AUR, flatpak is flatpak, all is the total", U.countFor("system") === 5 && U.countFor("flatpak") === 4 && U.countFor("all") === U.total);
        U.pacman = 2; U.aur = null; U.flatpak = null;
        shell.check("countFor: unknown (null) counts as 0", U.countFor("system") === 2 && U.countFor("flatpak") === 0);
        U.runUpdate();
        shell.check("refresh and runUpdate start nothing under QS_NO_APPLY", !U.active && !U.checking);
        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
