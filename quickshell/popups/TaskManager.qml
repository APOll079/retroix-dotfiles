import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Task Manager (Ctrl+Shift+Esc, left click on the bar's CPU button, `qs ipc call taskmanager open`),
// Win95 style. A normal window Hyprland manages (an xdg toplevel: move, resize, tile, Super+Q), one for
// the whole desktop (TaskWindow.qml owns it). Tabs:
// - Apps: open windows (Hyprland). Switch to, End task (SIGTERM to the window's process), Kill (SIGKILL).
// - Processes: grouped by program (scripts/procs.py), sortable columns, filter, Mine / All, End task / Kill
//   for your own processes (others are listed only).
// - Performance: CPU, RAM, GPU and VRAM history graphs plus temperatures (SysMon.qml).
// Ending things always goes through a confirm row, and only ever signals the pids of the row you picked.
// The data helper runs only while the window is open.
FloatingWindow {
    id: root

    // Hyprland matches this title (windowrules.lua "task-manager": float, size, centre, min size)
    title: "Task Manager"
    implicitWidth: MenuStyle.taskWindowWidth
    implicitHeight: MenuStyle.taskWindowHeight
    minimumSize: Qt.size(MenuStyle.taskMinWidth, MenuStyle.taskMinHeight)
    visible: false
    color: Config.colors.base

    // Closed by Hyprland (Super+Q, the close dispatcher): reset like closeMenu()
    onClosed: root.visible = false

    property string tab: "processes"     // apps | processes | performance
    property var sample: null            // the last procs.py line
    property var cpuHist: []
    property var memHist: []
    property var gpuHist: []
    property var vramHist: []

    property string sortKey: "cpu"       // name | cpu | mem | count
    property bool sortDesc: true
    property bool mineOnly: true
    property string selectedName: ""     // process group, kept across refreshes
    property int appIndex: 0
    property var confirm: null           // { text, verb, signal, name, pid } (pid only for the Apps tab)
    property string notice: ""           // a short refusal shown in the status line for a few seconds

    readonly property var groups: {
        if (!root.sample)
            return [];
        const q = filter.text.trim().toLowerCase();
        const list = root.sample.groups.filter(g => (!root.mineOnly || g.mine) && (q === "" || g.name.toLowerCase().includes(q)));
        const k = root.sortKey, dir = root.sortDesc ? -1 : 1;
        return list.sort((a, b) => (k === "name" ? a.name.localeCompare(b.name) : a[k] - b[k]) * dir);
    }
    readonly property var selectedGroup: root.groups.find(g => g.name === root.selectedName) || null
    readonly property var apps: Hyprland.toplevels.values.filter(t => t.title !== "" && t.lastIpcObject && t.lastIpcObject.pid > 0)
    readonly property var selectedApp: root.apps[root.appIndex] || null

    Item {
        id: frame
        anchors.fill: parent

        // Keys for the tabs without a text field (Apps, Performance)
        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: root.cancelOrClose()
            Keys.onUpPressed: root.appIndex = Math.max(0, root.appIndex - 1)
            Keys.onDownPressed: root.appIndex = Math.min(root.apps.length - 1, root.appIndex + 1)
            Keys.onReturnPressed: root.confirm ? confirmBar.accept() : root.switchToApp()
            Keys.onEnterPressed: root.confirm ? confirmBar.accept() : root.switchToApp()
            Keys.onTabPressed: event => {
                if (event.modifiers & Qt.ControlModifier)
                    root.cycleTab(1);
            }
        }

        PopupWindowFrame {
            windowTitle: root.title
            // Dragging the title bar moves the window, like any Win95 window
            titleDrag: true
            onTitlePressed: root.startSystemMove()
            windowTitleIcon: "\ue1db"

            ColumnLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap
                    Repeater {
                        model: [
                            { key: "apps", text: "Apps", glyph: "\ue8b0" },
                            { key: "processes", text: "Processes", glyph: "\ue8ef" },
                            { key: "performance", text: "Performance", glyph: "\ue922" }
                        ]
                        BevelButton {
                            Layout.fillWidth: true
                            text: modelData.text
                            glyph: modelData.glyph
                            checked: root.tab === modelData.key
                            focusPolicy: Qt.NoFocus
                            onClicked: root.showTab(modelData.key)
                        }
                    }
                }

                // --- Apps ---
                SunkenField {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.tab === "apps"
                    padding: 2
                    clip: true
                    EmptyState {
                        anchors.centerIn: parent
                        width: parent.width - 4 * MenuStyle.pad
                        visible: root.apps.length === 0
                        glyph: "\ue8b0"
                        text: "No open windows"
                    }
                    ListView {
                        id: appList
                        anchors.fill: parent
                        model: root.apps
                        currentIndex: root.appIndex
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        ScrollBar.vertical: RetroScrollBar {}
                        delegate: MenuRow {
                            required property int index
                            required property var modelData
                            width: appList.width - appList.gutter
                            reserveIcon: true
                            selected: index === root.appIndex
                            iconSource: Quickshell.iconPath(String(modelData.lastIpcObject.class || "").toLowerCase(), true)
                            glyph: "\ue8b0"
                            text: modelData.title
                            subtext: (modelData.lastIpcObject.class || "") + "  ·  pid " + modelData.lastIpcObject.pid
                            trailing: modelData.workspace ? modelData.workspace.name.replace("special:", "*") : ""
                            onClicked: root.appIndex = index
                            onDoubleClicked: {
                                root.appIndex = index;
                                root.switchToApp();
                            }
                        }
                    }
                }

                // --- Processes ---
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.tab === "processes"
                    spacing: MenuStyle.gap
                    SearchBox {
                        id: filter
                        Layout.fillWidth: true
                        placeholder: "Filter programs"
                        onEscaped: root.cancelOrClose()
                        onKeyPressed: event => {
                            const i = root.groups.findIndex(g => g.name === root.selectedName);
                            if (event.key === Qt.Key_Down) {
                                root.selectAt(Math.min(root.groups.length - 1, i + 1));
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.selectAt(Math.max(0, i - 1));
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Delete) {
                                root.askEnd(false);
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.confirm) {
                                confirmBar.accept();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape && root.confirm) {
                                // An open confirm row backs out first, before the filter is cleared
                                confirmBar.cancel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) {
                                root.cycleTab(1);
                                event.accepted = true;
                            }
                        }
                    }
                    BevelButton {
                        text: root.mineOnly ? "Mine" : "All"
                        glyph: root.mineOnly ? "\ue7fd" : "\ue7ef"
                        focusPolicy: Qt.NoFocus
                        onClicked: root.mineOnly = !root.mineOnly
                    }
                }

                // Column headers: click to sort, click again to flip
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.tab === "processes"
                    spacing: MenuStyle.gap
                    Repeater {
                        model: [
                            { key: "name", text: "Program", wide: true },
                            { key: "cpu", text: "CPU", wide: false },
                            { key: "mem", text: "Memory", wide: false },
                            { key: "count", text: "Procs", wide: false }
                        ]
                        BevelButton {
                            Layout.fillWidth: modelData.wide
                            Layout.preferredWidth: modelData.wide ? -1 : MenuStyle.taskColumnWidth
                            text: modelData.text + (root.sortKey === modelData.key ? (root.sortDesc ? " ▾" : " ▴") : "")
                            checked: root.sortKey === modelData.key
                            focusPolicy: Qt.NoFocus
                            onClicked: {
                                if (root.sortKey === modelData.key)
                                    root.sortDesc = !root.sortDesc;
                                else {
                                    root.sortKey = modelData.key;
                                    root.sortDesc = modelData.key !== "name";
                                }
                            }
                        }
                    }
                }

                SunkenField {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.tab === "processes"
                    padding: 2
                    clip: true
                    EmptyState {
                        anchors.centerIn: parent
                        width: parent.width - 4 * MenuStyle.pad
                        visible: root.groups.length === 0
                        glyph: root.sample ? "\ue8b6" : "\ue88b"
                        text: root.sample ? "No matches" : "Reading processes..."
                    }
                    ListView {
                        id: procList
                        anchors.fill: parent
                        model: root.groups
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                        ScrollBar.vertical: RetroScrollBar {}
                        delegate: Rectangle {
                            id: procRow
                            required property int index
                            required property var modelData
                            readonly property bool sel: modelData.name === root.selectedName
                            width: procList.width - procList.gutter
                            height: MenuStyle.rowHeight
                            color: sel ? MenuStyle.selectBar : (rowMouse.containsMouse ? Config.colors.highlight : "transparent")
                            readonly property color ink: sel ? MenuStyle.selectText : (modelData.mine ? Config.colors.text : Config.colors.shadow)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: MenuStyle.pad
                                anchors.rightMargin: MenuStyle.pad
                                spacing: MenuStyle.gap
                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    textFormat: Text.PlainText
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    color: procRow.ink
                                    text: procRow.modelData.name
                                }
                                Repeater {
                                    model: [procRow.modelData.cpu.toFixed(1) + "%", root.bytes(procRow.modelData.mem), String(procRow.modelData.count)]
                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        Layout.preferredWidth: MenuStyle.taskColumnWidth
                                        horizontalAlignment: Text.AlignRight
                                        font.family: MenuStyle.bodyFont
                                        font.pixelSize: MenuStyle.fontSize
                                        color: procRow.ink
                                        text: modelData
                                    }
                                }
                            }
                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.selectedName = procRow.modelData.name
                            }
                        }
                    }
                }

                // --- Performance ---
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.tab === "performance"
                    columns: 2
                    columnSpacing: MenuStyle.pad
                    rowSpacing: MenuStyle.pad
                    Graph {
                        title: "CPU"
                        value: root.sample ? root.sample.cpu.toFixed(0) + "%  ·  " + SysMon.tempText(SysMon.cpuTemp) : ""
                        history: root.cpuHist
                    }
                    Graph {
                        title: "Memory"
                        value: root.sample ? root.bytes(root.sample.mem.used) + " / " + root.bytes(root.sample.mem.total) : ""
                        history: root.memHist
                    }
                    Graph {
                        title: "GPU"
                        value: root.sample && root.sample.gpu ? root.sample.gpu.busy + "%  ·  " + SysMon.tempText(SysMon.gpuJunction) : "no data"
                        history: root.gpuHist
                    }
                    Graph {
                        title: "Video memory"
                        value: root.sample && root.sample.gpu ? root.bytes(root.sample.gpu.vramUsed) + " / " + root.bytes(root.sample.gpu.vramTotal) : "no data"
                        history: root.vramHist
                    }
                }

                // --- Confirm: replaces the action row while a question is open ---
                ConfirmBar {
                    id: confirmBar
                    Layout.fillWidth: true
                    visible: root.confirm !== null
                    message: root.confirm ? root.confirm.text : ""
                    verb: root.confirm ? root.confirm.verb : ""
                    glyph: "\ue002"
                    onAccepted: root.doConfirm()
                    onCanceled: root.confirm = null
                }

                // --- Actions ---
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.confirm === null
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
                        text: root.notice !== "" ? root.notice : root.statusText()
                    }
                    BevelButton {
                        visible: root.tab === "apps"
                        text: "Switch to"
                        enabled: root.selectedApp !== null
                        focusPolicy: Qt.NoFocus
                        onClicked: root.switchToApp()
                    }
                    BevelButton {
                        visible: root.tab !== "performance"
                        text: "End task"
                        enabled: root.tab === "apps" ? root.selectedApp !== null : (root.selectedGroup !== null && root.selectedGroup.mine)
                        focusPolicy: Qt.NoFocus
                        onClicked: root.askEnd(false)
                    }
                    BevelButton {
                        visible: root.tab !== "performance"
                        text: "Kill"
                        enabled: root.tab === "apps" ? root.selectedApp !== null : (root.selectedGroup !== null && root.selectedGroup.mine)
                        focusPolicy: Qt.NoFocus
                        onClicked: root.askEnd(true)
                    }
                }
            }
        }
    }

    // A labelled history graph: one solid bar per sample on the dithered track, newest on the right
    component Graph: ColumnLayout {
        id: graph
        property string title: ""
        property string value: ""
        property var history: []
        Layout.fillWidth: true
        Layout.fillHeight: true
        // Equal columns and rows, whatever the value text says
        Layout.preferredWidth: 1
        Layout.preferredHeight: 1
        spacing: MenuStyle.gap
        RowLayout {
            Layout.fillWidth: true
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                Layout.fillWidth: true
                font.family: MenuStyle.titleFont
                font.pixelSize: MenuStyle.fontSize
                font.bold: true
                color: Config.colors.text
                text: graph.title
            }
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: Config.colors.text
                text: graph.value
            }
        }
        SunkenField {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 2
            Dither {
                anchors.fill: parent
                color1: Config.colors.base
                color2: Config.colors.highlight
            }
            Row {
                id: bars
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height
                spacing: 1
                readonly property real barWidth: Math.max(1, Math.floor((parent.width - (MenuStyle.taskHistory - 1)) / MenuStyle.taskHistory))
                Repeater {
                    model: graph.history
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: bars.barWidth
                        height: Math.round(bars.height * Math.max(0, Math.min(1, modelData)))
                        color: MenuStyle.selectBar
                    }
                }
            }
        }
    }

    // --- data ---

    Process {
        id: feed
        command: ["python3", "-I", Quickshell.shellDir + "/scripts/procs.py", "--interval", String(MenuStyle.taskInterval / 1000)]
        running: root.visible
        stdout: SplitParser {
            onRead: data => root.take(data)
        }
    }

    function take(line) {
        let s = null;
        try {
            s = JSON.parse(line);
        } catch (e) {
            return;
        }
        root.sample = s;
        const push = (arr, v) => arr.concat([v]).slice(-MenuStyle.taskHistory);
        root.cpuHist = push(root.cpuHist, s.cpu / 100);
        root.memHist = push(root.memHist, s.mem.total > 0 ? s.mem.used / s.mem.total : 0);
        root.gpuHist = push(root.gpuHist, s.gpu ? s.gpu.busy / 100 : 0);
        root.vramHist = push(root.vramHist, s.gpu && s.gpu.vramTotal > 0 ? s.gpu.vramUsed / s.gpu.vramTotal : 0);
        if (root.selectedName === "" && root.groups.length > 0)
            root.selectedName = root.groups[0].name;
    }

    function bytes(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576)
            return Math.round(b / 1048576) + " MB";
        return Math.round(b / 1024) + " KB";
    }

    function statusText() {
        if (!root.sample)
            return "";
        const memPct = root.sample.mem.total > 0 ? Math.round(100 * root.sample.mem.used / root.sample.mem.total) : 0;
        return root.sample.count + " processes  ·  CPU " + Math.round(root.sample.cpu) + "%  ·  RAM " + memPct + "%";
    }

    function selectAt(i) {
        const g = root.groups[i];
        if (g) {
            root.selectedName = g.name;
            procList.positionViewAtIndex(i, ListView.Contain);
        }
    }

    // --- actions (only ever signal the pids of the row you picked) ---

    function switchToApp() {
        const t = root.selectedApp;
        if (!t)
            return;
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + t.address + "\" })");
    }

    // What happens if a core process is ended; "" = an ordinary program
    function coreEffect(name) {
        const n = name.toLowerCase();
        if (n === "quickshell" || n === "qs")
            return "the bar and every menu go away until it is restarted";
        if (n === "hyprland" || n === "start-hyprland")
            return "your session ends and every window closes";
        if (n.startsWith("pipewire") || n === "wireplumber")
            return "all sound stops";
        if (n.startsWith("dinit"))
            return "your user services go down";
        if (n === "dbus-daemon" || n === "dbus-broker")
            return "desktop apps lose their connection";
        return "";
    }

    function groupOfPid(pid) {
        return root.sample ? root.sample.groups.find(g => g.pids.indexOf(pid) !== -1) || null : null;
    }

    function ownHelper(g) {
        return root.sample !== null && g.pids.indexOf(root.sample.self) !== -1;
    }

    function say(text) {
        root.notice = text;
        noticeTimer.restart();
    }
    Timer {
        id: noticeTimer
        interval: 4000
        onTriggered: root.notice = ""
    }

    // A real pid: -1 would signal everything you own, 0 your process group
    function validPid(p) {
        return typeof p === "number" && Number.isInteger(p) && p > 1;
    }

    function askEnd(force) {
        let name = "", pid = 0;
        if (root.tab === "apps") {
            const t = root.selectedApp;
            if (!t)
                return;
            pid = t.lastIpcObject.pid;
            if (!root.validPid(pid)) {
                root.say("No pid for this window");
                return;
            }
            const g = root.groupOfPid(pid);
            name = g ? g.name : t.title;
            if (g && root.ownHelper(g)) {
                root.say("This is the Task Manager's own helper: ending it would freeze this window");
                return;
            }
        } else if (root.tab === "processes") {
            const g = root.selectedGroup;
            if (!g || !g.mine)
                return;
            if (root.ownHelper(g)) {
                root.say(g.name + " is the Task Manager's own helper: ending it would freeze this window");
                return;
            }
            name = g.name;
        } else
            return;
        const effect = root.coreEffect(name);
        const verb = force ? "Kill" : "End task";
        if (effect !== "")
            root.confirm = { text: name + " is a core process: " + effect + ". " + (force ? "Kill" : "End") + " anyway?", verb: verb + " anyway", signal: force ? "KILL" : "TERM", name: name, pid: pid };
        else {
            const g = root.tab === "processes" ? root.selectedGroup : null;
            root.confirm = { text: (force ? "Kill " : "End ") + (root.tab === "apps" ? root.selectedApp.title : name + (g && g.count > 1 ? " (" + g.count + " processes)" : "")) + "?", verb: verb, signal: force ? "KILL" : "TERM", name: name, pid: pid };
        }
    }

    // The pids are read again from the live sample now, not from when the question was asked
    function doConfirm() {
        const c = root.confirm;
        root.confirm = null;
        if (!c)
            return;
        let pids = [];
        if (c.pid > 0) {
            const g = root.groupOfPid(c.pid);
            if (g && !root.ownHelper(g))
                pids = [c.pid];
        } else {
            const g = root.sample ? root.sample.groups.find(x => x.name === c.name && x.mine) : null;
            if (g && !root.ownHelper(g))
                pids = g.pids;
        }
        pids = pids.filter(p => root.validPid(p));
        if (pids.length === 0) {
            root.say(c.name + " is already gone");
            return;
        }
        Quickshell.execDetached(["kill", "-" + c.signal].concat(pids.map(p => String(p))));
    }

    function cancelOrClose() {
        if (root.confirm)
            root.confirm = null;
        else
            root.closeMenu();
    }

    function showTab(key) {
        root.tab = key;
        root.confirm = null;
        if (key === "processes")
            filter.focusInput();
        else
            keys.forceActiveFocus();
    }

    function cycleTab(d) {
        const tabs = ["apps", "processes", "performance"];
        root.showTab(tabs[(tabs.indexOf(root.tab) + d + tabs.length) % tabs.length]);
    }

    onVisibleChanged: {
        SysMon.taskOpen = visible;
        if (!visible) {
            root.sample = null;
            root.cpuHist = [];
            root.memHist = [];
            root.gpuHist = [];
            root.vramHist = [];
        }
    }

    // Open on `tab` ("" = the tab it had). Already open: focus it where it is (it is never moved
    // to another monitor; you move windows with the mouse), never a second window.
    function open(tab) {
        if (tab !== "")
            root.tab = tab;
        if (root.visible) {
            root.focusSelf();
            root.showTab(root.tab);
            return;
        }
        root.confirm = null;
        filter.text = "";
        Hyprland.refreshToplevels();
        root.visible = true;
        root.showTab(root.tab);
    }

    // Our own toplevel: this title, this process (the address form switchToApp uses)
    function focusSelf() {
        const t = Hyprland.toplevels.values.find(w => w.title === root.title && w.lastIpcObject && w.lastIpcObject.pid === Quickshell.processId);
        if (t)
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + t.address + "\" })");
    }

    function closeMenu() {
        root.visible = false;
    }
}
