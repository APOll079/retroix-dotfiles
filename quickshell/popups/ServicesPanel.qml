import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// dinit services (Start > Services, `qs ipc call services_<mon> toggle`), centred like the Games
// menu. Lists `dinitctl list` with state; Start / Stop / Restart act on the selected service.
// Two scopes: "User" (your own dinit instance: pipewire, wireplumber, ...) runs straight away;
// "System" (the machine's dinit) runs `doas dinitctl ...` in a floating terminal (`kitty --class
// qs-dialog`), so the password prompt is the real one and nothing is stored. The panel closes while
// the terminal is open (it would hold the keyboard over it) and the list refreshes when the
// terminal exits. User actions refresh the list when they finish.
// Type to filter, Up / Down select, Escape clears the search, then closes.
// `dinitctl list` is expected as "[{+}     ] name (pid: 123)" per line; if your dinit prints it
// differently, parse() below is the one place to adjust.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    property var services: []              // { name, state: running|stopped|other, failed, info }
    property string filter: "all"          // all | running | stopped
    property string scope: "user"          // user | system
    property string error: ""
    // The last Start / Stop / Restart failure; kept apart from `error`, which a list refresh clears
    property string actionError: ""
    property int cursor: 0

    readonly property var shown: {
        const q = searchInput.text.trim().toLowerCase();
        return root.services.filter(s => (root.filter === "all" || s.state === root.filter) && (q === "" || s.name.toLowerCase().includes(q)));
    }
    readonly property var current: root.shown[root.cursor] || null
    readonly property bool busy: actProc.running || termProc.running
    property bool listAgain: false         // a refresh was asked while `dinitctl list` was running
    property string listScope: "user"      // the scope the running `dinitctl list` was started for

    onShownChanged: root.cursor = Math.max(0, Math.min(root.cursor, root.shown.length - 1))

    // An Overlay-layer panel, not a popup of the bar: the bar sits below fullscreen windows, so a
    // popup over a fullscreen video showed but its clicks went to the video
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // Covers the bar strip too: a click on the bar (its own button included) closes it
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
        y: Math.round(root.screenHeight / 2 - height / 2)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupWindowFrame {
            windowTitle: "Services"
            windowTitleIcon: "\ue8b8"

            ColumnLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                SearchBox {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholder: "Filter services"
                    onEscaped: root.closeCallback()
                    onKeyPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            root.move(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.move(-1);
                            event.accepted = true;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap
                    Repeater {
                        model: [
                            { key: "all", text: "All" },
                            { key: "running", text: "Running" },
                            { key: "stopped", text: "Stopped" }
                        ]
                        BevelButton {
                            text: modelData.text
                            checked: root.filter === modelData.key
                            focusPolicy: Qt.NoFocus
                            onClicked: {
                                root.filter = modelData.key;
                                searchInput.focusInput();
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [
                            { key: "user", text: "User" },
                            { key: "system", text: "System" }
                        ]
                        BevelButton {
                            text: modelData.text
                            checked: root.scope === modelData.key
                            focusPolicy: Qt.NoFocus
                            onClicked: {
                                root.scope = modelData.key;
                                root.services = [];
                                root.error = "";
                                root.actionError = "";
                                root.refresh();
                                searchInput.focusInput();
                            }
                        }
                    }
                    BevelButton {
                        text: "Refresh"
                        glyph: "\ue5d5"
                        focusPolicy: Qt.NoFocus
                        onClicked: {
                            root.refresh();
                            searchInput.focusInput();
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
                        width: parent.width - 2 * MenuStyle.pad
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        visible: root.shown.length === 0
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: MenuStyle.bevelDark
                        text: root.error !== "" ? root.error : (root.services.length === 0 ? "No services listed" : "No matches")
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        model: root.shown
                        currentIndex: root.cursor
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        delegate: MenuRow {
                            required property int index
                            required property var modelData
                            width: list.width
                            selected: index === root.cursor
                            text: modelData.name
                            subtext: modelData.info
                            trailing: modelData.failed ? "failed" : modelData.state
                            glyph: modelData.failed ? "\ue000" : modelData.state === "running" ? "\ue037" : "\ue047"
                            onClicked: {
                                root.cursor = index;
                                searchInput.focusInput();
                            }
                        }
                        ScrollIndicator.vertical: ScrollIndicator {
                            active: list.moving
                        }
                    }
                }

                // A failed Start / Stop / Restart: urgent icon, normal text, like the Bluetooth menu's
                // status line. Stays until the next action or the menu opens again.
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.actionError !== ""
                    spacing: MenuStyle.gap
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        font.family: MenuStyle.iconFont
                        font.pixelSize: MenuStyle.iconSize
                        Layout.alignment: Qt.AlignTop
                        color: Config.colors.urgent
                        text: "error"
                    }
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        // dinitctl's reason can be long: wrap rather than cut it off
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: Config.colors.text
                        text: root.actionError
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: MenuStyle.bevelDark
                        text: root.busy ? "Working..." : (root.current ? root.current.name + (root.scope === "system" ? " (asks for doas in a terminal)" : "") : "")
                    }
                    BevelButton {
                        text: "Start"
                        glyph: "\ue037"
                        enabled: root.current !== null && !root.busy
                        focusPolicy: Qt.NoFocus
                        onClicked: root.act("start")
                    }
                    BevelButton {
                        text: "Stop"
                        glyph: "\ue047"
                        enabled: root.current !== null && !root.busy
                        focusPolicy: Qt.NoFocus
                        onClicked: root.act("stop")
                    }
                    BevelButton {
                        text: "Restart"
                        glyph: "\ue042"
                        enabled: root.current !== null && !root.busy
                        focusPolicy: Qt.NoFocus
                        onClicked: root.act("restart")
                    }
                }
            }
        }
    }

    // --- data ---

    function move(d) {
        if (root.shown.length === 0)
            return;
        root.cursor = Math.max(0, Math.min(root.shown.length - 1, root.cursor + d));
    }

    function parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            if (line.length < 11 || line[0] !== "[")
                continue;
            const flags = line.slice(1, 9);
            const rest = line.slice(10).trim();
            const sp = rest.search(/\s/);
            const name = sp < 0 ? rest : rest.slice(0, sp);
            const info = sp < 0 ? "" : rest.slice(sp).trim().replace(/^\(|\)$/g, "");
            if (name === "")
                continue;
            out.push({
                name: name,
                state: flags.includes("+") ? "running" : flags.includes("-") ? "stopped" : "other",
                failed: /fail|exit status/i.test(info),
                info: info
            });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }

    // One `dinitctl list` at a time. Asked again while one runs (the scope was switched, an action
    // finished): the old one is stopped, its output is ignored (it belongs to the other scope) and a
    // new one starts as soon as it has exited.
    function refresh() {
        if (listProc.running) {
            root.listAgain = true;
            listProc.running = false;
        } else {
            root.listScope = root.scope;
            listProc.running = true;
        }
    }

    // Start / Stop / Restart. User services run directly. System services open a floating terminal
    // where doas asks for the password: the panel closes first (an Overlay panel with the keyboard
    // would sit over the terminal), the list refreshes when the terminal exits. The name goes in as
    // an argument, never into the script text, and must start with a letter or digit.
    function act(verb) {
        const s = root.current;
        if (!s || !/^[A-Za-z0-9][A-Za-z0-9@._:+-]*$/.test(s.name))
            return;
        if (root.scope === "system") {
            termProc.command = ["kitty", "--class", "qs-dialog", "fish", "-c", "doas dinitctl --system $argv[1] $argv[2]; echo; read -P 'Press Enter to close'", verb, s.name];
            termProc.running = true;
            root.closeCallback();
        } else {
            root.actionError = "";
            actProc.verb = verb;
            actProc.command = ["dinitctl", "--user", verb, s.name];
            actProc.running = true;
        }
    }

    Process {
        id: termProc
        onExited: root.refresh()
    }

    Process {
        id: listProc
        command: ["dinitctl", root.listScope === "system" ? "--system" : "--user", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.listScope !== root.scope)
                    return;
                root.services = root.parse(text);
                if (root.services.length > 0)
                    root.error = "";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (root.listScope === root.scope)
                    root.error = text.trim() !== "" ? text.trim() : "";
            }
        }
        onExited: code => {
            if (root.listAgain) {
                root.listAgain = false;
                root.listScope = root.scope;
                listProc.running = true;
                return;
            }
            if (code !== 0 && root.error === "")
                root.error = "dinitctl list failed (exit " + code + ")";
        }
    }

    Process {
        id: actProc
        property string verb: ""
        stderr: StdioCollector {
            id: actErr
        }
        onExited: code => {
            if (code !== 0)
                root.actionError = actErr.text.trim() !== "" ? actErr.text.trim() : "dinitctl " + actProc.verb + " failed (exit " + code + ")";
            root.refresh();
        }
    }

    function openMenu() {
        root.actionError = "";
        searchInput.text = "";
        root.filter = "all";
        root.cursor = 0;
        root.refresh();
        root.visible = true;
        searchInput.focusInput();
    }

    function closeMenu() {
        root.visible = false;
    }
}
