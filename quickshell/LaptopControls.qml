import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "popups" as Popups

// The status half of the bar's right side (Bar.qml puts it inside the plain BarWell): a Row of raised,
// boxed BarButtons with a gap between them: [mic, screen share, caffeine] [sysmon] [ETH] [Bluetooth].
Row {
    id: root
    spacing: MenuStyle.gap

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
        + (vpnBtn.visible ? vpnBtn.width : 0) + (recBtn.visible ? recBtn.width : 0) + (pauseBtn.visible ? pauseBtn.width : 0) + (replayInd.visible ? replayInd.width : 0)
        + caffeineBtn.width + ethLabel.width + btBtn.width
    // The gaps between the buttons that are shown (caffeine, sysmon, ETH and Bluetooth always are), plus one to the tray
    readonly property int itemCount: 4 + (micIcon.visible ? 1 : 0) + (screenIcon.visible ? 1 : 0) + (vpnBtn.visible ? 1 : 0) + (recBtn.visible ? 1 : 0) + (pauseBtn.visible ? 1 : 0) + (replayInd.visible ? 1 : 0)
    readonly property real widthWithGpu: otherWidth + sysProbe.implicitWidth + root.spacing * root.itemCount

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
        interactive: false
        urgent: Privacy.micLive   // an app is recording and the microphone is not muted
        iconFontValue: Privacy.micMuted ? "\ue02b" : "\ue029"
    }
    BarButton {
        id: screenIcon
        visible: Privacy.screen
        interactive: false
        urgent: true
        iconFontValue: "\ue0e2"
    }

    // Recording: "REC 0:42" in the urgent colour while the overlay's Record is running; a click stops it
    BarButton {
        id: recBtn
        visible: RecordState.recording
        urgent: true
        iconFontValue: ""
        // equal-width words (non-breaking spaces in a monospace font): pausing must not move the buttons beside it
        label: (RecordState.paused ? "PAUSED\u00a0" : "REC\u00a0\u00a0\u00a0\u00a0") + RecordState.label
        tooltip: "Click to stop recording"
        onClicked: RecordState.stop()
    }
    // Pause / resume the recording (Super+Alt+P)
    BarButton {
        id: pauseBtn
        visible: RecordState.recording
        iconFontValue: ""
        minWidth: MenuStyle.barLabelButtonWidth   // fits both words, so the button keeps its width
        label: RecordState.paused ? "Resume" : "Pause"
        tooltip: RecordState.paused ? "Resume the recording" : "Pause the recording"
        onClicked: RecordState.togglePause()
    }
    // Replay buffer armed (Super+Alt+R toggles, Super+Alt+S saves the last seconds)
    BarButton {
        id: replayInd
        visible: RecordState.replaying
        interactive: false
        dim: true
        iconFontValue: ""
        label: "REPLAY"
    }

    // Caffeine: sunken while on (idle dim/lock/screens-off paused)
    BarButton {
        id: caffeineBtn
        toggledIconFontValue: ""
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
        toggledIconFontValue: ""   // pushed in (menu or Task Manager open) must not swap the icon: the button would grow
        // No icon: the CPU/RAM labels say what it is (BarButton defaults to the Start grid icon)
        iconFontValue: ""
        label: root.sysLabel(Math.round(SysMon.cpuLoad * 100), SysMon.cpuTemp, SysMon.gpuEdge, SysMon.memPercent, root.showGpu)
        isToggled: root.currentPopup === Config.SystemPopup.SysMonMenu || TaskWindow.visible
        tooltip: "Left click: show / hide the Task Manager \u00b7 Right click: temperatures"
        onClicked: TaskWindow.toggle("performance")
        onRightClicked: root.toggleMenu(root.sysMonMenuRef, Config.SystemPopup.SysMonMenu, sysBtn)
    }

    // VPN (VpnState): shown only while a NetworkManager VPN / WireGuard connection is up; a click takes it down
    BarButton {
        id: vpnBtn
        visible: VpnState.up
        iconFontValue: "\ue897"
        label: VpnState.label
        maxLabelWidth: MenuStyle.barLabelButtonWidth * 2
        tooltip: VpnState.tooltip(VpnState.names)
        onClicked: VpnState.disconnect()
    }

    // Network: a status indicator (the desktop is wired), not a button
    BarButton {
        id: ethLabel
        iconFontValue: root.netIconVal
        toggledIconFontValue: ""
        label: root.netText
        interactive: false
        dim: true
    }

    // Bluetooth: a normal bar button next to the ETH label
    BarButton {
        id: btBtn
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
