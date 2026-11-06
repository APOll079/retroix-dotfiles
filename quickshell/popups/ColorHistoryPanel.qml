import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// The colour picker's history (Start > Colours): the last 20 colours picked with the picker bind (ColorHistory.qml), newest
// first. A row is a swatch, the hex and the rgb value; a click (or Enter on the selected row) copies the hex and says so on
// the status line. Up / Down select, Escape closes, a click outside closes. An Overlay-layer panel, not a popup of the bar
// (see ServicesPanel).
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    property int cursor: 0
    property string copied: ""             // the hex copied last (the status line says so)

    readonly property var shown: ColorHistory.list
    readonly property int listHeight: Math.max(MenuStyle.rowHeight * 3, Math.min(MenuStyle.rowHeight * 8, list.contentHeight))

    onShownChanged: root.cursor = Math.max(0, Math.min(root.cursor, root.shown.length - 1))

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
        width: MenuStyle.widthMedium
        height: content.implicitHeight + MenuStyle.chromeTop + MenuStyle.chromeBottom
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.screenHeight / 2 - height / 2)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupWindowFrame {
            windowTitle: "Colours"
            windowTitleIcon: "\ue3b8"

            ColumnLayout {
                id: content
                anchors.fill: parent
                spacing: MenuStyle.pad

                FocusScope {
                    id: keys
                    Layout.preferredWidth: 0
                    Layout.preferredHeight: 0
                    focus: true
                    Keys.onPressed: event => root.handleKey(event)
                }

                SunkenField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.shown.length === 0 ? MenuStyle.rowHeight * 4 : root.listHeight + 2 * padding
                    padding: 2
                    clip: true

                    EmptyState {
                        objectName: "noColours"
                        anchors.fill: parent
                        visible: root.shown.length === 0
                        glyph: "\ue3b8"
                        text: "No colours yet"
                    }

                    ListView {
                        id: list
                        objectName: "colourList"
                        anchors.fill: parent
                        model: root.shown
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                        ScrollBar.vertical: RetroScrollBar {}
                        delegate: MenuRow {
                            id: entry
                            required property int index
                            required property var modelData
                            width: list.width - list.gutter
                            reserveIcon: true          // the swatch sits in the icon column
                            focusPolicy: Qt.NoFocus    // keys stay with the panel
                            selected: entry.index === root.cursor
                            text: entry.modelData.hex
                            trailing: entry.modelData.rgb
                            onClicked: root.copy(entry.index)

                            Rectangle {
                                objectName: "swatch"
                                x: MenuStyle.pad
                                y: Math.round((parent.height - height) / 2)
                                width: MenuStyle.iconSize
                                height: MenuStyle.iconSize
                                color: entry.modelData.hex
                                border.width: 1
                                border.color: Config.colors.outline
                            }
                        }
                    }
                }

                StatusBar {
                    kind: root.copied !== "" ? "message" : "state"
                    text: root.copied !== "" ? "Copied " + root.copied
                        : root.shown.length === 0 ? "Pick one with the colour picker key"
                        : "Click a colour to copy its hex"
                    trailing: root.shown.length > 0 ? root.shown.length + " of " + ColorHistory.maxItems : ""
                }
            }
        }
    }

    // --- actions ---

    function copy(i) {
        if (i < 0 || i >= root.shown.length)
            return;
        root.cursor = i;
        if (ColorHistory.copy(root.shown[i].hex))
            root.copied = root.shown[i].hex;
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            root.closeCallback();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.copy(root.cursor);
        } else if (event.key === Qt.Key_Down) {
            root.cursor = Math.min(root.shown.length - 1, root.cursor + 1);
        } else if (event.key === Qt.Key_Up) {
            root.cursor = Math.max(0, root.cursor - 1);
        } else {
            return;
        }
        event.accepted = true;
    }

    function openMenu() {
        root.cursor = 0;
        root.copied = "";
        root.visible = true;
        keys.forceActiveFocus();
    }

    function closeMenu() {
        root.visible = false;
        root.copied = "";
    }
}
