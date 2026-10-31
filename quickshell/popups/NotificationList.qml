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

    RowLayout {
        Layout.fillWidth: true
        spacing: MenuStyle.pad
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.fillWidth: true
            font.family: MenuStyle.titleFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: NotificationStore.items.length === 0 ? "No notifications" : NotificationStore.items.length + (NotificationStore.items.length === 1 ? " notification" : " notifications")
        }
        // Do Not Disturb: notifications still land here, they just don't pop up
        BevelButton {
            text: "DND"
            glyph: Config.settings.notifications.dnd ? "\ue7f6" : "\ue7f4"
            checked: Config.settings.notifications.dnd
            onClicked: Config.settings.notifications.dnd = !Config.settings.notifications.dnd
        }
        BevelButton {
            text: "Clear all"
            visible: NotificationStore.items.length > 0
            onClicked: NotificationStore.clear()
        }
    }

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

    SunkenField {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: NotificationStore.items.length > 0
        padding: 2
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            model: NotificationStore.items
            clip: true
            spacing: MenuStyle.gap
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator {
                active: list.moving
            }
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property var entry: modelData
                readonly property bool canReply: entry.notif !== null && entry.notif.hasInlineReply
                readonly property real progress: NotificationStore.progressOf(entry.notif)
                readonly property bool open: root.expanded[entry.key] === true
                // Rows hover as a solid accent bar with inverted text, like MenuRow
                readonly property bool lit: rowMouse.containsMouse || expandButton.hovered || replyButton.hovered
                readonly property color ink: lit ? MenuStyle.selectText : Config.colors.text
                readonly property color dimInk: lit ? MenuStyle.selectText : MenuStyle.bevelDark
                width: list.width
                height: content.implicitHeight + 2 * MenuStyle.gap
                color: lit ? MenuStyle.selectBar : "transparent"

                // A click opens the notification in its app (default action) while it is alive
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationStore.open(row.entry.key)
                }

                RowLayout {
                    id: content
                    x: MenuStyle.pad
                    y: MenuStyle.gap
                    width: parent.width - 2 * MenuStyle.pad
                    spacing: MenuStyle.pad

                    // The notification's image or app icon, else a bell (critical: a warning sign)
                    Item {
                        Layout.preferredWidth: MenuStyle.notificationIconSize
                        Layout.preferredHeight: MenuStyle.notificationIconSize
                        Layout.alignment: Qt.AlignTop
                        Image {
                            id: icon
                            anchors.fill: parent
                            visible: status === Image.Ready
                            asynchronous: true
                            smooth: false
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: MenuStyle.notificationIconSize
                            sourceSize.height: MenuStyle.notificationIconSize
                            source: root.iconFor(row.entry)
                        }
                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            anchors.centerIn: parent
                            visible: icon.status !== Image.Ready
                            font.family: MenuStyle.iconFont
                            font.pixelSize: MenuStyle.iconSize
                            color: row.ink
                            text: row.entry.urgency === NotificationUrgency.Critical ? "\ue000" : "\ue7f4"
                        }
                    }

                    ColumnLayout {
                        // Exactly the room the icon and the button column leave, whatever it holds (also
                        // only the app line: no title, no body), so the time always sits at the right edge
                        Layout.preferredWidth: content.width - MenuStyle.notificationIconSize - expandButton.implicitWidth - 2 * content.spacing
                        Layout.alignment: Qt.AlignTop
                        spacing: 2

                        // App on the left, time (or progress) on the right
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: MenuStyle.pad
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.family: MenuStyle.titleFont
                                font.pixelSize: MenuStyle.fontSize
                                color: row.dimInk
                                textFormat: Text.PlainText
                                text: row.entry.appName || "Unknown"
                            }
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: row.dimInk
                                text: row.progress >= 0 ? Math.round(row.progress) + "%" : root.timeText(row.entry.time)
                            }
                        }
                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            Layout.fillWidth: true
                            visible: text !== ""
                            elide: Text.ElideRight
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.notificationTitleSize
                            color: row.ink
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
                            color: row.ink
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

                    // Show the whole body / fold it back; reply (apps that offer it). The column keeps
                    // its width on every row, so the times line up.
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
