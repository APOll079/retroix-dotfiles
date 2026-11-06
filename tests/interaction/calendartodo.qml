// Interaction test for the to-do list in the Calendar tab: the list shows the file's tasks, a click on a row
// toggles it, Enter in the add field adds (a leading date is the due date), a click on a calendar day sets the
// due date of the next add, a day with an open task due carries a mark, a right click opens the Delete menu,
// "No tasks" shows when empty, and the tab's height does not change as tasks come and go.
// The state file is a scratch one (the runner gives every test its own XDG_STATE_HOME). Run by
// scripts/run-interaction-tests.py (see components.qml for how these files work). The tab is loaded by path
// because a test file sits outside quickshell/, where qmllint can't resolve `import "popups"`.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property int winW: 480
    readonly property int winH: 700
    function asVar(o: var): var {
        return o;
    }
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    // first item below `it` (itself included) that satisfies pred
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
    function byName(name: string): var {
        return shell.find(shell.asVar(tabLoad.item), it => it.objectName === name);
    }
    function typeText(s: string) {
        for (const ch of s)
            tc.keyClick(ch);
    }

    FileView {
        id: io
        path: TodoState.path
        blockLoading: true
        blockWrites: true
    }

    FloatingWindow {
        implicitWidth: shell.winW; implicitHeight: shell.winH
        Rectangle {
            anchors.fill: parent
            color: Config.colors.base
            Loader {
                id: tabLoad
                x: 10; y: 10
                width: shell.winW - 20
                Component.onCompleted: setSource("popups/CalendarTab.qml", { active: true })
            }
            TestCase { id: tc; name: "sim"; when: false }
            Timer {
                interval: 900; running: true
                onTriggered: shell.run()
            }
        }
    }

    function run() {
        const tab = asVar(tabLoad.item);
        const now = new Date();
        const monthDay = d => TodoState.ymd(now.getFullYear(), now.getMonth(), d);
        const dayA = monthDay(28), dayB = monthDay(27);

        // fixture: an overdue task, one due on the 28th of the viewed month, a done one, a note
        io.setText("# notes\n[ ] 2000-01-01 overdue thing\n[ ] " + dayA + " buy milk\n[x] done one\n");
        tc.wait(700);
        const emptyHeightProbe = tab.implicitHeight;
        shell.check("the file's tasks are listed (notes skipped)", TodoState.items.length === 3);

        const list = shell.byName("todoList");
        tc.wait(100);
        shell.check("the list has three rows", list.count === 3);
        shell.check("the list shows exactly todoRows rows of room", list.parent.height >= MenuStyle.todoRows * MenuStyle.rowHeight);

        // the mark on a due day, none on a day without one
        const cellA = shell.find(tab, it => it.key === dayA && it.due !== undefined);
        const cellB = shell.find(tab, it => it.key === dayB && it.due !== undefined);
        const markA = shell.find(cellA, it => it.objectName === "dueMark");
        const markB = shell.find(cellB, it => it.objectName === "dueMark");
        shell.check("a day with an open task due carries a mark", markA !== null && markA.visible === true);
        shell.check("a day without one has none", markB !== null && markB.visible === false);

        // overdue due date in the urgent colour, a later one not
        const rowOverdue = list.itemAtIndex(0), rowLater = list.itemAtIndex(1);
        const dueOver = shell.find(rowOverdue, it => it.id === undefined && it.text === "2000-01-01");
        shell.check("an overdue due date is drawn in the urgent colour", dueOver !== null && Qt.colorEqual(dueOver.color, Config.colors.urgent));
        const dueLater = shell.find(rowLater, it => it.text === dayA);
        shell.check("a due date not yet reached is not urgent", dueLater !== null && !Qt.colorEqual(dueLater.color, Config.colors.urgent));

        // toggle by click
        tc.mouseClick(rowLater, 40, rowLater.height / 2);
        tc.wait(400);
        shell.check("a click on a row marks the task done", TodoState.items[1].done === true);
        shell.check("... and the mark on its day goes", markA.visible === false);
        io.reload();
        tc.wait(100);
        shell.check("... and the file has it", io.text() === "# notes\n[ ] 2000-01-01 overdue thing\n[x] " + dayA + " buy milk\n[x] done one\n");
        tc.mouseClick(list.itemAtIndex(1), 40, list.itemAtIndex(1).height / 2);
        tc.wait(300);
        shell.check("a second click opens it again", TodoState.items[1].done === false && markA.visible === true);

        // add by Enter, with a leading date
        const box = shell.byName("addBox");
        box.input.forceActiveFocus();
        shell.typeText("2026-12-24 wrap presents");
        tc.keyClick(Qt.Key_Return);
        tc.wait(300);
        const last = TodoState.items[TodoState.items.length - 1];
        shell.check("Enter adds the task with the leading date as due date", TodoState.items.length === 4 && last.text === "wrap presents" && last.due === "2026-12-24");
        shell.check("... and empties the field", box.text === "");
        box.input.forceActiveFocus();
        shell.typeText("plain task");
        tc.keyClick(Qt.Key_Enter);
        tc.wait(300);
        shell.check("a task without a date has no due date", TodoState.items.length === 5 && TodoState.items[4].text === "plain task" && TodoState.items[4].due === "");
        box.input.forceActiveFocus();
        tc.keyClick(Qt.Key_Return);
        tc.wait(200);
        shell.check("Enter on an empty field adds nothing", TodoState.items.length === 5);

        // a day clicked while the field is empty sets the due date of the next add
        tc.mouseClick(cellB, cellB.width / 2, cellB.height / 2);
        tc.wait(150);
        shell.check("a click on a day sets the due date for the next add", tab.dueFor === dayB);
        const chip = shell.byName("dueChip");
        shell.check("... and shows it with a clear button", chip.visible === true && chip.text === dayB);
        box.input.forceActiveFocus();
        shell.typeText("on the 27th");
        tc.keyClick(Qt.Key_Return);
        tc.wait(300);
        const added = TodoState.items[TodoState.items.length - 1];
        shell.check("the picked day became the new task's due date", added.text === "on the 27th" && added.due === dayB);
        shell.check("... and the pick is used up", tab.dueFor === "" && chip.visible === false);
        tc.mouseClick(cellB, cellB.width / 2, cellB.height / 2);
        tc.wait(100);
        tc.mouseClick(chip, chip.width / 2, chip.height / 2);
        tc.wait(100);
        shell.check("the clear button drops the picked date", tab.dueFor === "");
        box.input.forceActiveFocus();
        shell.typeText("half typed");
        tc.mouseClick(cellB, cellB.width / 2, cellB.height / 2);
        tc.wait(100);
        shell.check("a click on a day while the field has text does not pick", tab.dueFor === "");
        box.text = "";

        // delete through the shared menu
        const before = TodoState.items.length;
        const menu = tab.rowMenu;
        const row0 = list.itemAtIndex(0);
        tc.mouseClick(row0, 40, row0.height / 2, Qt.RightButton);
        tc.wait(300);
        shell.check("a right click on a row opens the menu with Delete", menu.model.length === 1 && menu.model[0].text === "Delete");
        menu.model[0].action();
        tc.wait(300);
        shell.check("Delete removes that task", TodoState.items.length === before - 1 && TodoState.items[0].text !== "overdue thing");

        // the height stays the same empty or full; "No tasks" shows when empty
        while (TodoState.items.length > 0)
            TodoState.remove(0);
        tc.wait(300);
        const noTasks = shell.find(tab, it => it.text === "No tasks" && it.visible === true);
        shell.check("an empty list shows No tasks", noTasks !== null);
        shell.check("the tab is the same height full and empty", tab.implicitHeight === emptyHeightProbe);
        io.reload();
        tc.wait(100);
        shell.check("the notes survive deleting every task", io.text() === "# notes\n");

        console.log("TEST done failures=" + shell.failures);
        Qt.quit();
    }
}
