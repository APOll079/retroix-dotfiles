pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording and the replay buffer. Everything goes through scripts/record.sh (a thin wrapper over
// gpu-screen-recorder); this singleton only holds the state (recording, replaying, elapsed) and shows the toasts.
// recording / file / since come from `record.sh status`, polled once at start (so a reload picks an ongoing
// recording up) and then every second while recording. The command building, label formatting and status parsing
// are pure functions so tests can drive them. Not started when QS_NO_APPLY is set (the test harness), so tests
// never exec real tools. shell.qml must reference RecordState once so it starts (singletons are lazy).
Singleton {
    id: root

    readonly property bool active: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    readonly property string script: Quickshell.shellDir + "/scripts/record.sh"
    readonly property string dir: Config.settings.record.dir
    readonly property int replaySeconds: Config.settings.record.replaySeconds

    property bool recording: false
    property string file: ""
    property real since: 0
    property int elapsed: 0
    readonly property string label: formatLabel(elapsed)
    property bool missing: false          // gpu-screen-recorder is not installed (record.sh exited 2)
    property bool paused: false
    property int idle: 0                  // seconds spent paused so far (from `status`); elapsed leaves them out
    // The last preflight (`record.sh check`): problems block, warnings don't. Until the first answer nothing blocks.
    property var preflight: ({ ok: true, problems: [], warnings: [] })
    property var queuedCheck: null
    property var startArgs: null
    property bool replaying: false
    property string replayDir: ""
    property string pendingMode: ""

    // ---- pure helpers ----

    // 42 -> "0:42", 62 -> "1:02", 3723 -> "1:02:03"; anything that is not a number >= 0 gives "0:00"
    function formatLabel(sec) {
        const s = Math.max(0, Math.floor(Number(sec)) || 0);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        const two = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + two(m) + ":" + two(r) : m + ":" + two(r);
    }

    // `record.sh status` / `replay-status` output -> { on, path, since, paused, idle }; broken input gives the "off" value
    function parseStatus(text) {
        try {
            const j = JSON.parse(String(text).trim());
            const on = j.recording === true || j.replaying === true;
            const p = j.file !== undefined ? j.file : j.dir;
            return {
                on: on,
                path: on && typeof p === "string" ? p : "",
                since: on && Number(j.since) > 0 ? Number(j.since) : 0,
                paused: on && j.paused === true,
                idle: on && Number(j.idle) > 0 ? Math.floor(Number(j.idle)) : 0
            };
        } catch (e) {
            return { on: false, path: "", since: 0, paused: false, idle: 0 };
        }
    }

    // Seconds recorded: wall time since the start, minus the time spent paused
    function elapsedFor(now, since, idle) {
        return Math.max(0, Math.floor(now - since - idle));
    }

    // `record.sh check` output -> { ok, problems, warnings }. If the check itself can't be read it doesn't block
    // anything (a broken preflight must never stop a recording that would have worked).
    function parseCheck(text) {
        try {
            const j = JSON.parse(String(text).trim());
            const arr = v => Array.isArray(v) ? v.filter(x => typeof x === "string") : [];
            const problems = arr(j.problems);
            return { ok: j.ok === true && problems.length === 0, problems: problems, warnings: arr(j.warnings) };
        } catch (e) {
            return { ok: true, problems: [], warnings: [] };
        }
    }

    // The overlay's hint line: what the next click does, or the first problem (only while Record is armed)
    function hintText(mode, record, pre) {
        if (record && pre && pre.problems && pre.problems.length > 0)
            return pre.problems[0];
        let t;
        if (!record)
            t = mode === "region" ? "Drag to select an area. Esc cancels." : mode === "window" ? "Click a window to capture it. Esc cancels." : "Picking this captures it at once.";
        else
            t = mode === "region" ? "Drag to select an area to record. Esc cancels." : mode === "window" ? "Click a window to record it. Esc cancels." : "Records this screen. Press Start or Enter.";
        if (record && pre && pre.warnings && pre.warnings.length > 0)
            t += " " + pre.warnings[0] + ".";
        return t;
    }
    function hintIsProblem(record, pre) {
        return !!record && !!pre && !!pre.problems && pre.problems.length > 0;
    }

    function checkCommand(script, mode, mic, dir) {
        return [script, "check", mode === "all" ? "screen" : mode, mic ? "1" : "0", dir];
    }

    // Geometry for the script from a rectangle in global pixels: "WxH+X+Y" (sizes at least 1, offsets whole)
    function geometry(x, y, w, h) {
        return Math.max(1, Math.round(w)) + "x" + Math.max(1, Math.round(h)) + "+" + Math.max(0, Math.round(x)) + "+" + Math.max(0, Math.round(y));
    }

    // Window class as shot-name.sh wants it; empty means "recording"
    function className(cls) {
        const c = String(cls || "");
        return c === "" ? "recording" : c;
    }

    // Argument arrays (never a shell string). mode: region | window | screen; target: WxH+X+Y, or the output name for screen
    function startCommand(script, mode, mic, dir, target, cls) {
        return [script, "start", mode, mic ? "1" : "0", dir, target, className(cls)];
    }
    function replayCommand(script, dir, seconds, output) {
        return [script, "replay-start", dir, String(Math.round(seconds)), output && output !== "" ? output : "screen"];
    }

    function expandDir(dir, home) {
        if (dir === "~")
            return home;
        return dir.indexOf("~/") === 0 ? home + dir.substring(1) : dir;
    }

    // notify-send with an Open action, run through sh so the chosen action id can be read; the arguments
    // (title, body, file) are positional parameters, never part of the script text
    function toastCommand(title, body, file) {
        if (!file)
            return ["notify-send", "-a", "Recording", title, body];
        return ["sh", "-c", 'a=$(notify-send -a Recording -A default=Open "$1" "$2"); [ "$a" = default ] && xdg-open "$3"', "sh", title, body, file];
    }

    function basename(path) {
        return String(path).split("/").pop();
    }

    // ---- live part ----

    function toast(title, body, file) {
        Quickshell.execDetached(toastCommand(title, body, file));
    }

    // Preflight for the overlay: asks `record.sh check`, the answer lands in `preflight`. A second ask while one runs
    // is queued (only the newest matters).
    function check(mode, mic) {
        if (!active)
            return;
        if (checkProc.running) {
            queuedCheck = { mode: mode, mic: mic };
            return;
        }
        checkProc.thenStart = false;
        checkProc.command = checkCommand(script, mode, mic, dir);
        checkProc.running = true;
    }

    // geometry: WxH+X+Y for region / window, the output name for screen. The preflight runs once more first.
    function start(mode, mic, geometry, cls) {
        if (!active || recording || startProc.running || checkProc.running)
            return;
        pendingMode = mode;
        startArgs = { mode: mode, mic: mic, geometry: geometry, cls: cls };
        checkProc.thenStart = true;
        checkProc.command = checkCommand(script, mode, mic, dir);
        checkProc.running = true;
    }

    function togglePause() {
        if (!active || !recording || pauseProc.running)
            return;
        pauseProc.running = true;
    }

    function stop() {
        if (!active || !recording || stopProc.running)
            return;
        stopProc.running = true;
    }

    function replayStart(output) {
        if (!active || replaying || replayStartProc.running)
            return;
        replayStartProc.command = replayCommand(script, dir, replaySeconds, output);
        replayStartProc.running = true;
    }

    function replayStop() {
        if (!active || !replaying || replayStopProc.running)
            return;
        replayStopProc.running = true;
    }

    function replaySave() {
        if (!active || replaySaveProc.running)
            return;
        replaySaveProc.running = true;
    }

    function replayToggle(output) {
        if (replaying)
            replayStop();
        else
            replayStart(output);
    }

    function applyStatus(text) {
        const s = parseStatus(text);
        recording = s.on;
        file = s.path;
        since = s.since;
        paused = s.paused;
        idle = s.idle;
        elapsed = s.on ? elapsedFor(Date.now() / 1000, s.since, s.idle) : 0;
    }

    onActiveChanged: {
        if (active) {
            statusProc.running = true;
            replayStatusProc.running = true;
        }
    }

    Process {
        id: statusProc
        command: [root.script, "status"]
        stdout: StdioCollector { onStreamFinished: root.applyStatus(text) }
    }

    Process {
        id: replayStatusProc
        command: [root.script, "replay-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = root.parseStatus(text);
                root.replaying = s.on;
                root.replayDir = s.path;
            }
        }
    }

    Process {
        id: checkProc
        property bool thenStart: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.preflight = root.parseCheck(text);
                if (checkProc.thenStart) {
                    checkProc.thenStart = false;
                    const a = root.startArgs;
                    if (!root.preflight.ok) {
                        root.toast("Recording blocked", root.preflight.problems[0], "");
                    } else if (a) {
                        startProc.command = root.startCommand(root.script, a.mode, a.mic, root.dir, a.geometry, a.cls);
                        startProc.running = true;
                    }
                }
            }
        }
        onExited: {
            if (root.queuedCheck) {
                const q = root.queuedCheck;
                root.queuedCheck = null;
                root.check(q.mode, q.mic);
            }
        }
    }

    Process {
        id: pauseProc
        command: [root.script, "pause"]
        onExited: statusProc.running = true
    }

    // A recorder that dies right after starting (a wrong portal, no permission) is reported with its own last line
    Timer {
        id: verifyTimer
        interval: 1500
        onTriggered: verifyProc.running = true
    }
    Process {
        id: verifyProc
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyStatus(text);
                if (!root.recording)
                    errProc.running = true;
            }
        }
    }
    Process {
        id: errProc
        command: [root.script, "error"]
        stdout: StdioCollector {
            onStreamFinished: root.toast("Recording stopped right away", text.trim() || "gpu-screen-recorder quit without a message", "")
        }
    }

    Process {
        id: startProc
        stdout: StdioCollector {}
        stderr: StdioCollector { id: startErr }
        onExited: code => {
            if (code === 0) {
                root.missing = false;
                statusProc.running = true;
                verifyTimer.restart();
            } else if (code === 2) {
                root.missing = true;
                root.toast("Recording failed", "gpu-screen-recorder is not installed", "");
            } else {
                root.toast("Recording failed", startErr.text.trim().split("\n")[0] || "unknown error", "");
            }
        }
    }

    Process {
        id: stopProc
        command: [root.script, "stop"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                root.recording = false;
                root.paused = false;
                root.idle = 0;
                root.elapsed = 0;
                root.file = "";
                if (f !== "")
                    root.toast("Recording saved", root.basename(f), f);
            }
        }
    }

    Process {
        id: replayStartProc
        stderr: StdioCollector { id: replayErr }
        onExited: code => {
            if (code === 0) {
                root.missing = false;
                replayStatusProc.running = true;
            } else if (code === 2) {
                root.missing = true;
                root.toast("Replay failed", "gpu-screen-recorder is not installed", "");
            } else {
                root.toast("Replay failed", replayErr.text.trim().split("\n")[0] || "unknown error", "");
            }
        }
    }

    Process {
        id: replayStopProc
        command: [root.script, "replay-stop"]
        onExited: root.replaying = false
    }

    // Save: SIGUSR1 to the replay process (exit 1 = nothing armed), then give gsr a moment to write the clip
    Process {
        id: replaySaveProc
        command: [root.script, "replay-save"]
        onExited: code => {
            if (code === 0)
                saveWait.restart();
            else
                root.toast("Replay isn't running", "", "");
        }
    }

    Timer {
        id: saveWait
        interval: 1500
        onTriggered: lastProc.running = true
    }

    Process {
        id: lastProc
        command: [root.script, "replay-last", root.expandDir(root.dir, Quickshell.env("HOME"))]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim();
                const d = root.expandDir(root.dir, Quickshell.env("HOME"));
                root.toast("Replay saved", n, n !== "" ? d + "/" + n : "");
            }
        }
    }

    Timer {
        interval: 1000
        running: root.active && root.recording
        repeat: true
        onTriggered: { if (!statusProc.running) statusProc.running = true; }
    }
}
