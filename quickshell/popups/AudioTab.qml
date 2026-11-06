import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell.Services.Pipewire
import ".."
import "." as P

// Audio section of the Home tab: the output (EasyEffects-aware routing), the microphone, and per-app volume (the overall volume is on the DAC). `active` is true while Home is showing.
// Each part is a GroupBox.
ColumnLayout {
    id: root
    property bool active: false
    spacing: MenuStyle.pad

    // === OUTPUT ===
    // The hardware sinks. EasyEffects sits in front of them and follows the default sink (see
    // AudioState.qml), so a click makes that sink the default and the tick is the current default;
    // "EQ off" marks a sink the EQ is switched off for (settings.json "audio.eqOutputMatch").
    P.GroupBox {
        Layout.fillWidth: true
        visible: AudioState.outputs.length > 0
        title: "Output"

        Repeater {
            model: AudioState.outputs

            MenuRow {
                required property var modelData
                Layout.fillWidth: true
                reserveIcon: true
                glyph: /^bluez/i.test(modelData.name) ? "\ue1a7" : "\ue050"
                text: modelData.description || modelData.nickname || modelData.name
                marked: AudioState.currentOutput === modelData
                trailing: AudioState.eqOffTag(modelData) ? "EQ off" : ""
                onClicked: AudioState.route(modelData)
            }
        }

        // EasyEffects feeds another sink than the default for a few seconds: it is pinned to one device
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.fillWidth: true
            visible: AudioState.notFollowing
            wrapMode: Text.Wrap
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: MenuStyle.bevelDark
            text: "EasyEffects isn't following the default output. Turn on \"Use default output\" in its PipeWire settings."
        }
    }

    // === EQ PRESETS ===
    // settings.json "audio.eqPresets" (empty = hidden): one click loads that EasyEffects preset; the
    // one loaded last is sunken. Separate from the automatic "EQ off" bypass above.
    P.GroupBox {
        Layout.fillWidth: true
        visible: AudioState.eqPresets.length > 0
        title: "EQ preset"

        GridLayout {
            Layout.fillWidth: true
            columns: Math.min(Math.max(1, AudioState.eqPresets.length), MenuStyle.eqPresetColumns)
            columnSpacing: MenuStyle.gap
            rowSpacing: MenuStyle.gap
            Repeater {
                model: AudioState.eqPresets
                BevelButton {
                    required property string modelData
                    Layout.fillWidth: true
                    text: modelData
                    checked: AudioState.activePreset === modelData
                    enabled: AudioState.presetPending === ""
                    onClicked: AudioState.loadPreset(modelData)
                }
            }
        }
    }

    // === MICROPHONE ===
    // One label: "nickname · description" when PipeWire gives both and they differ (a USB mic can be
    // "AT2020 USB" + "Analog Stereo"), else whichever there is
    function sourceLabel(n) {
        const d = n.description || "";
        const k = n.nickname || "";
        if (d !== "" && k !== "" && d.indexOf(k) < 0)
            return k + " · " + d;
        return d || k || n.name;
    }

    P.GroupBox {
        Layout.fillWidth: true
        visible: AudioState.mic !== null
        title: "Microphone"

        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            textFormat: Text.PlainText
            text: AudioState.mic ? root.sourceLabel(AudioState.mic) : ""
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: MenuStyle.pad

            BevelButton {
                implicitWidth: MenuStyle.rowHeight + MenuStyle.gap
                glyph: AudioState.micMuted ? "\ue02b" : "\ue029"
                checked: AudioState.micMuted
                onClicked: AudioState.setMicMuted(!AudioState.micMuted)
            }

            RetroSlider {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: AudioState.micVolume * 100
                dim: AudioState.micMuted
                onMoved: AudioState.setMicVolume(value / 100)
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                Layout.preferredWidth: MenuStyle.valueLabelWidth
                horizontalAlignment: Text.AlignRight
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: Config.colors.text
                text: AudioState.micMuted ? "MUTE" : Math.round(AudioState.micVolume * 100) + "%"
            }
        }
    }

    // === PER-APP VOLUME ===
    // Node properties are only filled in once a node is tracked, so track every stream first
    // and pick the playback ones ("Stream/Output/Audio") after that.
    readonly property var allStreams: Pipewire.nodes.values.filter(n => n.isStream)
    readonly property var streamNodes: allStreams.filter(n => n.properties && n.properties["media.class"] === "Stream/Output/Audio" && !AudioState.isEE(n))

    // One row per app: browsers open a stream per tab, so group streams by application name
    readonly property var appGroups: {
        var groups = [];
        var byName = {};
        for (var n of root.streamNodes) {
            var name = n.properties["application.name"] || n.description || n.nickname || "Unknown";
            if (!(name in byName)) {
                byName[name] = { name: name, nodes: [] };
                groups.push(byName[name]);
            }
            byName[name].nodes.push(n);
        }
        return groups;
    }

    PwObjectTracker {
        objects: root.active ? root.allStreams : []
    }

    // Capped (scrolls after a few apps) so the side panel can't outgrow the screen
    P.GroupBox {
        Layout.fillWidth: true
        visible: root.appGroups.length > 0
        title: "Applications"

        Flickable {
            id: appsView
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(appsColumn.implicitHeight, MenuStyle.audioAppsMaxHeight)
            contentHeight: appsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ScrollBar.vertical: RetroScrollBar { id: appsBar }

            ColumnLayout {
                id: appsColumn
                // room for the scroll bar while it shows
                width: appsView.width - (appsBar.visible ? MenuStyle.scrollBarWidth : 0)
                spacing: MenuStyle.pad

                Repeater {
                    model: root.active ? root.appGroups : []

                    ColumnLayout {
                        id: streamRow
                        required property var modelData
                        // The first stream speaks for the app; changes go to all of its streams
                        readonly property var lead: modelData.nodes[0]
                        readonly property real vol: lead.audio ? lead.audio.volume : 0
                        readonly property bool muted: lead.audio ? lead.audio.muted : false
                        function setVolume(v) {
                            for (var n of modelData.nodes) if (n.audio) n.audio.volume = v;
                        }
                        function setMuted(m) {
                            for (var n of modelData.nodes) if (n.audio) n.audio.muted = m;
                        }
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            textFormat: Text.PlainText
                            text: streamRow.modelData.name
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: MenuStyle.pad

                            BevelButton {
                                implicitWidth: MenuStyle.rowHeight + MenuStyle.gap
                                glyph: streamRow.muted ? "\ue04f" : "\ue050"
                                onClicked: streamRow.setMuted(!streamRow.muted)
                            }

                            RetroSlider {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                value: streamRow.vol * 100
                                dim: streamRow.muted
                                onMoved: streamRow.setVolume(value / 100)
                            }

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                Layout.preferredWidth: MenuStyle.valueLabelWidth
                                horizontalAlignment: Text.AlignRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: Config.colors.text
                                text: streamRow.muted ? "MUTE" : Math.round(streamRow.vol * 100) + "%"
                            }
                        }
                    }
                }
            }
        }
    }
}
