// Decision-function tests for AudioState.qml (mic key, output-switch toast, remembered app volumes, noise filter label)
// and NotificationStore.showsToast (Do Not Disturb while sharing the screen): pure values, no tool runs and PipeWire is
// never written (the runner sets QS_NO_APPLY, so AudioState.live is false). The remembered volumes are written to the
// runner's scratch state dir. Run by scripts/run-interaction-tests.py.
import QtQuick
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

    FileView {
        id: volFile
        blockLoading: true
        path: Quickshell.statePath("app-volumes.json")
    }

    Component.onCompleted: starter.start()
    Timer { id: starter; interval: 400; onTriggered: shell.run() }
    Timer { id: finish; interval: 1500; onTriggered: shell.finish() }

    function run() {
        const A = AudioState;
        // ---- mic key ----
        check("parseMuted: muted", A.parseMuted('{"muted":true}\n') === true);
        check("parseMuted: not muted", A.parseMuted('{"muted":false}') === false);
        check("parseMuted: anything else is null", A.parseMuted("") === null && A.parseMuted("nope") === null && A.parseMuted('{"muted":"yes"}') === null && A.parseMuted("{}") === null);
        check("toggleMic does nothing under the harness (no process)", A.live === false && (A.toggleMic(), true));

        // ---- output switch toast ----
        const dac = { name: "alsa_output.usb-dac", description: "DM15 DAC" };
        const bt = { name: "bluez_output.AA", description: "Headphones" };
        check("output: no toast at the start (no previous output)", A.outputSwitchText(null, dac) === "");
        check("output: the same device again is no toast", A.outputSwitchText(dac, { name: dac.name, description: "renamed" }) === "");
        check("output: a different device toasts its description", A.outputSwitchText(dac, bt) === "Sound now plays on Headphones");
        check("output: the device going away is no toast", A.outputSwitchText(bt, null) === "");
        check("output: back to the first one after it was gone toasts again", A.outputSwitchText(bt, dac) === "Sound now plays on DM15 DAC");
        // a sequence the way checkOutput walks it: [start dac, dac, bt, bt, none, dac] announces on bt and dac only
        let last = null, said = [];
        for (const cur of [dac, dac, bt, bt, null, dac]) {
            const t = A.outputSwitchText(last, cur);
            if (cur)
                last = cur;
            if (t !== "")
                said.push(cur.description);
        }
        check("output: one toast per change over a whole sequence", said.join("|") === "Headphones|DM15 DAC");

        // ---- remembered app volumes ----
        check("rememberAppVolumes defaults to true (key missing)", A.rememberVolumes === true);
        let m = A.rememberVolume({}, "Firefox", 0.456);
        check("remember: stored by app name, two decimals", m.Firefox === 0.46);
        m = A.rememberVolume(m, "Spotify", 1.7);
        check("remember: clamped to 0..1, other entries kept", m.Spotify === 1 && m.Firefox === 0.46);
        check("remember: the input map is not changed", A.rememberVolume(m, "X", 0.2).X === 0.2 && m.X === undefined);
        check("remember: Unknown, empty and non-numbers are skipped", Object.keys(A.rememberVolume({}, "Unknown", 0.5)).length === 0 && Object.keys(A.rememberVolume({}, "", 0.5)).length === 0 && Object.keys(A.rememberVolume({}, "A", "x")).length === 0);
        check("apply: a stream of a remembered app with another volume gets the saved one", A.volumeToApply(m, "Firefox", 1.0) === 0.46);
        check("apply: same volume (within 1 point) is left alone", A.volumeToApply(m, "Firefox", 0.455) === null);
        check("apply: an app never moved is left alone", A.volumeToApply(m, "Vesktop", 1.0) === null);
        check("apply: a broken saved value is ignored", A.volumeToApply({ A: "x", B: 7, C: -1 }, "A", 0.5) === null && A.volumeToApply({ B: 7 }, "B", 0.5) === null && A.volumeToApply({ C: -1 }, "C", 0.5) === null);
        check("apply: names like toString are not entries", A.volumeToApply({}, "toString", 0.5) === null);
        A.rememberAppVolume("Firefox", 0.4);
        A.rememberAppVolume("Firefox", 0.35);
        A.rememberAppVolume("Mpv", 0.8);
        check("rememberAppVolume: pending until the save timer, readable at once", A.savedVolumes.Firefox === 0.35 && A.savedVolumes.Mpv === 0.8);
        finish.start();

        // ---- noise filter ----
        check("noise label: no preset set", A.noiseLabel("", "", false, false) === "Noise filter (set audio.noisePreset)");
        check("noise label: a failed call", A.noiseLabel("Denoise", "", false, true) === "Noise filter (set audio.noisePreset)");
        check("noise label: ready", A.noiseLabel("Denoise", "", false, false) === "Noise filter");
        check("noise label: on with nothing to switch it off", A.noiseLabel("Denoise", "", true, false) === "Noise filter (set audio.noiseOffPreset)");
        check("noise label: on with an off preset", A.noiseLabel("Denoise", "Flat", true, false) === "Noise filter");
        check("noise filter is disabled without a preset setting", A.noisePreset === "" && A.noiseUsable === false && A.noiseOn === false);
        check("setNoise under the harness does nothing", (A.setNoise(true), A.noisePending === false));

        // ---- do not disturb while sharing ----
        const S = NotificationStore;
        check("toast: normal", S.showsToast(false, true, false, false) === true);
        check("toast: Do Not Disturb holds it back", S.showsToast(true, true, false, false) === false);
        check("toast: sharing holds it back", S.showsToast(false, true, true, false) === false);
        check("toast: sharing with the setting off shows it", S.showsToast(false, false, true, false) === true);
        check("toast: critical always shows", S.showsToast(true, true, true, true) === true);
        check("dndWhileSharing defaults to true (key missing)", S.dndWhileSharing === true);
        check("nobody shares the screen under the harness", Privacy.screen === false && Privacy.micLive === false && Privacy.micMuted === false);
    }

    function finish() {
        volFile.reload();
        const t = volFile.text();
        let j = null;
        try { j = JSON.parse(t); } catch (e) { }
        check("app-volumes.json is written with the remembered volumes", j !== null && j.volumes && j.volumes.Firefox === 0.35 && j.volumes.Mpv === 0.8);
        check("the pending copy is gone after the save", AudioState.pendingVolumes === null);
        console.log("TEST done failures=" + failures);
        Qt.quit();
    }
}
