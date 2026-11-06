import QtQuick
import QtQuick.Layouts

import ".."

// The one "nothing here" look: a dim glyph and one quiet line, centred in whatever it fills
// ("No notifications", "No paired devices", "No screenshots"). Wraps rather than cuts.
ColumnLayout {
    id: root

    property string glyph: ""
    property string text: ""

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
