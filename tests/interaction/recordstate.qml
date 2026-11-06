// Pure-function tests for RecordState.qml (label, status parsing, geometry, command building as arrays). No tool runs:
// the runner sets QS_NO_APPLY, so the singleton's Processes and timers stay off. The script itself is tested by
// tests/record-script-test.py (fake gpu-screen-recorder). Run by scripts/run-interaction-tests.py.
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

    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
    Component.onCompleted: {
        const R = RecordState;
        shell.check("label: seconds", R.formatLabel(42) === "0:42");
        shell.check("label: zero", R.formatLabel(0) === "0:00");
        shell.check("label: minutes", R.formatLabel(62) === "1:02");
        shell.check("label: just under an hour", R.formatLabel(3599) === "59:59");
        shell.check("label: hours", R.formatLabel(3723) === "1:02:03");
        shell.check("label: ten hours", R.formatLabel(36000) === "10:00:00");
        shell.check("label: junk and negatives give 0:00", R.formatLabel(-5) === "0:00" && R.formatLabel("x") === "0:00" && R.formatLabel(undefined) === "0:00");
        shell.check("label: fractions round down", R.formatLabel(61.9) === "1:01");

        const on = R.parseStatus('{"recording":true,"file":"/v/a b.mp4","since":1700000000}');
        shell.check("status: recording", on.on === true && on.path === "/v/a b.mp4" && on.since === 1700000000);
        const off = R.parseStatus('{"recording":false,"file":"","since":0}\n');
        shell.check("status: not recording", off.on === false && off.path === "" && off.since === 0);
        const rp = R.parseStatus('{"replaying":true,"dir":"/v","since":5}');
        shell.check("status: replay form", rp.on === true && rp.path === "/v" && rp.since === 5);
        shell.check("status: escaped quote in the path", R.parseStatus('{"recording":true,"file":"/v/a\\"b.mp4","since":1}').path === '/v/a"b.mp4');
        shell.check("status: broken or empty input is off", R.parseStatus("").on === false && R.parseStatus("not json").on === false && R.parseStatus("{").on === false);
        shell.check("status: a missing since is 0", R.parseStatus('{"recording":true,"file":"x"}').since === 0);

        const pz = R.parseStatus('{"recording":true,"file":"/v/a.mp4","since":100,"paused":true,"idle":12}');
        shell.check("status: paused and idle", pz.paused === true && pz.idle === 12);
        shell.check("status: not paused by default", on.paused === false && on.idle === 0 && off.paused === false);
        shell.check("status: idle and paused only count while recording", R.parseStatus('{"recording":false,"paused":true,"idle":9}').paused === false);
        shell.check("elapsed: leaves the paused time out", R.elapsedFor(160, 100, 20) === 40);
        shell.check("elapsed: never negative", R.elapsedFor(100, 100, 30) === 0 && R.elapsedFor(50, 100, 0) === 0);

        const good = R.parseCheck('{"ok":true,"problems":[],"warnings":["Under 2 GB free"]}');
        shell.check("check: ok with a warning", good.ok === true && good.problems.length === 0 && good.warnings[0] === "Under 2 GB free");
        const bad = R.parseCheck('{"ok":false,"problems":["No microphone found"],"warnings":[]}');
        shell.check("check: a problem blocks", bad.ok === false && bad.problems[0] === "No microphone found");
        shell.check("check: ok:true with a problem still blocks", R.parseCheck('{"ok":true,"problems":["x"],"warnings":[]}').ok === false);
        shell.check("check: unreadable output never blocks", R.parseCheck("").ok === true && R.parseCheck("oops").ok === true);
        shell.check("check: junk entries are dropped", R.parseCheck('{"ok":true,"problems":[1,null],"warnings":[{}]}').problems.length === 0);
        shell.check("checkCommand: all becomes screen, mic as 0 / 1", R.checkCommand("s.sh", "all", true, "~/V").join("|") === "s.sh|check|screen|1|~/V");

        const none = { ok: true, problems: [], warnings: [] };
        shell.check("hint: shot region", R.hintText("region", false, none) === "Drag to select an area. Esc cancels.");
        shell.check("hint: shot window", R.hintText("window", false, none) === "Click a window to capture it. Esc cancels.");
        shell.check("hint: record region", R.hintText("region", true, none) === "Drag to select an area to record. Esc cancels.");
        shell.check("hint: record window", R.hintText("window", true, none) === "Click a window to record it. Esc cancels.");
        shell.check("hint: record screen and all point at Start", R.hintText("screen", true, none) === R.hintText("all", true, none) && R.hintText("screen", true, none).indexOf("Start") > 0);
        shell.check("hint: a problem wins while recording is armed", R.hintText("region", true, bad) === "No microphone found" && R.hintIsProblem(true, bad) === true);
        shell.check("hint: a problem is ignored in shot mode", R.hintText("region", false, bad) === "Drag to select an area. Esc cancels." && R.hintIsProblem(false, bad) === false);
        shell.check("hint: a warning is appended", R.hintText("region", true, good) === "Drag to select an area to record. Esc cancels. Under 2 GB free.");

        shell.check("geometry: WxH+X+Y", R.geometry(10, 20, 300, 200) === "300x200+10+20");
        shell.check("geometry: rounds and clamps", R.geometry(-4, 1.6, 0.2, 99.5) === "1x100+0+2");

        const cmd = R.startCommand("/s/record.sh", "region", true, "~/Videos", "300x200+10+20", "firefox");
        shell.check("start command is an array", Array.isArray(cmd) && cmd.length === 7 && cmd.join("|") === "/s/record.sh|start|region|1|~/Videos|300x200+10+20|firefox");
        shell.check("start command: mic off and empty class", R.startCommand("/s/r.sh", "screen", false, "/v", "DP-1", "").join("|") === "/s/r.sh|start|screen|0|/v|DP-1|recording");
        const evil = "x'; touch /tmp/p; $(id) \"";
        const hc = R.startCommand("/s/r.sh", "region", false, evil, "1x1+0+0", evil);
        shell.check("hostile dir and class stay single array entries", hc.length === 7 && hc[4] === evil && hc[6] === evil);
        shell.check("replay command", R.replayCommand("/s/r.sh", "/v", 30, "DP-2").join("|") === "/s/r.sh|replay-start|/v|30|DP-2");
        shell.check("replay command: no output means screen", R.replayCommand("/s/r.sh", "/v", 30, "").join("|") === "/s/r.sh|replay-start|/v|30|screen");

        shell.check("expandDir", R.expandDir("~/Videos", "/h") === "/h/Videos" && R.expandDir("~", "/h") === "/h" && R.expandDir("/a/~b", "/h") === "/a/~b");

        const t = R.toastCommand("Recording saved", "a.mp4", "/v/a.mp4");
        shell.check("toast with an Open action keeps title, body and file as arguments", t[0] === "sh" && t[1] === "-c" && t[3] === "sh" && t.slice(4).join("|") === "Recording saved|a.mp4|/v/a.mp4" && t[2].indexOf("a.mp4") < 0 && t[2].indexOf("-A default=Open") > 0);
        shell.check("toast without a file is a plain notify-send", R.toastCommand("Replay isn't running", "", "").join("|") === "notify-send|-a|Recording|Replay isn't running|");
        shell.check("basename", R.basename("/v/a b.mp4") === "a b.mp4");
        shell.check("inactive under QS_NO_APPLY", R.active === false && R.recording === false && R.replaying === false);

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
}
