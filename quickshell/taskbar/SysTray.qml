import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Services.SystemTray
import QtQuick.Effects
import "../popups" as Popups

import ".."

// The tray half of the bar's well: tray icons as flat BarButtons, an etched separator, then bell +
// weather + clock. Bar.qml puts it inside the BarWell. The right-click menu is the shared PopupMenu
// built from the item's QsMenuOpener entries (menuModel); a menu with submenus falls back to Qt's native
// QsMenuAnchor for that item, since PopupMenu has no submenus.
Row {
    id: sysTrayRow
    spacing: MenuStyle.gap
    property bool clockToggled: false
    signal clockClicked(var item)

    // QsMenuOpener entries -> PopupMenu model: [{ text, enabled, checked, separator, action }].
    // Entry icons are dropped (PopupMenu has a glyph column, not image icons). Leading, trailing and
    // doubled separators are removed.
    function menuModel(entries) {
        const out = [];
        // forEach, not for-of: each entry needs its own closure for its action
        entries.forEach(function(e) {
            if (e.isSeparator) {
                if (out.length > 0 && !out[out.length - 1].separator)
                    out.push({ separator: true });
                return;
            }
            out.push({
                text: e.text,
                enabled: e.enabled,
                checked: e.buttonType > 0 && e.checkState === Qt.Checked,
                action: function() { e.triggered(); }
            });
        });
        while (out.length > 0 && out[out.length - 1].separator)
            out.pop();
        return out;
    }
    // True when any entry opens a submenu
    function hasSubmenu(entries) {
        return entries.some(e => e.hasChildren);
    }

    Repeater {
        id: sysTray
        model: SystemTray.items

        BarButton {
            id: trayItem
            property SystemTrayItem item: modelData
            flat: true
            iconFontValue: ""
            toggledIconFontValue: ""
            minWidth: Config.settings.bar.trayIconSize + MenuStyle.space2
            isToggled: ctx.visible || nativeMenu.visible

            function openMenu() {
                if (!item.hasMenu)
                    return;
                const entries = opener.children ? opener.children.values : [];
                const model = sysTrayRow.menuModel(entries);
                if (model.length === 0 || sysTrayRow.hasSubmenu(entries)) {
                    nativeMenu.open();
                    return;
                }
                ctx.model = model;
                const p = trayItem.mapToItem(taskbar.contentItem, 0, 0);
                ctx.openAt(taskbar.contentItem, p.x, taskbar.height);
            }

            onClicked: {
                if (item.onlyMenu && item.hasMenu)
                    openMenu();
                else
                    item.activate();
            }
            onRightClicked: openMenu()

            QsMenuOpener {
                id: opener
                menu: trayItem.item.menu
            }
            Popups.PopupMenu {
                id: ctx
            }
            // Fallback for menus with submenus. Anchored directly under its own icon, in
            // taskbar-window coordinates.
            QsMenuAnchor {
                id: nativeMenu

                menu: trayItem.item.menu
                anchor.window: taskbar

                anchor.rect.x: trayItem.mapToItem(null, 0, 0).x
                anchor.rect.y: taskbar.height

                anchor.rect.width: trayItem.width
                anchor.rect.height: trayItem.height
                anchor.edges: Edges.Bottom
            }

            // Middle click (BarButton itself handles left and right)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                onClicked: trayItem.item.secondaryActivate()
            }

            IconImage {
                id: trayIcon
                source: trayItem.item.icon
                anchors.centerIn: parent
                width: Config.settings.bar.trayIconSize
                height: Config.settings.bar.trayIconSize
                visible: false
            }
            Loader {
                anchors.fill: trayIcon
                sourceComponent: MultiEffect {
                    source: trayIcon
                    saturation: Config.settings.bar.monochromeTrayIcons ? -1.0 : 0
                    contrast: Config.settings.bar.monochromeTrayIcons ? 0.7 : 0.0
                    opacity: 1
                    blurEnabled: false
                }
            }

            // Tooltip after a short hover (not while the right-click menu is open)
            Timer {
                id: tipTimer
                interval: 500
                running: trayItem.hovered && !ctx.visible && !nativeMenu.visible
                onTriggered: tip.shown = true
            }
            PopupWindow {
                id: tip
                property bool shown: false
                property string title: trayItem.item.tooltipTitle !== "" ? trayItem.item.tooltipTitle : trayItem.item.title
                property string description: trayItem.item.tooltipDescription
                visible: shown && trayItem.hovered && !ctx.visible && !nativeMenu.visible && (title !== "" || description !== "")
                onVisibleChanged: if (!visible) shown = false
                anchor.window: taskbar
                anchor.rect.x: Math.max(4, Math.min(Math.round(trayItem.mapToItem(null, 0, 0).x + trayItem.width / 2 - width / 2), taskbar.width - width - 4))
                anchor.rect.y: taskbar.height
                implicitWidth: tipColumn.implicitWidth + 2 * MenuStyle.pad
                implicitHeight: tipColumn.implicitHeight + 2 * MenuStyle.gap + 2
                color: "transparent"
                Rectangle {
                    anchors.fill: parent
                    color: Config.colors.base
                    border.width: 1
                    border.color: Config.colors.outline
                    Column {
                        id: tipColumn
                        anchors.centerIn: parent
                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            font.bold: true
                            color: Config.colors.text
                            textFormat: Text.PlainText
                            text: tip.title
                            visible: text !== ""
                        }
                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            textFormat: Text.PlainText
                            text: tip.description
                            visible: text !== ""
                        }
                    }
                }
            }
        }
    }

    // Between the tray icons and the clock, only when there are tray icons
    Popups.MenuSeparator {
        vertical: true
        visible: sysTray.count > 0
    }

    ClockWidget {
        id: clockWidget
        isToggled: sysTrayRow.clockToggled
        onClicked: sysTrayRow.clockClicked(clockWidget)
    }
}
