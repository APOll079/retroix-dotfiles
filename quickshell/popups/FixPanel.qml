import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Fix my desktop (Start > Troubleshoot), centred like Services: one row per component that can be restarted (PipeWire and
// WirePlumber, the portals, hyprpaper, EasyEffects), each with a Restart button. Restart swaps the row for a ConfirmBar (verb
// "Restart"); only its verb runs scripts/fixes.sh <id>, and the status line shows the result. Nothing is ever restarted without
// that confirm. Quickshell itself is not here as a button: restarting it from inside kills this panel, so the last row only shows
// the command to copy. Up / Down select, Enter = Restart (then the confirm), Escape cancels the confirm, then closes.
// Under QS_NO_APPLY (the test harness) no script is started; the id is recorded in `runLog`.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    readonly property var fixes: [
        { id: "pipewire", label: "PipeWire + WirePlumber", note: "No sound, or the wrong device", glyph: "\ue050" },
        { id: "portals", label: "Portals", note: "Screen sharing, file pickers", glyph: "\ue0b9" },
        { id: "hyprpaper", label: "hyprpaper", note: "No wallpaper", glyph: "\ue3f4" },
        { id: "easyeffects", label: "EasyEffects", note: "Audio effects stopped", glyph: "\ue429" }
    ]
    readonly property string quickshellCommand: "pkill quickshell; quickshell &"

    property int cursor: 0
    property string confirmId: ""          // the row waiting for its confirm, "" = none
    property bool running: false
    property string result: ""
    property bool resultOk: true
    property var runLog: []                // ids run under QS_NO_APPLY (tests)
    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    readonly property var confirmFix: root.fixes.find(f => f.id === root.confirmId) || null

    // An Overlay-layer panel, not a popup of the bar (see ServicesPanel)
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
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
        width: MenuStyle.widthLarge
        height: content.implicitHeight + MenuStyle.chromeTop + MenuStyle.chromeBottom
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.screenHeight / 2 - height / 2)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupWindowFrame {
            windowTitle: "Troubleshoot"
            windowTitleIcon: "\ue869"

            ColumnLayout {
                id: content
                anchors.fill: parent
                spacing: MenuStyle.pad

                FocusScope {
                    id: keys
                    Layout.preferredWidth: 0
                    Layout.preferredHeight: 0
                    focus: true
                    Keys.onPressed: event => root.handleKey(event)
                }

                SunkenField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: list.contentHeight + 2 * padding
                    padding: 2
                    clip: true

                    ListView {
                        id: list
                        anchors.fill: parent
                        model: root.fixes
                        interactive: false
                        delegate: Item {
                            id: entry
                            required property int index
                            required property var modelData
                            readonly property bool asking: root.confirmId === modelData.id
                            width: list.width
                            height: asking ? ask.implicitHeight + MenuStyle.space4 : normal.implicitHeight

                            RowLayout {
                                id: normal
                                visible: !entry.asking
                                width: parent.width
                                spacing: MenuStyle.gap
                                MenuRow {
                                    Layout.fillWidth: true
                                    hoverLit: false
                                    reserveIcon: true
                                    selected: entry.index === root.cursor
                                    glyph: entry.modelData.glyph
                                    text: entry.modelData.label
                                    subtext: entry.modelData.note
                                    onClicked: root.cursor = entry.index
                                }
                                BevelButton {
                                    text: "Restart"
                                    focusPolicy: Qt.NoFocus
                                    enabled: root.confirmId === "" && !root.running
                                    onClicked: root.ask(entry.index)
                                }
                            }
                            ConfirmBar {
                                id: ask
                                visible: entry.asking
                                width: parent.width
                                y: MenuStyle.space2
                                glyph: "\ue002"
                                message: "Restart " + entry.modelData.label + "? Anything using it is interrupted for a moment."
                                verb: "Restart"
                                onAccepted: root.accept()
                                onCanceled: root.cancel()
                            }
                        }
                    }
                }

                // Quickshell is not restarted from here (it would close this panel): the command to run yourself
                GroupFrame {
                    Layout.fillWidth: true
                    title: "Restart Quickshell"
                    SunkenField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: MenuStyle.rowHeight + MenuStyle.gap
                        padding: MenuStyle.space4
                        TextInput {
                            id: shellCommand
                            anchors.fill: parent
                            readOnly: true
                            selectByMouse: true
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.quickshellCommand
                            onActiveFocusChanged: {
                                if (activeFocus)
                                    selectAll();
                                else
                                    keys.forceActiveFocus();
                            }
                        }
                    }
                }

                StatusBar {
                    kind: root.result !== "" && !root.resultOk ? "error" : (root.running || root.result !== "" ? "message" : "state")
                    text: root.running ? "Restarting..." : (root.result !== "" ? root.result : "Nothing is restarted until you confirm")
                }
            }
        }
    }

    // --- actions ---

    function ask(i) {
        if (i < 0 || i >= root.fixes.length || root.running)
            return;
        root.cursor = i;
        root.confirmId = root.fixes[i].id;
    }

    // The confirm's verb: runs the fix once, then forgets the confirm
    function accept() {
        const id = root.confirmId;
        root.confirmId = "";
        if (id !== "")
            root.run(id);
    }

    function cancel() {
        root.confirmId = "";
    }

    // Only ids of the fixed list reach the script (as its one argument)
    function run(id) {
        if (!root.fixes.some(f => f.id === id) || root.running)
            return;
        root.result = "";
        if (!root.live) {
            root.runLog = root.runLog.concat([id]);
            return;
        }
        root.running = true;
        fixProc.command = ["sh", Quickshell.shellDir + "/scripts/fixes.sh", id];
        fixProc.running = true;
    }

    Process {
        id: fixProc
        stdout: StdioCollector {
            id: fixOut
        }
        stderr: StdioCollector {
            id: fixErr
        }
        onExited: code => {
            root.running = false;
            root.resultOk = code === 0;
            const msg = (code === 0 ? fixOut.text : fixErr.text).trim().split("\n")[0];
            root.result = msg !== "" ? msg : (code === 0 ? "Restarted" : "The restart failed (exit " + code + ")");
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.confirmId !== "")
                root.cancel();
            else
                root.closeCallback();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.confirmId !== "")
                root.accept();
            else
                root.ask(root.cursor);
        } else if (event.key === Qt.Key_Down && root.confirmId === "") {
            root.cursor = Math.min(root.fixes.length - 1, root.cursor + 1);
        } else if (event.key === Qt.Key_Up && root.confirmId === "") {
            root.cursor = Math.max(0, root.cursor - 1);
        } else {
            return;
        }
        event.accepted = true;
    }

    function openMenu() {
        root.confirmId = "";
        root.result = "";
        root.cursor = 0;
        root.visible = true;
        keys.forceActiveFocus();
    }

    function closeMenu() {
        root.visible = false;
        root.confirmId = "";
    }
}
