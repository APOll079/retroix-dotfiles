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
// - Ports: listening TCP / UDP ports with the program that owns each (scripts/ports.sh, ss -ltunp); End task / Kill
//   for your own processes, through the same confirm and safety rules.
// - Performance: CPU, RAM, GPU, VRAM and network (up / down rate) history graphs plus temperatures (SysMon.qml).
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

    property string tab: "processes"     // apps | processes | ports | performance
    property var sample: null            // the last procs.py line
    property var cpuHist: []
    property var memHist: []
    property var gpuHist: []
    property var vramHist: []
    property var netRaw: []              // bytes per second (down + up), one per sample
    property var netRate: null           // { down, up } of the last sample, bytes per second
    property var prevNet: null
    property var ports: []               // ports.sh rows { proto, port, addr, pid, name }
    property bool portsLoaded: false
    property int portIndex: 0
    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    property var killLog: []             // signals sent under QS_NO_APPLY: { signal, pids } (tests)

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
    readonly property var selectedPort: root.ports[root.portIndex] || null
    // The selected port's owner when it is your own process (its group in the live sample), else null
    readonly property var selectedPortGroup: root.selectedPort && root.validPid(root.selectedPort.pid) ? root.ownGroupOfPid(root.selectedPort.pid) : null

    Item {
        id: frame

        anchors.fill: parent

        // Keys for the tabs without a text field (Apps, Performance)
        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: root.cancelOrClose()
            Keys.onUpPressed: root.moveRow(-1)
            Keys.onDownPressed: root.moveRow(1)
            // Delete = End task, with the same confirm as the button (Apps and Ports; Processes has it in its filter box)
            Keys.onDeletePressed: root.askEnd(false)
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

                // Menu bar: File / View open a dropdown with actions this window already has
                MenuStrip {
                    Layout.fillWidth: true
                    menus: [{ text: "File", build: root.fileModel }, { text: "View", build: root.viewModel }]
                    onClosed: root.refocus()
                }

                TabPage {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    tabs: root.tabList
                    current: root.tab
                    onTabClicked: key => root.showTab(key)

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: MenuStyle.pad

                        // --- Apps ---
                        SunkenField {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.tab === "apps"
                            padding: 2
                            clip: true
                            EmptyState {
                                anchors.fill: parent
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
                                    hoverLit: false
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
                                    // One lit row: the pointer moves the selection (real pointer movement only)
                                    HoverHandler {
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onPointChanged: {
                                            if (root.pointerMoved(point.scenePosition))
                                                root.appIndex = index;
                                        }
                                    }
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
                                    onClicked: root.sortBy(modelData.key)
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
                                anchors.fill: parent
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
                                    color: sel ? MenuStyle.selectBar : "transparent"
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
                                        // One lit row: the pointer moves the selection (real pointer movement only)
                                        onPositionChanged: mouse => {
                                            const g = rowMouse.mapToGlobal(mouse.x, mouse.y);
                                            if (root.pointerMoved(Qt.point(g.x, g.y)))
                                                root.selectedName = procRow.modelData.name;
                                        }
                                        onClicked: root.selectedName = procRow.modelData.name
                                    }
                                }
                            }
                        }

                        // --- Ports ---
                        SunkenField {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.tab === "ports"
                            padding: 2
                            clip: true
                            EmptyState {
                                anchors.fill: parent
                                visible: root.ports.length === 0
                                glyph: root.portsLoaded ? "\ue8b6" : "\ue88b"
                                text: root.portsLoaded ? "No listening ports" : "Reading ports..."
                            }
                            ListView {
                                id: portList
                                anchors.fill: parent
                                model: root.ports
                                currentIndex: root.portIndex
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                                ScrollBar.vertical: RetroScrollBar {}
                                delegate: MenuRow {
                                    hoverLit: false
                                    required property int index
                                    required property var modelData
                                    width: portList.width - portList.gutter
                                    reserveIcon: true
                                    selected: index === root.portIndex
                                    glyph: "\ue8be"
                                    text: ":" + modelData.port + "   " + modelData.proto + "   " + modelData.addr
                                    trailing: root.portOwnerText(modelData)
                                    onClicked: root.portIndex = index
                                    // One lit row: the pointer moves the selection (real pointer movement only)
                                    HoverHandler {
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onPointChanged: {
                                            if (root.pointerMoved(point.scenePosition))
                                                root.portIndex = index;
                                        }
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
                            // Network: down + up, scaled to the busiest second in the window (at least 1 MB/s so a quiet line stays flat)
                            Graph {
                                Layout.columnSpan: 2
                                title: "NET"
                                value: root.netRate ? root.netText(root.netRate) : "no data"
                                history: root.netBars(root.netRaw)
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
                            Item {
                                Layout.fillWidth: true
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
                                enabled: root.canEndNow
                                focusPolicy: Qt.NoFocus
                                onClicked: root.askEnd(false)
                            }
                            BevelButton {
                                visible: root.tab !== "performance"
                                text: "Kill"
                                enabled: root.canEndNow
                                focusPolicy: Qt.NoFocus
                                onClicked: root.askEnd(true)
                            }
                        }
                    }
                }

                StatusBar {
                    text: root.notice !== "" ? root.notice : root.statusText()
                    kind: root.notice !== "" ? "message" : "state"
                    trailing: root.tab === "apps" ? root.apps.length + (root.apps.length === 1 ? " window" : " windows")
                        : root.tab === "processes" ? root.groups.length + (root.groups.length === 1 ? " program" : " programs")
                        : root.tab === "ports" ? root.ports.length + (root.ports.length === 1 ? " port" : " ports") : ""
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

    // --- menu bar models (only actions the window already has: its buttons, tabs, sort and filter) ---

    // Something is selected that End task / Kill may act on (your own process; the Ports tab needs a pid in your own group)
    readonly property bool canEndNow: root.tab === "apps" ? root.selectedApp !== null
        : root.tab === "ports" ? root.selectedPortGroup !== null
        : (root.tab === "processes" && root.selectedGroup !== null && root.selectedGroup.mine)
    readonly property bool canEnd: root.confirm === null && root.canEndNow
    readonly property var tabList: [{ key: "apps", text: "Apps" }, { key: "processes", text: "Processes" }, { key: "ports", text: "Ports" }, { key: "performance", text: "Performance" }]

    function fileModel() {
        return [
            { text: "Switch to", enabled: root.confirm === null && root.tab === "apps" && root.selectedApp !== null, action: () => root.switchToApp() },
            { text: "End task", enabled: root.canEnd, action: () => root.askEnd(false) },
            { text: "Kill", enabled: root.canEnd, action: () => root.askEnd(true) },
            { separator: true },
            { text: "Close", action: () => root.cancelOrClose() }
        ];
    }

    function viewModel() {
        const inProcs = root.tab === "processes";
        const out = [
            { text: "Apps", checked: root.tab === "apps", action: () => root.showTab("apps") },
            { text: "Processes", checked: root.tab === "processes", action: () => root.showTab("processes") },
            { text: "Ports", checked: root.tab === "ports", action: () => root.showTab("ports") },
            { text: "Performance", checked: root.tab === "performance", action: () => root.showTab("performance") },
            { separator: true },
            { text: "Only my processes", checked: root.mineOnly, enabled: inProcs, action: () => root.mineOnly = !root.mineOnly },
            { separator: true }
        ];
        for (const c of [["name", "Sort by Program"], ["cpu", "Sort by CPU"], ["mem", "Sort by Memory"], ["count", "Sort by Procs"]])
            out.push({ text: c[1], checked: root.sortKey === c[0], enabled: inProcs, action: () => root.sortBy(c[0]) });
        return out;
    }

    // Click a column header, or pick Sort by: a new column starts in its natural order, the same one flips it
    function sortBy(key) {
        if (root.sortKey === key)
            root.sortDesc = !root.sortDesc;
        else {
            root.sortKey = key;
            root.sortDesc = key !== "name";
        }
    }

    // Keyboard focus back to where the tab keeps it, after a menu closed
    function refocus() {
        if (root.tab === "processes")
            filter.focusInput();
        else
            keys.forceActiveFocus();
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
        const rate = root.rateBetween(root.prevNet, s.net);
        root.prevNet = s.net || null;
        if (rate) {
            root.netRate = rate;
            root.netRaw = push(root.netRaw, rate.down + rate.up);
        }
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

    // What happens if a core process is ended; "" = an ordinary program. The list lives in procs.py (core_effect),
    // every group in the sample carries its answer.
    function coreEffect(name) {
        const g = root.sample ? root.sample.groups.find(x => x.name === name) : null;
        return g && typeof g.core === "string" ? g.core : "";
    }

    // --- network rate (pure) ---

    // Two procs.py `net` samples { rx, tx, t } -> { down, up } in bytes per second; null without a usable pair
    // (no earlier sample, time not moving). A counter that went down (an interface vanished) counts as 0.
    function rateBetween(prev, cur) {
        if (!prev || !cur || typeof prev.t !== "number" || typeof cur.t !== "number")
            return null;
        const dt = cur.t - prev.t;
        if (!(dt > 0))
            return null;
        return { down: Math.max(0, cur.rx - prev.rx) / dt, up: Math.max(0, cur.tx - prev.tx) / dt };
    }

    // 1.2 MB/s, 300 KB/s, 12 B/s (the same 1024 steps as bytes())
    function rateText(bps) {
        if (!(bps >= 0))
            return "0 B/s";
        if (bps >= 1073741824)
            return (bps / 1073741824).toFixed(1) + " GB/s";
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(1) + " MB/s";
        if (bps >= 1024)
            return Math.round(bps / 1024) + " KB/s";
        return Math.round(bps) + " B/s";
    }

    // "1.2 MB/s down 300 KB/s up"; the label on the Performance tab is "NET " + this
    function netText(r) {
        return root.rateText(r.down) + " down " + root.rateText(r.up) + " up";
    }

    // Raw bytes per second -> 0..1 bars, scaled to the busiest sample but never below 1 MB/s
    function netBars(raw) {
        const max = Math.max(1048576, ...raw);
        return raw.map(v => v / max);
    }

    // --- ports ---

    // The right-hand text of a port row: "firefox (1234)", or why there is no owner
    function portOwnerText(r) {
        if (!root.validPid(r.pid))
            return "owner not visible";
        return (r.name !== "" ? r.name : "?") + " (" + r.pid + ")";
    }

    // The group of a pid in the live sample when that group is yours, else null
    function ownGroupOfPid(pid) {
        const g = root.groupOfPid(pid);
        return g && g.mine ? g : null;
    }

    function moveRow(d) {
        if (root.tab === "ports")
            root.portIndex = Math.max(0, Math.min(root.ports.length - 1, root.portIndex + d));
        else
            root.appIndex = Math.max(0, Math.min(root.apps.length - 1, root.appIndex + d));
    }

    // True when the pointer really moved since the last call (a row sliding under a still pointer is not a move)
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(p) {
        if (p.x === root.lastPointer.x && p.y === root.lastPointer.y)
            return false;
        root.lastPointer = p;
        return true;
    }

    // ports.sh output -> rows, [] for anything else
    function parsePorts(text) {
        try {
            const d = JSON.parse(text);
            if (!Array.isArray(d))
                return [];
            return d.filter(r => r && typeof r.port === "number" && typeof r.proto === "string" && typeof r.addr === "string")
                .map(r => ({ proto: r.proto, port: r.port, addr: r.addr, pid: Number.isInteger(r.pid) ? r.pid : null, name: typeof r.name === "string" ? r.name : "" }));
        } catch (e) {
            return [];
        }
    }

    function refreshPorts() {
        if (root.live && !portsProc.running)
            portsProc.running = true;
    }

    Process {
        id: portsProc
        command: ["sh", Quickshell.shellDir + "/scripts/ports.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sel = root.selectedPort;
                root.ports = root.parsePorts(text);
                root.portsLoaded = true;
                // keep the same row selected across refreshes
                if (sel) {
                    const i = root.ports.findIndex(r => r.port === sel.port && r.proto === sel.proto && r.addr === sel.addr);
                    root.portIndex = i >= 0 ? i : Math.min(root.portIndex, Math.max(0, root.ports.length - 1));
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: root.visible && root.tab === "ports"
        repeat: true
        onTriggered: root.refreshPorts()
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
        } else if (root.tab === "ports") {
            const r = root.selectedPort;
            if (!r || !root.validPid(r.pid))
                return;
            pid = r.pid;
            const g = root.ownGroupOfPid(pid);
            if (!g) {
                root.say("Not your process: it can't be ended from here");
                return;
            }
            if (root.ownHelper(g)) {
                root.say("This is the Task Manager's own helper: ending it would freeze this window");
                return;
            }
            name = g.name;
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
            const what = root.tab === "apps" ? root.selectedApp.title
                : root.tab === "ports" ? name + " (pid " + pid + ", port " + root.selectedPort.port + ")"
                : name + (g && g.count > 1 ? " (" + g.count + " processes)" : "");
            root.confirm = { text: (force ? "Kill " : "End ") + what + "?", verb: verb, signal: force ? "KILL" : "TERM", name: name, pid: pid };
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
            if (g && g.mine && !root.ownHelper(g))
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
        root.sendSignal(c.signal, pids);
    }

    // The one place a signal leaves: `kill -TERM|-KILL <pids>`; under QS_NO_APPLY (tests) it is only recorded
    function sendSignal(signal, pids) {
        if (!root.live)
            root.killLog = root.killLog.concat([{ signal: signal, pids: pids }]);
        else
            Quickshell.execDetached(["kill", "-" + signal].concat(pids.map(p => String(p))));
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
        if (key === "ports")
            root.refreshPorts();
        if (key === "processes")
            filter.focusInput();
        else
            keys.forceActiveFocus();
    }

    function cycleTab(d) {
        const tabs = root.tabList.map(t => t.key);
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
            root.netRaw = [];
            root.netRate = null;
            root.prevNet = null;
            root.ports = [];
            root.portsLoaded = false;
            root.portIndex = 0;
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
