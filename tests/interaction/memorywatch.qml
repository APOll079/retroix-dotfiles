// Decision-function tests for the low-memory toast (MemoryWatch.qml): pure values and times, no tools run
// (the runner sets QS_NO_APPLY, so the singleton's timers and Processes stay off). Run by scripts/run-interaction-tests.py.
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
        const MW = MemoryWatch;
        const TH = 90, RE = 85, CD = 30 * 60000, MIN = 60000;
        // run a series of [value, minutes] samples; returns the list of sample indexes that fired
        function run(samples, th, re, cd) {
            let s = MW.newState();
            const fired = [];
            samples.forEach((smp, i) => {
                const r = MW.step(s, smp[0], th, re, cd, smp[1] * MIN);
                s = r.state;
                if (r.fire)
                    fired.push(i);
            });
            return fired.join(",");
        }

        shell.check("first crossing fires", run([[50, 0], [92, 1]], TH, RE, CD) === "1");
        shell.check("at the threshold exactly does not fire", run([[90, 0]], TH, RE, CD) === "");
        shell.check("staying above never repeats", run([[92, 0], [95, 40], [99, 100]], TH, RE, CD) === "0");
        shell.check("dipping to within 5 points does not re-arm", run([[92, 0], [88, 40], [92, 80]], TH, RE, CD) === "0");
        shell.check("dropping 5 points below and rising before the cooldown does not fire", run([[92, 0], [80, 5], [92, 10]], TH, RE, CD) === "0");
        shell.check("dropping, then rising after the cooldown fires again", run([[92, 0], [80, 5], [92, 40]], TH, RE, CD) === "0,2");
        shell.check("dropped before the cooldown, still low once it passed, then rising fires", run([[92, 0], [80, 5], [80, 35], [92, 36]], TH, RE, CD) === "0,3");
        shell.check("a low sample is remembered through a later dip above the margin", run([[92, 0], [80, 5], [88, 35], [92, 36]], TH, RE, CD) === "0,3");
        shell.check("starting above the threshold fires once", run([[95, 0], [96, 1], [97, 2]], TH, RE, CD) === "0");
        shell.check("shouldToast reads without changing state", (() => {
            const s = MW.newState();
            return MW.shouldToast(s, 95, TH, RE, CD, 0) === true && MW.shouldToast(s, 95, TH, RE, CD, 0) === true;
        })());
        shell.check("/tmp uses its own state and a 10 percent margin", (() => {
            const th = 4e9, re = 3.6e9;
            return run([[5e9, 0], [3.7e9, 40], [5e9, 41]], th, re, CD) === "0"
                && run([[5e9, 0], [3.5e9, 5], [5e9, 40]], th, re, CD) === "0,2";
        })());
        shell.check("RAM and /tmp states are independent", (() => {
            let ram = MW.newState(), tmp = MW.newState();
            ram = MW.step(ram, 95, TH, RE, CD, 0).state;
            return MW.step(tmp, 5e9, 4e9, 3.6e9, CD, MIN).fire === true && MW.step(ram, 96, TH, RE, CD, MIN).fire === false;
        })());

        // disabled: the live part is gated by `active`, which follows settings.memoryWatch.enabled
        shell.check("enabled setting is read (default true) and QS_NO_APPLY keeps the harness inactive", Config.settings.memoryWatch.enabled === true && MW.active === false);

        shell.check("formatBytes 7.2 GB", MW.formatBytes(7.2e9) === "7.2 GB");
        shell.check("formatBytes 6.1 GB from bytes", MW.formatBytes(6123456789) === "6.1 GB");
        shell.check("formatBytes below 1 GB is MB", MW.formatBytes(512e6) === "512 MB");
        shell.check("formatBytes junk is ?", MW.formatBytes(NaN) === "?" && MW.formatBytes(-1) === "?" && MW.formatBytes(undefined) === "?");

        const ok = MW.parseDf("Type 1B-blocks\ntmpfs 7730000000\n");
        shell.check("parseDf reads a tmpfs line", ok !== null && ok.fstype === "tmpfs" && ok.used === 7730000000);
        const ext = MW.parseDf("Type Used\next4 123\n");
        shell.check("parseDf returns the fstype of a non-tmpfs (the caller skips it)", ext !== null && ext.fstype === "ext4");
        shell.check("parseDf junk gives null", MW.parseDf("") === null && MW.parseDf("garbage") === null
            && MW.parseDf("Type Used\ntmpfs abc") === null && MW.parseDf("Type Used\ntmpfs 1 2 3") === null && MW.parseDf("Type Used\n\n") === null);

        const big = MW.biggestGroup('{"groups":[{"name":"a","mem":100},{"name":"zen","mem":6100000000},{"name":"b","mem":5}]}');
        shell.check("biggestGroup picks the largest by mem", big !== null && big.name === "zen" && big.mem === 6100000000);
        shell.check("biggestGroup survives junk", MW.biggestGroup("") === null && MW.biggestGroup("{}") === null && MW.biggestGroup("[1]") === null && MW.biggestGroup('{"groups":[]}') === null);
        shell.check("ramBody with a name", MW.ramBody(92, big) === "RAM 92% - biggest: zen (6.1 GB)");
        shell.check("ramBody without a name", MW.ramBody(92, null) === "RAM 92%");
        shell.check("tmpTitle", MW.tmpTitle(7.2e9) === "/tmp is using 7.2 GB of RAM");

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
