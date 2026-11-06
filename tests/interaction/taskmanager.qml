// Task Manager additions: the Ports tab (parse, owner text, End task through the same confirm and safety rules), Delete = End
// task on the Apps tab, the network rate / format functions with two fixture samples, the core list coming from procs.py's
// `core` field. TaskManager is a normal window, but its data helper (procs.py) and Hyprland list must not run: this writes a
// scratch copy (inside the runner's own scratch tree) with the helper switched off and the app list replaced by a fixture;
// everything else is the real file. QS_NO_APPLY is set, so signals are only recorded in `killLog` (no kill runs).
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
    function js(v) { return JSON.stringify(v); }

    FileView {
        id: src
        path: Quickshell.shellPath("popups/TaskManager.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/TaskManagerTest.qml")
        blockWrites: true
    }

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
        let t = src.text();
        t = t.replace("running: root.visible\n        stdout: SplitParser", "running: false\n        stdout: SplitParser");
        t = t.replace(/readonly property var apps: Hyprland\.toplevels\.values\.filter\([^\n]*\n/, 'readonly property var apps: [{ title: "Zen Browser", address: "1", workspace: null, lastIpcObject: { pid: 2001, "class": "zen" } }, { title: "Terminal", address: "2", workspace: null, lastIpcObject: { pid: 2200, "class": "kitty" } }]\n');
        dst.setText(t);
        loader.setSource("popups/TaskManagerTest.qml", {});
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    function sampleFor(selfPid) {
        return {
            cpu: 5, mem: { used: 1, total: 2 }, swap: { used: 0, total: 0 }, gpu: null, count: 9, self: selfPid,
            net: { rx: 1000, tx: 500, t: 10 },
            groups: [
                { name: "zen", count: 2, cpu: 1, mem: 100, mine: true, pids: [2001, 2002], core: "" },
                { name: "kitty", count: 1, cpu: 0, mem: 10, mine: true, pids: [2200], core: "" },
                { name: "sshd", count: 1, cpu: 0, mem: 10, mine: false, pids: [812], core: "" },
                { name: "pipewire", count: 1, cpu: 0, mem: 10, mine: true, pids: [1700], core: "all sound stops" },
                { name: "procs.py", count: 1, cpu: 0, mem: 1, mine: true, pids: [900], core: "" }
            ]
        };
    }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const tm = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", tm !== null && tm.rateBetween !== undefined);

            // ---- network rate / format (pure) ----
            const r = tm.rateBetween({ rx: 1000, tx: 500, t: 10 }, { rx: 1000 + 2 * 1048576, tx: 500 + 2 * 204800, t: 12 });
            shell.check("rateBetween: bytes per second from two samples", r !== null && r.down === 1048576 && r.up === 204800);
            shell.check("rateBetween: no earlier sample, no time passed, or junk gives null", tm.rateBetween(null, { rx: 1, tx: 1, t: 2 }) === null
                && tm.rateBetween({ rx: 1, tx: 1, t: 2 }, { rx: 5, tx: 5, t: 2 }) === null && tm.rateBetween({ rx: 1, tx: 1, t: 3 }, { rx: 5, tx: 5, t: 2 }) === null
                && tm.rateBetween({ rx: 1, tx: 1 }, { rx: 5, tx: 5, t: 2 }) === null && tm.rateBetween({ rx: 1, tx: 1, t: 1 }, undefined) === null);
            const back = tm.rateBetween({ rx: 5000, tx: 5000, t: 1 }, { rx: 100, tx: 6000, t: 2 });
            shell.check("rateBetween: a counter that went down counts as 0", back.down === 0 && back.up === 1000);
            shell.check("rateText: B, KB, MB, GB steps", tm.rateText(0) === "0 B/s" && tm.rateText(12.4) === "12 B/s" && tm.rateText(300 * 1024) === "300 KB/s"
                && tm.rateText(1.2 * 1048576) === "1.2 MB/s" && tm.rateText(3 * 1073741824) === "3.0 GB/s" && tm.rateText(1023) === "1023 B/s");
            shell.check("rateText of junk is 0 B/s", tm.rateText(NaN) === "0 B/s" && tm.rateText(-5) === "0 B/s" && tm.rateText(undefined) === "0 B/s");
            shell.check("netText reads like the label: 1.2 MB/s down 300 KB/s up", "NET " + tm.netText({ down: 1.2 * 1048576, up: 300 * 1024 }) === "NET 1.2 MB/s down 300 KB/s up");
            const bars = tm.netBars([0, 524288, 1048576, 2097152]);
            shell.check("netBars: scaled to the busiest sample, 0..1", shell.js(bars) === shell.js([0, 0.25, 0.5, 1]));
            shell.check("netBars: a quiet line stays low (floor 1 MB/s)", tm.netBars([1024, 2048])[1] < 0.01 && tm.netBars([]).length === 0);

            // ---- ports parse / text ----
            const rows = tm.parsePorts('[{"proto":"tcp","port":22,"addr":"0.0.0.0","pid":812,"name":"sshd"},{"proto":"udp","port":53,"addr":"127.0.0.53","pid":null,"name":""},{"port":"x"},5,{"proto":"tcp","port":80,"addr":"::","pid":2.5,"name":3}]');
            shell.check("parsePorts keeps rows, nulls a bad pid, drops junk", rows.length === 3 && rows[0].pid === 812 && rows[1].pid === null && rows[2].pid === null && rows[2].name === "");
            shell.check("parsePorts of junk is []", tm.parsePorts("oops").length === 0 && tm.parsePorts("{}").length === 0 && tm.parsePorts("").length === 0);
            shell.check("portOwnerText: name and pid, or why not", tm.portOwnerText(rows[0]) === "sshd (812)" && tm.portOwnerText(rows[1]) === "owner not visible");

            // ---- the window ----
            tm.visible = true;
            tc.wait(200);
            tm.sample = shell.sampleFor(900);
            shell.check("core effects come from the sample's core field, one list (procs.py)", tm.coreEffect("pipewire") === "all sound stops" && tm.coreEffect("zen") === "" && tm.coreEffect("nothing") === "");
            shell.check("the Ports tab is in the tab list and the View menu", tm.tabList.map(t => t.key).join() === "apps,processes,ports,performance" && tm.viewModel().some(m => m.text === "Ports"));
            tm.showTab("ports");
            tm.ports = [
                { proto: "tcp", port: 22, addr: "0.0.0.0", pid: 812, name: "sshd" },
                { proto: "tcp", port: 8080, addr: "127.0.0.1", pid: 2002, name: "zen" },
                { proto: "udp", port: 5353, addr: "::", pid: 1700, name: "pipewire" },
                { proto: "tcp", port: 631, addr: "127.0.0.1", pid: null, name: "" },
                { proto: "tcp", port: 9000, addr: "0.0.0.0", pid: 900, name: "python3" }
            ];
            tm.portsLoaded = true;
            tc.wait(100);
            shell.check("the Ports tab shows its rows", tm.tab === "ports" && tm.selectedPort.port === 22);
            shell.check("End task is off for a port owned by someone else", tm.selectedPortGroup === null && shell.buttons(tm, "End task").length === 1 && !shell.buttons(tm, "End task")[0].enabled);
            tm.askEnd(false);
            shell.check("asking to end another user's process is refused with a note, nothing asked", tm.confirm === null && tm.notice.indexOf("Not your process") === 0);
            tm.portIndex = 3;
            tc.wait(50);
            shell.check("a port with no visible owner can't be ended", tm.selectedPortGroup === null && !shell.buttons(tm, "End task")[0].enabled);
            tm.portIndex = 4;
            tc.wait(50);
            tm.askEnd(false);
            shell.check("the Task Manager's own helper is refused", tm.confirm === null && tm.notice.indexOf("own helper") >= 0);
            tm.portIndex = 1;
            tc.wait(50);
            shell.check("your own port enables End task and Kill", tm.selectedPortGroup !== null && shell.buttons(tm, "End task")[0].enabled && shell.buttons(tm, "Kill")[0].enabled);
            tc.keyClick(Qt.Key_Delete);
            tc.wait(100);
            shell.check("Delete asks (ConfirmBar, End task), nothing sent yet", tm.confirm !== null && tm.confirm.signal === "TERM" && tm.confirm.pid === 2002 && shell.confirmBars(tm).length === 1 && shell.confirmBars(tm)[0].verb === "End task" && tm.killLog.length === 0);
            shell.check("the question names the port", tm.confirm.text.indexOf("8080") >= 0 && tm.confirm.text.indexOf("zen") >= 0);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(50);
            shell.check("Esc cancels the question", tm.confirm === null && tm.killLog.length === 0);
            tc.keyClick(Qt.Key_Delete);
            tc.wait(50);
            // the process list changes before the answer: the pid is read again; here the pid is gone
            tm.sample = shell.sampleFor(900);
            tm.sample.groups[0].pids = [2002];
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter signals only that one pid (TERM)", shell.js(tm.killLog) === shell.js([{ signal: "TERM", pids: [2002] }]));
            tm.killLog = [];
            tc.keyClick(Qt.Key_Delete);
            tc.wait(50);
            const g = tm.sample.groups[0];
            tm.sample = Object.assign({}, tm.sample, { groups: tm.sample.groups.filter(x => x.name !== "zen") });
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            shell.check("a process that is gone by the confirm gets nothing", tm.killLog.length === 0 && tm.notice.indexOf("already gone") >= 0);
            tm.sample = shell.sampleFor(900);
            tm.portIndex = 2;
            tc.wait(50);
            tm.askEnd(false);
            shell.check("a core process on the Ports tab needs End anyway", tm.confirm !== null && tm.confirm.verb === "End task anyway" && tm.confirm.text.indexOf("core process") >= 0);
            tm.confirm = null;
            tm.askEnd(true);
            shell.check("Kill is a KILL signal with its own verb", tm.confirm.signal === "KILL" && tm.confirm.verb === "Kill anyway");
            tm.confirm = null;

            // ---- Delete on the Apps tab ----
            tm.showTab("apps");
            tm.appIndex = 0;
            tc.wait(50);
            tc.keyClick(Qt.Key_Delete);
            tc.wait(100);
            shell.check("Delete on the Apps tab asks to end the selected window's process", tm.confirm !== null && tm.confirm.pid === 2001 && tm.confirm.verb === "End task" && tm.confirm.text.indexOf("Zen Browser") >= 0 && tm.killLog.length === 0);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(50);
            shell.check("Esc cancels, the window stays open", tm.confirm === null && tm.visible);

            // ---- tabs ----
            tm.showTab("apps");
            tm.cycleTab(1);
            tm.cycleTab(1);
            shell.check("cycling goes Apps, Processes, Ports", tm.tab === "ports");
            tm.cycleTab(1);
            shell.check("... then Performance", tm.tab === "performance");

            // ---- a sample feeds the network history ----
            tm.take(JSON.stringify(shell.sampleFor(900)));
            const s2 = shell.sampleFor(900);
            s2.net = { rx: 1000 + 1048576, tx: 500 + 262144, t: 12 };
            tm.take(JSON.stringify(s2));
            shell.check("two samples give a rate and one history bar", tm.netRate !== null && tm.netRate.down === 524288 && tm.netRaw.length === 1);
            const labelOk = shell.find(tm.contentItem, c => c.visible && c.text === "NET", []).length === 1;
            shell.check("the Performance tab has a NET graph with the live rate label", labelOk && tm.netText(tm.netRate) === "512 KB/s down 128 KB/s up");

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
