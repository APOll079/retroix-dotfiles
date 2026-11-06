// The Start menu's Programs button (settings.ui.cascadingStart): with the setting off (the default) there is no Programs button
// and no cascade is loaded; with it on the button is the first in the first row, a click opens the cascade, a second click
// closes it, launching an app closes the Start menu, and closing the Start menu closes the cascade. StartMenu and PopupCascade are
// PopupWindows, which can't be created offscreen: like updatespanel.qml this loads scratch copies (in the runner's scratch tree)
// with PopupWindow turned into FloatingWindow and the anchor / grab lines dropped; the Start menu's copy loads the cascade's copy.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    property int closed: 0
    property var launched: []
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function asVar(o: var): var {
        return o;
    }
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }
    function strip(t) {
        t = t.split("PopupWindow {").join("FloatingWindow {");
        return t.split("\n").filter(l => l.indexOf("anchor.") < 0 && l.indexOf("grabFocus") < 0).join("\n");
    }

    FileView {
        id: startSrc
        path: Quickshell.shellPath("popups/StartMenu.qml")
        blockLoading: true
    }
    FileView {
        id: startDst
        path: Quickshell.shellPath("popups/StartMenuTest.qml")
        blockWrites: true
    }
    FileView {
        id: casSrc
        path: Quickshell.shellPath("popups/PopupCascade.qml")
        blockLoading: true
    }
    FileView {
        id: casDst
        path: Quickshell.shellPath("popups/PopupCascadeTest.qml")
        blockWrites: true
    }

    Component.onCompleted: {
        // a FloatingWindow is visible from the start, a PopupWindow is not
        casDst.setText(shell.strip(casSrc.text()).replace("FloatingWindow {\n    id: root", "FloatingWindow {\n    id: root\n    visible: false"));
        // Config.qml (not part of this change) does not have settings.ui.cascadingStart yet, so the copy takes the switch as a
        // plain property; the real line is checked below to read the setting with === true (missing or false = off)
        startDst.setText(shell.strip(startSrc.text()).replace('source: "PopupCascade.qml"', 'source: "PopupCascadeTest.qml"')
            .replace("readonly property bool cascading: Config.settings.ui.cascadingStart === true", "property bool cascading: false"));
        loader.setSource("popups/StartMenuTest.qml", { bar: null });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1500; running: true
        onTriggered: {
            const menu = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", menu !== null);
            menu.closeCallback = function () { shell.closed++; };
            const programs = () => shell.find(menu.contentItem, c => c.text === "Programs" && c.clicked !== undefined, [])[0] || null;
            const firstRow = text => shell.find(menu.contentItem, c => c.text === text && c.clicked !== undefined, [])[0];

            // off (the default)
            shell.check("the real file reads settings.ui.cascadingStart with === true, so a missing or false setting is off", startSrc.text().indexOf("readonly property bool cascading: Config.settings.ui.cascadingStart === true") >= 0 && menu.cascading === false);
            menu.visible = true;
            tc.wait(200);
            shell.check("off: no Programs button, no cascade", (programs() === null || !programs().visible) && menu.cascadeItem() === null);
            shell.check("off: the other buttons are all still there", ["Files", "Settings", "Terminal", "Power", "Services", "Network", "Keys", "Colours", "Default apps", "Troubleshoot", "Login report", "Clean up"].every(t => firstRow(t) !== undefined));

            // on
            menu.cascading = true;
            tc.wait(400);
            const c = shell.asVar(menu.cascadeItem());
            shell.check("on: the cascade is loaded", c !== null);
            shell.check("on: the Programs button shows, left of Files in the same row", programs() !== null && programs().visible && programs().x < firstRow("Files").x && programs().parent === firstRow("Files").parent);
            c.source = [
                { id: "ff", name: "Firefox", icon: "", categories: ["Network", "WebBrowser"], execute: function () { shell.launched = shell.launched.concat(["ff"]); } },
                { id: "code", name: "Code", icon: "", categories: ["Development"], execute: function () { shell.launched = shell.launched.concat(["code"]); } }
            ];
            tc.wait(100);
            tc.mouseClick(programs());
            shell.check("a click on Programs opens the cascade", c.visible === true);
            shell.check("the Programs button shows as pressed while it is open", programs().checked === true);
            tc.mouseClick(programs());
            tc.wait(200);
            shell.check("a second click closes it", c.visible === false);
            tc.mouseClick(programs());
            tc.wait(300);
            c.hoverCat(1);
            tc.wait(100);
            c.launch(0);
            tc.wait(100);
            shell.check("launching an app runs it and closes the Start menu (closeCallback)", shell.launched.join() === "ff" && shell.closed === 1 && !c.visible);
            tc.mouseClick(programs());
            tc.wait(300);
            menu.closeMenu();
            tc.wait(100);
            shell.check("closing the Start menu closes the cascade", !c.visible && !menu.visible);

            // back off
            menu.cascading = false;
            tc.wait(300);
            shell.check("off again: the Programs button is gone and the cascade is unloaded", (programs() === null || !programs().visible) && menu.cascadeItem() === null);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
