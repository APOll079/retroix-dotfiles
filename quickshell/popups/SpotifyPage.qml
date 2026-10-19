import QtQuick
import ".."

// The tabbed page: Win95 tabs (Library | Liked) joined to a raised page that holds the chips, Recent and the
// list. The selected tab is a pixel taller than the others and covers the page's top edge; the other tabs
// sit lower. Without tabs (the lyrics view, picking a playlist) it is just the raised page.
Item {
    id: page
    required property var panel
    readonly property bool tabsShown: !panel.addMode && !panel.lyricsMode
    readonly property int tabH: MenuStyle.spotifyTabHeight
    readonly property int frameTop: tabsShown ? tabH - 2 : 0
    // what the page holds (a layout anchored to this area)
    default property alias content: body.data

    // the page: outline + raised bevel
    Rectangle {
        id: frame
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
        visible: page.tabsShown
        x: MenuStyle.pad
        z: 1
        spacing: -1
        Repeater {
            model: [{ key: "library", text: "Library" }, { key: "liked", text: "Liked" }]
            Item {
                id: tab
                required property var modelData
                readonly property bool sel: page.panel.tab === modelData.key
                width: label.implicitWidth + 2 * MenuStyle.pad + 10
                height: sel ? page.tabH + 1 : page.tabH - 4
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
                    y: tab.sel ? 4 : 2
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: Config.colors.text
                    text: tab.modelData.text
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.panel.showTab(tab.modelData.key)
                }
            }
        }
    }

    Item {
        id: body
        x: 3 + MenuStyle.spotifyPagePad
        y: page.frameTop + 3 + MenuStyle.spotifyPagePad
        width: page.width - 2 * x
        height: page.height - y - 3 - MenuStyle.spotifyPagePad
    }
}
