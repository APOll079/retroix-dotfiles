import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

import ".."

// Raised push button; pressing it pushes the bevel in and nudges the content. checked = the same plus a
// dithered lighter face (flat lighter face when dither is off). No hover highlight: Win95 buttons don't
// light up (the pointer cursor still changes).
Button {
    id: root

    property string glyph: ""
    // Optional colour for the glyph (e.g. the green liked heart); transparent = normal text colour
    property color glyphColor: "transparent"
    property int glyphSize: MenuStyle.iconSize
    // The default button of a confirm (what Enter does): Win95's extra outline ring outside the bevel
    property bool isDefault: false
    hoverEnabled: true

    implicitHeight: MenuStyle.rowHeight + MenuStyle.gap
    // Icon-only buttons are square (the glyph centred); text buttons are at least three rows wide
    implicitWidth: root.text === "" ? implicitHeight : Math.max(MenuStyle.rowHeight * 3, implicitContentWidth + leftPadding + rightPadding)
    leftPadding: root.text === "" ? 0 : MenuStyle.pad + 3
    rightPadding: root.text === "" ? 0 : MenuStyle.pad + 3
    topPadding: 0
    bottomPadding: 0

    background: Rectangle {
        color: Config.colors.base
        border.width: root.isDefault ? 1 : 0
        border.color: Config.colors.outline
        Dither {
            anchors.fill: parent
            anchors.margins: 2
            visible: root.checked
            color1: MenuStyle.bevelInnerLight
            color2: MenuStyle.bevelLight
        }
        Bevel {
            anchors.fill: parent
            anchors.margins: root.isDefault ? 1 : 0
            button: true
            raised: !(root.down || root.checked)
        }
        FocusRect {
            anchors.fill: parent
            anchors.margins: 3
            visible: root.visualFocus
            color: Config.colors.text
        }
    }

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        RowLayout {
            id: row
            anchors.fill: parent
            // a pushed-in button moves its content 1 px down and right: a margin of 2 on a centred layout shifts it by 1
            anchors.topMargin: (root.down || root.checked) ? 2 : 0
            anchors.leftMargin: (root.down || root.checked) ? 2 : 0
            spacing: MenuStyle.gap
            Item { Layout.fillWidth: true }
            RetroText {
                visible: root.glyph !== ""
                color: root.glyphColor.a > 0 && root.enabled ? root.glyphColor : Config.colors.text
                font.family: MenuStyle.iconFont
                font.pixelSize: root.glyphSize
                disabledLook: !root.enabled
                text: root.glyph
            }
            RetroText {
                visible: root.text !== ""
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                disabledLook: !root.enabled
                text: root.text
            }
            Item { Layout.fillWidth: true }
        }
    }

    HoverHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        cursorShape: Qt.PointingHandCursor
    }
}
