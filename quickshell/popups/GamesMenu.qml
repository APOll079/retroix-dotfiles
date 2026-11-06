import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own ContextMenu; ours is reached through Local
import "." as Local

// Games (Super+Shift+G, `qs ipc call games_<mon> toggle`), centred: a grid of cover
// art for every installed Steam game, Steam shortcut (non-Steam games added through Steam) and the
// user's own entries (Add game). The content is GamesView.qml, shared with the launcher's Games tab.
// Type to search; arrows move the cursor (Left/Right too, so the search box has no caret
// movement); Enter or double-click launches; a click (or Shift+Enter) shows the game's buttons;
// Escape steps back (buttons, filter), then clears the search, then closes.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

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

    // Click outside the frame closes
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.closeCallback()
    }

    Item {
        id: frame

        // Dropdowns of the menu bar (popup windows, closed until a title opens them)
        Local.ContextMenu {
            id: fileMenu
            onVisibleChanged: if (!visible) searchInput.focusInput()
        }
        Local.ContextMenu {
            id: viewMenu
            onVisibleChanged: if (!visible) searchInput.focusInput()
        }
        width: MenuStyle.windowWidth
        height: MenuStyle.windowHeight
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.screenHeight / 2 - height / 2) - MenuStyle.barHeight

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupWindowFrame {
            windowTitle: view.filter === "hidden" ? "Games - hidden" : "Games"
            windowTitleIcon: "\ue338"

            ColumnLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                // Menu bar: File / View open a dropdown (ContextMenu) with actions this window already has
                Row {
                    Layout.fillWidth: true
                    MenuTitle {
                        id: fileTitle
        text: "File"
                        menu: fileMenu
                        build: root.fileModel
                    }
                    MenuTitle {
                        id: viewTitle
        text: "View"
                        menu: viewMenu
                        build: root.viewModel
                    }
                }

                // Search
                SearchBox {
                    id: searchInput
                    Layout.fillWidth: true
                    visible: !view.addMode
                    placeholder: "Search games"
                    onEscaped: root.closeCallback()
                    // Arrows move through the cover grid (so no caret movement), Enter launches,
                    // Escape first steps back (the game's buttons, a filter), then clears, then closes
                    onKeyPressed: event => {
                        if (root.menuKey(event))
                            return;
                        const steps = { [Qt.Key_Left]: -1, [Qt.Key_Right]: 1, [Qt.Key_Up]: -MenuStyle.gamesGridColumns, [Qt.Key_Down]: MenuStyle.gamesGridColumns };
                        if (event.key in steps) {
                            view.move(steps[event.key]);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            view.activateKey(event);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape && view.goBack()) {
                            event.accepted = true;
                        }
                    }
                }

                GamesView {
                    id: view
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    query: searchInput.text.trim()
                    closeCallback: root.closeCallback
                    onFocusSearch: searchInput.focusInput()
                }
            }
        }
    }

    // --- menu bar (only what the window already does: Add game, Close, the filter chips) ---

    function fileModel() {
        return [
            { text: "Add game...", enabled: !view.addMode, action: () => view.openForm() },
            { separator: true },
            { text: "Close", action: () => root.closeCallback() }
        ];
    }

    function viewModel() {
        const out = [];
        for (const c of view.chips)
            out.push({ text: c.text, checked: view.filter === c.key, enabled: !view.addMode, action: () => view.setFilter(c.key) });
        if (view.hiddenCount > 0 || view.filter === "hidden")
            out.push({ text: "Hidden (" + view.hiddenCount + ")", checked: view.filter === "hidden", enabled: !view.addMode, action: () => view.setFilter("hidden") });
        return out;
    }

    // Alt+F / Alt+V open the File / View menu (the same toggle as clicking the title)
    function menuKey(event) {
        if (!(event.modifiers & Qt.AltModifier))
            return false;
        if (event.key === Qt.Key_F) {
            fileTitle.toggle();
            event.accepted = true;
            return true;
        }
        if (event.key === Qt.Key_V) {
            viewTitle.toggle();
            event.accepted = true;
            return true;
        }
        return false;
    }

    // --- open / close ---

    function openMenu() {
        searchInput.text = "";
        view.reset();
        root.visible = true;
        searchInput.focusInput();
    }

    function closeMenu() {
        root.visible = false;
    }

    // A menu title in the window's menu bar: flat until hovered or open, then the accent bar. Click opens
    // the dropdown under it, a second click closes it. `build` returns the ContextMenu model when it opens.
    component MenuTitle: Rectangle {
        id: mt
        property string text: ""
        property var menu: null
        property var build: null
        property real closedAt: 0
        readonly property bool lit: area.containsMouse || (mt.menu !== null && mt.menu.visible)
        implicitWidth: label.implicitWidth + 2 * MenuStyle.pad
        implicitHeight: MenuStyle.rowHeight
        color: mt.lit ? MenuStyle.selectBar : "transparent"
        RetroText {
            id: label
            anchors.centerIn: parent
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: mt.lit ? MenuStyle.selectText : Config.colors.text
            text: mt.text
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: mt.toggle()
        }
        function toggle() {
            if (mt.menu.visible) {
                mt.menu.close();
                return;
            }
            // the click that dismissed the menu (its grab) must not open it again
            if (Date.now() - mt.closedAt < 250)
                return;
            mt.menu.model = mt.build();
            mt.menu.openAt(mt, 0, mt.height);
        }
        Connections {
            target: mt.menu
            function onVisibleChanged() {
                if (!mt.menu.visible)
                    mt.closedAt = Date.now();
            }
        }
    }
}
