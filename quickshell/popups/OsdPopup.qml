import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import ".."

Scope {
    id: root

    property string osdLabel: "Volume"
    property string osdIcon: "\ue050"
    property int osdValue: 0
    // Text instead of a meter (Bluetooth); "" = show the meter
    property string osdText: ""
    // Volume OSD while muted: "MUTE" instead of the percentage, empty meter
    property bool osdMuted: false
    property bool ready: false
    readonly property var cfg: Config.settings.osd

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Timer {
        id: startupGuard
        interval: 2000
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osdWindow.visible = false
    }

    function show(label, icon, value) {
        root.osdLabel = label;
        root.osdIcon = icon;
        root.osdText = "";
        root.osdMuted = false;
        root.osdValue = Math.max(0, Math.min(100, Math.round(value)));
        osdWindow.visible = true;
        hideTimer.restart();
    }

    function showText(label, icon, text) {
        root.osdLabel = label;
        root.osdIcon = icon;
        root.osdText = text;
        root.osdMuted = false;
        osdWindow.visible = true;
        hideTimer.restart();
    }

    function showVolume() {
        if (!root.ready || !root.cfg.volume)
            return;
        var sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.audio)
            return;
        root.show("Volume", sink.audio.muted ? "\ue04f" : "\ue050", sink.audio.volume * 100);
        root.osdMuted = sink.audio.muted;
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            root.showVolume();
        }
        function onMutedChanged() {
            root.showVolume();
        }
    }

    // The microphone key (Super+Ctrl+M): the new state as text
    Connections {
        target: AudioState
        function onMicToggled(muted) {
            root.showText("Microphone", muted ? "\ue02b" : "\ue029", muted ? "MIC OFF" : "MIC ON");
        }
    }

    // Bluetooth: a device connecting or disconnecting
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (!root.ready || !root.cfg.bluetooth)
                    return;
                root.showText("Bluetooth", modelData.connected ? "\ue1a8" : "\ue1a9",
                    (modelData.name || modelData.deviceName) + (modelData.connected ? " connected" : " disconnected"));
            }
        }
    }

    IpcHandler {
        target: "osd"

        function volume() {
            root.ready = true;
            root.showVolume();
        }
    }

    PanelWindow {
        id: osdWindow
        visible: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Empty input region: clicks go through to whatever is under the OSD
        mask: Region {}
        // The focused monitor, like the toasts (null = the compositor's choice)
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || null

        anchors {
            bottom: true
        }
        margins.bottom: MenuStyle.osdMargin

        implicitWidth: MenuStyle.widthMedium
        implicitHeight: MenuStyle.chromeHeight + MenuStyle.rowHeight + MenuStyle.gap

        PopupWindowFrame {
            windowTitle: root.osdLabel
            active: false
            windowTitleIcon: root.osdIcon

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: MenuStyle.pad

                SegmentBar {
                    visible: root.osdText === ""
                    Layout.fillWidth: true
                    implicitHeight: MenuStyle.rowHeight + MenuStyle.gap
                    value: root.osdValue / 100
                    dim: root.osdMuted
                }

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    Layout.fillWidth: root.osdText !== ""
                    Layout.preferredWidth: root.osdText === "" ? MenuStyle.valueLabelWidth : -1
                    Layout.preferredHeight: MenuStyle.rowHeight + MenuStyle.gap
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: root.osdText === "" ? Text.AlignRight : Text.AlignHCenter
                    elide: Text.ElideRight
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: Config.colors.text
                    text: root.osdText !== "" ? root.osdText : (root.osdMuted ? "MUTE" : root.osdValue + "%")
                }
            }
        }
    }
}
