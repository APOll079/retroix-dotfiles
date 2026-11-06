import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

import ".."

// One clickable row. Hover (or keyboard focus) fills it with the accent color, like a Win95 menu.
Button {
    id: root

    property string glyph: ""
    property url iconSource: ""
    property string trailing: ""
    property string subtext: ""
    property int subtextSize: MenuStyle.fontSize
    property bool marked: false
    property string markGlyph: "\ue5ca"     // the sign shown when marked (default: a check)
    property bool selected: false
    property int iconBox: MenuStyle.iconSize   // the icon / thumbnail square (the Spotify lists use a bigger one)
    // Keep the icon column's width even when this row has no icon, so labels line up down a menu. Set it on
    // every row of a menu that has at least one icon (ContextMenuBody does it by itself); a menu without
    // any icon leaves it off, so its labels don't indent.
    property bool reserveIcon: false
    property bool accentTitle: false           // the title in the accent colour (the playing song)
    property bool trailingDim: false           // the trailing text dim (a duration column)
    readonly property bool lit: hover.hovered || hovered || visualFocus || down || selected

    implicitHeight: subtext !== "" ? MenuStyle.rowHeight * 3 / 2 : MenuStyle.rowHeight
    implicitWidth: 160
    hoverEnabled: true
    leftPadding: MenuStyle.pad
    rightPadding: MenuStyle.pad
    topPadding: 0
    bottomPadding: 0

    background: Rectangle {
        color: root.lit ? MenuStyle.selectBar : Qt.rgba(MenuStyle.selectBar.r, MenuStyle.selectBar.g, MenuStyle.selectBar.b, 0)
        Behavior on color {
            ColorAnimation { duration: MenuStyle.animFast }
        }
        // Keyboard selection gets the dotted focus marker on top of the accent bar
        FocusRect {
            anchors.fill: parent
            anchors.margins: 1
            visible: root.selected || root.visualFocus
            color: MenuStyle.selectText
        }
    }

    contentItem: RowLayout {
        spacing: MenuStyle.pad
        Item {
            Layout.preferredWidth: root.iconBox
            Layout.preferredHeight: root.iconBox
            visible: root.reserveIcon || root.glyph !== "" || root.iconSource != ""
            Image {
                id: appIcon
                anchors.fill: parent
                asynchronous: true
                smooth: false
                source: root.iconSource
                sourceSize: Qt.size(root.iconBox * 2, root.iconBox * 2)
                visible: status === Image.Ready
            }
            RetroText {
                anchors.centerIn: parent
                visible: !appIcon.visible
                font.family: MenuStyle.iconFont
                font.pixelSize: MenuStyle.iconSize
                color: root.lit ? MenuStyle.selectText : Config.colors.text
                disabledLook: !root.enabled
                text: root.glyph
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RetroText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                disabledLook: !root.enabled
                color: root.lit ? MenuStyle.selectText : (root.accentTitle ? MenuStyle.barOnGlyph : Config.colors.text)
                text: root.text
            }
            Text {
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
                font.hintingPreference: Font.PreferFullHinting
                Layout.fillWidth: true
                visible: root.subtext !== ""
                elide: Text.ElideRight
                font.family: MenuStyle.bodyFont
                font.pixelSize: root.subtextSize
                color: root.lit ? MenuStyle.selectText : Config.colors.shadow
                text: root.subtext
            }
        }
        RetroText {
            visible: root.trailing !== ""
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: root.lit ? MenuStyle.selectText : (root.trailingDim ? Config.colors.shadow : Config.colors.text)
            disabledLook: !root.enabled
            text: root.trailing
        }
        RetroText {
            visible: root.marked
            font.family: MenuStyle.iconFont
            font.pixelSize: MenuStyle.iconSize
            color: root.lit ? MenuStyle.selectText : Config.colors.text
            disabledLook: !root.enabled
            text: root.markGlyph
        }
    }

    HoverHandler {
        id: hover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        cursorShape: Qt.PointingHandCursor
    }
}
