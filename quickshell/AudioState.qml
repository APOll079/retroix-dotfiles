pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Audio for the Home tab (popups/AudioTab.qml) on a desktop where EasyEffects sits between every app
// and the DAC: apps -> easyeffects_sink -> EasyEffects (EQ) -> one hardware sink; the mic goes through
// it as well. Apps are never touched. EasyEffects has "Use default output" switched on (its PipeWire
// settings) and follows the system default sink by itself ("New default output device" in its log),
// so choosing an output is just choosing the default hardware sink. We never make EasyEffects' own
// sink the default (its settings page warns against that).
//
//  - outputs         the hardware sinks (EasyEffects' own virtual nodes left out)
//  - currentOutput   the default hardware sink; where the sound goes when EasyEffects follows it
//  - route(sink)     make that sink the default (WirePlumber's configured default)
//  - notFollowing    EasyEffects feeds a different sink than the default for a few seconds: its
//                    "Use default output" is off (the Output section then shows a hint)
//  - EQ              settings.json "audio.eqOutputMatch" (e.g. "DM15"): the output EasyEffects really
//                    feeds decides the EQ: a matching sink -> `easyeffects -b 2` (on), any other
//                    -> `-b 1` (bypass). Applied (debounced) on every change, also when a Bluetooth
//                    device connects, and once at start, because EasyEffects keeps the bypass state
//                    across restarts. Empty = never touched. Only while EasyEffects runs.
//  - mic             the one hardware source (EasyEffects' virtual source left out); mute / volume go
//                    to it, so EasyEffects and every app hear the change.
// The flatpak (com.github.wwmm.easyeffects) when it is installed, else a native `easyeffects` on
// PATH; QS_EASYEFFECTS_CMD replaces both (tests: a fake). A failed call is retried up to 3 times.
//  - Presets         settings.json "audio.eqPresets": one button each; a click runs `easyeffects -l
//                    <name>` (the same command as above). Loading a preset never touches the bypass.
//                    The last one loaded is kept in eq-preset.json (state dir).
//  - mic key         toggleMic() flips the default source's mute through scripts/mic.sh (the Super+Alt+M bind,
//                    `qs ipc call mic_<monitor> toggle`) and emits micToggled(muted) for the OSD.
//  - output toast    "Sound now plays on <sink>" once per change of the default output (debounced, never at start).
//  - app volumes     the slider of an app in the Home tab is remembered by application name (app-volumes.json) and
//                    put back when a stream of that app appears (settings audio.rememberAppVolumes, default true).
//  - noise filter    the Home tab's "Noise filter" button loads an EasyEffects preset through scripts/noise.sh
//                    (settings audio.noisePreset on; audio.noiseOffPreset, else the last EQ preset, off).
// Under QS_NO_APPLY (the test harness) no tool runs and no toast is sent: `live` is false.
// (The audio.* settings are read defensively: a missing key counts as its default.)
Singleton {
    id: root

    readonly property bool live: Config.settingsLoaded && !Quickshell.env("QS_NO_APPLY")
    readonly property var audioCfg: Config.settings.audio || ({})

    readonly property var nodes: Pipewire.nodes.values
    // Node properties only fill in once a node is tracked
    PwObjectTracker {
        objects: root.nodes
    }

    function cls(n) {
        return n && n.properties ? (n.properties["media.class"] || "") : "";
    }
    // EasyEffects' own nodes by name / app (used to leave them out of the lists)
    function isEE(n) {
        if (!n)
            return false;
        const p = n.properties || {};
        return /^(ee_|easyeffects)/i.test(n.name || "")
            || /easy ?effects/i.test((p["application.name"] || "") + " " + (p["application.id"] || "") + " " + (p["application.process.binary"] || ""));
    }

    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream && cls(n) === "Audio/Sink" && !root.isEE(n))

    // --- where the sound goes ---
    readonly property var eeSink: nodes.find(n => n.isSink && !n.isStream && /^easyeffects_sink/.test(n.name || "")) || null
    readonly property var defaultOutput: Pipewire.defaultAudioSink && root.outputs.indexOf(Pipewire.defaultAudioSink) !== -1 ? Pipewire.defaultAudioSink : null

    // The hardware sink EasyEffects really feeds: linked from a node owned by EasyEffects' own PipeWire
    // client (same client.id as easyeffects_sink, so no guessing at its other node names)
    readonly property var eeOwner: eeSink && eeSink.properties ? eeSink.properties["client.id"] : undefined
    readonly property var feeding: {
        if (root.eeOwner === undefined)
            return null;
        const g = Pipewire.linkGroups.values.find(lg => lg.source && lg.target && lg.source !== root.eeSink
            && lg.source.properties && lg.source.properties["client.id"] === root.eeOwner && root.outputs.indexOf(lg.target) !== -1);
        return g ? g.target : null;
    }

    // What the tick shows: the default hardware sink; EasyEffects' real target if the default isn't one
    readonly property var currentOutput: root.defaultOutput || root.feeding

    // EasyEffects runs but feeds something else than the default
    readonly property bool mismatch: root.eeSink !== null && root.feeding !== null && root.defaultOutput !== null && root.feeding !== root.defaultOutput
    property bool notFollowing: false
    onMismatchChanged: {
        if (root.mismatch)
            followTimer.restart();
        else {
            followTimer.stop();
            root.notFollowing = false;
        }
    }
    Timer {
        id: followTimer
        interval: 3000
        onTriggered: root.notFollowing = root.mismatch
    }

    function route(sink) {
        if (sink)
            Pipewire.preferredDefaultAudioSink = sink;
    }

    // --- EQ follows the output ---
    readonly property string eqMatch: (Config.settings.audio && Config.settings.audio.eqOutputMatch) || ""
    // Does the EQ apply on this sink? (only meaningful with eqOutputMatch set)
    function eqOn(sink) {
        return root.eqMatch === "" || ((sink.description || "") + " " + (sink.nickname || "") + " " + (sink.name || "")).toLowerCase().indexOf(root.eqMatch.toLowerCase()) !== -1;
    }
    // Show "EQ off" next to a sink the EQ is switched off for
    function eqOffTag(sink) {
        return root.eqMatch !== "" && !root.eqOn(sink);
    }

    // The sink the EQ state has to match: where EasyEffects really sends the sound
    readonly property var eqTarget: root.feeding || root.defaultOutput
    property string lastEq: ""             // the last `-b` value sent ("1" or "2")
    onEqTargetChanged: {
        bypass.tries = 0;
        eqSettle.restart();
    }
    onEeSinkChanged: {
        // EasyEffects (re)started: it may come back with an old bypass state
        root.lastEq = "";
        bypass.tries = 0;
        eqSettle.restart();
    }
    onEqMatchChanged: {
        root.lastEq = "";
        bypass.tries = 0;
        eqSettle.restart();
    }
    Timer {
        id: eqSettle
        interval: 1000
        onTriggered: {
            if (root.eqMatch === "" || !root.eeSink || !root.eqTarget)
                return;
            const want = root.eqOn(root.eqTarget) ? "2" : "1";
            if (want === root.lastEq)
                return;
            root.lastEq = want;
            const base = Quickshell.env("QS_EASYEFFECTS_CMD");
            bypass.command = base ? [base, "-b", want] : ["sh", "-c",
                "if flatpak info com.github.wwmm.easyeffects >/dev/null 2>&1; then exec flatpak run com.github.wwmm.easyeffects -b \"$1\"; "
                + "elif command -v easyeffects >/dev/null; then exec easyeffects -b \"$1\"; else exit 127; fi", "sh", want];
            // A run being replaced exits non-zero: onExited must not count that as a failure
            if (bypass.running)
                bypass.replacing = true;
            bypass.running = false;
            bypass.running = true;
        }
    }
    Process {
        id: bypass
        property int tries: 0
        property bool replacing: false
        // Failed (EasyEffects busy starting, not installed): forget what was sent and try again
        onExited: code => {
            if (bypass.replacing) {
                bypass.replacing = false;
                return;
            }
            if (code === 0) {
                bypass.tries = 0;
                return;
            }
            root.lastEq = "";
            if (bypass.tries < 3) {
                bypass.tries++;
                eqRetry.restart();
            }
        }
    }
    Timer {
        id: eqRetry
        interval: 3000
        onTriggered: eqSettle.restart()
    }

    // --- EQ presets ---
    readonly property var eqPresets: Array.from((Config.settings.audio && Config.settings.audio.eqPresets) || []).map(String)
    readonly property string activePreset: presetAdapter.preset
    property string presetPending: ""       // the name being loaded right now
    function loadPreset(name) {
        if (name === "" || preset.running)
            return;
        root.presetPending = name;
        const base = Quickshell.env("QS_EASYEFFECTS_CMD");
        preset.command = base ? [base, "-l", name] : ["sh", "-c",
            "if flatpak info com.github.wwmm.easyeffects >/dev/null 2>&1; then exec flatpak run com.github.wwmm.easyeffects -l \"$1\"; "
            + "elif command -v easyeffects >/dev/null; then exec easyeffects -l \"$1\"; else exit 127; fi", "sh", name];
        preset.running = true;
    }
    Process {
        id: preset
        // Only a load EasyEffects accepted becomes the sunken (remembered) one
        onExited: code => {
            if (code === 0)
                presetAdapter.preset = root.presetPending;
            else
                console.warn("[AudioState] loading EasyEffects preset \"" + root.presetPending + "\" failed (exit " + code + ")");
            root.presetPending = "";
        }
    }
    GuardedFileView {
        path: Quickshell.statePath("eq-preset.json")
        printErrors: false
        JsonAdapter {
            id: presetAdapter
            property string preset: ""
        }
    }

    // --- microphone ---
    readonly property var mic: nodes.find(n => !n.isSink && !n.isStream && root.cls(n) === "Audio/Source" && !root.isEE(n)) || null
    readonly property bool micMuted: mic && mic.audio ? mic.audio.muted : false
    readonly property real micVolume: mic && mic.audio ? mic.audio.volume : 0
    function setMicMuted(m) {
        if (root.mic && root.mic.audio)
            root.mic.audio.muted = m;
    }
    function setMicVolume(v) {
        if (root.mic && root.mic.audio)
            root.mic.audio.volume = v;
    }

    // --- mic key ---
    signal micToggled(bool muted)
    // scripts/mic.sh output -> true / false, or null when it isn't {"muted":bool}
    function parseMuted(text) {
        try {
            const j = JSON.parse(String(text).trim());
            return typeof j.muted === "boolean" ? j.muted : null;
        } catch (e) {
            return null;
        }
    }
    function toggleMic() {
        if (!root.live || micProc.running)
            return;
        micProc.running = true;
    }
    Process {
        id: micProc
        command: ["sh", Quickshell.shellDir + "/scripts/mic.sh", "toggle"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = root.parseMuted(text);
                if (m !== null)
                    root.micToggled(m);
            }
        }
        onExited: code => {
            if (code !== 0)
                console.warn("[AudioState] mic.sh toggle failed (exit " + code + ")");
        }
    }

    // --- toast when the default output changes ---
    property var announcedOutput: null      // { name, description } of the output the last toast (or the start) knew
    function outputInfo(node) {
        return node ? { name: node.name || "", description: node.description || node.nickname || node.name || "" } : null;
    }
    // Pure: the toast text for a move from `last` to `cur` ({ name, description } or null), "" = no toast.
    // No toast without a previous output (the start), without a current one (a device went away: the next
    // one is compared with the last known) or when it is still the same device.
    function outputSwitchText(last, cur) {
        if (!last || !cur || last.name === cur.name)
            return "";
        return "Sound now plays on " + cur.description;
    }
    function checkOutput() {
        const cur = root.outputInfo(root.defaultOutput);
        const text = root.outputSwitchText(root.announcedOutput, cur);
        if (cur)
            root.announcedOutput = cur;
        if (text !== "" && root.live)
            Quickshell.execDetached(["notify-send", "-a", "Audio", text]);
    }
    onDefaultOutputChanged: outputDebounce.restart()
    Component.onCompleted: outputDebounce.restart()
    Timer {
        id: outputDebounce
        interval: 1000
        onTriggered: root.checkOutput()
    }

    // --- remembered per-app volumes ---
    readonly property bool rememberVolumes: root.audioCfg.rememberAppVolumes !== false
    property var pendingVolumes: null
    readonly property var savedVolumes: root.pendingVolumes || appVolumeAdapter.volumes || ({})
    // Pure: a copy of `map` with `name` -> volume (0..1, two decimals). The unnamed "Unknown" app is not remembered.
    function rememberVolume(map, name, volume) {
        const out = Object.assign({}, map || {});
        const v = Number(volume);
        if (!name || name === "Unknown" || isNaN(v))
            return out;
        out[name] = Math.round(Math.max(0, Math.min(1, v)) * 100) / 100;
        return out;
    }
    // Pure: the volume to put on a new stream of `name` (currently `current`), or null to leave it as it is
    function volumeToApply(map, name, current) {
        if (!map || !name || !Object.prototype.hasOwnProperty.call(map, name))
            return null;
        const saved = Number(map[name]);
        if (isNaN(saved) || saved < 0 || saved > 1)
            return null;
        return Math.abs(saved - Number(current)) < 0.01 ? null : saved;
    }
    function appNameOf(node) {
        const p = node.properties || {};
        return p["application.name"] || node.description || node.nickname || "Unknown";
    }
    // Called by the Home tab when the owner moves an app's slider (only those apps are remembered)
    function rememberAppVolume(name, volume) {
        if (!root.rememberVolumes)
            return;
        root.pendingVolumes = root.rememberVolume(root.pendingVolumes || appVolumeAdapter.volumes, name, volume);
        saveVolumes.restart();
    }
    Timer {
        id: saveVolumes
        interval: 600
        onTriggered: {
            if (root.pendingVolumes) {
                appVolumeAdapter.volumes = root.pendingVolumes;
                root.pendingVolumes = null;
            }
        }
    }
    GuardedFileView {
        path: Quickshell.statePath("app-volumes.json")
        printErrors: false
        JsonAdapter {
            id: appVolumeAdapter
            property var volumes: ({})
        }
    }
    readonly property var playbackStreams: nodes.filter(n => n.isStream && cls(n) === "Stream/Output/Audio" && !root.isEE(n))
    property var appliedIds: ({})
    property int applyTries: 0
    onPlaybackStreamsChanged: {
        root.applyTries = 0;
        applyTimer.restart();
    }
    function applyRemembered() {
        if (!root.live || !root.rememberVolumes)
            return;
        const seen = {};
        let waiting = false;
        for (const n of root.playbackStreams) {
            seen[n.id] = true;
            if (root.appliedIds[n.id])
                continue;
            if (!n.audio) {
                waiting = true;
                continue;
            }
            root.appliedIds[n.id] = true;
            const v = root.volumeToApply(root.savedVolumes, root.appNameOf(n), n.audio.volume);
            if (v !== null)
                n.audio.volume = v;
        }
        for (const id of Object.keys(root.appliedIds))
            if (!seen[id])
                delete root.appliedIds[id];
        if (waiting && root.applyTries++ < 6)
            applyTimer.restart();
    }
    Timer {
        id: applyTimer
        interval: 500
        onTriggered: root.applyRemembered()
    }

    // --- noise filter (EasyEffects preset) ---
    readonly property string noisePreset: String(root.audioCfg.noisePreset || "")
    readonly property string noiseOffPreset: String(root.audioCfg.noiseOffPreset || "")
    // what "off" loads: the off preset, else the EQ preset that was loaded last
    readonly property string noiseOffTarget: root.noiseOffPreset !== "" ? root.noiseOffPreset : root.activePreset
    readonly property bool noiseOn: noiseAdapter.enabled
    property bool noiseFailed: false
    property bool noisePending: false
    // Pure: the button text; anything but plain "Noise filter" also means the button is disabled
    function noiseLabel(preset, offTarget, on, failed) {
        if (preset === "" || failed)
            return "Noise filter (set audio.noisePreset)";
        if (on && offTarget === "")
            return "Noise filter (set audio.noiseOffPreset)";
        return "Noise filter";
    }
    readonly property string noiseText: root.noiseLabel(root.noisePreset, root.noiseOffTarget, root.noiseOn, root.noiseFailed)
    readonly property bool noiseUsable: root.noiseText === "Noise filter" && !root.noisePending
    function setNoise(on) {
        const name = on ? root.noisePreset : root.noiseOffTarget;
        if (!root.live || !root.noiseUsable || name === "")
            return;
        noiseProc.wantOn = on;
        noiseProc.command = ["sh", Quickshell.shellDir + "/scripts/noise.sh", "load", name];
        root.noisePending = true;
        noiseProc.running = true;
    }
    Process {
        id: noiseProc
        property bool wantOn: false
        onExited: code => {
            root.noisePending = false;
            if (code === 0) {
                noiseAdapter.enabled = noiseProc.wantOn;
            } else {
                root.noiseFailed = true;
                console.warn("[AudioState] noise.sh failed (exit " + code + ")");
            }
        }
    }
    GuardedFileView {
        path: Quickshell.statePath("noise-filter.json")
        printErrors: false
        JsonAdapter {
            id: noiseAdapter
            property bool enabled: false
        }
    }
}
