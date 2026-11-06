pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// What is recording right now, from PipeWire node types (no polling):
// - mic: any audio input stream (an app capturing a microphone), except EasyEffects' own
//   processing streams.
// - micMuted: the default microphone is muted (AudioState.micMuted). A muted microphone records nothing, so the bar
//   shows `mic && micMuted` as a quiet "muted" state and only `micLive` in the urgent colour.
// - screen: any video source. This desktop has no camera, so a video source is the portal's
//   screen-share stream. (Camera indicator skipped: no /dev/video* here.)
Singleton {
    id: root

    readonly property var nodes: Pipewire.nodes.values
    readonly property var micStreams: nodes.filter(n => n.type === PwNodeType.AudioInStream && !/^(ee_|easyeffects)/i.test(n.name))
    readonly property bool mic: micStreams.length > 0
    readonly property bool micMuted: AudioState.micMuted
    // an app is capturing and the microphone is not muted: the urgent case
    readonly property bool micLive: root.mic && !root.micMuted
    readonly property bool screen: nodes.some(n => n.type === PwNodeType.VideoSource)
}
