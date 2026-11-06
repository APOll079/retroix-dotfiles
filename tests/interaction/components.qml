// Interaction tests for the shared components (the runner copies this file to the root of a scratch copy of
// quickshell/, so `popups` and the singletons resolve like they do for the shell): real mouse clicks and key presses (QtTest's event
// simulation through Qt's input path), run offscreen by scripts/run-interaction-tests.py.
// QtTest's own runner doesn't work inside Quickshell, so TestCase is used only to simulate input and every
// check reports itself with a "TEST pass|FAIL <name>" line. What can't run here (layer-shell windows, the
// notification server, popup focus grabs on a compositor) is listed in docs/desktop.md, not faked.
import QtQuick
import QtTest
import QtQuick.Controls.Basic
import Quickshell
import "popups" as Popups

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    // test geometry only, not shell sizes
    readonly property int winW: 400
    readonly property int winH: 360
    readonly property int boxW: 380
    readonly property int listW: 200
    readonly property int listH: 110
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

            property string ran: ""
            property int accepted: 0
            property int canceled: 0

            Popups.ConfirmBar {
                id: confirm
                x: 10; y: 10; width: shell.boxW
                message: "Reboot now?"; verb: "Reboot"
                onAccepted: host.accepted++
                onCanceled: host.canceled++
            }
            Popups.MenuStrip {
                id: strip
                x: 10; y: 60
                menus: [{ text: "File", build: () => [{ text: "Close", action: () => host.ran = "close" }] }]
            }
            ListView {
                id: list
                x: 10; y: 100; width: shell.listW; height: shell.listH
                clip: true
                model: 30
                delegate: Item { width: list.width - MenuStyle.scrollBarWidth; height: MenuStyle.rowHeight }
                ScrollBar.vertical: Popups.RetroScrollBar { id: bar }
            }
            Popups.PopupMenu {
                id: menu
                model: [{ text: "One", action: () => host.ran = "one" }, { separator: true }, { text: "Two", action: () => host.ran = "two" }]
            }
            Popups.BevelButton { id: opener; x: 250; y: 100; text: "Open menu" }
            TestCase { id: tc; name: "sim"; when: false }

            Timer {
                interval: 900; running: true
                onTriggered: {
                    // ConfirmBar: the verb accepts, Cancel cancels (real clicks on the two buttons)
                    const btns = []; for (const c of confirm.children) if (c.text !== undefined && c.isDefault !== undefined) btns.push(c);
                    const cancelBtn = btns.find(b => b.text === "Cancel"), verbBtn = btns.find(b => b.text === "Reboot");
                    tc.mouseClick(verbBtn);   shell.check("ConfirmBar: clicking the verb accepts", host.accepted === 1 && host.canceled === 0);
                    tc.mouseClick(cancelBtn); shell.check("ConfirmBar: clicking Cancel cancels", host.canceled === 1 && host.accepted === 1);
                    shell.check("ConfirmBar: the verb is the default button", verbBtn.isDefault === true && cancelBtn.isDefault === false);

                    // MenuStrip: a click on a title opens its dropdown, a second click closes it
                    let title = null; for (const c of strip.children) if (c.modelData !== undefined) title = c;
                    let dd = null; for (let i = 0; i < title.data.length; i++) if (title.data[i].openAt !== undefined) dd = title.data[i];
                    tc.mouseClick(title); tc.wait(150);
                    shell.check("MenuStrip: a click opens the dropdown", dd.visible === true);
                    tc.mouseClick(title); tc.wait(150);
                    shell.check("MenuStrip: a second click closes it", dd.visible === false);
                    dd.close();

                    // PopupMenu: opens at a point, Escape closes it, a pick runs the action and closes it
                    menu.openAt(host, 20, 240); tc.wait(150);
                    shell.check("PopupMenu: openAt shows it", menu.visible === true);
                    const body = menu.contentItem.children[0];
                    tc.keyClick(Qt.Key_Escape); tc.wait(100);
                    shell.check("PopupMenu: Escape closes it", menu.visible === false);
                    menu.openAt(host, 20, 240); tc.wait(150);
                    tc.keyClick(Qt.Key_Down); tc.keyClick(Qt.Key_Down); tc.keyClick(Qt.Key_Return); tc.wait(100);
                    shell.check("PopupMenu: Down, Down, Enter runs the second action (skips the separator) and closes", host.ran === "two" && menu.visible === false);

                    // RetroScrollBar: the arrow buttons scroll the list (real press on the lower arrow)
                    const before = list.contentY;
                    tc.mousePress(bar, bar.width / 2, bar.height - MenuStyle.scrollBarWidth / 2); tc.wait(80); tc.mouseRelease(bar, bar.width / 2, bar.height - MenuStyle.scrollBarWidth / 2);
                    shell.check("RetroScrollBar: the down arrow scrolls the list", list.contentY > before);

                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
