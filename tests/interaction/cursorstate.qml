// CursorState.qml (the Themes menu's cursor and icon pickers): the pure checks and parsers, the two dropdown models, and the
// shared menu body with a real click on a theme and on a size. Under QS_NO_APPLY nothing runs: the script calls are only
// recorded in CursorState.log, so no gsettings / hyprctl is ever touched. scripts/appearance.sh itself is tested with fakes
// by tests/scripts-r4d.py.
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property int winSize: 300
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

    FloatingWindow {
        implicitWidth: shell.winSize; implicitHeight: shell.winSize
        Rectangle {
            anchors.fill: parent
            color: Config.colors.base
            Loader {
                id: bodyLoad
                x: 10; y: 10
                Component.onCompleted: setSource("popups/PopupMenuBody.qml", { model: [] })
            }
            TestCase { id: tc; name: "sim"; when: false }
            Timer {
                interval: 900; running: true
                onTriggered: {
                    const C = CursorState;
                    // pure
                    shell.check("validName: plain names pass", C.validName("posy-black") && C.validName("Bibata_Modern.Ice"));
                    shell.check("validName: hostile names fail", !["", "a b", "x;y", "$(id)", "`id`", "-rf", ".hidden", "a/b", "x'y", null, 5].some(n => C.validName(n)));
                    shell.check("validSize: 24 / 32 / 48 only", C.validSize(24) && C.validSize(32) && C.validSize(48) && !C.validSize(16) && !C.validSize("24"));
                    shell.check("parseList: keeps valid names, drops hostile ones", JSON.stringify(C.parseList('["a","b c","-x","ok.1"]')) === '["a","ok.1"]');
                    shell.check("parseList: not a list is null", C.parseList("nope") === null && C.parseList("{}") === null);
                    shell.check("parseCursor: theme and size", JSON.stringify(C.parseCursor('{"theme":"posy","size":32}')) === '{"theme":"posy","size":32}');
                    shell.check("parseCursor: unknown size falls back to 24, hostile theme to empty", JSON.stringify(C.parseCursor('{"theme":"a b","size":7}')) === '{"theme":"","size":24}');
                    shell.check("parseIcons: theme", C.parseIcons('{"theme":"Papirus"}').theme === "Papirus" && C.parseIcons('{"theme":"x y"}').theme === "");
                    shell.check("labels: default when unknown", C.cursorLabel() === "Cursor: default" && C.iconsLabel() === "Icons: default");

                    // setters validate and record
                    C.log = [];
                    shell.check("setCursor: a hostile name is refused and nothing is run", C.setCursor("x;y", 24) === false && C.setCursor("posy", 20) === false && C.log.length === 0);
                    shell.check("setIcons: a hostile name is refused", C.setIcons("$(id)") === false && C.log.length === 0);
                    shell.check("setCursor: runs set-cursor with the name and size as separate arguments", C.setCursor("Bibata", 32) && JSON.stringify(C.log[0]) === '["set-cursor","Bibata","32"]');
                    shell.check("setCursor: the labels follow", C.cursorLabel() === "Cursor: Bibata" && C.cursorSize === 32);
                    shell.check("setIcons: runs set-icons", C.setIcons("Papirus") && JSON.stringify(C.log[1]) === '["set-icons","Papirus"]' && C.iconsLabel() === "Icons: Papirus");

                    // models
                    C.cursors = [];
                    C.icons = [];
                    shell.check("models: nothing installed gives one disabled line each", C.cursorModel().length === 1 && C.cursorModel()[0].enabled === false && C.iconsModel()[0].enabled === false);
                    C.cursors = ["Adwaita", "Bibata"];
                    C.icons = ["Papirus", "hicolor"];
                    const cm = C.cursorModel();
                    shell.check("cursorModel: two themes, a separator, three sizes", cm.length === 6 && cm[2].separator === true && cm[3].text === "Size 24");
                    shell.check("cursorModel: the current theme and size carry a check", cm[1].checked === true && cm[0].checked === false && cm[4].checked === true && cm[3].checked === false);

                    // a real click in the menu body
                    C.log = [];
                    shell.asVar(bodyLoad.item).model = C.cursorModel();
                    tc.wait(100);
                    const rowsOf = text => shell.find(shell.asVar(bodyLoad.item), c => c.visible && c.text === text && c.clicked !== undefined, []);
                    const adw = shell.asVar(rowsOf("Adwaita")[0] || null);
                    shell.check("menu: the theme rows are there", adw !== null);
                    if (adw) {
                        tc.mouseClick(adw, 20, 5);
                        tc.wait(100);
                        shell.check("click on a theme: set-cursor with the current size", JSON.stringify(C.log) === '[["set-cursor","Adwaita","32"]]');
                    }
                    const sz = shell.asVar(rowsOf("Size 48")[0] || null);
                    shell.check("menu: the size rows are there", sz !== null);
                    if (sz) {
                        tc.mouseClick(sz, 20, 5);
                        tc.wait(100);
                        shell.check("click on a size: set-cursor again with that size", C.log.length === 2 && JSON.stringify(C.log[1]) === '["set-cursor","Adwaita","48"]');
                    }
                    C.log = [];
                    shell.asVar(bodyLoad.item).model = C.iconsModel();
                    tc.wait(100);
                    const pap = shell.asVar(rowsOf("hicolor")[0] || null);
                    if (pap) {
                        tc.mouseClick(pap, 20, 5);
                        tc.wait(100);
                    }
                    shell.check("click on an icon theme: set-icons", JSON.stringify(C.log) === '[["set-icons","hicolor"]]');
                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
