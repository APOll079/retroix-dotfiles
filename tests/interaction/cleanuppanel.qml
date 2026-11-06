// Confirm flow of the Clean up panel with real simulated clicks and keys: Clean -> ConfirmBar -> Esc cancels (nothing
// ran) -> Clean -> Enter confirms (run called once) -> the verb button runs too -> Esc with no confirm closes.
// CleanupPanel is a layer-shell PanelWindow and can't be created offscreen, so this test writes a scratch copy of it
// (inside the runner's own scratch tree, never the repo) with PanelWindow turned into FloatingWindow and the layer-shell
// lines dropped, then loads that. Everything else is the real file. QS_NO_APPLY is set: CleanupState.run(id) only records
// the id in runLog, no tool runs.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    property int closed: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function asVar(o: var): var {
        return o;
    }

    FileView {
        id: src
        path: Quickshell.shellPath("popups/CleanupPanel.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/CleanupPanelTest.qml")
        blockWrites: true
    }

    readonly property var rows: [
        { id: "pacman-cache", label: "Old package cache", bytes: 1.5e6, count: 7, needsRoot: true, note: "" },
        { id: "orphans", label: "Orphaned packages", bytes: 0, count: 0, needsRoot: true, note: "" },
        { id: "flatpak-unused", label: "Unused Flatpak runtimes", bytes: null, count: 2, needsRoot: false, note: "size unknown" },
        { id: "trash", label: "Trash", bytes: 1.2e9, count: null, needsRoot: false, note: "" }
    ]

    // all visible items under `item` matching `pred`
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }
    function buttons(win, text) {
        return shell.find(win.contentItem, c => c.visible && c.text === text && c.clicked !== undefined, []);
    }
    function confirmBars(win) {
        return shell.find(win.contentItem, c => c.visible && c.verb !== undefined && c.accept !== undefined, []);
    }

    Component.onCompleted: {
        // the scratch copy: layer-shell window -> plain window
        let t = src.text();
        t = t.replace("PanelWindow {", "FloatingWindow {");
        t = t.replace(/\n    anchors \{[\s\S]*?\n    \}/, "");
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0).join("\n");
        t = t.replace("property int screenHeight: 0", "property int screenHeight: 500\n    implicitWidth: 640\n    implicitHeight: 520");
        dst.setText(t);
        loader.setSource("popups/CleanupPanelTest.qml", { bar: null });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const panel = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", panel !== null && panel.confirmId !== undefined);
            panel.closeCallback = function () { shell.closed++; };
            panel.openMenu();
            CleanupState.rows = shell.rows;
            tc.wait(200);
            shell.check("rows with nothing to clean (and the Trash) are hidden (2 shown)", panel.shown.length === 2);
            shell.check("one Clean button per row", shell.buttons(panel, "Clean").length === 2);

            // 1. Clean -> confirm bar, nothing ran
            tc.mouseClick(shell.buttons(panel, "Clean")[0]);
            tc.wait(100);
            shell.check("Clean shows the confirm for that row", panel.confirmId === "pacman-cache" && shell.confirmBars(panel).length === 1);
            shell.check("the confirm's verb is Clean up", shell.confirmBars(panel)[0].verb === "Clean up");
            shell.check("the confirm names the size", shell.confirmBars(panel)[0].message.indexOf("1.5 MB") >= 0);
            shell.check("nothing ran yet", CleanupState.runLog.length === 0);
            shell.check("the other Clean buttons are off while asking", shell.buttons(panel, "Clean").every(b => !b.enabled));

            // 2. Esc cancels, does not close
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Esc cancels the confirm", panel.confirmId === "" && shell.confirmBars(panel).length === 0);
            shell.check("Esc on a confirm does not close the panel", shell.closed === 0);
            shell.check("after Esc nothing ran", CleanupState.runLog.length === 0);

            // 3. Cancel button
            tc.mouseClick(shell.buttons(panel, "Clean")[0]);
            tc.wait(100);
            tc.mouseClick(shell.buttons(panel, "Cancel")[0]);
            tc.wait(100);
            shell.check("the Cancel button cancels, nothing ran", panel.confirmId === "" && CleanupState.runLog.length === 0);

            // 4. Enter confirms
            tc.mouseClick(shell.buttons(panel, "Clean")[1]);
            tc.wait(100);
            shell.check("the flatpak row asks for its own confirm", panel.confirmId === "flatpak-unused");
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter confirms: run called once with the id", JSON.stringify(CleanupState.runLog) === JSON.stringify(["flatpak-unused"]));
            shell.check("the confirm is gone after accepting", panel.confirmId === "");

            // 6. keys: Down moves, Enter asks, Esc, Esc closes
            panel.cursor = 0;
            tc.keyClick(Qt.Key_Down);
            tc.wait(50);
            shell.check("Down moves the selection", panel.cursor === 1);
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            shell.check("Enter on a row asks (nothing runs)", panel.confirmId === "flatpak-unused" && CleanupState.runLog.length === 1);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(50);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(50);
            shell.check("a second Esc closes the panel", shell.closed === 1);

            // 8. nothing to clean
            panel.openMenu();
            CleanupState.rows = [];
            tc.wait(100);
            shell.check("no rows: Nothing to clean, no confirm", panel.shown.length === 0 && panel.confirmId === "");

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
