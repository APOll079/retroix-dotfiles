// Interaction test for EmptyState: it centres itself when it fills an Item (anchors.fill) and when it fills a
// ColumnLayout (Layout.fill*), wraps long text inside its width, and never swallows a click meant for what is
// under it. Run offscreen by scripts/run-interaction-tests.py (see components.qml for the conventions).
import QtQuick
import QtQuick.Layouts
import QtTest
import Quickshell
import "popups" as Popups

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    // test geometry only, not shell sizes
    readonly property int winW: 520
    readonly property int winH: 240
    readonly property int boxW: 220
    readonly property int boxH: 160
    readonly property string longText: "No phone found. Install KDE Connect on it and pair from there, then open this tab again."
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    FloatingWindow {
        implicitWidth: shell.winW; implicitHeight: shell.winH
        Rectangle {
            id: host
            anchors.fill: parent
            color: Config.colors.base
            property int clicks: 0

            Item {
                id: boxA
                x: 10; y: 10; width: shell.boxW; height: shell.boxH
                Popups.BevelButton { id: under; anchors.fill: parent; text: "Under"; onClicked: host.clicks++ }
                Popups.EmptyState { id: esA; anchors.fill: parent; glyph: ""; text: shell.longText }
            }
            ColumnLayout {
                id: boxB
                x: 270; y: 10; width: shell.boxW; height: shell.boxH
                Popups.EmptyState { id: esB; Layout.fillWidth: true; Layout.fillHeight: true; glyph: ""; text: "No notifications" }
            }
            TestCase { id: tc; name: "sim"; when: false }

            Timer {
                interval: 900; running: true
                onTriggered: {
                    const colA = esA.children[0], colB = esB.children[0];
                    const cA = colA.mapToItem(boxA, colA.width / 2, colA.height / 2);
                    const cB = colB.mapToItem(boxB, colB.width / 2, colB.height / 2);
                    shell.check("EmptyState: centred horizontally with anchors.fill", Math.abs(cA.x - shell.boxW / 2) <= 1);
                    shell.check("EmptyState: centred vertically with anchors.fill", Math.abs(cA.y - shell.boxH / 2) <= 1);
                    shell.check("EmptyState: centred horizontally with Layout.fill", Math.abs(cB.x - shell.boxW / 2) <= 1);
                    shell.check("EmptyState: centred vertically with Layout.fill", Math.abs(cB.y - shell.boxH / 2) <= 1);
                    shell.check("EmptyState: keeps MenuStyle.pad free at each side", colA.width === shell.boxW - 2 * MenuStyle.pad);
                    shell.check("EmptyState: long text wraps inside the width", colA.implicitHeight > colB.implicitHeight && colA.height <= shell.boxH && colA.children[1].height > colB.children[1].height && colA.children[1].width <= colA.width);
                    shell.check("EmptyState: implicitHeight passes through from the column", esA.implicitHeight === colA.implicitHeight);
                    tc.mouseClick(under);
                    shell.check("EmptyState: a button under it still receives a click", host.clicks === 1);

                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
