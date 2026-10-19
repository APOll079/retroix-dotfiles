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
Singleton {
    id: root

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
}
