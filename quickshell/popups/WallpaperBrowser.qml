import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

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

                // Menu bar: File / View open a dropdown with actions this window already has
                MenuStrip {
                    Layout.fillWidth: true
                    menus: [{ text: "File", build: root.fileModel }, { text: "View", build: root.viewModel }]
                    onClosed: searchInput.focusInput()
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
}
