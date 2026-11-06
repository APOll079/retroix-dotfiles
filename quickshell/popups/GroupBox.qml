import QtQuick
import QtQuick.Layouts

import ".."

// Win95 group box: a thin etched frame (dark line, light line beside it) with the label set into its top
// edge. Groups related controls without a second raised or sunken frame. Children go into a ColumnLayout
// inside the frame (padding MenuStyle.pad).
Item {
    id: root

    property string title: ""
    default property alias content: column.data
    readonly property int frameTop: Math.round(label.implicitHeight / 2)

    implicitWidth: column.implicitWidth + 2 * MenuStyle.pad + 2
    implicitHeight: root.frameTop + Math.round(label.implicitHeight / 2) + column.implicitHeight + 2 * MenuStyle.pad + 2

    // etched frame: the light rectangle 1px down-right, the dark one over it
    Rectangle {
        x: 1; y: root.frameTop + 1
        width: root.width - 1; height: root.height - root.frameTop - 1
        color: "transparent"
        border.width: 1
        border.color: MenuStyle.bevelLight
    }
    Rectangle {
        x: 0; y: root.frameTop
        width: root.width - 1; height: root.height - root.frameTop - 1
        color: "transparent"
        border.width: 1
        border.color: MenuStyle.bevelDark
    }
    // the label, on the face colour so it cuts the top line
    Rectangle {
        visible: root.title !== ""
        x: MenuStyle.pad
        width: label.implicitWidth + 2 * MenuStyle.space4
        height: label.implicitHeight
        color: Config.colors.base
        RetroText {
            id: label
            x: MenuStyle.space4
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            text: root.title
        }
    }

    ColumnLayout {
        id: column
        x: MenuStyle.pad + 1
        y: root.frameTop + Math.round(label.implicitHeight / 2) + MenuStyle.pad
        width: root.width - 2 * MenuStyle.pad - 2
        spacing: MenuStyle.gap
    }
}
