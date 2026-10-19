import QtQuick

import ".."

// Inset area for inputs, sliders and lists: light fill, solid 1px outline and a darker
// inner top/left edge so it reads as pressed in.
Rectangle {
    id: root

    default property alias content: inner.data
    property int padding: 4
    property bool flat: false      // no outline and no inner edges: just the fill (a list inside a framed page)

    color: Config.colors.highlight
    border.width: root.flat ? 0 : 1
    border.color: Config.colors.outline

    Rectangle { visible: !root.flat; x: 1; y: 1; width: root.width - 2; height: 1; color: MenuStyle.bevelDark }
    Rectangle { visible: !root.flat; x: 1; y: 1; width: 1; height: root.height - 2; color: MenuStyle.bevelDark }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
