import QtQuick
import QtQuick.Layouts

import ".."

// The one menu look for every right-click and dropdown menu: the shell's raised frame (outline + two-ring
// bevel), no title bar, MenuRows with an icon column, etched separators. Used inside PopupMenu (its
// own popup window) or placed inline (the Spotify drawer).
// model: [{ text, glyph, trailing, checked, enabled, separator, action }]; every key optional except text
// (or separator: true). action() runs after picked() is emitted.
// Keys (when it has focus): Up / Down move, Enter picks, Escape emits escaped().
Rectangle {
    id: root

    property var model: []
    property int currentIndex: -1
    // the icon column only when at least one entry has an icon
    readonly property bool anyIcon: root.model.some(e => !e.separator && !!e.glyph)
    signal picked(int index, var entry)
    signal escaped()

    // The width the longest label (and trailing text) needs; call measure() after changing model
    property int menuWidth: MenuStyle.contextMenuMinWidth
    function measure() {
        let label = 0, trail = 0;
        for (const e of root.model) {
            if (e.separator)
                continue;
            tm.text = e.text || "";
            label = Math.max(label, tm.advanceWidth);
            tm.text = e.trailing || "";
            trail = Math.max(trail, tm.advanceWidth);
        }
        const row = MenuStyle.pad + (root.anyIcon ? MenuStyle.iconSize + MenuStyle.pad : 0) + Math.ceil(label)
            + (trail > 0 ? MenuStyle.space12 + Math.ceil(trail) : 0) + MenuStyle.pad + MenuStyle.iconSize + MenuStyle.pad;
        root.menuWidth = Math.max(MenuStyle.contextMenuMinWidth, row + 2 * MenuStyle.frameInset);
    }
    onModelChanged: measure()
    Component.onCompleted: measure()

    function usable(i) {
        const e = root.model[i];
        return e !== undefined && !e.separator && e.enabled !== false;
    }
    function step(dir) {
        const n = root.model.length;
        let i = root.currentIndex;
        for (let k = 0; k < n; k++) {
            i = (i + dir + n) % n;
            if (root.usable(i)) {
                root.currentIndex = i;
                return;
            }
        }
    }
    function pick(i) {
        if (!root.usable(i))
            return;
        const e = root.model[i];
        root.picked(i, e);
        if (typeof e.action === "function")
            e.action();
    }

    implicitWidth: root.menuWidth
    implicitHeight: column.implicitHeight + 2 * MenuStyle.frameInset
    color: Config.colors.base
    border.width: 1
    border.color: Config.colors.outline

    Bevel {
        anchors.fill: parent
        anchors.margins: 1
    }

    TextMetrics {
        id: tm
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            root.step(1);
        } else if (event.key === Qt.Key_Up) {
            root.step(-1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.pick(root.currentIndex);
        } else if (event.key === Qt.Key_Escape) {
            root.escaped();
        } else {
            return;
        }
        event.accepted = true;
    }

    ColumnLayout {
        id: column
        x: MenuStyle.frameInset
        y: MenuStyle.frameInset
        width: root.width - 2 * MenuStyle.frameInset
        spacing: 0
        Repeater {
            model: root.model
            delegate: Item {
                id: entry
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: modelData.separator ? sep.implicitHeight : row.implicitHeight
                MenuSeparator {
                    id: sep
                    visible: entry.modelData.separator === true
                    width: parent.width
                }
                MenuRow {
                    id: row
                    visible: entry.modelData.separator !== true
                    width: parent.width
                    text: entry.modelData.text || ""
                    glyph: entry.modelData.glyph || ""
                    reserveIcon: root.anyIcon
                    trailing: entry.modelData.trailing || ""
                    marked: entry.modelData.checked === true
                    enabled: entry.modelData.enabled !== false
                    selected: entry.index === root.currentIndex
                    focusPolicy: Qt.NoFocus
                    onHoveredChanged: if (hovered && enabled) root.currentIndex = entry.index
                    onClicked: root.pick(entry.index)
                }
            }
        }
    }
}
