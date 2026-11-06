// Colour picker history: the pure parse / format / list functions of ColorHistory.qml, the saved file, and the panel
// (popups/ColorHistoryPanel.qml) with real clicks and keys: rows with a swatch, the hex and the rgb value, a click or Enter
// copies the hex (under QS_NO_APPLY only recorded in ColorHistory.copyLog, wl-copy never runs), Escape and a click outside
// close, "No colours yet" when empty. The panel is a layer-shell PanelWindow, so a scratch copy (in the runner's own
// scratch tree) turns it into a FloatingWindow; everything else is the real file.
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
        path: Quickshell.shellPath("popups/ColorHistoryPanel.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/ColorHistoryPanelTest.qml")
        blockWrites: true
    }
    FileView {
        id: saved
        path: Quickshell.statePath("color-history.json")
        blockLoading: true
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
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0).join("\n");
        t = t.replace("property int screenHeight: 0", "property int screenHeight: 0\n    implicitWidth: 2 * MenuStyle.windowWidth\n    implicitHeight: MenuStyle.windowHeight");
        dst.setText(t);
        loader.setSource("popups/ColorHistoryPanelTest.qml", { bar: null });
    }
    Loader { id: loader }
    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1500; running: true
        onTriggered: {
            const H = ColorHistory;
            // ---- pure ----
            shell.check("parseHex: with and without #, any case", H.parseHex("#A1B2C3") === "#a1b2c3" && H.parseHex("a1b2c3") === "#a1b2c3" && H.parseHex("  #a1b2c3\n") === "#a1b2c3");
            shell.check("parseHex: the short form is expanded", H.parseHex("#abc") === "#aabbcc");
            shell.check("parseHex: anything else is null", H.parseHex("") === null && H.parseHex("#12345") === null && H.parseHex("#gggggg") === null && H.parseHex("red") === null && H.parseHex(null) === null && H.parseHex("#a1b2c3; touch x") === null);
            shell.check("rgbText", H.rgbText("#a1b2c3") === "rgb(161, 178, 195)" && H.rgbText("#000000") === "rgb(0, 0, 0)" && H.rgbText("nope") === "");
            shell.check("entryFor: hex and rgb", JSON.stringify(H.entryFor("FFF")) === JSON.stringify({ hex: "#ffffff", rgb: "rgb(255, 255, 255)" }) && H.entryFor("x") === null);
            shell.check("withColor: newest first", H.withColor([{ hex: "#111111" }], "#222222").map(e => e.hex).join() === "#222222,#111111");
            shell.check("withColor: a colour picked again moves to the top, once", H.withColor([{ hex: "#111111" }, { hex: "#222222" }], "#222222").map(e => e.hex).join() === "#222222,#111111");
            shell.check("withColor: an invalid colour changes nothing", H.withColor([{ hex: "#111111" }], "oops").map(e => e.hex).join() === "#111111");
            let many = [];
            for (let i = 0; i < 25; i++)
                many = H.withColor(many, "#" + (i + 16).toString(16) + "0000");
            shell.check("the list keeps the last 20, newest first", many.length === 20 && many[0].hex === "#280000" && many[19].hex === "#150000" && many.every(e => /^#[0-9a-f]{6}$/.test(e.hex)));
            shell.check("clean: broken saved entries are dropped and rgb is rebuilt from the hex", JSON.stringify(H.clean([{ hex: "#ABCDEF", rgb: "junk" }, null, 5, { hex: "x" }, "#012345"])) === JSON.stringify([{ hex: "#abcdef", rgb: "rgb(171, 205, 239)" }, { hex: "#012345", rgb: "rgb(1, 35, 69)" }]));
            shell.check("copyCommand: wl-copy and the hex as one argument; invalid gives nothing", H.copyCommand("#A1B2C3").join("|") === "wl-copy|#a1b2c3" && H.copyCommand("a; rm -rf ~").length === 0);

            // ---- the panel, empty ----
            const p = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", p !== null && p.copied !== undefined);
            p.closeCallback = function () { shell.closed++; };
            H.clear();
            p.openMenu();
            tc.wait(200);
            const empty = shell.find(p.contentItem, c => c.objectName === "noColours", [])[0];
            shell.check("empty: No colours yet shows", empty !== undefined && empty.visible === true && empty.text === "No colours yet");
            tc.keyClick(Qt.Key_Escape);
            shell.check("Escape closes (the callback ran)", shell.closed === 1);

            // ---- with colours ----
            shell.check("add: a valid colour is stored", H.add("#A1B2C3") === true && H.add("#102030") === true && H.add("nope") === false);
            p.openMenu();
            tc.wait(200);
            shell.check("two rows, newest first", p.shown.length === 2 && p.shown[0].hex === "#102030");
            shell.check("the empty state is gone", empty.visible === false);
            const swatches = shell.find(p.contentItem, c => c.objectName === "swatch", []);
            shell.check("one swatch per row, filled with its colour", swatches.length === 2 && swatches.map(s => s.color.toString()).sort().join() === ["#102030", "#a1b2c3"].join());
            const rows = shell.find(p.contentItem, c => c.trailing !== undefined && c.text !== undefined && /^#/.test(c.text), []);
            shell.check("each row shows the hex and the rgb value", rows.length === 2 && rows.some(r => r.text === "#a1b2c3" && r.trailing === "rgb(161, 178, 195)"));
            tc.mouseClick(rows.find(r => r.text === "#a1b2c3"));
            shell.check("a click copies the hex and the status line says so", H.copyLog[H.copyLog.length - 1] === "#a1b2c3" && p.copied === "#a1b2c3");
            tc.keyClick(Qt.Key_Up);
            tc.keyClick(Qt.Key_Return);
            shell.check("Enter copies the selected row", H.copyLog[H.copyLog.length - 1] === "#102030");
            tc.keyClick(Qt.Key_Down);
            tc.keyClick(Qt.Key_Return);
            shell.check("Down then Enter copies the second row", H.copyLog[H.copyLog.length - 1] === "#a1b2c3" && p.cursor === 1);
            shell.check("the panel stays open after a copy", shell.closed === 1);
            tc.keyClick(Qt.Key_Escape);
            shell.check("Escape closes again", shell.closed === 2);

            tc.mouseClick(p.contentItem, 5, 5);
            shell.check("a click outside the frame closes", shell.closed === 3);

            // ---- saved file ----
            tc.wait(300);
            saved.reload();
            let j = null;
            try { j = JSON.parse(saved.text()); } catch (e) { }
            shell.check("color-history.json holds the list", j !== null && Array.isArray(j.colors) && j.colors.length === 2 && j.colors[0].hex === "#102030");
            console.log("TEST done failures=" + shell.failures);
            Qt.quit();
        }
    }
}
