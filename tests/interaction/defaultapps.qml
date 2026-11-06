// Default apps: DefaultApps.qml pure functions (parse, ids, flat rows) and the panel with fixture categories: Make default on a
// row records exactly (key, id) once, the current default has no button, Up / Down skip headers and the current default, Enter
// applies, Escape closes. Scratch copy of the panel (PanelWindow -> FloatingWindow) like cleanuppanel.qml. QS_NO_APPLY is set:
// makeDefault() only records in setLog, no xdg tool runs. scripts/defaultapps.sh is tested in tests/scripts-r4b.py.
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

    FileView {
        id: src
        path: Quickshell.shellPath("popups/DefaultAppsPanel.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/DefaultAppsPanelTest.qml")
        blockWrites: true
    }

    readonly property string fixture: JSON.stringify([
        { key: "browser", label: "Web browser", current: "firefox.desktop", candidates: [{ id: "firefox.desktop", name: "Firefox" }, { id: "zen.desktop", name: "Zen\u0001 Browser" }] },
        { key: "video", label: "Video player", current: "", candidates: [{ id: "vlc.desktop", name: "VLC" }, { id: "bad id.desktop", name: "x" }] },
        { key: "editor", label: "Text editor", current: "nope", candidates: [] },
        { key: "alien", label: "Other", current: "", candidates: [] }
    ])

    Component.onCompleted: {
        let t = src.text();
        t = t.replace("PanelWindow {", "FloatingWindow {");
        t = t.replace(/\n    anchors \{[\s\S]*?\n    \}/, "");
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0).join("\n");
        t = t.replace("property int screenHeight: 0", "property int screenHeight: MenuStyle.windowHeight\n    implicitWidth: MenuStyle.windowWidth\n    implicitHeight: MenuStyle.windowHeight");
        dst.setText(t);
        loader.setSource("popups/DefaultAppsPanelTest.qml", { bar: null, closeCallback: function () { shell.closed++; } });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const D = DefaultApps;
            const cats = D.parse(shell.fixture);
            shell.check("parse: known kinds only, bad ids dropped, control characters cleaned", cats.length === 3 && cats[0].candidates[1].name === "Zen Browser" && cats[1].candidates.length === 1 && cats[2].current === "");
            shell.check("parse of junk is []", D.parse("").length === 0 && D.parse("{}").length === 0 && D.parse("oops").length === 0);
            shell.check("validId follows the script's rule", D.validId("a.desktop") && D.validId("org.kde.kate.desktop") && !D.validId("a") && !D.validId("-a.desktop") && !D.validId("a b.desktop")
                && !D.validId("a;b.desktop") && !D.validId("../a.desktop") && !D.validId("") && !D.validId(null));
            shell.check("currentName: the Name= of the current default, none set when empty", D.currentName(cats[0]) === "Firefox" && D.currentName(cats[1]) === "none set");
            const rows = D.flatRows(cats);
            shell.check("flatRows: head, then candidates, an explanatory row for a kind without any", rows.length === 7);
            shell.check("pickable skips heads, the current default and the empty note", shell.js(D.pickable(rows)) === shell.js([2, 4]));

            const panel = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", panel !== null && panel.listRows !== undefined);
            panel.visible = true;
            D.take(shell.fixture);
            tc.wait(200);
            shell.check("the cursor starts on the first application that is not a default", panel.cursor === 2);
            shell.check("the current default has no Make default button: two buttons for two other applications", shell.buttons(panel, "Make default").length === 2);
            tc.keyClick(Qt.Key_Down);
            shell.check("Down moves to the next application, skipping the head row", panel.cursor === 4);
            tc.keyClick(Qt.Key_Down);
            shell.check("Down at the end stays", panel.cursor === 4);
            tc.keyClick(Qt.Key_Up);
            tc.keyClick(Qt.Key_Return);
            shell.check("Enter makes the cursor row the default: exactly (browser, zen.desktop) recorded", shell.js(D.setLog) === shell.js([{ key: "browser", id: "zen.desktop" }]));
            tc.mouseClick(shell.buttons(panel, "Make default")[1]);
            tc.wait(100);
            shell.check("clicking the other button records (video, vlc.desktop)", shell.js(D.setLog) === shell.js([{ key: "browser", id: "zen.desktop" }, { key: "video", id: "vlc.desktop" }]));
            shell.check("makeDefault refuses a bad key or id", D.makeDefault("alien", "a.desktop") === false && D.makeDefault("browser", "a;rm.desktop") === false && D.setLog.length === 2);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Escape calls the close callback once", shell.closed === 1);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
