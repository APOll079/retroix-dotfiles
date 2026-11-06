// Interaction test for MenuRow hover: an enabled row lights under the mouse, a disabled one does not.
// Run by scripts/run-interaction-tests.py (see components.qml for how these files work).
// The rows are loaded by path: a new test file sits outside quickshell/, where qmllint can't resolve
// `import "popups"`; the runner copies the file next to popups/, so the path resolves at run time.
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property int winW: 300
    readonly property int winH: 120
    readonly property int rowW: 200
    readonly property int gap: 10
    readonly property int offY: 50
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
                id: onLoad
                x: shell.gap; y: shell.gap
                Component.onCompleted: setSource("popups/MenuRow.qml", { width: shell.rowW, text: "Enabled" })
            }
            Loader {
                id: offLoad
                x: shell.gap; y: shell.offY
                Component.onCompleted: setSource("popups/MenuRow.qml", { width: shell.rowW, text: "Disabled", enabled: false })
            }
            TestCase { id: tc; name: "sim"; when: false }
            Timer {
                interval: 900; running: true
                onTriggered: {
                    const onRow = shell.asVar(onLoad.item), offRow = shell.asVar(offLoad.item);
                    tc.mouseMove(onRow, shell.gap * 4, shell.gap / 2); tc.wait(150);
                    shell.check("MenuRow: an enabled row lights when the mouse is over it", onRow.lit === true);
                    tc.mouseMove(offRow, shell.gap * 4, shell.gap / 2); tc.wait(150);
                    shell.check("MenuRow: the enabled row unlights when the mouse leaves", onRow.lit === false);
                    shell.check("MenuRow: a disabled row does not light under the mouse", offRow.lit === false);
                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
