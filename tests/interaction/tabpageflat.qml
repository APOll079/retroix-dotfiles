// Interaction test for TabPage's flat mode (the launcher's Clipboard tab): no page frame and no padding, the content
// fills the whole area; the normal mode keeps its inset. Run by scripts/run-interaction-tests.py (see menurow.qml
// for why the component is loaded by path).
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property int winW: 300
    readonly property int winH: 160
    readonly property int boxW: 140
    readonly property int boxH: 120
    function asVar(o: var): var {
        return o;
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
                id: normal
                Component.onCompleted: setSource("popups/TabPage.qml", { width: shell.boxW, height: shell.boxH, tabsShown: false })
            }
            Loader {
                id: flat
                x: shell.boxW + 10
                Component.onCompleted: setSource("popups/TabPage.qml", { width: shell.boxW, height: shell.boxH, tabsShown: false, flat: true })
            }
            Timer {
                interval: 600; running: true
                onTriggered: {
                    const n = shell.asVar(normal.item), f = shell.asVar(flat.item);
                    const nb = shell.asVar(n.children[n.children.length - 1]), fb = shell.asVar(f.children[f.children.length - 1]);
                    shell.check("TabPage: the normal page insets its content", nb.x > 0 && nb.y > 0 && nb.width < shell.boxW);
                    shell.check("TabPage: flat content starts at 0,0 and fills the area", fb.x === 0 && fb.y === 0 && fb.width === shell.boxW && fb.height === shell.boxH);
                    shell.check("TabPage: flat draws no page frame", f.children[0].visible === false && n.children[0].visible === true);
                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
