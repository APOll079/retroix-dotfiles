import QtQuick
import QtQuick.Layouts

import ".."

// The one "nothing here" look: a dim glyph and one quiet line, centred in whatever it fills
// ("No notifications", "No paired devices", "No screenshots"). Wraps rather than cuts.
// Fill the host (anchors.fill: parent, or Layout.fillWidth / fillHeight in a layout); it centres itself and
// keeps MenuStyle.pad free at each side. implicitWidth / implicitHeight are the column's, for hosts that size from them.
Item {
    id: root

    property string glyph: ""
    property string text: ""

    implicitWidth: column.implicitWidth + 2 * MenuStyle.pad
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: root.width - 2 * MenuStyle.pad
        spacing: MenuStyle.gap

        RetroText {
            visible: root.glyph !== ""
            Layout.alignment: Qt.AlignHCenter
            font.family: MenuStyle.iconFont
            font.pixelSize: MenuStyle.iconSizeLarge
            color: MenuStyle.bevelDark
            text: root.glyph
        }
        RetroText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: MenuStyle.bevelDark
            text: root.text
        }
    }
}
