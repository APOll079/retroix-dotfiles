import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Keybind cheat sheet (Super+F1, `qs ipc call cheatsheet_<mon> toggle`), centred like the Games
// menu. The list comes from scripts/binds.py, which reads hypr/binds.lua and hypr/inputs.lua next
// to the shell folder; the label of each bind is its `-- help: Group | Label` comment there.
// A heading row starts each group. The list scrolls (wheel; Up / Down / PageUp / PageDown in the
// search box). Type to filter (keys, label or group); Escape clears the search, then closes.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}
    property var binds: []

    readonly property var shown: {
        const q = searchInput.text.trim().toLowerCase();
        return root.binds.filter(b => q === "" || (b.keys + " " + b.label + " " + b.group).toLowerCase().includes(q));
    }

    // shown + a heading row ({ heading: "Apps" }) wherever the group changes
    readonly property var rows: {
        const out = [];
        let group = null;
        for (const b of root.shown) {
            if (b.group !== group) {
                group = b.group;
                out.push({ heading: group });
            }
            out.push(b);
        }
        return out;
    }

    // An Overlay-layer panel, not a popup of the bar: the bar sits below fullscreen windows, so a
    // popup over a fullscreen video showed but its clicks went to the video
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins.top: MenuStyle.barHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: false
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.closeCallback()
    }

    Item {
        id: frame
        width: MenuStyle.launcherWidth
        height: MenuStyle.launcherHeight
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.screenHeight / 2 - height / 2) - MenuStyle.barHeight

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupWindowFrame {
            windowTitle: "Keybinds"
            windowTitleIcon: ""

            ColumnLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                SearchBox {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholder: "Filter keybinds"
                    onEscaped: root.closeCallback()
                    onKeyPressed: event => {
                        const steps = { [Qt.Key_Up]: -3 * MenuStyle.rowHeight, [Qt.Key_Down]: 3 * MenuStyle.rowHeight, [Qt.Key_PageUp]: -list.height, [Qt.Key_PageDown]: list.height };
                        if (event.key in steps) {
                            list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + steps[event.key]));
                            event.accepted = true;
                        }
                    }
                }

                SunkenField {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 2
                    clip: true

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        anchors.centerIn: parent
                        visible: root.shown.length === 0
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: MenuStyle.bevelDark
                        text: root.binds.length === 0 ? "No keybinds found" : "No matches"
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        model: root.rows
                        delegate: Item {
                            id: row
                            required property var modelData
                            readonly property bool isHeading: modelData.heading !== undefined
                            width: list.width
                            height: MenuStyle.rowHeight

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                visible: row.isHeading
                                anchors.left: parent.left
                                anchors.leftMargin: MenuStyle.gap
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                font.family: MenuStyle.titleFont
                                font.pixelSize: MenuStyle.fontSize
                                font.bold: true
                                color: MenuStyle.bevelDark
                                text: row.isHeading ? row.modelData.heading : ""
                            }
                            Rectangle {
                                visible: row.isHeading
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: MenuStyle.gap
                                anchors.rightMargin: MenuStyle.gap
                                height: 1
                                color: Config.colors.shadow
                            }

                            Rectangle {
                                id: chip
                                visible: !row.isHeading
                                anchors.verticalCenter: parent.verticalCenter
                                x: MenuStyle.gap
                                width: Math.max(MenuStyle.cheatKeyWidth, keyText.implicitWidth + 2 * MenuStyle.pad)
                                height: parent.height - 4
                                color: Config.colors.base
                                border.width: 1
                                border.color: Config.colors.outline
                                Text {
                                    id: keyText
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    anchors.centerIn: parent
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    color: Config.colors.text
                                    text: row.isHeading ? "" : row.modelData.keys
                                }
                            }
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                visible: !row.isHeading
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: chip.right
                                anchors.leftMargin: MenuStyle.gap
                                anchors.right: parent.right
                                anchors.rightMargin: MenuStyle.gap
                                elide: Text.ElideRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: Config.colors.text
                                text: row.isHeading ? "" : row.modelData.label
                            }
                        }
                        ScrollIndicator.vertical: ScrollIndicator {
                            active: list.moving
                        }
                    }
                }
            }
        }
    }

    Process {
        id: bindsProc
        command: ["python3", "-I", Quickshell.shellDir + "/scripts/binds.py", Quickshell.shellDir + "/../hypr/binds.lua", Quickshell.shellDir + "/../hypr/inputs.lua"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(text);
                } catch (e) {
                    console.warn("scripts/binds.py gave no valid JSON: " + e);
                    root.binds = [];
                }
            }
        }
    }

    function openMenu() {
        searchInput.text = "";
        bindsProc.running = true;
        root.visible = true;
        searchInput.focusInput();
    }

    function closeMenu() {
        root.visible = false;
    }
}
