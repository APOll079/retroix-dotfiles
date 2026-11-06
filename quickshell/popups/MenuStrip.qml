import QtQuick

import ".."

// A window's menu bar (File / View ...): flat titles that fill with the accent bar while hovered or open.
// A click opens the dropdown (a PopupMenu under the title), a second click closes it; the click that
// dismissed the dropdown (its grab) is ignored so it doesn't reopen it. The dropdowns only list actions the
// window already has.
// menus: [{ text, build }]: build() returns the PopupMenu model when that menu opens. closed() is emitted
// when a dropdown closes (the host gives the keyboard back to its search box).
Row {
    id: root

    property var menus: []
    signal closed()

    Repeater {
        model: root.menus
        delegate: Rectangle {
            id: title
            required property var modelData
            property real closedAt: 0
            readonly property bool lit: area.containsMouse || dropdown.visible

            implicitWidth: label.implicitWidth + 2 * MenuStyle.pad
            implicitHeight: MenuStyle.rowHeight
            color: title.lit ? MenuStyle.selectBar : "transparent"

            RetroText {
                id: label
                anchors.centerIn: parent
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: title.lit ? MenuStyle.selectText : Config.colors.text
                text: title.modelData.text
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (dropdown.visible) {
                        dropdown.close();
                        return;
                    }
                    // the click that dismissed the menu (its grab) must not open it again
                    if (Date.now() - title.closedAt < 250)
                        return;
                    dropdown.model = title.modelData.build();
                    dropdown.openAt(title, 0, title.height);
                }
            }
            PopupMenu {
                id: dropdown
                onVisibleChanged: {
                    if (!visible) {
                        title.closedAt = Date.now();
                        root.closed();
                    }
                }
            }
        }
    }
}
