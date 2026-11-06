// Disk warning logic (DiskWatch.qml): re-arm step, mount expansion, parsing of the disk-usage.sh / disk-health.sh JSON,
// toast plans. Pure values and times; no tool runs (the runner sets QS_NO_APPLY). The scripts themselves are tested
// with fake df / smartctl / lsblk by tests/script_disk.py. Run by scripts/run-interaction-tests.py.
import QtQuick
import Quickshell

ShellRoot {
    id: shell
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    Component.onCompleted: {
        const DW = DiskWatch;
        const J = JSON.stringify;
        const MIN = 60000, CD = 60 * MIN;

        function run(samples, th, cd) {
            let s = DW.newState();
            const fired = [];
            samples.forEach((smp, i) => {
                const r = DW.step(s, smp[0], th, th - 5, cd, smp[1] * MIN);
                s = r.state;
                if (r.fire)
                    fired.push(i);
            });
            return fired.join(",");
        }
        shell.check("step: first crossing fires, at the threshold does not", run([[50, 0], [93, 5]], 90, CD) === "1" && run([[90, 0]], 90, CD) === "");
        shell.check("step: staying above never repeats", run([[93, 0], [95, 100], [99, 500]], 90, CD) === "0");
        shell.check("step: dipping to 86 (within 5) does not re-arm", run([[93, 0], [86, 70], [93, 80]], 90, CD) === "0");
        shell.check("step: dropping to 85 and rising after the cooldown fires again", run([[93, 0], [85, 5], [93, 70]], 90, CD) === "0,2");
        shell.check("step: dropping to 85 but rising before the cooldown does not", run([[93, 0], [85, 5], [93, 30]], 90, CD) === "0");
        shell.check("unreachableDue: never, too soon, due", DW.unreachableDue(undefined, CD, 5) && !DW.unreachableDue(100, CD, 100 + 30 * MIN) && DW.unreachableDue(100, CD, 100 + CD));

        shell.check("expandMounts: ~ and ~/x use HOME, dupes and junk dropped", J(DW.expandMounts(["/", "~", "~/x", "/", "", 5, "/mnt/disk1"], "/home/u")) === J(["/", "/home/u", "/home/u/x", "/mnt/disk1"]));
        shell.check("expandMounts: ~user is left alone, missing list is empty", J(DW.expandMounts(["~bob"], "/h")) === J(["~bob"]) && DW.expandMounts(undefined, "/h").length === 0);

        const usageJson = '[{"mount":"/","usedPercent":93,"size":1000000000000,"used":930000000000,"status":"ok"},'
            + '{"mount":"/mnt/disk1","usedPercent":null,"size":null,"used":null,"status":"unreachable"},'
            + '{"mount":"/mnt/disk2","usedPercent":null,"size":null,"used":null,"status":"missing"},'
            + '{"mount":"bad","usedPercent":null,"size":1,"used":1,"status":"ok"},{"nomount":1},{"mount":"x","status":"weird"}]';
        const u = DW.parseUsage(usageJson);
        shell.check("parseUsage: keeps the three good entries, drops the broken ones", u.length === 3 && u[0].mount === "/" && u[0].usedPercent === 93 && u[1].status === "unreachable" && u[2].status === "missing");
        shell.check("parseUsage: junk gives []", DW.parseUsage("").length === 0 && DW.parseUsage("{}").length === 0 && DW.parseUsage("nope").length === 0);
        shell.check("parseUsage: a mount name with a quote and backslash survives", DW.parseUsage('[{"mount":"/a\\"b\\\\c","usedPercent":1,"size":2,"used":1,"status":"ok"}]')[0].mount === "/a\"b\\c");

        shell.check("formatBytes", DW.formatBytes(930e9) === "930 GB" && DW.formatBytes(1.8e12) === "1.8 TB" && DW.formatBytes(512e6) === "512 MB" && DW.formatBytes(NaN) === "?");

        const p1 = DW.plan(u, {}, {}, 90, CD, 1000);
        shell.check("plan: one disk toast and one quiet unreachable toast, missing is silent", p1.toasts.length === 2);
        shell.check("plan: disk toast text", J(p1.toasts[0]) === J(["notify-send", "-a", "Disk", "/ is 93% full", "930 GB of 1.0 TB used"]));
        shell.check("plan: unreachable toast is low urgency", p1.toasts[1].includes("-u") && p1.toasts[1].includes("low") && p1.toasts[1][p1.toasts[1].length - 2] === "/mnt/disk1 is not responding");
        const p2 = DW.plan(u, p1.states, p1.unreachableAt, 90, CD, 1000 + 5 * MIN);
        shell.check("plan: the next round 5 minutes later toasts nothing (no storm)", p2.toasts.length === 0);
        const p3 = DW.plan(u, p2.states, p2.unreachableAt, 90, CD, 1000 + 61 * MIN);
        shell.check("plan: unreachable may toast again after the cooldown, the full disk does not", p3.toasts.length === 1 && p3.toasts[0].includes("low"));
        shell.check("plan: input states are not mutated", J(p1.states) !== J({}) && J(DW.plan(u, {}, {}, 90, CD, 1000).states) === J(p1.states));
        const hostile = DW.plan([{ mount: "/a; rm -rf ~ $(x)", usedPercent: 99, size: 100, used: 99, status: "ok" }], {}, {}, 90, CD, 0);
        shell.check("plan: a hostile mount name stays one argument", hostile.toasts[0][3] === "/a; rm -rf ~ $(x) is 99% full" && hostile.toasts[0].length === 5);

        const hJson = '[{"dev":"sda","passed":true,"status":"ok"},{"dev":"sdb","passed":false,"status":"failed"},{"dev":"nvme0n1","passed":null,"status":"permission"},{"dev":"BAD;x","passed":null,"status":"ok"},{"dev":"zram0","passed":null,"status":"missing"}]';
        const h = DW.parseHealth(hJson);
        shell.check("parseHealth: bad device names are dropped", h.length === 4 && h[1].passed === false && h[2].passed === null && h[2].status === "permission");
        shell.check("parseHealth: junk gives []", DW.parseHealth("").length === 0 && DW.parseHealth("{").length === 0);
        const ph = DW.planHealth(h);
        shell.check("planHealth: failed disk gives a critical toast, permission only flags", ph.toasts.length === 1 && J(ph.toasts[0]) === J(["notify-send", "-a", "Disk", "-u", "critical", "sdb reports SMART failure", "Back up the disk and replace it."]) && ph.needsPermission === true);
        shell.check("planHealth: all ok or missing is silent", (() => {
            const q = DW.planHealth(DW.parseHealth('[{"dev":"sda","passed":true,"status":"ok"},{"dev":"sdb","passed":null,"status":"missing"}]'));
            return q.toasts.length === 0 && q.needsPermission === false;
        })());
        shell.check("permission toast text", J(DW.permissionToast) === J(["notify-send", "-a", "Disk", "SMART needs permission", "See docs/desktop.md"]));

        shell.check("settings: defaults read, harness inactive", Config.settings.diskWatch.percent === 90 && Config.settings.diskWatch.cooldownMinutes === 60 && J(Config.settings.diskWatch.mounts) === J(["/", "~", "/mnt/disk1", "/mnt/disk2"]) && DW.active === false && DW.smartNeedsPermission === false);

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
