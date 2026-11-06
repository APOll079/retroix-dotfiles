// Interaction test for PopupMenuBody's optional title strip: empty = nothing changes, set = an accent strip
// above the rows that elides a long title without widening the menu; a click on it emits escaped(), a click on
// a row still picks. Run by scripts/run-interaction-tests.py (see components.qml for how these files work).
// The bodies are loaded by path: a new test file sits outside quickshell/, where qmllint can't resolve
// `import "popups"`; the runner copies the file next to popups/, so the path resolves at run time.
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    property int escapes: 0
    property int picks: 0
    readonly property int winW: 600
    readonly property int winH: 200
    readonly property int gap: 10
    readonly property int colX: 200
    readonly property int rowCount: 3
    readonly property string longTitle: "A very very long song name that cannot possibly fit in the menu 한국어 노래 제목이 아주 길다 (Remastered 2011) [Live at Somewhere]"
    readonly property var entries: [{ text: "Play" }, { text: "Add to queue" }, { text: "Like" }]
    function asVar(o: var): var {
        return o;
    }
    // the title Text inside a body's strip (null when it has none)
    function findText(item: var): var {
        for (const c of item.children)
            for (const g of c.children)
                if (g.truncated !== undefined)
                    return g;
        return null;
    }
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    FloatingWindow {
        implicitWidth: shell.winW; implicitHeight: shell.winH
        Rectangle {
            anchors.fill: parent
            color: Config.colors.base
            Loader {
                id: plain
                x: shell.gap; y: shell.gap
                Component.onCompleted: setSource("popups/PopupMenuBody.qml", { model: shell.entries })
            }
            Loader {
                id: titled
                x: shell.colX; y: shell.gap
                Component.onCompleted: setSource("popups/PopupMenuBody.qml", { model: shell.entries, title: "Short" })
            }
            Loader {
                id: longOne
                x: shell.colX * 2; y: shell.gap
                Component.onCompleted: setSource("popups/PopupMenuBody.qml", { model: shell.entries, title: shell.longTitle })
            }
            Connections {
                target: shell.asVar(titled.item)
                function onEscaped() { shell.escapes++; }
                function onPicked() { shell.picks++; }
            }
            TestCase { id: tc; name: "sim"; when: false }
            Timer {
                interval: 900; running: true
                onTriggered: {
                    const p = shell.asVar(plain.item), t = shell.asVar(titled.item), l = shell.asVar(longOne.item);
                    const base = shell.rowCount * MenuStyle.rowHeight + 2 * MenuStyle.frameInset;
                    shell.check("PopupMenuBody: empty title keeps the old height (rows + frame only)", p.implicitHeight === base);
                    shell.check("PopupMenuBody: empty title shows no strip", shell.findText(p) === null || shell.findText(p).visible === false);
                    shell.check("PopupMenuBody: a title adds exactly MenuStyle.titleHeight", t.implicitHeight === base + MenuStyle.titleHeight);
                    shell.check("PopupMenuBody: a long title does not widen the menu", l.implicitWidth === p.implicitWidth && l.width === p.width);
                    const lt = shell.findText(l);
                    shell.check("PopupMenuBody: a long title elides", lt !== null && lt.truncated === true);
                    const st = shell.findText(t);
                    shell.check("PopupMenuBody: a short title does not elide", st !== null && st.truncated === false);

                    tc.mouseClick(t, t.width / 2, MenuStyle.frameInset + MenuStyle.titleHeight / 2);
                    shell.check("PopupMenuBody: a click on the strip emits escaped once and picks nothing", shell.escapes === 1 && shell.picks === 0);
                    tc.mouseClick(t, t.width / 2, MenuStyle.frameInset + MenuStyle.titleHeight + MenuStyle.rowHeight / 2);
                    shell.check("PopupMenuBody: a click on a row still picks it (and does not escape)", shell.picks === 1 && shell.escapes === 1);

                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
