import QtQuick
import Quickshell

import ".."

// A right-click / dropdown menu in its own popup window (PopupMenuBody inside). openAt(item, x, y)
// shows it at that point of item (it slides / flips to stay on screen). It takes keyboard focus while
// open (grabFocus) and closes on a pick, Escape, or a click anywhere outside it.
// model: see PopupMenuBody. picked(index, entry) is emitted before the entry's action runs.
PopupWindow {
    id: root

    property alias model: body.model
    signal picked(int index, var entry)

    property Item anchorItem: null
    property int anchorX: 0
    property int anchorY: 0

    function openAt(item, x, y) {
        body.measure();
        body.currentIndex = -1;
        root.anchorItem = item;
        root.anchorX = Math.round(x);
        root.anchorY = Math.round(y);
        visible = true;
        body.forceActiveFocus();
    }
    function close() {
        visible = false;
    }

    grabFocus: true
    color: "transparent"
    anchor.item: root.anchorItem
    anchor.rect.x: root.anchorX
    anchor.rect.y: root.anchorY
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    PopupMenuBody {
        id: body
        anchors.fill: parent
        focus: true
        onPicked: (index, entry) => {
            root.close();
            root.picked(index, entry);
        }
        onEscaped: root.close()
    }
}
