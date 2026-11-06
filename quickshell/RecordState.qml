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

    // `record.sh status` / `replay-status` output -> { on, path, since }; broken input gives the "off" value
    function parseStatus(text) {
        try {
            const j = JSON.parse(String(text).trim());
            const on = j.recording === true || j.replaying === true;
            const p = j.file !== undefined ? j.file : j.dir;
            return { on: on, path: on && typeof p === "string" ? p : "", since: on && Number(j.since) > 0 ? Number(j.since) : 0 };
        } catch (e) {
            return { on: false, path: "", since: 0 };
        }
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

    // geometry: WxH+X+Y for region / window, the output name for screen
    function start(mode, mic, geometry, cls) {
        if (!active || recording || startProc.running)
            return;
        pendingMode = mode;
        startProc.command = startCommand(script, mode, mic, dir, geometry, cls);
        startProc.running = true;
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
        elapsed = s.on ? Math.max(0, Math.floor(Date.now() / 1000 - s.since)) : 0;
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
        id: startProc
        stdout: StdioCollector {}
        stderr: StdioCollector { id: startErr }
        onExited: code => {
            if (code === 0) {
                root.missing = false;
                statusProc.running = true;
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
