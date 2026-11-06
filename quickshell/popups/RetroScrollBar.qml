import QtQuick
import QtQuick.Controls.Basic

import ".."

// Win95 scrollbar: an arrow button at each end, a raised thumb sized to the view and a dithered track.
// Attach it like any ScrollBar (ListView { ScrollBar.vertical: RetroScrollBar {} }). It floats over the
// view's edge like every Controls scroll bar, so give the content a right (or bottom) margin of
// MenuStyle.scrollBarWidth while it shows (visible is false when everything fits).
ScrollBar {
    id: root

    readonly property bool isVertical: orientation === Qt.Vertical
    readonly property int arrow: MenuStyle.scrollBarWidth

    policy: ScrollBar.AlwaysOn
    visible: size < 1.0
    implicitWidth: isVertical ? arrow : 0
    implicitHeight: isVertical ? 0 : arrow
    padding: 0
    topPadding: isVertical ? arrow : 0
    bottomPadding: isVertical ? arrow : 0
    leftPadding: isVertical ? 0 : arrow
    rightPadding: isVertical ? 0 : arrow
    // never smaller than a square thumb
    minimumSize: Math.min(1, arrow / Math.max(1, (isVertical ? height : width) - 2 * arrow))

    contentItem: Rectangle {
        implicitWidth: root.arrow
        implicitHeight: root.arrow
        color: Config.colors.base
        Bevel {
            anchors.fill: parent
            button: true
        }
    }

    background: Item {
        Dither {
            anchors.fill: parent
        }
        component Arrow: Rectangle {
            id: btn
            property string glyph: ""
            property bool up: true
            width: root.arrow
            height: root.arrow
            color: Config.colors.base
            Bevel {
                anchors.fill: parent
                button: true
                raised: !area.pressed
            }
            RetroText {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: area.pressed ? 1 : 0
                anchors.verticalCenterOffset: area.pressed ? 1 : 0
                font.family: MenuStyle.iconFont
                font.pixelSize: MenuStyle.iconSize
                text: btn.glyph
            }
            MouseArea {
                id: area
                anchors.fill: parent
                onPressed: { btn.up ? root.decrease() : root.increase(); repeat.interval = MenuStyle.scrollRepeatDelay; repeat.start(); }
                onReleased: repeat.stop()
                onCanceled: repeat.stop()
            }
            Timer {
                id: repeat
                repeat: true
                onTriggered: { interval = MenuStyle.scrollRepeatRate; btn.up ? root.decrease() : root.increase(); }
            }
        }
        Arrow {
            up: true
            glyph: root.isVertical ? "\ue5c7" : "\ue5de"
        }
        Arrow {
            up: false
            x: root.isVertical ? 0 : root.width - width
            y: root.isVertical ? root.height - height : 0
            glyph: root.isVertical ? "\ue5c5" : "\ue5df"
        }
    }
}
