import Quickshell
import QtQuick
import QtQuick.Layouts

import ".."

PopupWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int menuWidth: 0
    property var closeCallback: function () {}
    property var openPowerMenuCallback: function () {}
    property var openKeysCallback: function () {}
    property var openSettingsCallback: function () {}
    property var openUpdatesCallback: function () {}
    // settings.ui.cascadingStart (off by default): a Programs button opens the cascading Programs menu (PopupCascade.qml)
    readonly property bool cascading: Config.settings.ui.cascadingStart === true
    anchor.window: root.bar
    anchor.rect.x: menuWidth
    anchor.rect.y: MenuStyle.barHeight
    implicitWidth: MenuStyle.widthLarge
    implicitHeight: MenuStyle.chromeHeight + row.implicitHeight
    color: "transparent"

    PopupWindowFrame {
        windowTitle: "Your Computer"
        windowTitleIcon: "\ue30c"

        RowLayout {
            id: row
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: MenuStyle.pad

            ColumnLayout {
                id: column
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: MenuStyle.pad

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.pad

                    SunkenField {
                        Layout.preferredWidth: MenuStyle.avatarSize
                        Layout.preferredHeight: MenuStyle.avatarSize
                        padding: 2
                        Image {
                            anchors.fill: parent
                            asynchronous: true
                            // settings.json may use ~ (QML doesn't expand it)
                            source: {
                                const p = Config.settings.systemProfileImageSource || "";
                                return p.startsWith("~/") ? Quickshell.env("HOME") + p.slice(1) : p;
                            }
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                        }
                    }

                    SunkenField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: MenuStyle.avatarSize
                        padding: MenuStyle.pad

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            Repeater {
                                model: [
                                    { icon: "\ue161", value: Config.settings.systemDetails.osName },
                                    { icon: "\ue394", value: Config.settings.systemDetails.osVersion },
                                    { icon: "\uf7a3", value: Config.settings.systemDetails.ram },
                                    { icon: "\ue322", value: Config.settings.systemDetails.cpu },
                                    { icon: "\ue2ac", value: Config.settings.systemDetails.gpu }
                                ]
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: MenuStyle.pad
                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        font.family: MenuStyle.iconFont
                                        font.pixelSize: MenuStyle.iconSize
                                        color: Config.colors.text
                                        text: modelData.icon
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: MenuStyle.bodyFont
                                        font.pixelSize: MenuStyle.fontSize
                                        color: Config.colors.text
                                        text: modelData.value
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.pad

                    BevelButton {
                        id: programsButton
                        Layout.fillWidth: true
                        visible: root.cascading
                        text: "Programs"
                        glyph: "\ue5c3"
                        checked: root.cascadeItem() !== null && root.cascadeItem().visible
                        onClicked: root.toggleCascade()
                    }
                    BevelButton {
                        Layout.fillWidth: true
                        text: "Files"
                        glyph: "\ue2c7"
                        onClicked: {
                            Quickshell.execDetached(["sh", "-c", Config.settings.execCommands.files]);
                            root.closeCallback();
                        }
                    }
                    BevelButton {
                        Layout.fillWidth: true
                        text: "Settings"
                        glyph: "\ue8b8"
                        onClicked: {
                            root.closeCallback();
                            root.openSettingsCallback();
                        }
                    }
                    BevelButton {
                        Layout.fillWidth: true
                        text: "Terminal"
                        glyph: "\ueb8e"
                        onClicked: {
                            Quickshell.execDetached(["sh", "-c", Config.settings.execCommands.terminal]);
                            root.closeCallback();
                        }
                    }
                    BevelButton {
                        Layout.fillWidth: true
                        text: "Power"
                        glyph: "\uf418"
                        onClicked: {
                            root.closeCallback();
                            root.openPowerMenuCallback();
                        }
                    }
                }

                // The daily extras: the cheat sheet, the Trash (its size; only opens the folder in the file manager: what is in the
                // Trash is deleted there, where you can see it), and the pending updates while there are any. The rarely used
                // tools (Services, Network, Default apps, Troubleshoot, Login report, Clean up, Colours) are in Settings > System tools.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.pad

                    BevelButton {
                        Layout.fillWidth: true
                        text: "Keys"
                        glyph: "\ue312"
                        onClicked: {
                            root.closeCallback();
                            root.openKeysCallback();
                        }
                    }
                    BevelButton {
                        Layout.fillWidth: true
                        text: CleanupState.trashLabel
                        glyph: "\ue872"
                        onClicked: {
                            Quickshell.execDetached(["sh", "-c", Config.settings.execCommands.files + " trash:///"]);
                            root.closeCallback();
                        }
                    }
                    BevelButton {
                        Layout.fillWidth: true
                        visible: UpdateState.total > 0
                        text: "Updates (" + UpdateState.total + ")"
                        glyph: "\ue923"
                        onClicked: {
                            root.closeCallback();
                            root.openUpdatesCallback();
                        }
                    }
                }

                // Mounted USB drives, one button each; a click unmounts and powers the drive off (UsbState)
                Repeater {
                    model: UsbState.ejectable
                    BevelButton {
                        required property var modelData
                        Layout.fillWidth: true
                        glyph: "\ue8fb"
                        text: "Eject " + UsbState.displayName(modelData)
                        onClicked: {
                            UsbState.eject(modelData.dev);
                            root.closeCallback();
                        }
                    }
                }
            }
        }
    }

    // Only loaded while the setting is on, so with it off nothing of the cascade exists
    LazyLoader {
        id: cascade
        active: root.cascading
        source: "PopupCascade.qml"
    }

    function cascadeItem(): var {
        return cascade.item;
    }

    // The Programs menu opens at the Start menu's right edge, level with its button; the button again closes it
    function toggleCascade() {
        const c = root.cascadeItem();
        if (!c)
            return;
        if (c.visible) {
            c.close();
            return;
        }
        c.closeCallback = function () { root.closeCallback(); };
        const p = programsButton.mapToItem(null, 0, 0);
        c.openAt(programsButton, root.width - p.x, 0);
    }

    function openMenu() { openStartMenu() }

    function openStartMenu() {
        // the Empty Trash row's size: measured once (read-only `sizes`), refreshed whenever the Clean up panel opens
        if (CleanupState.rows.length === 0)
            CleanupState.load();
        root.visible = true;
    }

    function closeMenu() {
        if (root.cascadeItem())
            root.cascadeItem().close();
        root.visible = false;
    }
}
