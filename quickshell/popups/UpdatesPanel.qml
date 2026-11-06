import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".."

// Pending updates (Start > Updates (N)), centred like Services. Counts per source, then the newest Arch news
// (read it BEFORE updating: pacman updates sometimes need a manual step), then Refresh and Update. Update all / System / Flatpak
// open the configured terminal on `yay -Syu` and / or `flatpak update` (UpdateState.runUpdate) and close the panel; nothing is installed here.
// Arch's news feed, not Artix's. Enter = Update, Escape / a click outside / the Start row again close.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    readonly property var sources: [
        { key: "pacman", label: "Pacman", count: UpdateState.pacman },
        { key: "aur", label: "AUR", count: UpdateState.aur },
        { key: "flatpak", label: "Flatpak", count: UpdateState.flatpak }
    ]
    readonly property int newsRows: 5          // updates.sh lists at most 5 headlines: room for them from the start
    readonly property bool checkedOnce: UpdateState.lastChecked !== null

    // An Overlay-layer panel, not a popup of the bar (see ServicesPanel)
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: false
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.closeCallback()
    }

    Item {
        id: frame
        width: MenuStyle.widthLarge
        height: content.implicitHeight + MenuStyle.chromeTop + MenuStyle.chromeBottom
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.screenHeight / 2 - height / 2)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupWindowFrame {
            windowTitle: "Updates"
            windowTitleIcon: "\ue923"

            ColumnLayout {
                id: content
                anchors.fill: parent
                spacing: MenuStyle.pad

                FocusScope {
                    id: keys
                    Layout.preferredWidth: 0
                    Layout.preferredHeight: 0
                    focus: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.closeCallback();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.update();
                            event.accepted = true;
                        }
                    }
                }

                // Both groups keep room for their full content from the start, so the panel does not resize
                // when the counts or the news arrive
                GroupFrame {
                    Layout.fillWidth: true
                    title: "Available"

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(implicitHeight, root.sources.length * MenuStyle.rowHeight)
                        spacing: MenuStyle.gap
                        EmptyState {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.checkedOnce && UpdateState.total === 0
                            glyph: "\ue86c"
                            text: "Up to date"
                        }
                        Repeater {
                            model: root.sources
                            RowLayout {
                                Layout.fillWidth: true
                                visible: !(root.checkedOnce && UpdateState.total === 0)
                                spacing: MenuStyle.gap
                                RetroText {
                                    Layout.fillWidth: true
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    text: modelData.label
                                }
                                RetroText {
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    disabledLook: modelData.count === null
                                    text: modelData.count === null ? (root.checkedOnce ? "not installed" : "...") : String(modelData.count)
                                }
                            }
                        }
                    }
                }

                GroupFrame {
                    Layout.fillWidth: true
                    title: "Arch news"

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(implicitHeight, root.newsRows * MenuStyle.rowHeight)
                        spacing: MenuStyle.gap
                        EmptyState {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: UpdateState.news.length === 0
                            glyph: "\ue0be"
                            text: root.checkedOnce ? "No news (or no network)" : "Checking..."
                        }
                        Repeater {
                            model: UpdateState.news
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: MenuStyle.gap
                                RetroText {
                                    Layout.alignment: Qt.AlignTop
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    disabledLook: true
                                    text: modelData.date
                                }
                                // Headlines come from outside: plain text (RetroText is PlainText), wrapped, never cut
                                RetroText {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    text: modelData.title
                                }
                            }
                        }
                        Item {
                            Layout.fillHeight: true
                            visible: UpdateState.news.length > 0
                        }
                    }
                }

                RetroText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    text: "Read the news before updating"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap
                    Item {
                        Layout.fillWidth: true
                    }
                    BevelButton {
                        id: refreshButton
                        text: "Refresh"
                        glyph: "\ue5d5"
                        enabled: !UpdateState.checking
                        focusPolicy: Qt.NoFocus
                        onClicked: UpdateState.refresh()
                    }
                    BevelButton {
                        text: "System"
                        glyph: "\ue923"
                        enabled: UpdateState.countFor("system") > 0
                        focusPolicy: Qt.NoFocus
                        onClicked: root.update("system")
                    }
                    BevelButton {
                        text: "Flatpak"
                        glyph: "\ue923"
                        enabled: UpdateState.countFor("flatpak") > 0
                        focusPolicy: Qt.NoFocus
                        onClicked: root.update("flatpak")
                    }
                    BevelButton {
                        id: updateButton
                        text: "Update all"
                        glyph: "\ue923"
                        isDefault: true
                        enabled: UpdateState.total > 0
                        focusPolicy: Qt.NoFocus
                        onClicked: root.update("all")
                    }
                }

                StatusBar {
                    kind: UpdateState.error !== "" ? "error" : (UpdateState.checking ? "message" : "state")
                    text: UpdateState.error !== "" ? UpdateState.error
                        : UpdateState.checking ? "Checking for updates..."
                        : root.checkedOnce ? UpdateState.summary + " (checked " + Qt.formatTime(UpdateState.lastChecked, "hh:mm") + ")"
                        : "Not checked yet"
                }
            }
        }
    }

    // Opens the terminal on the update (kind: "system" = yay -Syu, "flatpak", "all" = both) and closes the panel
    // (an Exclusive-keyboard panel would sit over it)
    function update(kind) {
        const k = kind || "all";
        if (UpdateState.countFor(k) <= 0)
            return;
        UpdateState.runUpdate(k);
        root.closeCallback();
    }

    function openMenu() {
        UpdateState.refresh();
        root.visible = true;
        keys.forceActiveFocus();
    }

    function closeMenu() {
        root.visible = false;
    }
}
