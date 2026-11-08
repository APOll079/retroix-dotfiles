import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// Settings (Start > Settings, Super+Shift+comma, `qs ipc call settings toggle`, the launcher's Settings tab): a real window
// (an xdg toplevel Hyprland floats, centres and lets you move and resize, see windowrules.lua "settings-window"), one for the
// whole desktop. ToolWindows.qml owns it and opens / toggles / closes it. The content is SettingsView (the categories, the
// rows, the status line); this file only adds the window, the search box on top and the keys.
// Type to filter the settings; Down moves into the first control; Escape in a field reverts it, then returns to the search
// box, then clears it, then closes the window. The System tools rows call `runTool(id)` (ToolWindows.runTool).
FloatingWindow {
    id: root

    // Hyprland matches this title (windowrules.lua "settings-window")
    title: "Settings"
    implicitWidth: MenuStyle.windowWidth
    implicitHeight: MenuStyle.windowHeight
    minimumSize: Qt.size(MenuStyle.toolMinWidth, MenuStyle.toolMinHeight)
    visible: false
    color: Config.colors.base

    // ToolWindows.qml: opens a System tool by id
    property var runTool: function (id) {}

    readonly property Item searchItem: searchInput
    readonly property Item view: settingsView

    // Closed by Hyprland (Super+Q, the close dispatcher): reset like closeMenu()
    onClosed: root.visible = false

    Item {
        id: frame
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeMenu()

        PopupWindowFrame {
            windowTitle: "Settings"
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
                    placeholder: "Search settings"
                    onEscaped: root.closeMenu()
                    onKeyPressed: event => {
                        if (settingsView.handleKey(event))
                            event.accepted = true;
                    }
                }

                SettingsView {
                    id: settingsView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    query: searchInput.text.trim()
                    onFocusSearch: searchInput.focusInput()
                    onActionRequested: id => root.runTool(id)
                }
            }
        }
    }

    function openMenu() {
        searchInput.text = "";
        root.visible = true;
        searchInput.focusInput();
    }

    function closeMenu() {
        root.visible = false;
    }
}
