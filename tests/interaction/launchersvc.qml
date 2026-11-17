// Launcher "/svc" (services by name): the rows per service state, the verb and prefix filters, the second Enter, and that a
// run only records its argv under QS_NO_APPLY (a fake list stands in for ServiceWatch's `dinitctl --user list`; the real
// dinitctl is never started). Same scratch copy of AppLauncher as launcher.qml (PanelWindow -> FloatingWindow).
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

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const panel = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", panel !== null && panel.serviceItems !== undefined);
            panel.closeCallback = function () { shell.closed++; };
            ServiceWatch.prev = [
                { name: "spotifyd", state: "running", failed: false, info: "pid: 11" },
                { name: "solaar", state: "stopped", failed: false, info: "" },
                { name: "broken", state: "stopped", failed: true, info: "exit status 1" },
                { name: "bad name; rm -rf", state: "running", failed: false, info: "" }
            ];
            const titles = rest => panel.serviceItems(rest).map(i => i.title).join("|");
            shell.check("bare /svc lists every safe service with its actions (a running one: Restart and Stop)", titles("") === "Restart spotifyd|Stop spotifyd|Start solaar|Start broken");
            shell.check("a name start filters", titles("spo") === "Restart spotifyd|Stop spotifyd" && titles("SO") === "Start solaar");
            shell.check("a trailing verb keeps only that action", titles("spo stop") === "Stop spotifyd" && titles("stop") === "Stop spotifyd" && titles("sol start") === "Start solaar");
            shell.check("a verb that does not fit the state shows nothing", titles("solaar stop") === "" && titles("spotifyd start") === "");
            shell.check("a service with an unsafe name is never listed", titles("bad") === "");
            shell.check("the sub line says Running / Stopped / Failed", panel.serviceItems("").map(i => i.sub).join() === "Running,Running,Stopped,Failed");
            shell.check("the rows are glyph rows with a key for arming", panel.serviceItems("spo")[0].key === "svc-restart-spotifyd" && panel.serviceItems("spo")[0].glyph !== undefined);

            // ---- the real flow through the search box ----
            panel.open("apps");
            tc.wait(100);
            const box = shell.find(panel.contentItem, c => c.input !== undefined && c.focusInput !== undefined, [])[0];
            shell.check("the search box exists", box !== undefined);
            box.focusInput();
            box.text = "/svc spo";
            tc.wait(150);
            shell.check("typing /svc spo: svcMode on, not the file search, two rows", panel.svcMode === true && panel.fileMode === false && panel.results.length === 2);
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("the first Enter only arms (nothing recorded, launcher stays open)", panel.confirmKey === "svc-restart-spotifyd" && panel.svcLog.length === 0 && shell.closed === 0 && panel.results[0].title.indexOf("now? Enter again") >= 0);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Escape disarms and the launcher stays open", panel.confirmKey === "" && panel.svcLog.length === 0 && shell.closed === 0);
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("the second Enter records exactly one restart and closes", panel.svcLog.join() === "dinitctl --user restart spotifyd" && shell.closed === 1);
            shell.check("the stop was announced to ServiceWatch (no toast)", ServiceWatch.expected["spotifyd"] !== undefined);
            panel.open("apps");
            tc.wait(100);
            box.focusInput();
            box.text = "/ notes";
            tc.wait(150);
            shell.check("/ name is still the file search", panel.svcMode === false && panel.fileMode === true);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
