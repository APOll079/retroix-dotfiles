// Interaction test for the notification history filter (popups/NotificationList.qml): the pure filter
// (app name, title, body, case-insensitive, order kept), the live box, "No matches", the end line, Escape
// (clears, then lets go of the keyboard), and a right click on a filtered row removing the right entry.
// The history is fixtures set on NotificationStore (the runner gives every test its own XDG_STATE_HOME).
// Run by scripts/run-interaction-tests.py (see components.qml for how these files work). The list is loaded by
// path because a test file sits outside quickshell/, where qmllint can't resolve `import "popups"`.
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property int winW: 480
    readonly property int winH: 600
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
    function typeText(s: string) {
        for (const ch of s)
            tc.keyClick(ch);
    }
    function entry(key, app, summary, body) {
        return { key: key, appName: app, summary: summary, body: body, urgency: 1, appIcon: "", image: "", time: new Date(), notif: null };
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
                onTriggered: shell.run()
            }
        }
    }

    function run() {
        const lst = asVar(listLoad.item);
        const items = [
            entry(1, "Firefox", "Download finished", "report.pdf is ready"),
            entry(2, "Vesktop", "Anna", "see you at NOON"),
            entry(3, "Mail", "Invoice", "Your firefox bill"),
            entry(4, "Updates", "Nothing", "")
        ];

        // the pure function
        const keys = r => r.map(e => e.key).join(",");
        shell.check("filter: an empty query returns the list itself", lst.filterItems(items, "") === items && lst.filterItems(items, "   ") === items);
        shell.check("filter: app name, title and body match, case-insensitive, order kept", keys(lst.filterItems(items, "FIREFOX")) === "1,3");
        shell.check("filter: a title match", keys(lst.filterItems(items, "anna")) === "2");
        shell.check("filter: a body match, mixed case", keys(lst.filterItems(items, "noon")) === "2");
        shell.check("filter: no match gives an empty list", lst.filterItems(items, "zzz").length === 0);
        shell.check("filter: leading and trailing spaces are ignored", keys(lst.filterItems(items, "  invoice ")) === "3");
        shell.check("filter: does not change the input", items.length === 4 && keys(items) === "1,2,3,4");

        NotificationStore.items = items;
        tc.wait(300);
        const box = shell.find(lst, it => it.objectName === "filterBox");
        const none = shell.find(lst, it => it.objectName === "noMatches");
        const view = shell.find(lst, it => it.count !== undefined && it.itemAtIndex !== undefined);
        const endLine = () => shell.find(lst, it => it.text === "No older notifications");
        shell.check("the box shows with a history and says what it searches", box.visible === true && box.placeholder === "Search notifications");
        shell.check("all four entries show with no query, no 'No matches'", view.count === 4 && none.visible === false);

        // live typing
        box.input.forceActiveFocus();
        shell.typeText("firef");
        tc.wait(200);
        shell.check("typing filters live", view.count === 2 && lst.query === "firef");
        shell.check("... newest first order kept", view.model[0].key === 1 && view.model[1].key === 3);
        shell.check("... the end line still shows", endLine() !== null && endLine().visible === true);
        shell.check("... the history itself is untouched", NotificationStore.items.length === 4);

        // right click on the second filtered row removes entry 3, not entry 2 (the row beneath in the full list)
        const second = view.itemAtIndex(1);
        tc.mouseClick(second, 30, 8, Qt.RightButton);
        tc.wait(300);
        shell.check("right click on a filtered row removes that entry", NotificationStore.items.map(e => e.key).join(",") === "1,2,4");
        shell.check("... the list follows", view.count === 1 && view.model[0].key === 1);

        // no match
        shell.typeText("x");
        tc.wait(200);
        shell.check("no match shows 'No matches'", none.visible === true && view.count === 0);
        shell.check("... the end line is gone with it", endLine() === null || endLine().height === 0 || endLine().visible === false || endLine().parent.visible === false);

        // Escape: clears, then lets go
        tc.keyClick(Qt.Key_Escape);
        tc.wait(200);
        shell.check("Escape clears the box and shows everything", box.text === "" && view.count === 3);
        shell.check("... the box keeps the keyboard after the first Escape", box.input.activeFocus === true);
        tc.keyClick(Qt.Key_Escape);
        tc.wait(100);
        shell.check("a second Escape hands the keyboard back", box.input.activeFocus === false);

        // the box hides with an empty history; the empty state takes over
        NotificationStore.clear();
        tc.wait(200);
        shell.check("an empty history hides the box", box.visible === false);

        console.log("TEST done failures=" + shell.failures);
        Qt.quit();
    }
}
