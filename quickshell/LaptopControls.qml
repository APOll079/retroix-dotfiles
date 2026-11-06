import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "popups" as Popups

// The status half of the bar's tray well (Bar.qml puts it inside the BarWell): a Row of flat
// BarButtons, etched separators only between real groups: [mic, screen share, caffeine] | sysmon |
// [ETH, Bluetooth].
Row {
    id: root
    spacing: 0

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
    readonly property bool btConnected: root.btDevices.some(d => d.connected)
    // The devices the battery choice looks at (a plain list; tests replace it with fixtures)
    property var btDevices: Bluetooth.devices.values
    // Battery of connected devices (BlueZ reports it as 0..1 when the device exposes it). The text is the
    // lowest one as "82%", or "" when no connected device has a battery; the tooltip is one "name 82%"
    // line per such device. Pure functions of a plain array, so tests feed them fixtures.
    function btDeviceName(d) {
        return d.name || d.deviceName || d.address || "";
    }
    function btWithBattery(devices) {
        return (devices || []).filter(d => d && d.connected && d.batteryAvailable);
    }
    function btBatteryText(devices) {
        const list = root.btWithBattery(devices);
        if (list.length === 0)
            return "";
        return Math.round(Math.min(...list.map(d => d.battery)) * 100) + "%";
    }
    function btBatteryTooltip(devices) {
        return root.btWithBattery(devices).map(d => root.btDeviceName(d) + " " + Math.round(d.battery * 100) + "%").join("\n");
    }
    readonly property string btText: root.btBatteryText(root.btDevices) || (btOn ? "ON" : "OFF")
    readonly property string btIconVal: !btOn ? "\ue1a9" : (btConnected ? "\ue1a8" : "\ue1a7")

    // Everything but the sysmon button, so Bar.qml can work out the width with the GPU part shown
    // without reading anything that changes when it hides (that would be a binding loop)
    readonly property real otherWidth: (micIcon.visible ? micIcon.width : 0) + (screenIcon.visible ? screenIcon.width : 0)
        + (recBtn.visible ? recBtn.width : 0) + (replayInd.visible ? replayInd.width : 0)
        + caffeineBtn.width + sep1.width + sep2.width + ethLabel.width + btBtn.width
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

    // Privacy: mic / screen-share icons in the urgent colour, only while something records
    BarButton {
        id: micIcon
        visible: Privacy.mic
        flat: true
        interactive: false
        urgent: true
        iconFontValue: "\ue029"
    }
    BarButton {
        id: screenIcon
        visible: Privacy.screen
        flat: true
        interactive: false
        urgent: true
        iconFontValue: "\ue0e2"
    }

    // Recording: "REC 0:42" in the urgent colour while the overlay's Record is running; a click stops it
    BarButton {
        id: recBtn
        visible: RecordState.recording
        flat: true
        urgent: true
        iconFontValue: ""
        label: "REC " + RecordState.label
        tooltip: "Click to stop recording"
        onClicked: RecordState.stop()
    }
    // Replay buffer armed (Super+Alt+R toggles, Super+Alt+S saves the last seconds)
    BarButton {
        id: replayInd
        visible: RecordState.replaying
        flat: true
        interactive: false
        dim: true
        iconFontValue: ""
        label: "REPLAY"
    }

    // Caffeine: sunken while on (idle dim/lock/screens-off paused)
    BarButton {
        id: caffeineBtn
        flat: true
        iconFontValue: "\uefef"
        isToggled: Idle.caffeine
        glyphOn: Idle.caffeine
        tooltip: Idle.caffeine ? "Caffeine on: idle dim, lock and screen-off paused" : "Caffeine off"
        onClicked: Idle.caffeine = !Idle.caffeine
    }

    Popups.MenuSeparator { id: sep1; vertical: true }

    // CPU load + temperature, GPU temperature, RAM use. Left click: the Task Manager on Performance;
    // right click: the sysmon popup (GPU hotspot / memory). Fixed width so it never jitters.
    BarButton {
        id: sysBtn
        flat: true
        // No icon: the CPU/RAM labels say what it is (BarButton defaults to the Start grid icon)
        iconFontValue: ""
        label: root.sysLabel(Math.round(SysMon.cpuLoad * 100), SysMon.cpuTemp, SysMon.gpuEdge, SysMon.memPercent, root.showGpu)
        isToggled: root.currentPopup === Config.SystemPopup.SysMonMenu
        tooltip: "Left click: Task Manager \u00b7 Right click: temperatures"
        onClicked: TaskWindow.open("performance")
        onRightClicked: root.toggleMenu(root.sysMonMenuRef, Config.SystemPopup.SysMonMenu, sysBtn)
    }

    Popups.MenuSeparator { id: sep2; vertical: true }

    // Network: a status indicator (the desktop is wired), not a button
    BarButton {
        id: ethLabel
        flat: true
        iconFontValue: root.netIconVal
        toggledIconFontValue: ""
        label: root.netText
        interactive: false
        dim: true
    }

    // Bluetooth: a normal bar button next to the ETH label
    BarButton {
        id: btBtn
        flat: true
        iconFontValue: root.btIconVal
        toggledIconFontValue: ""
        label: root.btText
        tooltip: root.btBatteryTooltip(root.btDevices)
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
