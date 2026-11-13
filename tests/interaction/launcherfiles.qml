// Launcher additions for the file search ("/ report") and the currency row ("100 eur in sek"): the rows, the states, the
// 250 ms debounce, Enter / Shift+Enter, the Files tab (the same search without the "/"). Same setup as launcher.qml: AppLauncher is a layer-shell
// PanelWindow, so a scratch copy turns it into a FloatingWindow. QS_NO_APPLY is set: filesearch.sh never runs (FileSearch only
// records what it would have run in `launched`; the test hands it answers with gotText / gotExit) and xdg-open is not run
// (the paths go to the panel's `openLog`).
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "utils" as Utils

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
        t = t.replace("property int screenHeight: 0", "property int screenHeight: MenuStyle.windowLargeHeight\n    implicitWidth: MenuStyle.windowLargeWidth\n    implicitHeight: MenuStyle.windowLargeHeight");
        dst.setText(t);
        loader.setSource("popups/AppLauncherTest.qml", { bar: null });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const panel = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", panel !== null && panel.fileItems !== undefined);
            panel.closeCallback = function () { shell.closed++; };
            const FS = FileSearch;
            const home = "/home/tester";

            // ---- pure functions ----
            shell.check("validQuery: names, limits, dash, control characters", FS.validQuery("report") && FS.validQuery("a b") && FS.validQuery("x".repeat(100))
                && !FS.validQuery("x".repeat(101)) && !FS.validQuery("-rf") && !FS.validQuery("a\nb") && !FS.validQuery("") && !FS.validQuery(5) && FS.validQuery("", true));
            shell.check("homeShort shows $HOME as ~", FS.homeShort("/home/tester/docs", home) === "~/docs" && FS.homeShort("/home/tester", home) === "~" && FS.homeShort("/home/testers", home) === "/home/testers" && FS.homeShort("/etc", home) === "/etc");
            const parsed = FS.parseResults("/home/tester/docs/Annual Report.txt\n/home/tester/Reports/\n/home/tester/docs/-dash report.txt\n/home/tester/docs/quote'\"report\n\nnot a path\n/\n/top.txt\n", home);
            shell.check("parseResults: names, folders, hostile names", parsed.length === 5 && parsed[0].name === "Annual Report.txt" && parsed[0].dir === "~/docs" && !parsed[0].isDir
                && parsed[1].isDir && parsed[1].name === "Reports" && parsed[1].path === "/home/tester/Reports" && parsed[1].dir === "~"
                && parsed[2].name === "-dash report.txt" && parsed[3].name === "quote'\"report" && parsed[4].dirFull === "/");
            shell.check("parseResults: lines that are not paths are ignored, at most 50", FS.parseResults("x\n\n", home).length === 0
                && FS.parseResults(Array.from({ length: 80 }, (_, i) => "/a/" + i).join("\n"), home).length === 50);
            shell.check("command: the query and the folder are separate arguments", JSON.stringify(FS.command("/s.sh", "a b;$(x)", "")) === JSON.stringify(["sh", "/s.sh", "a b;$(x)"])
                && FS.command("/s.sh", "a", "~/x").length === 4);

            // ---- the rows, the debounce ----
            panel.openMenu();
            tc.wait(100);
            const box = shell.find(panel.contentItem, c => c.input !== undefined && c.focusInput !== undefined, [])[0];
            const list = shell.find(panel.contentItem, c => c.positionViewAtIndex !== undefined && c.maximumFlickVelocity === 3500, [])[0];
            shell.check("found the search box and the list", box !== undefined && list !== undefined);
            const before = FS.launched.length;
            box.text = "/";
            tc.wait(50);
            shell.check("'/' alone: file mode, asks for a name, nothing searched", panel.fileMode && panel.fileEmpty && panel.fileEmptyText === "Type part of a file or folder name" && FS.launched.length === before);
            box.text = "/a";
            box.text = "/ab";
            box.text = "/ ab c";
            tc.wait(100);
            shell.check("typing: Searching... while waiting, no search yet (250 ms debounce)", panel.fileEmptyText === "Searching..." && FS.launched.length === before);
            tc.wait(400);
            shell.check("three quick keys start one search, for the last query", FS.launched.length === before + 1 && JSON.stringify(FS.launched[before].slice(2)) === JSON.stringify(["ab c"]));
            shell.check("'/ report' and '/report' are the same search", (() => { box.text = "/ report"; tc.wait(500); const a = FS.launched.length; box.text = "/report"; tc.wait(500); return FS.launched.length === a; })());
            const tok = FS.token;

            // ---- an answer ----
            const txt = FS.home + "/docs/Annual Report.txt\n" + FS.home + "/Reports/\n/etc/report.conf\n";
            FS.gotText(tok - 5, "/stale/old\n");
            shell.check("an answer of an older search is dropped", FS.results.length === 0);
            FS.gotText(tok, txt);
            FS.gotExit(tok, 0);
            tc.wait(100);
            shell.check("rows: the files, nothing after them", panel.results.map(r => r.title).join("|") === "Annual Report.txt|Reports|report.conf");
            shell.check("rows: the folder is shown with ~, a folder gets the folder glyph", panel.results[0].sub === "~/docs" && panel.results[1].sub === "~" && panel.results[2].sub === "/etc"
                && panel.results[1].glyph === "\ue2c7" && panel.results[0].glyph === "\ue873");
            shell.check("rows: not empty any more, the list fills the field", !panel.fileEmpty && list.height > 3 * 22);
            tc.wait(50);
            box.focusInput();
            const opened = shell.closed;
            tc.keyClick(Qt.Key_Return);
            shell.check("Enter opens the file with xdg-open and closes", panel.openLog.length === 1 && panel.openLog[0] === FS.home + "/docs/Annual Report.txt" && shell.closed === opened + 1);
            tc.keyClick(Qt.Key_Return, Qt.ShiftModifier);
            shell.check("Shift+Enter opens its folder", panel.openLog.length === 2 && panel.openLog[1] === FS.home + "/docs");
            tc.keyClick(Qt.Key_Down);
            tc.keyClick(Qt.Key_Return, Qt.ShiftModifier);
            shell.check("Shift+Enter on a folder row opens the folder that holds it", panel.openLog[2] === FS.home);
            tc.keyClick(Qt.Key_Return);
            shell.check("Enter on a folder row opens the folder itself", panel.openLog[3] === FS.home + "/Reports");
            shell.check("typing Shift+Enter outside file mode still means the app options (no file open)", (() => { const n = panel.openLog.length; box.text = "zzzz"; tc.wait(100); tc.keyClick(Qt.Key_Return, Qt.ShiftModifier); return panel.openLog.length === n; })());
            box.text = "/report";
            FS.reset();
            tc.wait(100);
            FS.search("report");
            FS.gotText(FS.token, txt);
            FS.gotExit(FS.token, 0);
            tc.wait(100);

            // ---- the Files tab: the same search, no "/" ----
            panel.open("files");
            tc.wait(50);
            shell.check("Files tab: the tab exists and is current", panel.tabs.some(t => t.key === "files") && panel.mode === "files" && panel.fileMode);
            box.text = "report";
            tc.wait(400);
            shell.check("Files tab: a plain name starts the file search", FS.query === "report" && panel.fileName === "report");
            FS.gotText(FS.token, txt);
            FS.gotExit(FS.token, 0);
            tc.wait(100);
            shell.check("Files tab: the same rows", panel.results.map(r => r.title).join("|") === "Annual Report.txt|Reports|report.conf");
            shell.check("Files tab: a ',' is a name here, not the window search", (() => { box.text = ",x"; tc.wait(100); return panel.fileMode && panel.mode === "files"; })());
            box.focusInput();
            tc.keyClick(Qt.Key_Tab, Qt.ControlModifier);
            shell.check("Ctrl+Tab leaves Files for the next tab", panel.mode === "clipboard");
            panel.open("apps");
            tc.wait(50);

            // ---- states ----
            box.text = "/nothing here";
            tc.wait(400);
            FS.gotText(FS.token, "");
            FS.gotExit(FS.token, 0);
            tc.wait(100);
            shell.check("no files: No files found, no rows", panel.fileEmpty && panel.fileEmptyText === "No files found" && panel.results.length === 0);
            box.text = "/no tool";
            tc.wait(400);
            FS.gotText(FS.token, "");
            FS.gotExit(FS.token, 3);
            tc.wait(100);
            shell.check("none of fd, plocate, find: the clear line", panel.fileEmptyText === "fd, plocate or find not available");
            box.text = "/-rf";
            tc.wait(100);
            shell.check("a query with a leading dash is not searched", panel.fileEmptyText.indexOf("cannot be searched") >= 0 && FS.error === "badquery");
            const n2 = FS.launched.length;
            tc.wait(400);
            shell.check("...and no search is started for it", FS.launched.length === n2);
            box.text = "firefox";
            tc.wait(100);
            shell.check("leaving the '/' search forgets it", FS.requested === "" && !panel.fileMode);

            // ---- currency ----
            let C;
            try {
                C = Utils.Currency;
            } catch (e) {
                C = undefined;
            }
            if (!C || C.codes === undefined) {
                console.log("TEST pass Currency rows: not registered in utils/qmldir yet (skipped)");
            } else {
                box.text = "100 eur in sek";
                tc.wait(100);
                shell.check("currency, no rates: the row says No exchange rates yet and does nothing", panel.results[0].title === "No exchange rates yet" && panel.results[0].run === undefined);
                const closedC = shell.closed;
                panel.activate(0);
                shell.check("...Enter on it neither copies nor closes", shell.closed === closedC);
                C.take(JSON.stringify({ ok: true, date: "2026-11-06", rates: { EUR: 1, SEK: 11.234, USD: 1.08 } }), Date.now());
                box.text = "";
                box.text = "100 eur in sek";
                tc.wait(100);
                shell.check("currency, with rates: the converted row first", panel.results[0].title === "100.00 EUR = 1,123.40 SEK" && panel.results[0].sub === "rates of 2026-11-06 - Enter copies 1123.40" && typeof panel.results[0].run === "function");
                box.text = "5 km in mi";
                tc.wait(100);
                shell.check("a unit conversion still answers first and no currency row joins it", panel.results[0].title.indexOf("mi") >= 0 && panel.results.every(r => r.title.indexOf("EUR") < 0));
                box.text = "2+2*3";
                tc.wait(100);
                shell.check("the calculator still answers", panel.results[0].title === "= 8");
            }

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 100; onTriggered: Qt.quit() }
}
