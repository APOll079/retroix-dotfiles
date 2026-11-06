import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own ContextMenu; ours is reached through Local
import "." as Local

// Wallpaper browser (Themes > Wallpapers...), centred, the launcher's size. The content is
// WallpaperView.qml. Type to filter; arrows move; Enter or double-click sets the wallpaper on the
// chosen monitor(s); Escape clears the search, then closes.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    // Overlay-layer panel like the Games menu, so it works over fullscreen windows too
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
        y: Math.round(root.screenHeight / 2 - height / 2)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupWindowFrame {
            windowTitle: "Wallpapers"
            windowTitleIcon: "\ue1bc"

            ColumnLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                // Menu bar: File / View open a dropdown (ContextMenu) with actions this window already has
                Row {
                    Layout.fillWidth: true
                    MenuTitle {
                        text: "File"
                        menu: fileMenu
                        build: root.fileModel
                    }
                    MenuTitle {
                        text: "View"
                        menu: viewMenu
                        build: root.viewModel
                    }
                }

                SearchBox {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholder: "Search wallpapers"
                    onEscaped: root.closeCallback()
                    onKeyPressed: event => {
                        const steps = { [Qt.Key_Left]: -1, [Qt.Key_Right]: 1, [Qt.Key_Up]: -MenuStyle.wallGridColumns, [Qt.Key_Down]: MenuStyle.wallGridColumns };
                        if (event.key in steps) {
                            view.move(steps[event.key]);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            view.activateKey(event);
                            event.accepted = true;
                        }
                    }
                }

                WallpaperView {
                    id: view
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    query: searchInput.text.trim()
                    onFocusSearch: searchInput.focusInput()
                }
            }
        }
    }

    // --- menu bar (only what the window already does: Set, Set + colours, Close, monitor and fit buttons) ---

    function fileModel() {
        return [
            { text: "Set", enabled: view.current !== "", action: () => view.apply(view.current, false) },
            { text: Config.settings.currentTheme === "wallpaper" ? "Set + theme" : "Set + colours", enabled: view.current !== "", action: () => view.apply(view.current, true) },
            { separator: true },
            { text: "Close", action: () => root.closeCallback() }
        ];
    }

    function viewModel() {
        const out = [];
        for (const m of ["all"].concat(view.screenNames))
            out.push({ text: m === "all" ? "All monitors" : m, checked: view.target === m, action: () => view.target = m });
        out.push({ separator: true });
        for (const f of view.fits)
            out.push({ text: f.charAt(0).toUpperCase() + f.slice(1), checked: view.fit === f, action: () => view.fit = f });
        return out;
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
            onClicked: {
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
