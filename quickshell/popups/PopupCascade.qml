import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

import ".."
import "../utils" as Utils

// The cascading Programs menu of the Start menu (only when settings.ui.cascadingStart is on): a list of categories in its
// own popup, and next to it (to the right; to the left when there is no room) a second popup with the apps of the category
// under the pointer. Same categories as the launcher's filter row (AppLauncher.categories, kept in step by a test) and the
// same apps (DesktopEntries through Utils.AppSearch); apps hidden from the launcher (LauncherState) are left out, and a
// category with no apps is not listed.
//   Hover a category, or Right / Enter on it, opens its apps.  Up / Down move in the list that has the keys.
//   Enter or a click on an app launches it (entry.execute(), like the launcher) and closes everything (closeCallback).
//   Left closes the apps list (back to the categories); Escape closes the whole cascade, and only that: the Start menu stays.
//   A click on the empty edge of the category list closes the apps list; a click anywhere else closes the cascade (popup grab).
// openAt(item, x, y) shows it at that point of item; close() hides it. All keys come to the category popup (it holds the
// grab), the apps popup is only drawn and clicked, so the keys never get lost between the two windows.
PopupWindow {
    id: root

    // Called after an app was launched, to close the Start menu as well
    property var closeCallback: function () {}
    // The apps to list; tests hand in fakes ({ id, name, icon, categories: [...], execute() })
    property var source: Array.from(Utils.AppSearch.list)

    // key, label, glyph, freedesktop categories ([] = everything)
    readonly property var categories: [
        { key: "all", label: "All programs", glyph: "\ue5c3", cats: [] },
        { key: "web", label: "Internet", glyph: "\ue894", cats: ["Network", "WebBrowser", "Email", "Chat"] },
        { key: "media", label: "Media", glyph: "\ue405", cats: ["AudioVideo", "Audio", "Video", "Music", "Player"] },
        { key: "dev", label: "Development", glyph: "\ue86f", cats: ["Development", "IDE"] },
        { key: "graphics", label: "Graphics", glyph: "\ue40a", cats: ["Graphics", "Photography"] },
        { key: "office", label: "Office", glyph: "\ue873", cats: ["Office", "TextEditor"] },
        { key: "system", label: "System", glyph: "\ue8b8", cats: ["System", "Settings", "Monitor"] },
        { key: "utility", label: "Utilities", glyph: "\ue869", cats: ["Utility", "Accessories"] }
    ]

    // [{ key, label, glyph, apps: [entry] }] for the categories that have apps; hidden apps are never in it
    readonly property var groups: root.groupsOf(root.source)

    property int catIndex: -1
    property int appIndex: -1
    property bool subOpen: false          // the apps popup is wanted
    property bool inApps: false           // the keys move in the apps list
    readonly property var shownApps: root.catIndex >= 0 && root.catIndex < root.groups.length ? root.groups[root.catIndex].apps : []
    readonly property bool subVisible: root.visible && root.subOpen && root.shownApps.length > 0

    property Item anchorItem: null
    property int anchorX: 0
    property int anchorY: 0

    grabFocus: true
    color: "transparent"
    anchor.item: root.anchorItem
    anchor.rect.x: root.anchorX
    anchor.rect.y: root.anchorY
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
    implicitWidth: MenuStyle.contextMenuMinWidth + 2 * MenuStyle.rowHeight
    implicitHeight: catColumn.implicitHeight + 2 * MenuStyle.frameInset

    // ---- pure logic ----
    function inCategory(entry, cat) {
        if (cat.cats.length === 0)
            return true;
        const ec = entry.categories || [];
        return cat.cats.some(x => ec.indexOf(x) !== -1);
    }

    function groupsOf(entries) {
        const shown = entries.filter(e => !LauncherState.isHidden(e.id));
        const out = [];
        for (const c of root.categories) {
            const apps = shown.filter(e => root.inCategory(e, c));
            if (apps.length > 0)
                out.push({ key: c.key, label: c.label, glyph: c.glyph, apps: apps });
        }
        return out;
    }

    // the list changed under an open cascade (an app was hidden, a different source): never point past its end
    onGroupsChanged: {
        if (root.catIndex >= root.groups.length) {
            root.catIndex = -1;
            root.appIndex = -1;
            root.inApps = false;
        }
        if (root.appIndex >= root.shownApps.length)
            root.appIndex = root.shownApps.length > 0 ? 0 : -1;
    }

    function hoverCat(i) {
        root.catIndex = i;
        root.appIndex = -1;
        root.inApps = false;
        root.subOpen = true;
    }

    function enterApps() {
        if (root.catIndex < 0 || root.shownApps.length === 0)
            return;
        root.subOpen = true;
        root.inApps = true;
        root.appIndex = 0;
    }

    function launch(i) {
        const entry = root.shownApps[i];
        if (!entry)
            return;
        LauncherState.bump(entry.id);
        entry.execute();
        root.close();
        root.closeCallback();
    }

    function move(dir) {
        if (root.inApps) {
            const n = root.shownApps.length;
            root.appIndex = (root.appIndex + dir + n) % n;
        } else {
            const n = root.groups.length;
            if (n === 0)
                return;
            const next = root.catIndex < 0 ? (dir > 0 ? 0 : n - 1) : (root.catIndex + dir + n) % n;
            root.catIndex = next;
            root.appIndex = -1;
        }
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            root.close();
        } else if (event.key === Qt.Key_Down) {
            root.move(1);
        } else if (event.key === Qt.Key_Up) {
            root.move(-1);
        } else if (event.key === Qt.Key_Right) {
            if (!root.inApps)
                root.enterApps();
        } else if (event.key === Qt.Key_Left) {
            if (root.inApps || root.subOpen) {
                root.inApps = false;
                root.appIndex = -1;
                root.subOpen = false;
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.inApps)
                root.launch(root.appIndex);
            else
                root.enterApps();
        } else {
            return;
        }
        event.accepted = true;
    }

    function openAt(item, x, y) {
        root.catIndex = -1;
        root.appIndex = -1;
        root.subOpen = false;
        root.inApps = false;
        root.anchorItem = item;
        root.anchorX = Math.round(x);
        root.anchorY = Math.round(y);
        root.visible = true;
        keys.forceActiveFocus();
    }

    function close() {
        root.visible = false;
        root.subOpen = false;
        root.inApps = false;
    }

    // the grab was lost (a click elsewhere): the apps list goes with it
    onVisibleChanged: if (!root.visible) {
        root.subOpen = false;
        root.inApps = false;
    }

    // ---- the category list ----
    Rectangle {
        id: catFrame
        anchors.fill: parent
        color: Config.colors.base
        border.width: 1
        border.color: Config.colors.outline

        Bevel {
            anchors.fill: parent
            anchors.margins: 1
        }

        // the empty edge: a click there closes the apps list
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.subOpen = false;
                root.inApps = false;
                root.appIndex = -1;
            }
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => root.handleKey(event)

            ColumnLayout {
                id: catColumn
                x: MenuStyle.frameInset
                y: MenuStyle.frameInset
                width: parent.width - 2 * MenuStyle.frameInset
                spacing: 0

                Repeater {
                    model: root.groups
                    MenuRow {
                        id: catRow
                        required property var modelData
                        required property int index
                        objectName: "cat-" + catRow.modelData.key
                        Layout.fillWidth: true
                        text: catRow.modelData.label
                        glyph: catRow.modelData.glyph
                        reserveIcon: true
                        trailing: ">"
                        hoverLit: false
                        selected: catRow.index === root.catIndex
                        focusPolicy: Qt.NoFocus
                        onHoveredChanged: if (hovered) root.hoverCat(catRow.index)
                        onClicked: root.hoverCat(catRow.index)
                    }
                }
            }
        }
    }

    // ---- the apps of the category ----
    PopupWindow {
        id: sub
        objectName: "sub"
        visible: root.subVisible
        color: "transparent"
        anchor.item: catFrame
        anchor.rect.x: 0
        anchor.rect.y: MenuStyle.frameInset + Math.max(0, root.catIndex) * MenuStyle.rowHeight
        anchor.rect.width: catFrame.width
        anchor.rect.height: MenuStyle.rowHeight
        anchor.edges: Edges.Right | Edges.Top
        anchor.gravity: Edges.Right | Edges.Bottom
        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        implicitWidth: MenuStyle.widthMedium
        implicitHeight: Math.min(MenuStyle.windowHeight, root.shownApps.length * MenuStyle.rowHeight) + 2 * MenuStyle.frameInset

        Rectangle {
            anchors.fill: parent
            color: Config.colors.base
            border.width: 1
            border.color: Config.colors.outline

            Bevel {
                anchors.fill: parent
                anchors.margins: 1
            }

            ListView {
                id: appList
                objectName: "apps"
                x: MenuStyle.frameInset
                y: MenuStyle.frameInset
                width: parent.width - 2 * MenuStyle.frameInset
                height: parent.height - 2 * MenuStyle.frameInset
                model: root.shownApps
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.appIndex
                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                ScrollBar.vertical: RetroScrollBar {}
                delegate: MenuRow {
                    id: appRow
                    required property var modelData
                    required property int index
                    objectName: "app-" + appRow.modelData.id
                    width: appList.width - appList.gutter
                    text: appRow.modelData.name
                    glyph: "\ue5c3"
                    iconSource: Utils.AppSearch.getIcon(appRow.modelData.icon)
                    reserveIcon: true
                    hoverLit: false
                    selected: appRow.index === root.appIndex
                    focusPolicy: Qt.NoFocus
                    onHoveredChanged: if (hovered) {
                        root.inApps = true;
                        root.appIndex = appRow.index;
                    }
                    onClicked: root.launch(appRow.index)
                }
            }
        }
    }
}
