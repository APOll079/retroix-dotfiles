import QtQuick
import ".."

// The tooltip: a small flat frame next to the control (below it, above when there is no room), set by
// SpotifyHint through panel.tip = { text, item }. It takes no clicks and goes when the pointer leaves.
Item {
    id: tipRoot
    required property var panel
    readonly property var tip: panel.tip
    anchors.fill: parent
    visible: tip !== null && panel.rowMenu === null && !panel.menuOpen
    z: 20

    Rectangle {
        id: box
        readonly property point at: tipRoot.tip && tipRoot.tip.item ? tipRoot.tip.item.mapToItem(tipRoot, 0, 0) : Qt.point(0, 0)
        readonly property real itemHeight: tipRoot.tip && tipRoot.tip.item ? tipRoot.tip.item.height : 0
        readonly property real below: at.y + itemHeight + MenuStyle.gap / 2
        width: label.width + 2 * MenuStyle.pad
        height: label.height + 2 * MenuStyle.gap
        x: Math.max(MenuStyle.gap, Math.min(at.x, tipRoot.width - width - MenuStyle.gap))
        y: below + height <= tipRoot.height - MenuStyle.spotifyStatusHeight ? below : Math.max(0, at.y - height - MenuStyle.gap / 2)
        color: Config.colors.base
        border.width: 1
        border.color: Config.colors.outline
        Text {
            id: label
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            textFormat: Text.PlainText
            x: MenuStyle.pad
            y: MenuStyle.gap
            width: Math.min(implicitWidth, tipRoot.width - 2 * MenuStyle.gap - 2 * MenuStyle.pad)
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: tipRoot.tip ? tipRoot.tip.text : ""
        }
    }
}
