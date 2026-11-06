// Fix my desktop panel (popups/FixPanel.qml) with real simulated clicks and keys: Restart -> ConfirmBar (verb Restart) -> Escape
// cancels and nothing ran -> Restart -> the verb runs exactly one id -> Enter does the same from the keyboard -> the Quickshell row
// is only text to copy (no button) -> Escape with no confirm closes. A scratch copy of the panel (PanelWindow -> FloatingWindow,
// layer-shell lines dropped) is loaded; QS_NO_APPLY is set, so run() only records the id in runLog and no script starts.
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
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }
    function buttons(win, text) {
        return shell.find(win.contentItem, c => c.visible && c.text === text && c.clicked !== undefined, []);
    }
    function confirmBars(win) {
        return shell.find(win.contentItem, c => c.visible && c.verb !== undefined && c.accept !== undefined, []);
    }

    FileView {
        id: src
        path: Quickshell.shellPath("popups/FixPanel.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/FixPanelTest.qml")
        blockWrites: true
    }

    Component.onCompleted: {
        let t = src.text();
        t = t.replace("PanelWindow {", "FloatingWindow {");
        t = t.replace(/\n    anchors \{[\s\S]*?\n    \}/, "");
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0).join("\n");
        t = t.replace("property int screenHeight: 0", "property int screenHeight: MenuStyle.windowHeight\n    implicitWidth: MenuStyle.windowWidth\n    implicitHeight: MenuStyle.windowHeight");
        dst.setText(t);
        loader.setSource("popups/FixPanelTest.qml", { bar: null, closeCallback: function () { shell.closed++; } });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const p = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", p !== null && p.confirmId !== undefined);
            p.openMenu();
            tc.wait(150);
            shell.check("four fixes, four Restart buttons, no confirm yet", p.fixes.map(f => f.id).join() === "pipewire,portals,hyprpaper,easyeffects" && shell.buttons(p, "Restart").length === 4 && shell.confirmBars(p).length === 0);
            shell.check("Quickshell is not a fix: no button for it, the command is shown to copy", p.fixes.every(f => f.id !== "quickshell") && p.quickshellCommand === "pkill quickshell; quickshell &"
                && shell.find(p.contentItem, c => c.visible && c.text === "pkill quickshell; quickshell &" && c.selectByMouse === true, []).length === 1);
            tc.mouseClick(shell.buttons(p, "Restart")[2]);
            tc.wait(100);
            const bars = shell.confirmBars(p);
            shell.check("Restart asks first: a ConfirmBar with the verb Restart naming hyprpaper, nothing ran", p.confirmId === "hyprpaper" && bars.length === 1 && bars[0].verb === "Restart" && bars[0].message.indexOf("hyprpaper") >= 0 && p.runLog.length === 0);
            shell.check("while asking the other Restart buttons are off", shell.buttons(p, "Restart").filter(b => b.enabled).length === 1);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Escape cancels the confirm, nothing ran, the panel stays open", p.confirmId === "" && p.runLog.length === 0 && shell.closed === 0);
            tc.mouseClick(shell.buttons(p, "Restart")[0]);
            tc.wait(100);
            tc.mouseClick(shell.find(p.contentItem, c => c.visible && c.text === "Cancel" && c.clicked !== undefined, [])[0]);
            tc.wait(100);
            shell.check("Cancel in the bar cancels too", p.confirmId === "" && p.runLog.length === 0);
            tc.mouseClick(shell.buttons(p, "Restart")[1]);
            tc.wait(100);
            tc.mouseClick(shell.confirmBars(p)[0].children.filter(c => c.text === "Restart")[0]);
            tc.wait(100);
            shell.check("the verb button runs exactly that id once", shell.js(p.runLog) === shell.js(["portals"]) && p.confirmId === "");
            p.cursor = 3;
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter asks for the cursor row (no run yet)", p.confirmId === "easyeffects" && p.runLog.length === 1);
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter again confirms: easyeffects ran", shell.js(p.runLog) === shell.js(["portals", "easyeffects"]));
            p.run("quickshell");
            p.run("pipewire; rm -rf x");
            shell.check("run() refuses an id that is not in the fixed list", p.runLog.length === 2);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Escape with no confirm calls the close callback once", shell.closed === 1);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
