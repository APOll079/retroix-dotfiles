import QtQuick
import QtQuick.Layouts

import ".."

// The status bar at the bottom of a window (Spotify drawer, Task Manager, Games, Wallpapers, Services,
// screenshot History): one line, left, what is going on; optionally a dim right-hand text (counts); extra
// children (buttons) go after it on the right.
// kind: "state" (dim: nothing special is going on), "message" (normal text: a hint or a short note),
// "error" (urgent colour). highlighted: the text cell on an accent bar, for a state worth noticing.
Item {
    id: root

    property string text: ""
    property string kind: "state"
    property bool highlighted: false
    property string trailing: ""
    default property alias content: row.data

    Layout.fillWidth: true
    implicitHeight: MenuStyle.statusHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: MenuStyle.gap
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.highlighted ? MenuStyle.selectBar : "transparent"
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                anchors.fill: parent
                anchors.leftMargin: MenuStyle.gap
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: root.highlighted ? MenuStyle.selectText
                    : root.kind === "error" ? Config.colors.urgent
                    : root.kind === "message" ? Config.colors.text
                    : MenuStyle.bevelDark
                text: root.text
            }
        }
        Text {
            visible: root.trailing !== ""
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: MenuStyle.gap
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: MenuStyle.bevelDark
            text: root.trailing
        }
    }
}
