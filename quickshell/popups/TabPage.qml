import QtQuick

import ".."

// Win95 tabs joined to a raised page: the one tab look (Spotify drawer, side panel, launcher). The selected
// tab is a pixel taller than the others and covers the page's top edge; the others sit lower. With no tabs
// (or tabsShown false) it is just the raised page. Content goes into the page (inset by the bevel + pagePad).
// tabs: [{ key, text }]; current: the selected key; tabClicked(key) when one is clicked (the host switches).
Item {
    id: page

    property var tabs: []
    property string current: ""
    property bool tabsShown: true
    // flat: no raised page and no padding, the content fills the whole area (the launcher's Clipboard tab; the host draws its own tab buttons)
    property bool flat: false
    property int tabHeight: MenuStyle.tabHeight
    property int pagePad: MenuStyle.tabPagePad
    signal tabClicked(string key)

    readonly property bool hasTabs: page.tabsShown && page.tabs.length > 0
    readonly property int frameTop: hasTabs ? tabHeight - 2 : 0
    readonly property int inset: page.flat ? 0 : 3 + page.pagePad
    default property alias content: body.data

    // the page: outline + raised bevel
    Rectangle {
        id: frame
        visible: !page.flat
        y: page.frameTop
        width: parent.width
        height: parent.height - y
        color: Config.colors.base
        border.width: 1
        border.color: Config.colors.outline
        Bevel {
            anchors.fill: parent
            anchors.margins: 1
            raised: true
        }
    }

    // the tabs, drawn after the page so the selected one covers its top edge
    Row {
        visible: page.hasTabs
        x: MenuStyle.pad
        z: 1
        spacing: -1
        Repeater {
            model: page.tabs
            Item {
                id: tab
                required property var modelData
                readonly property bool sel: page.current === modelData.key
                width: label.implicitWidth + 2 * MenuStyle.pad + 10
                height: sel ? page.tabHeight + 1 : page.tabHeight - 4
                y: sel ? 0 : 2
                // face, then the raised edges on three sides (the bottom joins the page)
                Rectangle { anchors.fill: parent; color: Config.colors.base }
                Rectangle { x: 0; y: 0; width: tab.width; height: 1; color: Config.colors.outline }
                Rectangle { x: 0; y: 0; width: 1; height: tab.height; color: Config.colors.outline }
                Rectangle { x: tab.width - 1; y: 0; width: 1; height: tab.height; color: Config.colors.outline }
                Rectangle { x: 1; y: 1; width: tab.width - 3; height: 1; color: MenuStyle.bevelLight }
                Rectangle { x: 1; y: 1; width: 1; height: tab.height - 1; color: MenuStyle.bevelLight }
                Rectangle { x: tab.width - 2; y: 1; width: 1; height: tab.height - 1; color: MenuStyle.bevelDark }
                Text {
                    id: label
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round((tab.height - implicitHeight) / 2) + (tab.sel ? 1 : 0)
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: Config.colors.text
                    text: tab.modelData.text
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.tabClicked(tab.modelData.key)
                }
            }
        }
    }

    Item {
        id: body
        x: page.inset
        y: page.frameTop + page.inset
        width: page.width - 2 * x
        height: page.height - y - page.inset
    }
}
