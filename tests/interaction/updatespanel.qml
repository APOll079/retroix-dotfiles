// Updates panel with real simulated clicks and keys: the Update button is off with nothing to update, on with updates;
// the news and the "Read the news before updating" line show; Enter and the button close the panel (runUpdate is a
// no-op under QS_NO_APPLY, so no terminal opens); Esc closes. UpdatesPanel is a layer-shell PanelWindow and can't be
// created offscreen: like cleanuppanel.qml this loads a scratch copy (in the runner's scratch tree) with PanelWindow
// turned into FloatingWindow and the layer-shell lines dropped. Everything else is the real file.
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

    FileView {
        id: src
        path: Quickshell.shellPath("popups/UpdatesPanel.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/UpdatesPanelTest.qml")
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
    function buttons(win, text) {
        return shell.find(win.contentItem, c => c.visible && c.text === text && c.clicked !== undefined, []);
    }
    function texts(win) {
        return shell.find(win.contentItem, c => c.visible && typeof c.text === "string" && c.clicked === undefined, []).map(c => c.text);
    }

    Component.onCompleted: {
        let t = src.text();
        t = t.replace("PanelWindow {", "FloatingWindow {");
        t = t.replace(/\n    anchors \{[\s\S]*?\n    \}/, "");
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0).join("\n");
        t = t.replace("property int screenHeight: 0", "property int screenHeight: 500\n    implicitWidth: 640\n    implicitHeight: 520");
        dst.setText(t);
        loader.setSource("popups/UpdatesPanelTest.qml", { bar: null });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const panel = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", panel !== null);
            panel.closeCallback = function () { shell.closed++; };
            panel.openMenu();
            tc.wait(200);
            shell.check("Update is off before any update is known", shell.buttons(panel, "Update").length === 1 && !shell.buttons(panel, "Update")[0].enabled);
            shell.check("the Read-the-news line shows", shell.texts(panel).indexOf("Read the news before updating") >= 0);

            UpdateState.pacman = 8;
            UpdateState.aur = 3;
            UpdateState.flatpak = null;
            UpdateState.news = [{ title: "Manual intervention for <b>foo</b>", date: "2026-06-01" }];
            UpdateState.lastChecked = new Date();
            tc.wait(100);
            shell.check("Update is on with updates", shell.buttons(panel, "Update")[0].enabled);
            shell.check("the headline shows as plain text", shell.texts(panel).indexOf("Manual intervention for <b>foo</b>") >= 0);
            shell.check("a missing tool reads not installed", shell.texts(panel).indexOf("not installed") >= 0);
            shell.check("the status line has the summary", shell.texts(panel).some(s => s.indexOf("11 updates: 8 pacman, 3 AUR") === 0));
            tc.mouseClick(shell.buttons(panel, "Update")[0]);
            tc.wait(100);
            shell.check("the Update button closes the panel", shell.closed === 1);
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter does the same", shell.closed === 2);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Esc closes", shell.closed === 3);

            UpdateState.pacman = 0;
            UpdateState.aur = 0;
            tc.wait(100);
            shell.check("nothing to update: Up to date, Update off", shell.texts(panel).indexOf("Up to date") >= 0 && !shell.buttons(panel, "Update")[0].enabled);
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter with nothing to update does nothing", shell.closed === 3);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
