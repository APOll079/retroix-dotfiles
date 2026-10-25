import QtQuick
import ".."
import "." as Local

// The one heading style in the drawer ("Recent", "Pinned", search groups): a dim bold label, a thin etched
// line to the right, and optionally an action at the right end in the same dim text (Recent's Hide / Show).
Item {
    id: heading
    required property var panel
    property string label: ""
    property string actionText: ""
    property string actionGlyph: ""
    property string actionHint: ""
    signal actionClicked()
    implicitHeight: MenuStyle.rowHeight

    Text {
        id: headingText
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        anchors.left: parent.left
        anchors.leftMargin: MenuStyle.pad
        anchors.verticalCenter: parent.verticalCenter
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        font.bold: true
        color: MenuStyle.bevelDark
        text: heading.label
    }
    Row {
        id: action
        anchors.right: parent.right
        anchors.rightMargin: MenuStyle.pad
        anchors.verticalCenter: parent.verticalCenter
        visible: heading.actionText !== ""
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            anchors.verticalCenter: parent.verticalCenter
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: MenuStyle.bevelDark
            text: heading.actionText
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            anchors.verticalCenter: parent.verticalCenter
            font.family: MenuStyle.iconFont
            font.pixelSize: MenuStyle.iconSize
            color: MenuStyle.bevelDark
            text: heading.actionGlyph
        }
    }
    Local.MenuSeparator {
        anchors.left: headingText.right
        anchors.leftMargin: heading.label === "" ? 0 : MenuStyle.pad
        anchors.right: action.visible ? action.left : parent.right
        anchors.rightMargin: action.visible ? MenuStyle.pad : MenuStyle.pad
        anchors.verticalCenter: parent.verticalCenter
    }
    MouseArea {
        anchors.fill: action
        enabled: action.visible
        cursorShape: Qt.PointingHandCursor
        onClicked: heading.actionClicked()
        SpotifyHint { panel: heading.panel; text: heading.actionHint }
    }
}
