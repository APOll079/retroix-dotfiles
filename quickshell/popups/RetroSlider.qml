import QtQuick
import QtQuick.Controls.Basic

import ".."

// Win95 trackbar: a thin sunken groove across the whole width and a raised bevel thumb; no fill (the
// accent is kept for selection and "on"). dim (muted): the thumb's face goes grey.
// fill: for a slider that is also a meter (the Spotify seek bar shows progress): the SegmentBar track
// with its accent fill instead of the groove; dim then also empties the fill.
Slider {
    id: root

    property bool dim: false
    property bool fill: false

    implicitHeight: MenuStyle.rowHeight + MenuStyle.gap
    hoverEnabled: true

    background: Item {
        SegmentBar {
            visible: root.fill
            anchors.fill: parent
            value: root.visualPosition
            dim: root.dim
        }
        Rectangle {
            visible: !root.fill
            x: root.leftPadding
            y: Math.round(root.topPadding + root.availableHeight / 2 - height / 2)
            width: root.availableWidth
            height: MenuStyle.sliderGroove
            color: Config.colors.highlight
            Bevel {
                anchors.fill: parent
                raised: false
            }
        }
    }

    handle: Rectangle {
        x: Math.round(root.leftPadding + root.visualPosition * (root.availableWidth - width))
        y: Math.round(root.topPadding + root.availableHeight / 2 - height / 2)
        implicitWidth: MenuStyle.sliderKnobWidth
        implicitHeight: root.implicitHeight
        color: root.dim ? Config.colors.shadow : Config.colors.base
        Bevel {
            anchors.fill: parent
            button: true
            raised: !root.pressed
        }
    }
}
