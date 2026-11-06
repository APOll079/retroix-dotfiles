import QtQuick
import ".."

// The drawer's tabbed page (Library | Liked | Queue) on the shared TabPage. Without tabs (the lyrics view,
// picking a playlist) it is just the raised page.
TabPage {
    id: page
    required property var panel
    tabs: [{ key: "library", text: "Library" }, { key: "liked", text: "Liked" }, { key: "queue", text: "Queue" }]
    current: panel.tab
    tabsShown: !panel.addMode && !panel.lyricsMode
    tabHeight: MenuStyle.spotifyTabHeight
    pagePad: MenuStyle.spotifyPagePad
    onTabClicked: key => panel.showTab(key)
}
