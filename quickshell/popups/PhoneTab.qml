import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Phone tab of the side panel (Super+N > Phone): KDE Connect through `kdeconnect-cli`. Lists the phones
// kdeconnectd knows, with Pair / Unpair, Ping, Send clipboard and Send file (a typed path; there is
// no file picker). Phone notifications arrive on their own through the notification daemon, and
// clipboard sync is a per-device plugin switch in the phone app.
// `kdeconnect-cli -l` is expected as "- Name: id (paired and reachable)" per line.
// `active` is true while this tab is showing.
ColumnLayout {
    id: root
    property bool active: false
    spacing: MenuStyle.pad

    property var devices: []               // { id, name, paired, reachable }
    property string selectedId: ""
    property string status: ""
    property bool statusError: false       // the status is a failure: shown as an error line

    readonly property var current: root.devices.find(d => d.id === root.selectedId) || root.devices[0] || null
    readonly property bool busy: cmdProc.running || clipProc.running
    property bool confirmUnpair: false

    onCurrentChanged: root.confirmUnpair = false
    onActiveChanged: {
        root.confirmUnpair = false;
        if (active) {
            root.status = "";
            root.statusError = false;
            root.refresh();
        }
    }

    // While the tab is open: re-read the devices (a phone coming into range, a pair accepted on it)
    Timer {
        interval: MenuStyle.phoneRefresh
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }

    SunkenField {
        Layout.fillWidth: true
        implicitHeight: Math.max(MenuStyle.rowHeight * 3, root.devices.length === 0 ? noPhone.implicitHeight + 2 * MenuStyle.pad : deviceColumn.implicitHeight + 4)
        padding: 2

        EmptyState {
            id: noPhone
            anchors.fill: parent
            visible: root.devices.length === 0
            glyph: "\ue324"
            text: root.status !== "" ? root.status : "No phone found. Install KDE Connect on it and pair from there."
        }

        ColumnLayout {
            id: deviceColumn
            width: parent.width
            spacing: 0
            Repeater {
                model: root.devices
                MenuRow {
                    hoverLit: false
                    Layout.fillWidth: true
                    selected: root.current && modelData.id === root.current.id
                    text: modelData.name
                    trailing: modelData.paired ? (modelData.reachable ? "paired" : "offline") : (modelData.reachable ? "not paired" : "offline")
                    glyph: "\ue324"
                    onClicked: root.selectedId = modelData.id
                    // One lit row: the pointer moves the selection (real pointer movement only)
                    HoverHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onPointChanged: {
                            if (root.pointerMoved(point.scenePosition))
                                root.selectedId = modelData.id;
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        visible: !root.confirmUnpair
        BevelButton {
            Layout.fillWidth: true
            text: root.current && root.current.paired ? "Unpair" : "Pair"
            glyph: "\ue157"
            enabled: root.current !== null && !root.busy && (root.current.paired || root.current.reachable)
            focusPolicy: Qt.NoFocus
            onClicked: {
                if (root.current.paired)
                    root.confirmUnpair = true;
                else
                    root.run(["--pair"], "Pairing request sent: accept it on the phone");
            }
        }
        BevelButton {
            Layout.fillWidth: true
            text: "Ping"
            glyph: "\ue0b7"
            enabled: root.usable && !root.busy
            focusPolicy: Qt.NoFocus
            onClicked: root.run(["--ping"], "Pinged")
        }
    }
    // Inline confirm: the verb is the default button
    ConfirmBar {
        Layout.fillWidth: true
        visible: root.confirmUnpair
        glyph: "\ue002"
        message: root.current ? "Unpair " + root.current.name + "?" : ""
        verb: "Unpair"
        onAccepted: {
            root.confirmUnpair = false;
            root.run(["--unpair"], "Unpaired");
        }
        onCanceled: root.confirmUnpair = false
    }
    BevelButton {
        Layout.fillWidth: true
        text: "Send clipboard"
        glyph: "\ue14f"
        enabled: root.usable && !root.busy
        focusPolicy: Qt.NoFocus
        onClicked: {
            clipProc.deviceId = root.current.id;
            clipProc.running = true;
        }
    }

    SunkenField {
        Layout.fillWidth: true
        implicitHeight: MenuStyle.searchHeight
        padding: 4
        TextField {
            id: pathInput
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            anchors.fill: parent
            placeholderText: "File path, e.g. ~/shot.png"
            placeholderTextColor: MenuStyle.bevelDark
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            selectionColor: Config.colors.shadow
            padding: 0
            verticalAlignment: Text.AlignVCenter
            background: Item {}
            Keys.onReturnPressed: root.sendFile()
            Keys.onEnterPressed: root.sendFile()
        }
    }
    BevelButton {
        Layout.fillWidth: true
        text: "Send file"
        glyph: "\ue2c6"
        enabled: root.usable && !root.busy && pathInput.text.trim() !== ""
        focusPolicy: Qt.NoFocus
        onClicked: root.sendFile()
    }

    StatusBar {
        visible: root.devices.length > 0
        kind: root.busy ? "state" : (root.statusError ? "error" : "state")
        text: root.busy ? "Working..." : root.status
    }

    // Paired and reachable: the actions that need the phone to answer
    readonly property bool usable: root.current !== null && root.current.paired && root.current.reachable

    // True when the pointer really moved since the last call (a row sliding under a still pointer is not a move)
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(p) {
        if (p.x === root.lastPointer.x && p.y === root.lastPointer.y)
            return false;
        root.lastPointer = p;
        return true;
    }

    function parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            const m = line.match(/^- (.+): (\S+) \((.*)\)\s*$/);
            if (m)
                out.push({ id: m[2], name: m[1], paired: /paired/.test(m[3]) && !/not paired|unpaired/.test(m[3]), reachable: /reachable/.test(m[3]) && !/unreachable/.test(m[3]) });
        }
        return out;
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    // Run a kdeconnect-cli action on the selected phone; `done` is the message on success
    function run(args, done) {
        if (!root.current || !/^[A-Za-z0-9_]+$/.test(root.current.id))
            return;
        cmdProc.done = done;
        cmdProc.command = ["kdeconnect-cli", "-d", root.current.id].concat(args);
        cmdProc.running = true;
    }

    function sendFile() {
        let p = pathInput.text.trim();
        if (p === "" || !root.usable || root.busy)
            return;
        if (p.startsWith("~/"))
            p = Quickshell.env("HOME") + p.slice(1);
        root.run(["--share", p], "Sent " + p.split("/").pop());
    }

    Process {
        id: listProc
        command: ["kdeconnect-cli", "-l"]
        stdout: StdioCollector {
            onStreamFinished: root.devices = root.parse(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    root.status = text.trim();
                    root.statusError = true;
                }
            }
        }
    }

    Process {
        id: cmdProc
        property string done: ""
        stderr: StdioCollector {
            id: cmdErr
        }
        onExited: code => {
            root.statusError = code !== 0;
            root.status = code === 0 ? cmdProc.done : (cmdErr.text.trim() || "Failed (exit " + code + ")");
            root.refresh();
        }
    }

    // Clipboard text to the phone: read it with wl-paste, then share it as text. Only sent (and
    // "Clipboard sent") when wl-paste gave some text and kdeconnect-cli succeeded.
    Process {
        id: clipProc
        property string deviceId: ""
        command: ["sh", "-c", "t=$(wl-paste -n --type text 2>/dev/null) && [ -n \"$t\" ] && kdeconnect-cli -d \"$1\" --share-text \"$t\"", "sh", clipProc.deviceId]
        onExited: code => {
            root.statusError = code !== 0;
            root.status = code === 0 ? "Clipboard sent" : "Could not send the clipboard (is it text?)";
        }
    }
}
