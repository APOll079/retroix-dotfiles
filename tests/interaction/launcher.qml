// Launcher (AppLauncher.qml) additions: kill by name (parse / match / safety functions with fixtures, then the ConfirmBar flow
// with real keys), the calculator history, the emoji search, Escape out of the Hidden list, the Clipboard right-click menu.
// AppLauncher is a layer-shell PanelWindow and can't be created offscreen, so this writes a scratch copy of it (inside the runner's own
// scratch tree) with PanelWindow turned into FloatingWindow and the layer-shell lines dropped; everything else is the real file.
// QS_NO_APPLY is set: no tool runs (no procs.py, no cliphist, no kill): confirmKill() works on the fresh read `testProcs` and records the
// pids it would hand to endtask.sh in `endLog`.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    property int closed: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function asVar(o: var): var {
        return o;
    }
    function js(v) { return JSON.stringify(v); }

    FileView {
        id: src
        path: Quickshell.shellPath("popups/AppLauncher.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/AppLauncherTest.qml")
        blockWrites: true
    }

    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }

    Component.onCompleted: {
        let t = src.text();
        t = t.replace("PanelWindow {", "FloatingWindow {");
        t = t.replace(/\n    anchors \{[\s\S]*?\n    \}/, "");
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0 && l.indexOf("margins.top") < 0).join("\n");
        t = t.replace("property int screenHeight: 0", "property int screenHeight: 700\n    implicitWidth: 900\n    implicitHeight: 700");
        dst.setText(t);
        loader.setSource("popups/AppLauncherTest.qml", { bar: null });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    readonly property string procsText: JSON.stringify({
        cpu: 1, self: 900, groups: [
            { name: "zen", count: 3, cpu: 1, mem: 3000000000, mine: true, pids: [2001, 2002, 2003], core: "" },
            { name: "zenity", count: 1, cpu: 0, mem: 20000000, mine: true, pids: [2100], core: "" },
            { name: "quickshell", count: 1, cpu: 1, mem: 400000000, mine: true, pids: [1500], core: "the bar and every menu go away until it is restarted" },
            { name: "Xorg", count: 1, cpu: 0, mem: 90000000, mine: false, pids: [700], core: "" },
            { name: "procs.py", count: 1, cpu: 0, mem: 30000000, mine: true, pids: [900], core: "" },
            { name: "mixed", count: 3, cpu: 0, mem: 1000, mine: true, pids: [900, 1, -1, 0, 3.5, "7", 3300], core: "" },
            { name: "", count: 1, cpu: 0, mem: 5, mine: true, pids: [3400], core: "" },
            { name: "fish", count: 1, cpu: 0, mem: 8000000, mine: true, pids: [3500], core: "" }
        ]
    })

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const panel = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", panel !== null && panel.killQuery !== undefined);
            panel.closeCallback = function () { shell.closed++; };

            // ---- pure functions ----
            shell.check("killQuery: kill alone, kill + word, case, spaces", panel.killQuery("kill") === "" && panel.killQuery("kill zen") === "zen" && panel.killQuery("KILL  Zen ") === "Zen");
            shell.check("killQuery: other words are not kill queries", panel.killQuery("killer") === null && panel.killQuery("skill") === null && panel.killQuery("") === null && panel.killQuery("kil") === null);
            const p = panel.parseProcs(shell.procsText + "\n");
            shell.check("parseProcs reads the groups and the helper's own pid", p !== null && p.self === 900 && p.groups.length === 8);
            shell.check("parseProcs of junk is null", panel.parseProcs("") === null && panel.parseProcs("oops") === null && panel.parseProcs("{}") === null && panel.parseProcs("[]") === null);
            const m = panel.killMatches(p.groups, p.self, "zen");
            shell.check("killMatches: name contains, biggest memory first", m.map(x => x.name).join() === "zen,zenity");
            shell.check("killMatches: other users' groups are never listed", panel.killMatches(p.groups, p.self, "xorg").length === 0);
            shell.check("killMatches: procs.py's own pid is never offered, its group goes away", panel.killMatches(p.groups, p.self, "procs").length === 0);
            const mixed = panel.killMatches(p.groups, p.self, "mixed");
            shell.check("killMatches: only integer pids above 1, own pid removed", mixed.length === 1 && shell.js(mixed[0].pids) === "[3300]");
            shell.check("killMatches: a group with no name is skipped", panel.killMatches(p.groups, p.self, "").every(x => x.name !== ""));
            shell.check("killMatches: no needle lists the biggest first, at most 8", (() => {
                const all = panel.killMatches(p.groups, p.self, "");
                return all.length <= 8 && all[0].name === "zen" && all[1].name === "quickshell";
            })());
            shell.check("killMatches keeps the core effect", panel.killMatches(p.groups, p.self, "quickshell")[0].core.indexOf("the bar") === 0);
            shell.check("killMatches survives junk", panel.killMatches(null, 0, "x").length === 0 && panel.killMatches([null, 5, { name: "a" }], 0, "").length === 0);
            shell.check("killPids: the fresh read's pids for that exact name", shell.js(panel.killPids(p.groups, p.self, "zen")) === "[2001,2002,2003]");
            shell.check("killPids: a name that is gone gives []", panel.killPids(p.groups, p.self, "firefox").length === 0 && panel.killPids(p.groups, p.self, "").length === 0);
            shell.check("killPids: never procs.py's own pid, never another user's group", panel.killPids(p.groups, p.self, "procs.py").length === 0 && panel.killPids(p.groups, p.self, "Xorg").length === 0);
            shell.check("killMessage: ordinary and core", panel.killMessage({ name: "zen", count: 3, core: "" }).indexOf("End zen (3 processes)?") === 0
                && panel.killMessage({ name: "quickshell", count: 1, core: "x goes" }) === "quickshell is a core process: x goes. End anyway?");
            shell.check("validPid", panel.validPid(2) && !panel.validPid(1) && !panel.validPid(0) && !panel.validPid(-1) && !panel.validPid(2.5) && !panel.validPid("5") && !panel.validPid(null));

            // ---- the kill rows and the confirm, with real keys ----
            panel.openMenu();
            tc.wait(100);
            const box = shell.find(panel.contentItem, c => c.input !== undefined && c.focusInput !== undefined, [])[0];
            shell.check("found the search box", box !== undefined);
            panel.killGroups = p.groups;
            panel.killSelf = p.self;
            panel.killLoadedAt = 1;
            box.text = "kill zen";
            tc.wait(100);
            shell.check("kill zen lists the matching groups with their memory", panel.results.map(r => r.title).join() === "zen,zenity" && panel.results[0].trailing === "2.8 GB");
            shell.check("the kill list shows no confirm yet", panel.killAsk === null);
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter asks (nothing ended)", panel.killAsk !== null && panel.killAsk.name === "zen" && panel.endLog.length === 0);
            shell.check("the question is a ConfirmBar with the verb End task", shell.find(panel.contentItem, c => c.visible && c.verb === "End task" && c.accept !== undefined, []).length === 1);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Esc cancels the question, the list stays, the launcher stays open", panel.killAsk === null && panel.results.length === 2 && shell.closed === 0 && panel.endLog.length === 0);
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            // the processes changed between the question and the answer: 2002 is gone, 2004 is new
            panel.testProcs = JSON.stringify({ self: 900, groups: [{ name: "zen", count: 3, cpu: 0, mem: 1, mine: true, pids: [2001, 2003, 2004], core: "" }] });
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter ends the group with the pids re-read now, not the ones from the question", shell.js(panel.endLog) === "[[2001,2003,2004]]");
            shell.check("the launcher closes after ending", shell.closed === 1);

            // already gone: nothing is sent
            panel.endLog = [];
            box.text = "kill zen";
            tc.wait(50);
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            panel.testProcs = JSON.stringify({ self: 900, groups: [] });
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            shell.check("a group that is already gone sends nothing", panel.endLog.length === 0);

            // core: End anyway
            box.text = "kill quick";
            tc.wait(50);
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            shell.check("a core process asks with End anyway", panel.killAsk !== null && panel.killAsk.core !== "" && shell.find(panel.contentItem, c => c.visible && c.verb === "End anyway" && c.accept !== undefined, []).length === 1);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(50);
            shell.check("Esc backs out of the core question", panel.killAsk === null && panel.endLog.length === 0);
            box.text = "kill";
            tc.wait(50);
            shell.check("kill alone lists the biggest", panel.results.length >= 3 && panel.results[0].title === "zen");
            box.text = "kill zen";
            tc.wait(50);
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            box.text = "kill ze";
            tc.wait(50);
            shell.check("typing again drops an open question", panel.killAsk === null);
            box.text = "";

            // ---- calculator history ----
            CalcHistory.entries = [{ value: "4", query: "2+2" }, { value: "3.1069 mi", query: "5 km in mi" }];
            box.text = "=";
            tc.wait(100);
            shell.check("= alone lists the history: value as the title, the query below", panel.results.length === 2 && panel.results[0].title === "4" && panel.results[0].sub === "2+2");
            box.text = "hist";
            tc.wait(100);
            shell.check("hist lists the history too, then apps", panel.results.length >= 2 && panel.results[0].title === "4");
            CalcHistory.entries = [];
            box.text = "=";
            tc.wait(100);
            shell.check("an empty history says so and has nothing to run", panel.results.length === 1 && panel.results[0].run === undefined);
            box.text = "";

            // ---- emoji ----
            box.text = ":rocket";
            tc.wait(100);
            shell.check(": and a word lists emoji, the rocket first, name after the character", panel.results.length >= 1 && panel.results[0].title.indexOf("rocket") > 0 && panel.results[0].title.length > "rocket".length + 2);
            box.text = ":qzxwv";
            tc.wait(100);
            shell.check("no emoji match gives an empty list", panel.results.length === 0);
            box.text = "";

            // ---- Escape steps out of the Hidden list ----
            panel.category = "hidden";
            panel.rebuild();
            box.focusInput();
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Esc leaves the Hidden list first, the launcher stays open", panel.category === "all" && shell.closed === 1);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("the next Esc closes", shell.closed === 2);

            // ---- Clipboard right-click ----
            panel.mode = "clipboard";
            panel.clipLines = [{ id: "7", text: "hello", ext: "", info: "" }, { id: "8", text: "world", ext: "", info: "" }];
            panel.rebuild();
            tc.wait(100);
            const menus = panel.data.filter(o => o && o.openAt !== undefined);
            shell.check("the options menu exists", menus.length === 1);
            panel.openOptionsAt(0);
            tc.wait(100);
            shell.check("a Clipboard row opens a one-entry menu: Delete", menus[0].model.length === 1 && menus[0].model[0].text === "Delete");
            panel.closeOptions();

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
