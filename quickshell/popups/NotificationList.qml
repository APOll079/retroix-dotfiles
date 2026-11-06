import Quickshell
import QtQuick
import Quickshell.Services.Notifications
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Notification history for the Home tab of the side panel. `active` is true while Home is showing.
// It takes all the height the panel has left and scrolls inside. One entry per notification, newest
// first: app and time, the title (16 px), the body wrapped to notificationBodyLines (the chevron
// shows the rest). A click opens it in its app while it is alive.
ColumnLayout {
    id: root
    property bool active: false
    spacing: MenuStyle.pad

    onActiveChanged: {
        if (active) NotificationStore.unread = 0
    }

    // Anything that arrives while this tab is showing counts as read
    Connections {
        target: NotificationStore
        function onUnreadChanged() {
            if (root.active && NotificationStore.unread > 0) NotificationStore.unread = 0
        }
    }

    // Today: "14:05"; older (the history keeps a week): "Thu 14:05"
    function timeText(t) {
        const today = new Date();
        const same = t.getFullYear() === today.getFullYear() && t.getMonth() === today.getMonth() && t.getDate() === today.getDate();
        return Qt.formatDateTime(t, same ? "hh:mm" : "ddd hh:mm");
    }

    // "Clear all" asks first (ConfirmBar in place of the header); Enter is the verb, Escape cancels
    property bool confirmClear: false
    function askClear() {
        root.confirmClear = true;
        root.forceActiveFocus();
    }
    function cancelClear() {
        root.confirmClear = false;
    }
    Keys.onPressed: event => {
        if (!root.confirmClear)
            return;
        if (event.key === Qt.Key_Escape)
            root.confirmBar.cancel();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            root.confirmBar.accept();
        else
            return;
        event.accepted = true;
    }
    // (the list may empty meanwhile: a confirm for nothing goes away)
    readonly property bool hasItems: NotificationStore.items.length > 0
    onHasItemsChanged: if (!root.hasItems) root.confirmClear = false
    readonly property var confirmBar: clearConfirm

    ConfirmBar {
        id: clearConfirm
        Layout.fillWidth: true
        visible: root.confirmClear
        message: "Clear all " + NotificationStore.items.length + (NotificationStore.items.length === 1 ? " notification?" : " notifications?")
        verb: "Clear all"
        onAccepted: {
            root.confirmClear = false;
            NotificationStore.clear();
        }
        onCanceled: root.cancelClear()
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !root.confirmClear
        spacing: MenuStyle.pad
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.fillWidth: true
            font.family: MenuStyle.titleFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: NotificationStore.items.length === 0 ? "Notifications" : NotificationStore.items.length + (NotificationStore.items.length === 1 ? " notification" : " notifications")
        }
        // Do Not Disturb (same switch as a right click on the bar clock): notifications still land
        // here, they just don't pop up. Sunken while on.
        BevelButton {
            id: dndButton
            Layout.preferredWidth: Math.max(dndButton.implicitWidth, clearButton.implicitWidth)
            text: "DND"
            glyph: Config.settings.notifications.dnd ? "\ue7f6" : "\ue7f4"
            checked: Config.settings.notifications.dnd
            onClicked: Config.settings.notifications.dnd = !Config.settings.notifications.dnd
        }
        BevelButton {
            id: clearButton
            Layout.preferredWidth: Math.max(dndButton.implicitWidth, clearButton.implicitWidth)
            text: "Clear all"
            visible: NotificationStore.items.length > 0
            onClicked: root.askClear()
        }
    }

    // Apps whose toasts are switched off (right-click a toast > Don't show toasts from ...): this button shows while
    // there are any and opens the list; picking one unmutes it. Their notifications still land in the history.
    BevelButton {
        id: mutedButton
        objectName: "mutedButton"
        Layout.fillWidth: true
        visible: !root.confirmClear && NotificationStore.mutedApps.length > 0
        text: "Muted apps (" + NotificationStore.mutedApps.length + ")"
        glyph: "\ue7f6"
        focusPolicy: Qt.NoFocus
        onClicked: root.openMutedMenu()
    }
    // the model of the list: one entry per muted app, picking it unmutes
    function mutedEntries(apps) {
        return Array.from(apps || []).map(a => ({ text: "Unmute " + a, glyph: "\ue7f6", action: () => NotificationStore.unmuteApp(a) }));
    }
    function openMutedMenu() {
        mutedMenu.model = root.mutedEntries(NotificationStore.mutedApps);
        mutedMenu.openAt(mutedButton, 0, mutedButton.height);
    }
    readonly property var mutedMenuItem: mutedMenu
    PopupMenu {
        id: mutedMenu
    }

    // The history filter (the box under the header): matches app name, title and body, case-insensitive
    property string query: ""
    // Pure: the entries of `items` that match `query`, in their order. An empty query returns `items` itself.
    function filterItems(items, query) {
        const q = String(query || "").trim().toLowerCase();
        if (q === "")
            return items;
        const has = v => String(v || "").toLowerCase().indexOf(q) >= 0;
        return items.filter(e => has(e.appName) || has(e.summary) || has(e.body));
    }
    readonly property var shown: root.filterItems(NotificationStore.items, root.query)

    property var expanded: ({})          // entry key -> true while its whole body shows
    property var replyTo: null           // history entry whose reply box is open

    function toggleExpanded(key) {
        const x = Object.assign({}, root.expanded);
        x[key] = !x[key];
        root.expanded = x;
    }

    function iconFor(e) {
        if (e.image)
            return e.image;
        return e.appIcon ? Quickshell.iconPath(e.appIcon, true) : "";
    }

    SearchBox {
        id: filterBox
        objectName: "filterBox"
        Layout.fillWidth: true
        visible: NotificationStore.items.length > 0
        placeholder: "Search notifications"
        onTextChanged: root.query = text
        // Escape clears the text (SearchBox); on an empty box it hands the keyboard back, as in the Calendar tab
        onEscaped: filterBox.input.focus = false
    }

    EmptyState {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: NotificationStore.items.length === 0
        glyph: "\ue7f4"
        text: "No notifications"
    }

    // The list sits in a deep well (darker field, 2 px sunken bevel). Each notification is a small
    // raised window on it: an inactive title bar (icon, app, time, like the toasts) that lights up in
    // the accent on hover, like a window getting focus, then the title and the body.
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: NotificationStore.items.length > 0
        color: MenuStyle.notificationWell
        border.width: 1
        border.color: Config.colors.outline
        Bevel {
            anchors.fill: parent
            anchors.margins: 1
            raised: false
        }

        EmptyState {
            objectName: "noMatches"
            anchors.fill: parent
            visible: root.shown.length === 0
            glyph: "\ue8b6"
            text: "No matches"
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: MenuStyle.frameInset
            model: root.shown
            clip: true
            spacing: MenuStyle.pad
            topMargin: MenuStyle.pad
            bottomMargin: MenuStyle.pad
            boundsBehavior: Flickable.StopAtBounds
            // The quiet end of the history
            footer: Item {
                width: list.width - list.barRoom
                visible: root.shown.length > 0
                height: visible ? MenuStyle.rowHeight + MenuStyle.pad : 0
                RetroText {
                    anchors.centerIn: parent
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: Config.colors.base
                    text: "No older notifications"
                }
            }
            // Floats over the right edge: the cards give it room while it shows (content overflows)
            ScrollBar.vertical: RetroScrollBar { id: listBar }
            readonly property int barRoom: listBar.visible ? MenuStyle.scrollBarWidth : 0
            delegate: Item {
                id: row
                required property var modelData
                readonly property var entry: modelData
                readonly property bool canReply: entry.notif !== null && entry.notif.hasInlineReply
                readonly property real progress: NotificationStore.progressOf(entry.notif)
                readonly property bool open: root.expanded[entry.key] === true
                readonly property bool lit: rowMouse.containsMouse || expandButton.hovered || replyButton.hovered
                readonly property color barInk: lit ? MenuStyle.selectText : Config.colors.text
                x: MenuStyle.pad
                width: list.width - 2 * MenuStyle.pad - list.barRoom
                height: card.height

                Rectangle {
                    id: card
                    width: parent.width
                    height: cardColumn.implicitHeight + 2 * MenuStyle.notificationCardInset
                    color: Config.colors.base
                    border.width: 1
                    border.color: Config.colors.outline
                    Bevel {
                        anchors.fill: parent
                        anchors.margins: 1
                        raised: true
                    }

                    // Left-click opens the notification in its app (default action) while it is alive;
                    // right-click removes it from the history without opening it
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                NotificationStore.remove(row.entry.key);
                            else
                                NotificationStore.open(row.entry.key);
                        }
                    }

                    ColumnLayout {
                        id: cardColumn
                        x: MenuStyle.notificationCardInset
                        y: MenuStyle.notificationCardInset
                        width: card.width - 2 * MenuStyle.notificationCardInset
                        spacing: 0

                        // Title bar: icon, app, time (or progress)
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: MenuStyle.titleHeight
                            color: row.lit ? MenuStyle.selectBar : Config.colors.shadow
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: MenuStyle.gap
                                anchors.rightMargin: MenuStyle.gap
                                spacing: MenuStyle.titleIconGap
                                // The notification's image or app icon, else a bell (critical: a warning sign)
                                Item {
                                    Layout.preferredWidth: MenuStyle.iconSize
                                    Layout.preferredHeight: MenuStyle.iconSize
                                    Image {
                                        id: icon
                                        anchors.fill: parent
                                        visible: status === Image.Ready
                                        asynchronous: true
                                        smooth: false
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize.width: MenuStyle.iconSize
                                        sourceSize.height: MenuStyle.iconSize
                                        source: root.iconFor(row.entry)
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        anchors.centerIn: parent
                                        visible: icon.status !== Image.Ready
                                        font.family: MenuStyle.iconFont
                                        font.pixelSize: MenuStyle.iconSize
                                        color: row.barInk
                                        text: row.entry.urgency === NotificationUrgency.Critical ? "\ue000" : "\ue7f4"
                                    }
                                }
                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.family: MenuStyle.titleFont
                                    font.pixelSize: MenuStyle.fontSize
                                    font.bold: true
                                    color: row.barInk
                                    textFormat: Text.PlainText
                                    text: row.entry.appName || "Unknown"
                                }
                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    color: row.barInk
                                    text: row.progress >= 0 ? Math.round(row.progress) + "%" : root.timeText(row.entry.time)
                                }
                            }
                        }

                        // Inside the window: title, body, progress; chevron / reply on the right
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.margins: MenuStyle.boxPadH
                            visible: row.entry.summary !== "" || row.entry.body !== "" || row.progress >= 0 || row.canReply
                            spacing: MenuStyle.pad

                            ColumnLayout {
                                // Exactly the room the button column leaves, whatever it holds
                                Layout.preferredWidth: cardColumn.width - 2 * MenuStyle.boxPadH - expandButton.implicitWidth - MenuStyle.pad
                                Layout.alignment: Qt.AlignTop
                                spacing: MenuStyle.space2
                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    elide: Text.ElideRight
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.notificationTitleSize
                                    color: Config.colors.text
                                    textFormat: Text.PlainText
                                    text: row.entry.summary
                                }
                                Text {
                                    id: bodyText
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    maximumLineCount: row.open ? MenuStyle.notificationExpandedLines : MenuStyle.notificationBodyLines
                                    elide: Text.ElideRight
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    color: Config.colors.text
                                    textFormat: Text.PlainText
                                    text: row.entry.body
                                }
                                // Progress (downloads, copies): the "value" hint, 0-100
                                SegmentBar {
                                    Layout.fillWidth: true
                                    visible: row.progress >= 0
                                    implicitHeight: MenuStyle.rowHeight - 6
                                    value: row.progress / 100
                                }
                            }

                            // Show the whole body / fold it back; reply (apps that offer it)
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: expandButton.implicitWidth
                                spacing: MenuStyle.gap
                                BevelButton {
                                    id: expandButton
                                    visible: bodyText.truncated || row.open
                                    glyph: row.open ? "\ue5ce" : "\ue5cf"
                                    focusPolicy: Qt.NoFocus
                                    onClicked: root.toggleExpanded(row.entry.key)
                                }
                                BevelButton {
                                    id: replyButton
                                    visible: row.canReply
                                    glyph: "\ue15e"
                                    focusPolicy: Qt.NoFocus
                                    onClicked: {
                                        root.replyTo = row.entry;
                                        historyReply.text = "";
                                        historyReply.focusInput();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Reply to a history notification (apps that offer it); Enter sends, Escape cancels
    SearchBox {
        id: historyReply
        Layout.fillWidth: true
        visible: root.replyTo !== null && root.replyTo.notif !== null
        showIcon: false
        placeholder: root.replyTo ? "Reply to " + root.replyTo.summary : ""
        onEscaped: root.replyTo = null
        onKeyPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                NotificationStore.reply(root.replyTo.notif, historyReply.text);
                root.replyTo = null;
                event.accepted = true;
            }
        }
    }
}
