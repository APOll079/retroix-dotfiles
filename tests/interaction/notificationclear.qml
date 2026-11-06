// "Clear all" in the notification history asks first (NotificationList.qml): the button shows a ConfirmBar in place of
// the header, Escape cancels (nothing removed), Enter and the verb button clear. The history is fixtures set on
// NotificationStore (the runner gives every test its own XDG_STATE_HOME). Run by scripts/run-interaction-tests.py.
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property int winW: 480
    readonly property int winH: 400
    function asVar(o: var): var {
        return o;
    }
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function find(it: var, pred: var): var {
        if (pred(it))
            return it;
        for (const c of it.children) {
            const r = shell.find(c, pred);
            if (r)
                return r;
        }
        return null;
    }
    function entry(key, app) {
        return { key: key, appName: app, summary: "s" + key, body: "b", urgency: 1, appIcon: "", image: "", time: new Date(), notif: null };
    }
    function fill() {
        NotificationStore.items = [shell.entry(1, "A"), shell.entry(2, "B"), shell.entry(3, "C")];
    }

    FloatingWindow {
        implicitWidth: shell.winW; implicitHeight: shell.winH
        Rectangle {
            anchors.fill: parent
            color: Config.colors.base
            Loader {
                id: listLoad
                x: 10; y: 10
                width: shell.winW - 20
                height: shell.winH - 20
                Component.onCompleted: setSource("popups/NotificationList.qml", { active: true })
            }
            TestCase { id: tc; name: "sim"; when: false }
            Timer {
                interval: 900; running: true
                onTriggered: {
                    const list = shell.asVar(listLoad.item);
                    NotificationStore.restored = true;
                    shell.fill();
                    tc.wait(100);
                    // the header button is the Clear all that is not the default button; the verb is the default one
                    const clear = () => shell.find(list, it => it.text === "Clear all" && it.clicked !== undefined && it.isDefault === false);
                    const verb = () => shell.find(list, it => it.text === "Clear all" && it.clicked !== undefined && it.isDefault === true);
                    shell.check("the Clear all button shows, no confirm yet", clear() !== null && list.confirmBar.visible === false);

                    tc.mouseClick(clear());
                    tc.wait(50);
                    shell.check("clicking Clear all shows the confirm and removes nothing", list.confirmBar.visible === true && NotificationStore.items.length === 3);
                    tc.keyClick(Qt.Key_Escape);
                    shell.check("Escape cancels: confirm gone, all 3 stay", list.confirmBar.visible === false && NotificationStore.items.length === 3);

                    tc.mouseClick(clear());
                    tc.wait(50);
                    tc.mouseClick(shell.find(list, it => it.text === "Cancel" && it.clicked !== undefined && it.visible));
                    shell.check("the Cancel button cancels", list.confirmBar.visible === false && NotificationStore.items.length === 3);

                    tc.mouseClick(clear());
                    tc.wait(50);
                    tc.keyClick(Qt.Key_Return);
                    tc.wait(50);
                    shell.check("Enter is the verb: everything cleared", NotificationStore.items.length === 0 && list.confirmBar.visible === false);

                    shell.fill();
                    tc.wait(100);
                    tc.mouseClick(clear());
                    tc.wait(50);
                    tc.mouseClick(verb());
                    shell.check("the Clear all verb button clears", NotificationStore.items.length === 0);
                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
