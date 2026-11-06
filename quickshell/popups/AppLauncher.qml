import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Effects
import Quickshell.Hyprland
import Quickshell.Io
import ".."
import "../utils" as Utils
// Qt.Controls ships an attached-only PopupMenu that would shadow ours, so ours is reached as Popups.PopupMenu
import "." as Popups

// Launcher (Super+D). One result list fed by providers:
// - apps: fuzzy search, usage-ranked, pinned first when empty, category filter row
// - calculator: "2+2*3", "10 km to mi" -> top row, Enter copies the result
// - session: type lock / logout / reboot / suspend / shutdown (or a custom action's name)
// - windows: start with "," to search open windows
// - clipboard: Super+V opens the cliphist history; Enter copies the entry back
// Tabs along the top switch between Apps, Games (cover grid, GamesView.qml, shared with the
// standalone Games menu) and Clipboard; Ctrl+Tab cycles them.
// Right-click an app (or Shift+Enter) for its options in the shared PopupMenu: launch, pin/unpin, move pinned up/down, hide
// (the "Hidden (n)" chip lists hidden apps) and uninstall (owner found by scripts/app-owner.sh, then
// `yay -Rns` / `flatpak uninstall` in a terminal after a confirm).
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    property string mode: "apps"          // apps | windows | games | clipboard
    property string category: "all"
    property var results: []
    property var optionsFor: null         // DesktopEntry whose options menu is open
    property string confirmKey: ""        // session action / "Clear all" waiting for a second Enter
    property bool keepArm: false          // true while the list is rebuilt around an armed row
    property var uninstallFor: null       // { name, kind, pkg }: uninstall waiting for its confirm
    readonly property int hiddenCount: Array.from(Utils.AppSearch.list).filter(e => LauncherState.isHidden(e.id)).length

    property var clipLines: []

    // Category filter: glyph + freedesktop categories it matches
    readonly property var categories: [
        { key: "all", glyph: "\ue5c3", cats: [] },
        { key: "web", glyph: "\ue894", cats: ["Network", "WebBrowser", "Email", "Chat"] },
        { key: "media", glyph: "\ue405", cats: ["AudioVideo", "Audio", "Video", "Music", "Player"] },
        { key: "dev", glyph: "\ue86f", cats: ["Development", "IDE"] },
        { key: "graphics", glyph: "\ue40a", cats: ["Graphics", "Photography"] },
        { key: "office", glyph: "\ue873", cats: ["Office", "TextEditor"] },
        { key: "system", glyph: "\ue8b8", cats: ["System", "Settings", "Monitor"] },
        { key: "utility", glyph: "\ue869", cats: ["Utility", "Accessories"] }
    ]

    // An Overlay-layer panel, not a popup of the bar: the bar sits below fullscreen windows, so a
    // popup over a fullscreen video showed but its clicks went to the video
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins.top: MenuStyle.barHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: false
    color: "transparent"

    // Clicks outside the frame close the launcher (behind the frame, so it never eats its clicks)
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.closeCallback()
    }

    // The frame sits in the middle of the screen. The popup itself starts under the bar and is
    // as wide as the screen, so y subtracts the bar. Every tab has the same size.
    Item {
        id: frame
        width: MenuStyle.launcherWidth
        height: MenuStyle.launcherHeight
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.screenHeight / 2 - height / 2) - MenuStyle.barHeight

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupWindowFrame {
            windowTitle: root.mode === "windows" ? "Windows" : root.mode === "clipboard" ? "Clipboard" : root.mode === "games" ? "Games" : "Search"
            windowTitleIcon: root.mode === "windows" ? "\ue8f9" : root.mode === "clipboard" ? "\ue14f" : "\ue8b6"

            RowLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                StartBanner {}

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: MenuStyle.pad

                    // Tabs joined to a raised page; the search box, filters and list live inside the page
                    TabPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        tabs: root.tabs
                        current: root.tabOf(root.mode)
                        onTabClicked: key => {
                            if (root.tabOf(root.mode) !== key)
                                root.open(key);
                            searchInput.focusInput();
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: MenuStyle.pad

                            SearchBox {
                                id: searchInput
                                Layout.fillWidth: true
                                visible: !(root.mode === "games" && gamesView.addMode)
                                fontSize: MenuStyle.searchFontSize
                                onTextChanged: {
                                    root.confirmKey = "";
                                    root.rebuild();
                                }
                                Component.onCompleted: searchInput.focusInput()
                                onKeyPressed: event => root.handleKey(event)
                            }

                            // Category filter (apps only)
                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.mode === "apps" && !searchInput.text.startsWith(",")
                                spacing: MenuStyle.gap
                                Repeater {
                                    model: root.categories
                                    BevelButton {
                                        Layout.fillWidth: true
                                        glyph: modelData.glyph
                                        checked: root.category === modelData.key
                                        focusPolicy: Qt.NoFocus
                                        onClicked: {
                                            root.category = modelData.key;
                                            root.rebuild();
                                            searchInput.focusInput();
                                        }
                                    }
                                }
                                BevelButton {
                                    visible: root.hiddenCount > 0
                                    text: "Hidden (" + root.hiddenCount + ")"
                                    checked: root.category === "hidden"
                                    focusPolicy: Qt.NoFocus
                                    onClicked: {
                                        root.category = root.category === "hidden" ? "all" : "hidden";
                                        root.rebuild();
                                        searchInput.focusInput();
                                    }
                                }
                            }

                            // Games tab: the cover grid
                            GamesView {
                                id: gamesView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: root.mode === "games"
                                query: root.mode === "games" ? searchInput.text.trim() : ""
                                closeCallback: root.closeCallback
                                onFocusSearch: searchInput.focusInput()
                            }

                            // Results; in clipboard mode a preview pane sits on the left of the list
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: root.mode !== "games"
                                spacing: MenuStyle.pad

                                SunkenField {
                                    id: preview
                                    visible: root.mode === "clipboard"
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: parent.width * MenuStyle.clipPreviewFraction
                                    padding: MenuStyle.pad
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        visible: root.previewImage !== ""
                                        source: root.previewImage === "" ? "" : "file://" + root.previewImage
                                        sourceSize.width: preview.width * 2
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: false
                                    }

                                    Flickable {
                                        id: previewFlick
                                        anchors.fill: parent
                                        visible: root.previewImage === "" && root.previewText !== ""
                                        contentHeight: previewLabel.implicitHeight
                                        boundsBehavior: Flickable.StopAtBounds
                                        clip: true
                                        ScrollBar.vertical: RetroScrollBar {}
                                        Text {
                                            id: previewLabel
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            width: parent.width - (previewFlick.ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0)
                                            wrapMode: Text.WrapAnywhere
                                            font.family: MenuStyle.bodyFont
                                            font.pixelSize: MenuStyle.fontSize
                                            color: Config.colors.text
                                            textFormat: Text.PlainText
                                            text: root.previewText
                                        }
                                    }

                                    EmptyState {
                                        anchors.fill: parent
                                        visible: root.previewImage === "" && root.previewText === ""
                                        glyph: "\ue8f4"
                                        text: "Nothing selected"
                                    }
                                }

                                SunkenField {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    padding: 2
                                    clip: true

                                    EmptyState {
                                        anchors.fill: parent
                                        visible: root.results.length === 0
                                        glyph: root.mode === "clipboard" ? (root.clipMissing ? "\ue002" : "\ue14f") : "\ue8b6"
                                        text: root.mode === "clipboard" ? (root.clipMissing ? "cliphist not installed" : "Clipboard history is empty") : "No matches"
                                    }

                                    ListView {
                                        id: appsView
                                        anchors.fill: parent
                                        model: root.results
                                        currentIndex: 0
                                        onCurrentIndexChanged: {
                                            positionViewAtIndex(currentIndex, ListView.Contain);
                                            // Moving the cursor off an armed row disarms it
                                            const r = root.results[currentIndex];
                                            if (root.confirmKey !== "" && !root.keepArm && (!r || r.key !== root.confirmKey))
                                                root.disarm();
                                        }
                                        flickableDirection: Flickable.VerticalFlick
                                        boundsBehavior: Flickable.DragOverBounds
                                        maximumFlickVelocity: 3500
                                        clip: true

                                        delegate: MenuRow {
                                            width: appsView.width - (appsView.ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0)
                                            selected: index === appsView.currentIndex
                                            text: modelData.title
                                            subtext: modelData.sub || ""
                                            trailing: modelData.trailing || ""
                                            glyph: modelData.glyph || ""
                                            reserveIcon: true      // the list has icons: labels line up on rows without one
                                            iconSource: modelData.icon || ""
                                            marked: !!modelData.pinned
                                            onClicked: root.activate(index)
                                            // Clipboard: the preview follows the pointer too
                                            onHoveredChanged: {
                                                if (hovered && root.mode === "clipboard")
                                                    appsView.currentIndex = index;
                                                // The pointer leaving an armed row disarms it
                                                else if (!hovered && modelData.key && modelData.key === root.confirmKey)
                                                    root.disarm();
                                            }

                                            // Right-click: the app's options
                                            TapHandler {
                                                acceptedButtons: Qt.RightButton
                                                onTapped: (point) => {
                                                    appsView.currentIndex = index;
                                                    root.openOptionsAt(index, parent, point.position.x, point.position.y);
                                                }
                                            }
                                        }

                                        ScrollBar.vertical: RetroScrollBar {}
                                    }
                                }
                            }

                            // Clipboard keys, one dim line like the Games bottom row
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                Layout.fillWidth: true
                                visible: root.mode === "clipboard"
                                elide: Text.ElideRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: MenuStyle.bevelDark
                                text: root.clipLines.length + (root.clipLines.length === 1 ? " entry" : " entries") + " · Enter copies · Del removes (Shift+Del while typing) · Down to the end for Clear all"
                            }
                        }
                    }
                }
            }
        }
    }

    // Keys from the search box. Escape: games step back / clear / close; else close (the options menu takes its own Escape).
    // Escape in the other tabs clears the search text first, then closes. In Clipboard, Delete (empty
    // search) or Shift+Delete removes the highlighted entry.
    // Up / Down (and Left / Right in the games grid) move, Ctrl+Tab cycles the tabs, plain Tab
    // steps, Enter activates (Shift+Enter: the app's options). Everything else types.
    function handleKey(event) {
        const games = root.mode === "games";
        const ctrl = event.modifiers & Qt.ControlModifier;
        let handled = true;
        switch (event.key) {
        case Qt.Key_Escape:
            if (root.confirmKey !== "") {
                root.disarm();
            } else if (games) {
                if (gamesView.goBack())
                    break;
                if (searchInput.text !== "")
                    searchInput.text = "";
                else
                    root.closeCallback();
            } else if (searchInput.text !== "") {
                searchInput.text = "";
            } else {
                root.closeCallback();
            }
            break;
        case Qt.Key_Delete:
            // Clipboard: Delete (with an empty search box) or Shift+Delete removes the highlighted entry
            if (root.mode === "clipboard" && (searchInput.text === "" || (event.modifiers & Qt.ShiftModifier)) && root.results[appsView.currentIndex] && root.results[appsView.currentIndex].clip)
                root.deleteClip(root.results[appsView.currentIndex].clip);
            else
                handled = false;
            break;
        case Qt.Key_Down:
            games ? gamesView.move(MenuStyle.gamesGridColumns) : root.step(1);
            break;
        case Qt.Key_Up:
            games ? gamesView.move(-MenuStyle.gamesGridColumns) : root.step(-1);
            break;
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (games)
                gamesView.move(event.key === Qt.Key_Left ? -1 : 1);
            else
                handled = false;        // caret movement in the search text
            break;
        case Qt.Key_Tab:
            ctrl ? root.cycleTab(1) : (games ? gamesView.move(1) : root.step(1));
            break;
        case Qt.Key_Backtab:
            ctrl ? root.cycleTab(-1) : (games ? gamesView.move(-1) : root.step(-1));
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (games)
                gamesView.activateKey(event);
            else if (event.key === Qt.Key_Return && (event.modifiers & Qt.ShiftModifier))
                root.openOptionsAt(appsView.currentIndex);
            else
                root.activate(appsView.currentIndex);
            break;
        default:
            handled = false;
        }
        event.accepted = handled;
    }

    // --- results ---

    function step(d) {
        if (root.results.length === 0)
            return;
        appsView.currentIndex = (appsView.currentIndex + d + root.results.length) % root.results.length;
    }

    readonly property var tabs: [
        { key: "apps", text: "Apps" },
        { key: "games", text: "Games" },
        { key: "clipboard", text: "Clipboard" }
    ]

    // "windows" (the "," search) lives on the Apps tab
    function tabOf(m) {
        return m === "windows" ? "apps" : m;
    }

    function cycleTab(d) {
        const i = root.tabs.findIndex(t => t.key === root.tabOf(root.mode));
        root.open(root.tabs[(i + d + root.tabs.length) % root.tabs.length].key);
    }

    function setResults(list, index) {
        root.results = list;
        appsView.currentIndex = Math.max(0, Math.min(index || 0, list.length - 1));
    }

    // Arm / disarm a row that needs a second Enter; the list is rebuilt around the cursor
    function arm(key) {
        root.confirmKey = key;
        root.keepArm = true;
        const i = appsView.currentIndex;
        root.rebuild();
        appsView.currentIndex = i;
        root.keepArm = false;
    }

    function disarm() {
        if (root.confirmKey === "")
            return;
        root.confirmKey = "";
        root.keepArm = true;
        const i = appsView.currentIndex;
        root.rebuild();
        appsView.currentIndex = i;
        root.keepArm = false;
    }

    // keep: stay on the current row (clamped) instead of jumping back to the first
    function rebuild(keep) {
        if (root.mode === "games")
            return;
        const q = searchInput.text.trim();
        if (root.mode === "windows" || q.startsWith(","))
            return root.setResults(root.windowItems(root.mode === "windows" ? q : q.slice(1).trim()), root.mode === "windows" && q === "" ? 1 : 0);
        if (root.mode === "clipboard")
            return root.setResults(root.clipItems(q), keep ? appsView.currentIndex : 0);

        const items = [];
        const calc = Utils.Calc.evaluate(q);
        if (calc !== "")
            items.push({ title: "= " + calc, sub: "Enter copies the result", glyph: "\uea5f", run: () => root.copy(calc.replace(/ [a-z/]+$/, "")) });
        for (const s of root.sessionItems(q))
            items.push(s);
        root.setResults(items.concat(root.appItems(q)), 0);
    }

    function inCategory(entry) {
        const hidden = LauncherState.isHidden(entry.id);
        if (root.category === "hidden")
            return hidden;
        if (hidden)
            return false;
        const c = root.categories.find(x => x.key === root.category);
        if (!c || c.cats.length === 0)
            return true;
        const ec = entry.categories || [];
        return c.cats.some(x => ec.indexOf(x) !== -1);
    }

    function appItem(entry) {
        return {
            title: entry.name,
            glyph: "\ue5c3",
            icon: Utils.AppSearch.getIcon(entry.icon),
            pinned: LauncherState.isPinned(entry.id),
            entry: entry,
            run: () => {
                LauncherState.bump(entry.id);
                entry.execute();
                root.closeCallback();
            }
        };
    }

    // Usage nudges the order a little (up to +0.1 on fuzzysort's 0..1 score)
    function usageBonus(entry) {
        const n = LauncherState.counts[entry.id] || 0;
        return Math.min(0.1, Math.log(1 + n) / Math.log(10) * 0.05);
    }

    function appItems(q) {
        if (q === "") {
            const all = Array.from(Utils.AppSearch.list).filter(e => root.inCategory(e));
            const pinned = LauncherState.pinned.map(id => all.find(e => e.id === id)).filter(e => e);
            const rest = all.filter(e => !LauncherState.isPinned(e.id))
                .sort((a, b) => (LauncherState.counts[b.id] || 0) - (LauncherState.counts[a.id] || 0) || a.name.localeCompare(b.name));
            return pinned.concat(rest).map(e => root.appItem(e));
        }
        return Utils.AppSearch.scoredQuery(q)
            .filter(r => root.inCategory(r.entry))
            .map(r => ({ entry: r.entry, rank: r.score + root.usageBonus(r.entry) }))
            .sort((a, b) => b.rank - a.rank)
            .map(r => root.appItem(r.entry));
    }

    // Session actions by name or a whole synonym. A row shows only when the typed text IS the name
    // (or a synonym), never a prefix: "res" (GNOME Resources) used to put Reboot on top and
    // res + Enter + Enter rebooted. Lock runs on one Enter; the others ask for a second Enter.
    readonly property var sessionWords: ({ sleep: "Suspend", restart: "Reboot", poweroff: "Shutdown", "power off": "Shutdown", logout: "Log out", quit: "Log out" })
    function sessionItems(q) {
        const l = q.toLowerCase();
        if (l === "")
            return [];
        return Session.all.filter(a => a.name.toLowerCase() === l || root.sessionWords[l] === a.name)
            .map(a => ({
                title: root.confirmKey === a.name ? a.name + " now? Enter again · Esc cancels" : a.name,
                sub: a.confirm ? "Session" : "Custom action",
                glyph: a.icon,
                key: a.name,
                run: () => {
                    // A custom action with confirm: false runs on one Enter only when its full name was typed
                    if ((a.confirm || l !== a.name.toLowerCase()) && root.confirmKey !== a.name) {
                        root.arm(a.name);
                        return;
                    }
                    root.confirmKey = "";
                    Session.run(a);
                    root.closeCallback();
                }
            }));
    }

    function windowItems(q) {
        Hyprland.refreshToplevels();
        const l = q.toLowerCase();
        const focusOrder = t => t.lastIpcObject && t.lastIpcObject.focusHistoryID !== undefined ? t.lastIpcObject.focusHistoryID : 999;
        return Hyprland.toplevels.values
            .filter(t => t.title !== "" && (l === "" || t.title.toLowerCase().includes(l)
                || (t.lastIpcObject && String(t.lastIpcObject.class).toLowerCase().includes(l))))
            .sort((a, b) => focusOrder(a) - focusOrder(b))
            .map(t => ({
                title: t.title,
                trailing: t.workspace ? t.workspace.name.replace("special:", "*") : "",
                glyph: "\ue8f9",
                icon: t.wayland ? Utils.AppSearch.getIcon(t.wayland.appId) : "",
                run: () => {
                    Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + t.address + "\" })");
                    root.closeCallback();
                }
            }));
    }

    function clipItems(q) {
        const l = q.toLowerCase();
        const items = root.clipLines
            .filter(c => l === "" || c.text.toLowerCase().includes(l))
            .map(c => ({
                // Images list as "png 1920x1141  3 MiB"; the picture shows in the preview pane
                title: c.ext ? c.info : c.text,
                glyph: c.ext ? "\ue3f4" : "\ue14f",
                clip: c,
                run: () => {
                    Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", c.id]);
                    root.closeCallback();
                }
            }));
        // Clear all: last row, a second Enter (or click) confirms
        if (l === "" && root.clipLines.length > 0)
            items.push({
                title: root.confirmKey === "clip-wipe" ? "Clear all now? Enter again · Esc cancels" : "Clear all",
                glyph: "\ue872",
                key: "clip-wipe",
                run: () => {
                    if (root.confirmKey !== "clip-wipe") {
                        root.arm("clip-wipe");
                        return;
                    }
                    root.confirmKey = "";
                    root.clipLines = [];
                    root.rebuild();
                    clipEdit.command = ["sh", "-c", "cliphist wipe; cd \"$1\" 2>/dev/null && rm -f -- *", "sh", root.clipCacheDir];
                    clipEdit.running = true;
                }
            });
        return items;
    }

    // One entry out of the history (cliphist delete takes the list line on stdin), its cached preview too
    function deleteClip(c) {
        if (clipEdit.running)
            return;
        // Drop it from the list at once and stay on the same row; the real list is re-read quietly after
        root.clipLines = root.clipLines.filter(x => x.id !== c.id);
        root.rebuild(true);
        clipEdit.command = ["sh", "-c", "printf '%s\\t%s\\n' \"$1\" \"$2\" | cliphist delete; cd \"$3\" 2>/dev/null && rm -f -- \"$1\".*", "sh", c.id, c.text, root.clipCacheDir];
        clipEdit.running = true;
    }

    // The options menu (shared PopupMenu): entries for the app whose row was right-clicked / Shift+Entered
    function optionsModel(entry) {
        const pinned = LauncherState.isPinned(entry.id);
        const hidden = LauncherState.isHidden(entry.id);
        const m = [
            { text: "Launch " + entry.name, glyph: "\ue89e", action: () => root.appItem(entry).run() },
            { text: pinned ? "Unpin" : "Pin to the top", glyph: "\uf10d", action: () => LauncherState.togglePin(entry.id) }
        ];
        if (pinned) {
            m.push({ text: "Move up", glyph: "\ue5d8", action: () => root.movePinned(entry, -1) });
            m.push({ text: "Move down", glyph: "\ue5db", action: () => root.movePinned(entry, 1) });
        }
        m.push({ separator: true });
        m.push({ text: hidden ? "Unhide" : "Hide from the launcher", glyph: hidden ? "\ue8f4" : "\ue8f5", action: () => {
            LauncherState.toggleHidden(entry.id);
            if (root.hiddenCount === 0)
                root.category = "all";
        } });
        m.push({ text: "Uninstall...", glyph: "\ue872", action: () => {
            ownerProc.entryName = entry.name;
            ownerProc.command = ["sh", Quickshell.shellDir + "/scripts/app-owner.sh", entry.id];
            ownerProc.running = true;
        } });
        return m;
    }

    // Move up / down keeps the menu (re-opened where it was) and the cursor on the moved app
    function movePinned(entry, d) {
        LauncherState.move(entry.id, d);
        root.rebuild();
        const i = root.results.findIndex(r => r.entry && r.entry.id === entry.id);
        if (i >= 0)
            appsView.currentIndex = i;
        Qt.callLater(() => root.showOptions(entry));
    }

    // Confirm step: names the package, then runs the removal in a terminal so you see the prompts
    function uninstallModel() {
        const u = root.uninstallFor;
        if (u.kind === "none")
            return [
                { text: "No package owns " + u.name, glyph: "\ue002", enabled: false },
                { text: "Only Hide is possible", enabled: false },
                { separator: true },
                { text: "Cancel" }
            ];
        return [
            { text: "Remove " + u.pkg + "?", glyph: "\ue872", trailing: u.kind === "flatpak" ? "flatpak uninstall" : "yay -Rns", action: () => {
                const cmd = u.kind === "flatpak" ? "flatpak uninstall " + u.pkg : "yay -Rns " + u.pkg;
                Quickshell.execDetached([Config.settings.execCommands.terminal, "fish", "-c", cmd + "; echo; read -P 'Press Enter to close'"]);
                root.closeCallback();
            } },
            { text: "Cancel" }
        ];
    }

    Process {
        id: ownerProc
        property string entryName: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^(pacman|flatpak):([A-Za-z0-9@._+-]+)$/);
                root.uninstallFor = { name: ownerProc.entryName, kind: m ? m[1] : "none", pkg: m ? m[2] : "" };
                root.showOptions(root.optionsFor);
            }
        }
    }

    // Where the menu opens (in the list's coordinates): the pointer for a right-click, under the cursor row for Shift+Enter
    property Item optionsAnchor: null
    property point optionsPoint: Qt.point(0, 0)

    Popups.PopupMenu {
        id: optionsMenu
        // KEYBOARD: when the menu goes away the search box takes the keys back (needs a live test)
        onVisibleChanged: {
            if (!visible && root.visible)
                searchInput.focusInput();
        }
    }

    // Open (or re-open, for the uninstall confirm and Move up / down) the menu for one app
    function showOptions(entry) {
        if (!entry || !root.optionsAnchor)
            return;
        root.optionsFor = entry;
        optionsMenu.model = root.uninstallFor ? root.uninstallModel() : root.optionsModel(entry);
        optionsMenu.openAt(root.optionsAnchor, root.optionsPoint.x, root.optionsPoint.y);
    }

    // item / x / y: the point the menu opens at; without them it opens under the cursor row
    function openOptionsAt(i, item, x, y) {
        const r = root.results[i];
        if (!r || !r.entry)
            return;
        root.uninstallFor = null;
        // Anchored to the list itself (its rows are rebuilt when the list changes), at a point inside it
        const row = item || appsView.itemAtIndex(i);
        root.optionsAnchor = appsView;
        root.optionsPoint = row ? appsView.mapFromItem(row, item ? x : MenuStyle.pad * 4, item ? y : MenuStyle.rowHeight) : Qt.point(MenuStyle.pad * 4, MenuStyle.rowHeight);
        root.showOptions(r.entry);
    }

    function closeOptions() {
        optionsMenu.close();
        root.optionsFor = null;
        root.uninstallFor = null;
    }

    function activate(i) {
        const r = root.results[i];
        if (r && r.run)
            r.run();
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", "--", text]);
        root.closeCallback();
    }

    // Desktop entries load asynchronously: refresh the list when they arrive
    Connections {
        target: Utils.AppSearch
        function onListChanged() {
            if (root.visible)
                root.rebuild();
        }
    }

    // cliphist list: "<id>\t<preview>" per line, newest first
    property bool clipMissing: false
    Process {
        id: clipProc
        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 127; cliphist list"]
        onExited: code => {
            root.clipMissing = code === 127;
            if (root.clipMissing)
                root.rebuild();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipLines = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const tab = l.indexOf("\t");
                    const t = l.slice(tab + 1);
                    // "[[ binary data 3 MiB png 1920x1141 ]]"
                    const m = t.match(/^\[\[ binary data (\S+ \S+) (png|jpe?g|gif|webp|bmp) (\d+x\d+) \]\]$/i);
                    return { id: l.slice(0, tab), text: t, ext: m ? m[2].toLowerCase() : "", info: m ? m[2].toLowerCase() + " " + m[3] + "  " + m[1] : "" };
                });
                root.rebuild(true);
            }
        }
    }

    // Delete / wipe, then list again (without emptying the list meanwhile)
    Process {
        id: clipEdit
        onExited: clipProc.running = true
    }

    // --- clipboard preview ---
    // The highlighted entry, decoded on demand: images into Quickshell's cache dir (kept for
    // next time, newest clipCacheMax files only), text straight from `cliphist decode` (first 4000 bytes).
    readonly property string clipCacheDir: Quickshell.cachePath("clipboard")
    readonly property int clipCacheMax: 50
    readonly property int clipCacheMaxKb: 102400     // and at most 100 MB in total
    readonly property var previewClip: root.mode === "clipboard" && root.results[appsView.currentIndex] ? (root.results[appsView.currentIndex].clip || null) : null
    property string previewImage: ""
    property string previewText: ""
    onPreviewClipChanged: root.loadPreview()

    function loadPreview() {
        const c = root.previewClip;
        root.previewImage = "";
        root.previewText = c && !c.ext ? c.text : "";
        if (!c || previewProc.running)
            return;
        previewProc.clipId = c.id;
        if (c.ext) {
            previewProc.path = root.clipCacheDir + "/" + c.id + "." + c.ext;
            // decode to .tmp, then mv: a cut-short decode never leaves a truncated cache entry. Then prune by count, then by size
            // (oldest first, never the last file); cd first so the removals can only touch the cache dir
            previewProc.command = ["sh", "-c", "d=$(dirname \"$2\"); mkdir -p \"$d\"; [ -s \"$2\" ] || { cliphist decode \"$1\" > \"$2.tmp\" && mv -f \"$2.tmp\" \"$2\" || rm -f \"$2.tmp\"; }; [ -e \"$2\" ] && touch \"$2\"; cd \"$d\" 2>/dev/null || exit 0; ls -1t | tail -n +$(($3 + 1)) | xargs -r rm -f --; while [ \"$(du -sk . | cut -f1)\" -gt \"$4\" ] && [ \"$(ls -1 | wc -l)\" -gt 1 ]; do ls -1t | tail -n 1 | xargs -r rm -f --; done", "sh", c.id, previewProc.path, String(root.clipCacheMax), String(root.clipCacheMaxKb)];
        } else {
            previewProc.path = "";
            previewProc.command = ["sh", "-c", "cliphist decode \"$1\" | head -c 4000", "sh", c.id];
        }
        previewProc.running = true;
    }

    Process {
        id: previewProc
        property string clipId: ""
        property string path: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (previewProc.path === "" && root.previewClip && root.previewClip.id === previewProc.clipId)
                    root.previewText = text;
            }
        }
        onExited: {
            if (root.previewClip && root.previewClip.id === previewProc.clipId) {
                if (previewProc.path !== "")
                    root.previewImage = previewProc.path;
            } else {
                // The highlight moved while this ran: load the current one
                Qt.callLater(root.loadPreview);
            }
        }
    }

    // --- open / close ---

    function openMenu() { openAppLauncher() }

    function openAppLauncher() {
        root.open("apps");
    }

    function open(mode) {
        root.mode = mode;
        root.category = "all";
        root.closeOptions();
        root.confirmKey = "";
        root.visible = true;
        searchInput.text = "";
        if (mode === "clipboard") {
            root.clipLines = [];
            clipProc.running = true;
        }
        if (mode === "games")
            gamesView.reset();
        root.rebuild();
        searchInput.focusInput();
    }

    function closeMenu() {
        root.visible = false;
    }
}
