import QtQuick

// The bar's one sunken tray well (fall25 / Win95 taskbar tray): the face colour with a 1px sunken edge
// (dark top-left, light bottom-right). Status items go inside as flat BarButtons in a row, split by
// vertical MenuSeparators, never boxed one by one.
Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + 2 * MenuStyle.barWellPad + 2
    implicitHeight: MenuStyle.barButtonHeight + 2 * MenuStyle.barWellPad
    color: Config.colors.base

    Bevel {
        anchors.fill: parent
        thickness: 1
        raised: false
    }

    Row {
        id: row
        x: MenuStyle.barWellPad + 1
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
    }
}
