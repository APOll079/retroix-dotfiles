// Screenshot History filter box: Escape clears the typed text first, a second Escape closes (contract: search boxes clear, then
// close). Also the button labels: Trash (was Delete), Prev / Next. The panel lists a folder, so the scratch copy (inside the
// runner's own scratch tree) points it at an empty scratch folder instead of the real screenshots folder, and turns the
// layer-shell PanelWindow into a FloatingWindow; everything else is the real file.
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
        path: Quickshell.shellPath("popups/ScreenshotPanel.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/ScreenshotPanelTest.qml")
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
        t = t.replace('Quickshell.env("HOME") + "/screenshots"', 'Quickshell.cachePath("no-shots-here")');
        t = t.replace("property int screenHeight: 0", "property int screenHeight: 700\n    implicitWidth: 1000\n    implicitHeight: 700");
        dst.setText(t);
        loader.setSource("popups/ScreenshotPanelTest.qml", { bar: null });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const p = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", p !== null && p.confirmDelete !== undefined);
            p.closeCallback = function () { shell.closed++; };
            p.openMenu();
            tc.wait(200);
            const box = shell.find(p.contentItem, c => c.input !== undefined && c.focusInput !== undefined, [])[0];
            shell.check("found the filter box", box !== undefined);
            const labels = shell.find(p.contentItem, c => c.clicked !== undefined && typeof c.text === "string", []).map(c => c.text);
            shell.check("the action buttons: Copy, Open, Trash, Folder (no Delete), Prev, Next", ["Copy", "Open", "Trash", "Folder", "Prev", "Next"].every(l => labels.indexOf(l) >= 0) && labels.indexOf("Delete") < 0);
            const confirm = shell.find(p.contentItem, c => c.verb !== undefined && c.accept !== undefined, [])[0];
            shell.check("the confirm's verb stays Move to Trash", confirm !== undefined && confirm.verb === "Move to Trash");

            box.focusInput();
            box.text = "abc";
            tc.wait(50);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Escape in the filter box clears the text first", box.text === "" && shell.closed === 0);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("the next Escape closes", shell.closed === 1);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
