// Games view (GamesView.qml, the Games tab and the Games menu): the button row that appears after a click keeps the grid the
// same size, Remove asks first (ConfirmBar, verb Remove; Enter accepts, Escape cancels, Back and moving drop it), the Back
// button has its glyph. GamesState.removeCustom would save games.json and that starts the real games.py scan (it reads the
// Steam folders), so the scratch copy of the file records the removal in `removedLog` instead; GamesState.games is a fixture.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
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
        path: Quickshell.shellPath("popups/GamesView.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/GamesViewTest.qml")
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

    FloatingWindow {
        id: win
        visible: true
        implicitWidth: 640
        implicitHeight: 520
        color: Config.colors.base
        Loader {
            id: loader
            anchors.fill: parent
        }
    }

    Component.onCompleted: {
        let t = src.text();
        t = t.replace("GamesState.removeCustom(g.title);", "root.removedLog = root.removedLog.concat([g.title]);");
        t = t.replace("    property var nameInput: null\n", "    property var nameInput: null\n    property var removedLog: []\n");
        dst.setText(t);
        loader.setSource("popups/GamesViewTest.qml", {});
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const v = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", v !== null && v.doRemove !== undefined);
            GamesState.games = [
                { id: "c1", title: "My Game", source: "custom", launch: "true", cwd: "", dir: "/nonexistent", art: "", lastPlayed: 0 },
                { id: "s1", title: "Steam One", source: "steam", launch: "true", cwd: "", dir: "", art: "", lastPlayed: 0 }
            ];
            GamesState.loaded = true;
            tc.wait(200);
            const fields = shell.find(v, c => c.padding === 2 && c.clip === true, []);
            const gridBox = fields[0];
            const h0 = gridBox.height;
            shell.check("the grid starts with a size", h0 > 100);
            v.cursor = 0;
            v.optionsFor = GamesState.games[0];
            tc.wait(100);
            shell.check("showing the game's buttons does not change the grid's size", gridBox.height === h0);
            shell.check("the Back button has a glyph", shell.find(v, c => c.visible && c.text === "Back" && c.glyph !== undefined && c.glyph !== "", []).length === 1);
            const remove = shell.find(v, c => c.visible && c.text === "Remove" && c.clicked !== undefined, [])[0];
            shell.check("Remove is there for a custom game", remove !== undefined);
            tc.mouseClick(remove);
            tc.wait(100);
            const bars = shell.find(v, c => c.visible && c.verb === "Remove" && c.accept !== undefined, []);
            shell.check("Remove asks first: a ConfirmBar with the verb Remove, nothing removed", v.confirmRemove && bars.length === 1 && v.removedLog.length === 0 && bars[0].message.indexOf("My Game") >= 0);
            shell.check("the grid keeps its size while asking", gridBox.height === h0);
            shell.check("Escape (goBack) cancels the question and keeps the buttons", v.goBack() === true && !v.confirmRemove && v.optionsFor !== null && v.removedLog.length === 0);
            tc.mouseClick(shell.find(v, c => c.visible && c.text === "Remove" && c.clicked !== undefined, [])[0]);
            tc.wait(100);
            shell.check("Cancel in the bar cancels", (() => {
                const cancel = shell.find(v, c => c.visible && c.text === "Cancel" && c.clicked !== undefined, [])[0];
                tc.mouseClick(cancel);
                return !v.confirmRemove && v.removedLog.length === 0;
            })());
            tc.mouseClick(shell.find(v, c => c.visible && c.text === "Remove" && c.clicked !== undefined, [])[0]);
            tc.wait(100);
            v.activateKey({ modifiers: 0 });
            tc.wait(100);
            shell.check("Enter accepts: that game is removed, the buttons go", shell.js(v.removedLog) === shell.js(["My Game"]) && !v.confirmRemove && v.optionsFor === null);
            v.optionsFor = GamesState.games[0];
            v.confirmRemove = true;
            v.move(1);
            shell.check("moving the cursor drops the question", !v.confirmRemove && v.optionsFor === null);
            v.optionsFor = GamesState.games[1];
            tc.wait(100);
            shell.check("a Steam game shows no Remove", shell.find(v, c => c.visible && c.text === "Remove", []).length === 0);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
