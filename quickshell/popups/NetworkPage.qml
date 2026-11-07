import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// The Network page (Start > Network, the bar's ETH button, `qs ipc call network_<mon> toggle` or `qs ipc call network toggle`):
// a real window (an xdg toplevel Hyprland floats, centres and lets you move and resize, see windowrules.lua
// "network-window"), one for the whole desktop. ToolWindows.qml owns it and opens / toggles / closes it.
//   This computer   your addresses and the gateway (`ip -j addr / route`)
//   Ping            one echo at the gateway and one at 1.1.1.1, on a button (`ping -c1 -W2`), the answer in ms
//   Devices         what the system already knows about the LAN (`ip -j neigh`): address, name if /etc/hosts has one, MAC, state.
//                   Nothing is scanned and no name is looked up.
//   Speed test      a button that downloads a fixed test file (settings.networkPage.speedTestUrl, 20 s at most) and shows
//                   "93.2 Mbit/s". Nothing runs until the button is pressed.
// The data and the scripts are NetworkState.qml / scripts/lan.sh / scripts/speedtest.sh. A missing tool is a line of text.
// Escape closes the window; the Devices list takes the extra room when it is resized.
FloatingWindow {
    id: root

    // Hyprland matches this title (windowrules.lua "network-window")
    title: "Network"
    implicitWidth: MenuStyle.windowWidth
    implicitHeight: MenuStyle.windowHeight
    minimumSize: Qt.size(MenuStyle.toolMinWidth, MenuStyle.toolMinHeight)
    visible: false
    color: Config.colors.base

    // Closed by Hyprland (Super+Q, the close dispatcher): reset like closeMenu()
    onClosed: root.visible = false

    // (through a var so the singleton's members are not lint errors)
    readonly property var net: NetworkState
    readonly property var addrs: root.net.addrs
    readonly property var gateway: root.net.gateway
    readonly property var neigh: root.net.neigh
    readonly property string speedHost: root.net.hostOf(root.net.speedUrlFrom(Config.settings))
    readonly property Item deviceList: devices
    readonly property Item emptyDevices: noDevices
    readonly property Item speedButton: speedButton
    readonly property Item refreshButton: refreshButton

    Item {
        id: frame
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeMenu()

        PopupWindowFrame {
            windowTitle: "Network"
            windowTitleIcon: "\ue8be"
            // Dragging the title bar moves the window, like any Win95 window
            titleDrag: true
            onTitlePressed: root.startSystemMove()

            ColumnLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                // ---- this computer ----
                GroupFrame {
                    Layout.fillWidth: true
                    title: "This computer"

                    Repeater {
                        model: root.addrs
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: MenuStyle.pad
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                textFormat: Text.PlainText
                                Layout.preferredWidth: MenuStyle.gamesLabelWidth
                                elide: Text.ElideRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: MenuStyle.bevelDark
                                text: modelData.ifname
                            }
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: Config.colors.text
                                text: modelData.addr + (modelData.prefix >= 0 ? "/" + modelData.prefix : "")
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MenuStyle.pad
                        RetroText {
                            Layout.preferredWidth: MenuStyle.gamesLabelWidth
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: MenuStyle.bevelDark
                            text: "Gateway"
                        }
                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            text: root.gateway ? root.gateway.addr + (root.gateway.dev !== "" ? "  (" + root.gateway.dev + ")" : "") : (root.net.loaded ? "none" : "...")
                        }
                    }
                    RetroText {
                        Layout.fillWidth: true
                        visible: root.net.loaded && root.addrs.length === 0 && root.net.error === ""
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: MenuStyle.bevelDark
                        text: "No network address: the computer is not connected"
                    }
                }

                // ---- ping ----
                GroupFrame {
                    Layout.fillWidth: true
                    title: "Ping"

                    Repeater {
                        model: [
                            { key: "gw", label: "Gateway" },
                            { key: "cf", label: "1.1.1.1" }
                        ]
                        RowLayout {
                            id: pingRow
                            required property var modelData
                            readonly property var result: root.net.pings[pingRow.modelData.key]
                            Layout.fillWidth: true
                            spacing: MenuStyle.pad
                            RetroText {
                                Layout.preferredWidth: MenuStyle.gamesLabelWidth
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: Config.colors.text
                                text: pingRow.modelData.label
                            }
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: pingRow.result.done && !pingRow.result.ok ? Config.colors.urgent : Config.colors.text
                                text: pingRow.modelData.key === "gw" && !root.gateway ? "no gateway" : root.net.pingText(pingRow.result)
                            }
                            BevelButton {
                                id: pingButton
                                Layout.preferredWidth: MenuStyle.shotActionButtonWidth
                                text: "Ping"
                                enabled: !pingRow.result.running && (pingRow.modelData.key !== "gw" || root.gateway !== null)
                                focusPolicy: Qt.NoFocus
                                onClicked: root.net.ping(pingRow.modelData.key)
                                Component.onCompleted: {
                                    if (pingRow.modelData.key === "gw")
                                        pingGw = pingButton;
                                    else
                                        pingCf = pingButton;
                                }
                            }
                        }
                    }
                }

                // ---- devices ----
                GroupFrame {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Devices on the LAN"

                    SunkenField {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        padding: 2
                        clip: true

                        EmptyState {
                            id: noDevices
                            anchors.fill: parent
                            visible: root.neigh.length === 0
                            glyph: "\ue8be"
                            text: root.net.loaded ? "No devices known yet. Only devices this computer has talked to lately show here." : "Reading..."
                        }

                        ListView {
                            id: devices
                            anchors.fill: parent
                            model: root.neigh
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: MenuRow {
                                required property var modelData
                                width: devices.width - (devices.ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0)
                                hoverLit: false
                                text: modelData.addr
                                subtext: (modelData.name !== "" ? modelData.name + "  " : "") + modelData.mac
                                trailing: modelData.state
                                trailingDim: true
                            }
                            ScrollBar.vertical: RetroScrollBar {}
                        }
                    }
                }

                // ---- speed test ----
                GroupFrame {
                    Layout.fillWidth: true
                    title: "Speed test"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MenuStyle.pad
                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: root.net.speed.done && !root.net.speed.ok ? Config.colors.urgent : Config.colors.text
                            text: root.net.speedText(root.net.speed) !== "" ? root.net.speedText(root.net.speed) : "Downloads a test file from " + root.speedHost + " (up to 20 s)"
                        }
                        BevelButton {
                            id: speedButton
                            Layout.preferredWidth: MenuStyle.shotActionButtonWidth
                            text: root.net.speed.running ? "Testing..." : "Speed test"
                            enabled: !root.net.speed.running
                            focusPolicy: Qt.NoFocus
                            onClicked: root.net.speedTest(Config.settings)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap
                    StatusBar {
                        Layout.fillWidth: true
                        kind: root.net.error !== "" ? "error" : "state"
                        text: root.net.error !== "" ? root.net.error : (root.net.loading ? "Reading..." : root.neigh.length + " device(s) known - nothing is scanned")
                    }
                    BevelButton {
                        id: refreshButton
                        Layout.preferredWidth: MenuStyle.shotActionButtonWidth
                        text: "Refresh"
                        enabled: !root.net.loading
                        focusPolicy: Qt.NoFocus
                        onClicked: root.net.refresh()
                    }
                }
            }
        }
    }

    // (the two Ping buttons, found by key for tests)
    property Item pingGw: null
    property Item pingCf: null

    function openMenu() {
        root.net.resetResults();
        root.net.refresh();
        root.visible = true;
        frame.forceActiveFocus();
    }

    function closeMenu() {
        root.visible = false;
    }
}
