// Tests for TodoState (the Calendar tab's to-do file): the pure parse / serialise / edit functions with
// fixtures, then the real singleton against a scratch state file (the runner gives every test its own
// XDG_STATE_HOME, so TodoState.path is never the owner's file).
// Run by scripts/run-interaction-tests.py (see components.qml for how these files work).
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function same(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    // Whatever bytes go in come out unchanged
    readonly property var samples: [
        "",
        "\n",
        "[ ] buy milk",
        "[ ] buy milk\n",
        "[x] 2026-11-10 buy milk\r\n[ ] 2026-11-11 call\r\n",
        "[x] 2026-11-10 buy milk\r\n[ ] no cr here\n",
        "# my notes\n\n[ ] a\n   indented note\n[]  nope\n[ ]\n[ ] \n\n\n",
        "[ ]  two spaces\n[X] caps done\n[ ] 2026-13-45 not a date\n",
        "[ ] kaffe åäö ☕ 😀\nüber note\n",
        "no tasks at all"
    ]

    Timer {
        interval: 600; running: true
        onTriggered: shell.run()
    }
    TestCase { id: tc; name: "sim"; when: false }
    // the same file TodoState watches, read and written synchronously
    FileView {
        id: io
        path: TodoState.path
        blockLoading: true
        blockWrites: true
    }
    function disk() {
        io.reload();
        tc.wait(150);
        return io.text();
    }

    function run() {
        // ---- pure functions ----
        let allSame = true;
        for (const s of samples)
            if (TodoState.serialise(TodoState.parse(s)) !== s)
                allSame = false;
        check("round trip: parse then serialise gives the identical bytes for every sample (CRLF, no final newline, odd spacing, unicode)", allSame);

        const p = TodoState.parse("# notes\n[ ] 2026-11-10 buy milk\n\n[x] done thing\n[ ]  odd\n");
        check("parse: only task lines are items, in order", p.items.length === 3 && p.items[0].text === "buy milk" && p.items[1].text === "done thing");
        check("parse: due date and done flag", p.items[0].due === "2026-11-10" && !p.items[0].done && p.items[1].done && p.items[1].due === "");
        check("parse: odd spacing keeps the extra space in the text", p.items[2].text === " odd");
        check("parse: an impossible date is part of the text", TodoState.parse("[ ] 2026-02-30 x").items[0].due === "" && TodoState.parse("[ ] 2026-02-30 x").items[0].text === "2026-02-30 x");
        check("parse: a bare [ ] with no text is not a task", TodoState.parse("[ ]\n[ ] \n").items.length === 0);

        const t = TodoState.toggled(p, 1);
        check("toggle: only that line changes", TodoState.serialise(t) === "# notes\n[ ] 2026-11-10 buy milk\n\n[ ] done thing\n[ ]  odd\n");
        check("toggle twice gives the file back", TodoState.serialise(TodoState.toggled(t, 1)) === TodoState.serialise(p));
        const crlf = TodoState.toggled(TodoState.parse("[ ] a\r\n[ ] b\r\n"), 0);
        check("toggle keeps CRLF", TodoState.serialise(crlf) === "[x] a\r\n[ ] b\r\n");

        check("add without a due date", TodoState.serialise(TodoState.added(TodoState.parse("[ ] a\n"), "b", "")) === "[ ] a\n[ ] b\n");
        check("add with a due date", TodoState.serialise(TodoState.added(TodoState.parse("[ ] a\n"), "b", "2026-11-10")) === "[ ] a\n[ ] 2026-11-10 b\n");
        check("add to a file without a final newline", TodoState.serialise(TodoState.added(TodoState.parse("[ ] a"), "b", "")) === "[ ] a\n[ ] b");
        check("add to an empty file", TodoState.serialise(TodoState.added(TodoState.parse(""), "b", "")) === "[ ] b\n");
        check("add to a CRLF file uses CRLF", TodoState.serialise(TodoState.added(TodoState.parse("[ ] a\r\n"), "b", "")) === "[ ] a\r\n[ ] b\r\n");
        check("add keeps notes where they are", TodoState.serialise(TodoState.added(TodoState.parse("# n\n[ ] a\nnote\n"), "b", "")) === "# n\n[ ] a\nnote\n[ ] b\n");
        check("add of blank text changes nothing", TodoState.added(p, "   ", "") === p);
        check("add flattens a newline in the text", TodoState.added(TodoState.parse(""), "a\nb", "").items[0].text === "a b");
        check("add ignores an invalid due date", TodoState.added(TodoState.parse(""), "a", "soon").items[0].due === "");

        check("remove: only that line goes", TodoState.serialise(TodoState.removed(p, 0)) === "# notes\n\n[x] done thing\n[ ]  odd\n");
        check("remove the last task of a one-line file leaves an empty file", TodoState.serialise(TodoState.removed(TodoState.parse("[ ] a"), 0)) === "");

        const dd = TodoState.dueDaysOf(TodoState.parse("[ ] 2026-11-10 a\n[x] 2026-11-11 b\n[ ] c\n[ ] 2026-11-10 d\n[ ] 2026-12-01 e\n").items);
        check("dueDays: open items with a due date only", shell.same(Object.keys(dd).sort(), ["2026-11-10", "2026-12-01"]));

        const today = "2026-11-06";
        check("overdue: open and before today", TodoState.isOverdue({ done: false, due: "2026-11-05" }, today));
        check("overdue: not today, not later, not done, not undated",
              !TodoState.isOverdue({ done: false, due: today }, today) && !TodoState.isOverdue({ done: false, due: "2026-11-07" }, today)
              && !TodoState.isOverdue({ done: true, due: "2026-11-01" }, today) && !TodoState.isOverdue({ done: false, due: "" }, today));
        check("splitInput: a leading date is the due date", shell.same(TodoState.splitInput("2026-11-10 buy milk"), { due: "2026-11-10", text: "buy milk" }));
        check("splitInput: no date, an impossible date", shell.same(TodoState.splitInput(" buy milk "), { due: "", text: "buy milk" })
              && shell.same(TodoState.splitInput("2026-99-99 x"), { due: "", text: "2026-99-99 x" }));
        check("ymd pads month and day (month is 0-based)", TodoState.ymd(2026, 0, 5) === "2026-01-05" && TodoState.ymd(new Date(2026, 10, 6)) === "2026-11-06");

        // ---- the singleton on a scratch file ----
        check("singleton: starts empty and not broken with no file", TodoState.items.length === 0 && !TodoState.broken);
        check("singleton: a missing file is not created by loading", disk() === "");
        check("singleton: add reports it saved", TodoState.add("buy milk", "2026-11-10") === true);
        tc.wait(300);
        check("singleton: the first add creates the file", disk() === "[ ] 2026-11-10 buy milk\n");
        check("singleton: dueDays has the day", TodoState.dueDays["2026-11-10"] === true);
        TodoState.toggle(0);
        tc.wait(300);
        check("singleton: toggle is written", disk() === "[x] 2026-11-10 buy milk\n");
        check("singleton: a done task has no due day", TodoState.dueDays["2026-11-10"] === undefined);

        io.setText("# from my notes app\n[ ] 2026-12-01 from outside\n");
        tc.wait(600);
        check("singleton: an external edit shows up", TodoState.items.length === 1 && TodoState.items[0].text === "from outside");
        TodoState.add("second", "");
        tc.wait(300);
        check("singleton: the note line survives our write", disk() === "# from my notes app\n[ ] 2026-12-01 from outside\n[ ] second\n");

        Quickshell.execDetached(["chmod", "000", TodoState.path]);
        tc.wait(200);
        TodoState.reload();
        tc.wait(600);
        check("singleton: an unreadable file marks it broken and the list runs empty", TodoState.broken && TodoState.items.length === 0);
        check("singleton: add on a broken file does not write", TodoState.add("lost", "") === false);
        Quickshell.execDetached(["chmod", "644", TodoState.path]);
        tc.wait(200);
        check("singleton: the unreadable file was never overwritten", disk() === "# from my notes app\n[ ] 2026-12-01 from outside\n[ ] second\n");
        TodoState.reload();
        tc.wait(600);
        check("singleton: a later successful load clears broken and reads the file", !TodoState.broken && TodoState.items.length === 2);

        console.log("TEST done failures=" + shell.failures);
        Qt.quit();
    }
}
