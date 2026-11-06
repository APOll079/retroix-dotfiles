// Tests for popups/FindWindow.qml ("Find: Files or Folders"): the fields, Find Now / Stop, the Name and In Folder columns, the
// status line, double-click and Enter to open, Shift+Enter and Open Folder for the folder, Escape. QS_NO_APPLY is set: no
// filesearch.sh and no xdg-open run; FileSearch records what it would have run in `launched` and the test hands it answers with
// gotText / gotExit; the window records the paths it would open in `openLog`. The window is loaded by path (the runner copies
// this file next to popups/).
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    property int closeRequests: 0
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

    TestCase { id: tc; name: "sim"; when: false }
    Timer { id: starter; interval: 600; running: true; onTriggered: shell.run() }
    Timer { id: quitTimer; interval: 100; onTriggered: Qt.quit() }

    function run() {
        const comp = Qt.createComponent("popups/FindWindow.qml");
        if (comp.status !== Component.Ready) {
            check("FindWindow.qml loads: " + comp.errorString(), false);
            console.log("TEST done failures=" + failures);
            quitTimer.start();
            return;
        }
        const w = shell.asVar(comp.createObject(shell, { visible: true }));
        w.closeRequested.connect(() => shell.closeRequests++);
        tc.wait(300);
        const FS = FileSearch;
        const home = FS.home;

        check("titled Find: Files or Folders", w.title === "Find: Files or Folders");
        check("Look in starts at ~", w.lookIn === "~");
        check("nothing searched yet: the status says what to do and the list says so", w.status.text === "Type a name and press Find Now" && w.emptyItem.visible && w.emptyItem.text === "Nothing searched yet");
        check("Find Now is the default button, Stop is off, Open and Open Folder are off", w.findButton.isDefault === true && !w.stopButton.enabled && !w.openButton.enabled && !w.folderButton.enabled);

        // ---- Find Now ----
        const n0 = FS.launched.length;
        w.named = "report";
        w.findButton.clicked();
        tc.wait(100);
        check("Find Now: Searching... and Stop is on", w.status.text === "Searching..." && w.stopButton.enabled);
        tc.wait(400);
        check("Find Now runs the search for Named in Look in (one argument each)", FS.launched.length === n0 + 1 && JSON.stringify(FS.launched[n0].slice(2)) === JSON.stringify(["report", "~"]));
        w.stopButton.clicked();
        check("Stop ends the search", !FS.searching && !w.stopButton.enabled);
        w.findNow();
        w.findNow();
        tc.wait(400);
        check("pressing Find Now twice runs one search (the newer replaces the older)", FS.launched.length === n0 + 2);
        w.lookIn = "/some/where else";
        w.findNow();
        tc.wait(400);
        check("Look in is passed as typed (the script validates it)", JSON.stringify(FS.launched[n0 + 2].slice(2)) === JSON.stringify(["report", "/some/where else"]));
        w.lookIn = "   ";
        w.findNow();
        tc.wait(400);
        check("a blank Look in means ~", JSON.stringify(FS.launched[n0 + 3].slice(2)) === JSON.stringify(["report", "~"]));

        // ---- answers ----
        FS.gotText(FS.token, home + "/docs/Annual Report.txt\n" + home + "/Reports/\n/etc/report.conf\n/mnt/long/" + "x".repeat(80) + "/report.txt\n");
        FS.gotExit(FS.token, 0);
        tc.wait(200);
        check("the status counts the files", w.status.text === "4 file(s) found");
        check("the empty text is hidden", !w.emptyItem.visible);
        const list = w.listItem;
        check("four rows", list.count === 4);
        const rows = shell.find(list.contentItem, c => c.modelData !== undefined && c.text !== undefined, []);
        check("rows: Name and In Folder columns", rows.length === 4 && rows[0].text === "Annual Report.txt" && rows[2].text === "report.conf");
        const folderTexts = rows.map(r => shell.find(r, c => c.text !== undefined && c.elide === Text.ElideMiddle, [])[0]);
        check("In Folder shows ~ for the home folder", folderTexts[0].text === "~/docs" && folderTexts[1].text === "~" && folderTexts[2].text === "/etc");
        check("the In Folder column starts where the Name column ends and stays inside the row", rows.every((r, i) => folderTexts[i].x >= r.width - list.folderColumn - 1 && folderTexts[i].x + folderTexts[i].width <= r.width));
        check("the first row is selected, Open and Open Folder are on", list.currentIndex === 0 && w.openButton.enabled && w.folderButton.enabled);

        // ---- opening ----
        w.openCurrent();
        check("Open opens the file", w.openLog[0] === home + "/docs/Annual Report.txt");
        w.folderButton.clicked();
        check("Open Folder opens its folder", w.openLog[1] === home + "/docs");
        tc.mouseDoubleClickSequence(rows[2], 20, 8);
        tc.wait(100);
        check("double-click opens the file it is on", w.openLog[2] === "/etc/report.conf");
        w.namedItem.focusInput();
        tc.keyClick(Qt.Key_Down);
        check("Down from Named moves into the list", list.activeFocus);
        list.currentIndex = 0;
        tc.keyClick(Qt.Key_Down);
        tc.keyClick(Qt.Key_Return);
        check("Enter in the list opens the selected file or folder", w.openLog[3] === home + "/Reports");
        tc.keyClick(Qt.Key_Return, Qt.ShiftModifier);
        check("Shift+Enter opens the folder that holds it", w.openLog[4] === home);
        tc.keyClick(Qt.Key_Up);
        tc.keyClick(Qt.Key_Up);
        check("Up from the first row goes back to Named", w.namedItem.input.activeFocus);
        const n1 = FS.launched.length;
        tc.keyClick(Qt.Key_Return);
        tc.wait(400);
        check("Enter in Named is Find Now", FS.launched.length === n1 + 1);

        // ---- states ----
        FS.gotText(FS.token, "");
        FS.gotExit(FS.token, 0);
        tc.wait(100);
        check("nothing found: 0 file(s) found, the list says No files found", w.status.text === "0 file(s) found" && w.emptyItem.visible && w.emptyItem.text === "No files found");
        w.findNow();
        tc.wait(400);
        FS.gotText(FS.token, "");
        FS.gotExit(FS.token, 4);
        tc.wait(100);
        check("a Look in that is not a folder: its own line, as an error", w.status.text === "Look in: that is not a folder" && w.status.kind === "error");
        w.findNow();
        tc.wait(400);
        FS.gotExit(FS.token, 3);
        tc.wait(100);
        check("no search tool: the clear line, as an error", w.status.text === "fd, plocate or find not available" && w.status.kind === "error");
        w.named = "-x";
        w.findNow();
        tc.wait(100);
        check("a name with a leading dash is refused with a line, nothing is launched", w.status.kind === "error" && w.status.text.indexOf("cannot be searched") >= 0);
        check("fifty hits say it is the first 50", w.statusOf(false, "", true, 50).text === "50 file(s) found (the first 50)");
        w.named = "";
        w.findNow();
        tc.wait(400);
        check("an empty name with a Look in folder is allowed", FS.error === "" && FS.searching);

        // ---- Escape ----
        w.stopSearch();
        const c0 = shell.closeRequests;
        w.namedItem.focusInput();
        tc.keyClick(Qt.Key_Escape);
        check("Escape in Named (empty) closes the window", shell.closeRequests === c0 + 1);

        console.log("TEST done failures=" + failures);
        quitTimer.start();
    }
}
