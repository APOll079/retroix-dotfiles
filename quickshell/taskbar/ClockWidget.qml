import QtQuick
import ".."

// Bell + weather + clock: "12°C | Sat 31 Oct | 14:05". Left click: the side panel; right click: Do Not
// Disturb on / off. The temperature (Weather.qml, wttr.in) is left out while there is no weather yet.
BarButton {
    // Bell, or bell-off while Do Not Disturb is on
    iconFontValue: Config.settings.notifications.dnd ? "\ue7f6" : "\ue7f4"
    toggledIconFontValue: ""
    label: (Weather.ok ? Weather.temp + Weather.unit + " | " : "") + Time.time
    onRightClicked: Config.settings.notifications.dnd = !Config.settings.notifications.dnd

    // Unread marker on the bell
    Rectangle {
        visible: NotificationStore.unread > 0
        x: MenuStyle.unreadDotX
        y: MenuStyle.unreadDotY
        width: MenuStyle.unreadDotSize
        height: MenuStyle.unreadDotSize
        color: Config.colors.urgent
        border.width: 1
        border.color: Config.colors.outline
    }
}
