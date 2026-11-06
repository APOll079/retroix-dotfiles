import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Item {
    id: root

    property int currentPopup: Config.SystemPopup.None
    property var toggleMenu: function(menu, popup, item) {}
    property var bluetoothMenuRef: null
    property var sysMonMenuRef: null
    // Bar.qml turns the GPU part of the sysmon button off when the centre text needs the room
    property bool showGpu: true


    property string netText: "OFF"
    property string netIconVal: "\ue63d"
    // Bluetooth from BlueZ directly: OFF, ON, or ON with the connected icon
    readonly property bool btOn: Bluetooth.defaultAdapter !== null && Bluetooth.defaultAdapter.enabled
    readonly property bool btConnected: Bluetooth.devices.values.some(d => d.connected)
    readonly property string btText: btOn ? "ON" : "OFF"
    readonly property string btIconVal: !btOn ? "\ue1a9" : (btConnected ? "\ue1a8" : "\ue1a7")

    // Everything but the sysmon button, so Bar.qml can work out the width with the GPU part shown
    // without reading anything that changes when it hides (that would be a binding loop)
    readonly property real otherWidth: (privacyRow.width > 0 ? privacyRow.width + MenuStyle.gap : 0) + caffeineBtn.width + MenuStyle.gap + MenuStyle.gap + ethLabel.width + MenuStyle.gap + btBtn.width
    readonly property real widthWithGpu: otherWidth + sysProbe.implicitWidth

    // The sysmon label: every number sits in a fixed-width cell (Monaco is monospace), so the button
    // never changes width while it ticks and nothing next to it moves. Cells are sized to the widest
    // real value: CPU load up to 100, a temperature up to 99 degrees (or "--"), RAM up to 99.
    function cell(value, width) {
        return String(value).padStart(width, " ");
    }
    function sysLabel(cpu, cpuTemp, gpuTemp, mem, withGpu) {
        return "CPU " + cell(cpu, 3) + "% " + cell(SysMon.tempShort(cpuTemp), 3)
            + (withGpu ? " GPU " + cell(SysMon.tempShort(gpuTemp), 3) : "")
            + " RAM " + cell(mem, 2) + "%";
    }
    // Measures the widest label with the real button (font, size and padding included); never shown
    BarButton {
        id: sysProbe
        visible: false
        iconFontValue: ""
        label: root.sysLabel(100, 99, 99, 99, true)
    }
    implicitWidth: otherWidth + sysBtn.width
    implicitHeight: MenuStyle.barButtonHeight

    // Privacy: mic / screen-share icons in the urgent colour, only while something records
    Row {
        id: privacyRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: MenuStyle.gap
        BarButton {
            visible: Privacy.mic
            anchors.verticalCenter: parent.verticalCenter
            interactive: false
            tucked: true
            urgent: true
            iconFontValue: "\ue029"
        }
        BarButton {
            visible: Privacy.screen
            anchors.verticalCenter: parent.verticalCenter
            interactive: false
            tucked: true
            urgent: true
            iconFontValue: "\ue0e2"
        }
    }

    // Caffeine: sunken while on (idle dim/lock/screens-off paused)
    BarButton {
        id: caffeineBtn
        anchors.left: privacyRow.width > 0 ? privacyRow.right : parent.left
        anchors.leftMargin: privacyRow.width > 0 ? MenuStyle.gap : 0
        anchors.verticalCenter: parent.verticalCenter
        iconFontValue: "\uefef"
        isToggled: Idle.caffeine
        glyphOn: Idle.caffeine
        tooltip: Idle.caffeine ? "Caffeine on: idle dim, lock and screen-off paused" : "Caffeine off"
        onClicked: Idle.caffeine = !Idle.caffeine
    }

    // CPU load + temperature, GPU temperature, RAM use. Left click: the Task Manager on Performance;
    // right click: the sysmon popup (GPU hotspot / memory). Fixed width so it never jitters.
    BarButton {
        id: sysBtn
        anchors.left: caffeineBtn.right
        anchors.leftMargin: MenuStyle.gap
        anchors.verticalCenter: parent.verticalCenter
        // No icon: the CPU/RAM labels say what it is (BarButton defaults to the Start grid icon)
        iconFontValue: ""
        label: root.sysLabel(Math.round(SysMon.cpuLoad * 100), SysMon.cpuTemp, SysMon.gpuEdge, SysMon.memPercent, root.showGpu)
        isToggled: root.currentPopup === Config.SystemPopup.SysMonMenu
        tooltip: "Left click: Task Manager \u00b7 Right click: temperatures"
        onClicked: TaskWindow.open("performance")
        onRightClicked: root.toggleMenu(root.sysMonMenuRef, Config.SystemPopup.SysMonMenu, sysBtn)
    }

    // Network: a status indicator (the desktop is wired), not a button
    BarButton {
        id: ethLabel
        anchors.left: sysBtn.right
        anchors.leftMargin: MenuStyle.gap
        anchors.verticalCenter: parent.verticalCenter
        iconFontValue: root.netIconVal
        toggledIconFontValue: ""
        label: root.netText
        // Its own quiet box (no hover, dim text) so it sits in rhythm with its boxed neighbours
        interactive: false
        dim: true
    }

    // Bluetooth: a normal bar button next to the ETH label
    BarButton {
        id: btBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconFontValue: root.btIconVal
        toggledIconFontValue: ""
        label: root.btText
        minWidth: MenuStyle.barLabelButtonWidth
        isToggled: root.currentPopup === Config.SystemPopup.BluetoothMenu
        onClicked: root.toggleMenu(root.bluetoothMenuRef, Config.SystemPopup.BluetoothMenu, btBtn)
    }

    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "STATE", "g"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var state = text.trim()
                // Wired desktop: connected means Ethernet ("connected (site only)" and
                // "(local only)" too: the cable is up, only the internet check differs)
                if (/^connected/.test(state)) {
                    root.netIconVal = "\ue627"
                    root.netText = "ETH"
                } else {
                    root.netIconVal = "\ue63d"
                    root.netText = "OFF"
                }
            }
        }
    }

    // NetworkManager prints a line on every state change: check again at once
    Process {
        id: netMonitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: _ => netProc.running = true
        }
    }

    // Slow poll as a fallback; it also restarts the monitor if it stopped (NetworkManager restart)
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netProc.running = true
            if (!netMonitor.running)
                netMonitor.running = true
        }
    }
}
