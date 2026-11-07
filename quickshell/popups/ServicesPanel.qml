import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// dinit services (Start > Services, `qs ipc call services_<mon> toggle` or `qs ipc call services toggle`): a real window
// (an xdg toplevel Hyprland floats, centres and lets you move and resize, see windowrules.lua "services-window"), one for
// the whole desktop. ToolWindows.qml owns it and opens / toggles / closes it. Lists `dinitctl list` with state; Start /
// Stop / Restart act on the selected service.
// Two scopes: "User" (your own dinit instance: pipewire, wireplumber, ...) runs straight away;
// "System" (the machine's dinit) runs `doas dinitctl ...` in a floating terminal (the configured
// `execCommands.terminal`, named `qs-dialog` through `execCommands.terminalClassFlag`), so the password prompt is the real one and nothing is stored.
// The window stays open while the terminal is up (it holds no keyboard grab, unlike the old Overlay panel) and the list
// refreshes when the terminal exits. User actions refresh the list when they finish.
// Type to filter, Up / Down select, Escape goes back from the log, then clears the search, then closes the window.
// `dinitctl list` is expected as "[{+}     ] name (pid: 123)" per line; if your dinit prints it
// differently, parse() below is the one place to adjust.
// Under QS_NO_APPLY (the test harness) no dinitctl or terminal runs: the argv lists are recorded in `launched`.
FloatingWindow {
    id: root

    // Hyprland matches this title (windowrules.lua "services-window")
    title: "Services"
    implicitWidth: MenuStyle.windowWidth
    implicitHeight: MenuStyle.windowHeight
    minimumSize: Qt.size(MenuStyle.toolMinWidth, MenuStyle.toolMinHeight)
    visible: false
    color: Config.colors.base

    // Closed by Hyprland (Super+Q, the close dispatcher): reset like closeMenu()
    onClosed: root.visible = false

    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    property var launched: []              // argv lists asked for under QS_NO_APPLY (tests)
    readonly property Item searchItem: searchInput

    property var services: []              // { name, state: running|stopped|other, failed, info }
    property string filter: "all"          // all | running | stopped
    property string scope: "user"          // user | system
    property string error: ""
    // The last Start / Stop / Restart failure; kept apart from `error`, which a list refresh clears
    property string actionError: ""
    property int cursor: 0
    // Log view (user scope): the last lines of the selected service's buffered log, in place of the list
    property bool logOpen: false
    property string logName: ""
    property string logText: ""
    property string logError: ""
    property bool logDone: false
    property string pendingSelect: ""      // showDetails() waits for the list, then selects this and opens its log

    readonly property var shown: {
        const q = searchInput.text.trim().toLowerCase();
        return root.services.filter(s => (root.filter === "all" || s.state === root.filter) && (q === "" || s.name.toLowerCase().includes(q)));
    }
    readonly property var current: root.shown[root.cursor] || null
    readonly property bool busy: actProc.running || termProc.running
    property bool listAgain: false         // a refresh was asked while `dinitctl list` was running
    property string listScope: "user"      // the scope the running `dinitctl list` was started for

    onShownChanged: root.cursor = Math.max(0, Math.min(root.cursor, root.shown.length - 1))

    Item {
        id: frame
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.backOrClose()

        PopupWindowFrame {
            windowTitle: "Services"
            windowTitleIcon: "\ue8b8"
            // Dragging the title bar moves the window, like any Win95 window
            titleDrag: true
            onTitlePressed: root.startSystemMove()

            ColumnLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                SearchBox {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholder: "Filter services"
                    onEscaped: root.backOrClose()
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

                    EmptyState {
                        anchors.fill: parent
                        visible: !root.logOpen && root.shown.length === 0
                        glyph: root.error !== "" ? "\ue000" : (root.services.length === 0 ? "\ue8b8" : "\ue8b6")
                        text: root.error !== "" ? root.error : (root.services.length === 0 ? "No services listed" : "No matches")
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        visible: !root.logOpen
                        model: root.shown
                        currentIndex: root.cursor
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                        ScrollBar.vertical: RetroScrollBar {}
                        delegate: MenuRow {
                            hoverLit: false
                            required property int index
                            required property var modelData
                            width: list.width - list.gutter
                            reserveIcon: true
                            selected: index === root.cursor
                            text: modelData.name
                            subtext: modelData.info
                            trailing: modelData.failed ? "failed" : modelData.state
                            glyph: modelData.failed ? "\ue000" : modelData.state === "running" ? "\ue037" : "\ue047"
                            onClicked: {
                                root.cursor = index;
                                searchInput.focusInput();
                            }
                            // One lit row: the pointer moves the cursor (only on real pointer movement, so a list scrolled by the keys does not fight it)
                            HoverHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onPointChanged: {
                                    if (root.pointerMoved(point.scenePosition))
                                        root.cursor = index;
                                }
                            }
                        }
                    }

                    Flickable {
                        id: logFlick
                        anchors.fill: parent
                        visible: root.logOpen
                        contentWidth: width
                        contentHeight: logBody.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        ScrollBar.vertical: RetroScrollBar {}
                        Text {
                            id: logBody
                            width: logFlick.width - MenuStyle.scrollBarWidth
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            textFormat: Text.PlainText
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: root.logText === "" ? MenuStyle.bevelDark : Config.colors.text
                            text: root.logText !== "" ? root.logText : (!root.logDone ? "Loading..." : (root.logError !== "" ? root.logError : "No log. The service needs log-type = buffer in its dinit file."))
                        }
                    }
                }

                // A failed Start / Stop / Restart. Stays until the next action or the menu opens again.
                StatusBar {
                    visible: root.actionError !== ""
                    kind: "error"
                    text: root.actionError
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap
                    Item {
                        Layout.fillWidth: true
                    }
                    BevelButton {
                        text: "Log"
                        glyph: "\ue873"
                        visible: root.scope === "user" && !root.logOpen
                        enabled: root.current !== null
                        focusPolicy: Qt.NoFocus
                        onClicked: {
                            root.openLog();
                            searchInput.focusInput();
                        }
                    }
                    BevelButton {
                        text: "Back"
                        glyph: "\ue5c4"
                        visible: root.logOpen
                        focusPolicy: Qt.NoFocus
                        onClicked: {
                            root.logOpen = false;
                            searchInput.focusInput();
                        }
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

                StatusBar {
                    kind: root.busy || root.current ? "message" : "state"
                    text: root.busy ? "Working..." : (root.logOpen ? "Log: " + root.logName : root.current ? root.current.name + (root.scope === "system" ? " (asks for doas in a terminal)" : "") : "No service selected")
                    trailing: root.shown.length + " of " + root.services.length
                }
            }
        }
    }

    // --- data ---

    // True when the pointer really moved since the last call (a row sliding under a still pointer is not a move)
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(p) {
        if (p.x === root.lastPointer.x && p.y === root.lastPointer.y)
            return false;
        root.lastPointer = p;
        return true;
    }

    function move(d) {
        if (root.logOpen || root.shown.length === 0)
            return;
        root.cursor = Math.max(0, Math.min(root.shown.length - 1, root.cursor + d));
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
            root.startList();
        }
    }

    // Starts `dinitctl list` (under QS_NO_APPLY only records it)
    function startList() {
        if (root.live)
            listProc.running = true;
        else
            root.launched = root.launched.concat([["dinitctl", root.listScope === "system" ? "--system" : "--user", "list"]]);
    }

    // Escape: back out of the log first, else close the window
    function backOrClose() {
        if (root.logOpen)
            root.logOpen = false;
        else
            root.closeMenu();
    }

    // The System-scope terminal command. Pure: verb and name stay separate arguments after the script,
    // never in its text. classFlag "" = don't name the window.
    function dialogCommand(terminal, classFlag, verb, name) {
        return [terminal].concat(classFlag !== "" ? [classFlag, "qs-dialog"] : []).concat(["fish", "-c", "doas dinitctl --system $argv[1] $argv[2]; echo; read -P 'Press Enter to close'", verb, name]);
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
            const cmd = root.dialogCommand(Config.settings.execCommands.terminal, Config.settings.execCommands.terminalClassFlag, verb, s.name);
            if (root.live) {
                termProc.command = cmd;
                termProc.running = true;
            } else {
                root.launched = root.launched.concat([cmd]);
            }
        } else {
            root.actionError = "";
            // an intended stop must not raise ServiceWatch's "stopped" toast
            ServiceWatch.expect(s.name);
            actProc.verb = verb;
            const cmd = ["dinitctl", "--user", verb, s.name];
            if (root.live) {
                actProc.command = cmd;
                actProc.running = true;
            } else {
                root.launched = root.launched.concat([cmd]);
            }
        }
    }

    Process {
        id: termProc
        onExited: root.refresh()
    }

    // The answer of `dinitctl list` (tests hand it a fixture)
    function gotList(text) {
        if (root.listScope !== root.scope)
            return;
        root.services = ServiceWatch.parseList(text, root.listScope);
        if (root.services.length > 0)
            root.error = "";
        if (root.pendingSelect !== "") {
            const i = root.shown.findIndex(x => x.name === root.pendingSelect);
            root.pendingSelect = "";
            if (i >= 0) {
                root.cursor = i;
                root.openLog();
            }
        }
    }

    Process {
        id: listProc
        command: ["dinitctl", root.listScope === "system" ? "--system" : "--user", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.gotList(text)
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
                root.startList();
                return;
            }
            if (code !== 0 && root.error === "")
                root.error = "dinitctl list failed (exit " + code + ")";
        }
    }

    // Opens the log of the selected user service (scripts/service-log.sh: last 40 lines of `dinitctl --user catlog`)
    function openLog() {
        const s = root.current;
        if (!s || root.scope !== "user")
            return;
        root.logName = s.name;
        root.logText = "";
        root.logError = "";
        root.logDone = false;
        root.logOpen = true;
        logProc.running = false;
        const cmd = ["sh", Quickshell.shellDir + "/scripts/service-log.sh", s.name];
        if (root.live) {
            logProc.command = cmd;
            logProc.running = true;
        } else {
            root.launched = root.launched.concat([cmd]);
        }
    }

    // The toast's Details action (ToolWindows.showServiceDetails calls this): user scope, that service
    // selected in the list, its log open. Opens the window if it is closed.
    function showDetails(name) {
        root.scope = "user";
        root.services = [];
        root.error = "";
        root.openMenu();
        root.pendingSelect = name;
    }

    Process {
        id: logProc
        stdout: StdioCollector {
            onStreamFinished: root.logText = text.replace(/\n+$/, "")
        }
        stderr: StdioCollector {
            onStreamFinished: root.logError = text.trim()
        }
        onExited: root.logDone = true
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
        root.logOpen = false;
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
