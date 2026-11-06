// Task Manager GPU / VRAM / Read / Write columns: the cell text ("--" for null), the short byte and rate formats, and sorting by each
// new column with null always last in both directions. Same scratch-copy approach as taskmanager.qml (helper off, app list fixture).
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
    function asVar(o: var): var {
        return o;
    }
    function names(list) { return list.map(g => g.name).join(","); }

    FileView {
        id: src
        path: Quickshell.shellPath("popups/TaskManager.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/TaskManagerColsTest.qml")
        blockWrites: true
    }

    Component.onCompleted: {
        let t = src.text();
        t = t.replace("running: root.visible\n        stdout: SplitParser", "running: false\n        stdout: SplitParser");
        t = t.replace(/readonly property var apps: Hyprland\.toplevels\.values\.filter\([^\n]*\n/, "readonly property var apps: []\n");
        dst.setText(t);
        loader.setSource("popups/TaskManagerColsTest.qml", {});
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const tm = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", tm !== null && tm.extraCells !== undefined);

            shell.check("bytesShort: K, M, G steps and -- for unknown", tm.bytesShort(512 * 1024) === "512K" && tm.bytesShort(300 * 1048576) === "300M"
                && tm.bytesShort(1.5 * 1073741824) === "1.5G" && tm.bytesShort(null) === "--" && tm.bytesShort(undefined) === "--" && tm.bytesShort(-1) === "--");
            shell.check("rateShort: 0 below 1 KB/s, K/s, M/s, -- for unknown", tm.rateShort(10) === "0" && tm.rateShort(2048) === "2K/s"
                && tm.rateShort(5 * 1048576) === "5M/s" && tm.rateShort(null) === "--");
            const cells = tm.extraCells({ gpu: 12.4, vram: 2 * 1048576, read: 0, write: null });
            shell.check("extraCells: percent, VRAM, Read, Write with -- for null", cells.join("|") === "12%|2M|0|--");
            shell.check("extraCells: everything null shows four dashes", tm.extraCells({ gpu: null, vram: null, read: null, write: null }).join("|") === "--|--|--|--");
            shell.check("extraCells: a group from an older helper (fields missing) shows dashes", tm.extraCells({}).join("|") === "--|--|--|--");

            const base = { cpu: 0, mem: 1, count: 1, mine: true, core: "" };
            tm.sample = {
                cpu: 5, mem: { used: 1, total: 2 }, swap: { used: 0, total: 0 }, gpu: null, count: 4, self: 1, net: { rx: 1, tx: 1, t: 1 },
                groups: [
                    Object.assign({}, base, { name: "a", pids: [1], gpu: 10, vram: 500, read: 5, write: null }),
                    Object.assign({}, base, { name: "b", pids: [2], gpu: null, vram: null, read: null, write: 9 }),
                    Object.assign({}, base, { name: "c", pids: [3], gpu: 40, vram: 100, read: 50, write: 1 }),
                    Object.assign({}, base, { name: "d", pids: [4], gpu: 0, vram: 900, read: 0, write: 3 })
                ]
            };
            tm.sortBy("gpu");
            shell.check("sort by GPU starts descending, null last", tm.sortKey === "gpu" && shell.names(tm.groups) === "c,a,d,b");
            tm.sortBy("gpu");
            shell.check("sorting by GPU again flips to ascending, null still last", shell.names(tm.groups) === "d,a,c,b");
            tm.sortBy("vram");
            shell.check("sort by VRAM descending, null last", shell.names(tm.groups) === "d,a,c,b");
            tm.sortBy("read");
            shell.check("sort by Read descending, null last", shell.names(tm.groups) === "c,a,d,b");
            tm.sortBy("write");
            shell.check("sort by Write descending, null last", shell.names(tm.groups) === "b,d,c,a");
            shell.check("the View menu lists Sort by GPU / VRAM / Read / Write", ["Sort by GPU", "Sort by VRAM", "Sort by Read", "Sort by Write"].every(x => tm.viewModel().some(m => m.text === x)));
            tm.sortBy("name");
            shell.check("sort by Program still works (ascending)", shell.names(tm.groups) === "a,b,c,d");

            console.log("TEST done failures=" + shell.failures);
            Qt.quit();
        }
    }
}
