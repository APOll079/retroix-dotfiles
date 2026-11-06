import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell.Bluetooth
import ".."

// Bluetooth, straight from BlueZ through Quickshell.Bluetooth (no bluetoothctl polling).
// - Power and scan toggles.
// - Paired devices: click to connect / disconnect; Trust (= BlueZ lets it auto-reconnect) and
//   Forget (asks first) per row; battery when the device reports it.
// - While scanning, unpaired devices show under "Available": click pairs, then trusts and
//   connects. Headphones and speakers pair without a PIN.
// - PIN / passkey / number-comparison devices: while the menu is open, scripts/bt-agent.py runs as a
//   BlueZ pairing agent and is the default agent until the menu closes (then blueman's takes over
//   again). Each request it forwards shows as a prompt block above the lists (type the PIN, read the
//   code to type on the device, compare six digits, Allow); the answer goes back to it as one JSON
//   line. Protocol: see the script's header.
PopupWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar
    property var closeCallback: function() {}
    property var forgetting: null     // device waiting for "Forget?" confirm
    // The pairing request waiting for an answer from bt-agent.py: {id, method, name, code, uuid} or null
    property var prompt: null

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    readonly property var devices: Bluetooth.devices.values
    readonly property var paired: devices.filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || root.label(a).localeCompare(root.label(b)))
    readonly property var available: devices.filter(d => !d.paired && (d.name !== "" || d.deviceName !== "")).sort((a, b) => root.label(a).localeCompare(root.label(b)))

    anchor.window: root.bar
    anchor.rect.y: MenuStyle.barHeight
    implicitWidth: MenuStyle.widthMedium
    implicitHeight: MenuStyle.chromeHeight + column.implicitHeight
    color: "transparent"

    function label(d) {
        return d.name || d.deviceName || d.address;
    }

    function status(d) {
        if (d.pairing)
            return "Pairing...";
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting...";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting...";
        if (d.connected)
            return d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "Connected";
        return "";
    }

    // Last pairing failure, shown on the status line until the next pair
    property string pairError: ""
    // The status line: no adapter, else a failed pair
    readonly property string statusText: root.adapter === null ? "No Bluetooth adapter" : root.pairError

    // What the prompt block says for each request kind
    // The device name is shortened, never the sentence around it
    function shortName(n) {
        const max = MenuStyle.bluetoothNameChars;
        const name = n || "device";
        return name.length > max ? name.slice(0, max - 1) + "\u2026" : name;
    }
    function promptTitle(p) {
        const who = root.shortName(p.name);
        switch (p.method) {
        case "pin": return "PIN for " + who;
        case "passkey": return "Passkey for " + who;
        case "displayPin": return "Type this PIN on " + who;
        case "displayPasskey": return "Type this passkey on " + who;
        case "confirm": return "Does " + who + " match?";
        case "authorize": return "Let " + who + " pair?";
        default: return "Let " + who + " use a service?";
        }
    }
    readonly property bool promptTyped: prompt !== null && (prompt.method === "pin" || prompt.method === "passkey")
    readonly property bool promptShown: prompt !== null && (prompt.method === "displayPin" || prompt.method === "displayPasskey" || prompt.method === "confirm")
    readonly property bool promptAnswers: prompt !== null && prompt.method !== "displayPin" && prompt.method !== "displayPasskey"
    readonly property string promptVerb: prompt !== null && (prompt.method === "authorize" || prompt.method === "service") ? "Allow" : "Pair"

    // Answer the pending request (ok = Pair / Allow), or turn it down; a display-only prompt just goes away
    function answerPrompt(ok, value) {
        const p = root.prompt;
        root.prompt = null;
        if (p && p.id > 0)
            agent.write(JSON.stringify({ id: p.id, ok: ok, value: value }) + "\n");
        else if (!ok && pairWatch.device)
            pairWatch.device.cancelPair();
    }

    // The pairing helper: runs while the menu is open
    Process {
        id: agent
        command: ["python3", "-I", Quickshell.shellDir + "/scripts/bt-agent.py"]
        stdinEnabled: true
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("bt-agent: " + text.trim())
        }
        stdout: SplitParser {
            onRead: line => {
                let r = null;
                try {
                    r = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (r.method === "cancel" || r.method === "release")
                    root.prompt = null;
                else if (r.method !== "ready")
                    root.prompt = r;
            }
        }
    }

    // Pair, then trust (auto-reconnect) and connect once BlueZ reports it paired
    function pairDevice(d) {
        root.pairError = "";
        d.pair();
        pairWatch.device = d;
    }

    Connections {
        id: pairWatch
        property var device: null
        target: device
        function onPairedChanged() {
            if (pairWatch.device && pairWatch.device.paired) {
                pairWatch.device.trusted = true;
                pairWatch.device.connect();
                pairWatch.device = null;
            }
        }
        // BlueZ stopped pairing without it being paired (rejected, timed out, wrong PIN): drop any
        // prompt and say so
        function onPairingChanged() {
            if (pairWatch.device && !pairWatch.device.pairing && !pairWatch.device.paired) {
                root.prompt = null;
                root.pairError = "Pairing " + root.label(pairWatch.device) + " failed";
                pairWatch.device = null;
            }
        }
    }

    // Scanning stops on its own after a while
    Timer {
        id: scanStop
        interval: MenuStyle.bluetoothScanTime
        onTriggered: if (root.adapter) root.adapter.discovering = false
    }

    PopupWindowFrame {
        windowTitle: "Bluetooth"
        windowTitleIcon: "\ue1a7"

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: MenuStyle.pad

            RowLayout {
                Layout.fillWidth: true
                spacing: MenuStyle.pad
                BevelButton {
                    Layout.fillWidth: true
                    enabled: root.adapter !== null
                    text: root.powered ? "Turn Bluetooth Off" : "Turn Bluetooth On"
                    onClicked: root.adapter.enabled = !root.adapter.enabled
                }
                BevelButton {
                    enabled: root.powered
                    glyph: "\ue1aa"
                    text: "Scan"
                    checked: root.adapter !== null && root.adapter.discovering
                    onClicked: {
                        root.adapter.discovering = !root.adapter.discovering;
                        if (root.adapter.discovering)
                            scanStop.restart();
                    }
                }
            }

            // Status: no adapter, or the last pairing failure
            StatusBar {
                visible: root.statusText !== "" && root.prompt === null
                kind: "error"
                text: root.statusText
            }

            // Pairing request from the agent: title, the code or a field to type in, verb buttons
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.prompt !== null
                spacing: MenuStyle.gap
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: MenuStyle.titleFont
                    font.pixelSize: MenuStyle.fontSize
                    color: Config.colors.text
                    text: root.prompt ? root.promptTitle(root.prompt) : ""
                }
                SunkenField {
                    Layout.fillWidth: true
                    visible: root.promptShown
                    implicitHeight: MenuStyle.bluetoothCodeHeight
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.bluetoothCodeSize
                        color: Config.colors.text
                        text: root.prompt && root.prompt.code ? root.prompt.code : ""
                    }
                }
                SearchBox {
                    id: pinField
                    Layout.fillWidth: true
                    visible: root.promptTyped
                    showIcon: false
                    placeholder: root.prompt && root.prompt.method === "passkey" ? "6 digits" : "PIN"
                    onEscaped: root.answerPrompt(false, "")
                    onKeyPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            event.accepted = true;
                            if (pinField.text !== "")
                                root.answerPrompt(true, pinField.text);
                        }
                    }
                    Connections {
                        target: root
                        function onPromptChanged() {
                            pinField.text = "";
                            if (root.promptTyped)
                                pinField.focusInput();
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.pad
                    BevelButton {
                        Layout.fillWidth: true
                        visible: root.promptAnswers
                        enabled: !root.promptTyped || pinField.text !== ""
                        text: root.promptVerb
                        onClicked: root.answerPrompt(true, root.promptTyped ? pinField.text : "")
                    }
                    BevelButton {
                        Layout.fillWidth: true
                        text: "Cancel"
                        onClicked: root.answerPrompt(false, "")
                    }
                }
            }

            // Forget confirm: the verb is the default button
            ConfirmBar {
                Layout.fillWidth: true
                visible: root.forgetting !== null
                glyph: "\ue002"
                message: root.forgetting ? "Forget " + root.shortName(root.label(root.forgetting)) + "?" : ""
                verb: "Forget"
                onAccepted: {
                    root.forgetting.forget();
                    root.forgetting = null;
                }
                onCanceled: root.forgetting = null
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                visible: root.powered
                font.family: MenuStyle.titleFont
                font.pixelSize: MenuStyle.fontSize
                color: Config.colors.text
                text: "Paired"
            }

            SunkenField {
                Layout.fillWidth: true
                visible: root.powered
                Layout.preferredHeight: root.paired.length === 0 ? noPaired.implicitHeight + 2 * MenuStyle.pad : Math.min(root.paired.length, MenuStyle.bluetoothListRows) * MenuStyle.rowHeight + 2 * padding
                padding: 2
                clip: true

                EmptyState {
                    id: noPaired
                    anchors.fill: parent
                    visible: root.paired.length === 0
                    glyph: "\ue1a7"
                    text: "No paired devices"
                }

                ListView {
                    id: pairedList
                    anchors.fill: parent
                    model: root.paired
                    // The scroll bar floats over the right edge: the rows give it room while it shows
                    ScrollBar.vertical: RetroScrollBar { id: pairedBar }
                    delegate: RowLayout {
                        width: pairedList.width - (pairedBar.visible ? MenuStyle.scrollBarWidth : 0)
                        spacing: MenuStyle.gap
                        MenuRow {
                            Layout.fillWidth: true
                            glyph: modelData.connected ? "\ue1a8" : "\ue1a7"
                            text: root.label(modelData)
                            marked: modelData.connected
                            trailing: root.status(modelData)
                            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                        }
                        // Trust: sunken = BlueZ may auto-reconnect it
                        BevelButton {
                            implicitHeight: MenuStyle.rowHeight
                            text: "Trust"
                            checked: modelData.trusted
                            onClicked: modelData.trusted = !modelData.trusted
                        }
                        BevelButton {
                            implicitHeight: MenuStyle.rowHeight
                            text: "Forget"
                            onClicked: root.forgetting = modelData
                        }
                    }
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                visible: root.powered
                font.family: MenuStyle.titleFont
                font.pixelSize: MenuStyle.fontSize
                color: Config.colors.text
                text: root.adapter && root.adapter.discovering ? "Available (scanning...)" : "Available"
            }

            SunkenField {
                Layout.fillWidth: true
                visible: root.powered
                // Always the full height while on: the menu does not resize when a scan starts or finds devices
                Layout.preferredHeight: MenuStyle.bluetoothListRows * MenuStyle.rowHeight + 2 * padding
                padding: 2
                clip: true

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    anchors.centerIn: parent
                    visible: root.available.length === 0
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: MenuStyle.bevelDark
                    text: root.adapter && root.adapter.discovering ? "Looking for devices..." : "Press Scan to look for devices"
                }

                ListView {
                    id: availableList
                    anchors.fill: parent
                    model: root.available
                    ScrollBar.vertical: RetroScrollBar { id: availableBar }
                    delegate: MenuRow {
                        width: availableList.width - (availableBar.visible ? MenuStyle.scrollBarWidth : 0)
                        glyph: "\ue1aa"
                        text: root.label(modelData)
                        trailing: modelData.pairing ? "Cancel" : "Pair"
                        onClicked: modelData.pairing ? modelData.cancelPair() : root.pairDevice(modelData)
                    }
                }
            }
        }
    }

    function openMenu() {
        root.forgetting = null;
        root.prompt = null;
        agent.running = true;
        root.visible = true;
    }

    function closeMenu() {
        root.forgetting = null;
        root.prompt = null;
        agent.running = false;
        if (root.adapter && root.adapter.discovering)
            root.adapter.discovering = false;
        root.visible = false;
    }
}
