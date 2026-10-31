import QtQuick
import ".."

// Bell + weather + clock: "12° | Sat 31 Oct | 14:05". Left click: the side panel; right click: Do Not
// Disturb on / off. The tooltip has the forecast (Weather.qml, wttr.in); the temperature is left out
// while there is no weather yet.
BarButton {
    // Bell, or bell-off while Do Not Disturb is on
    iconFontValue: Config.settings.notifications.dnd ? "\ue7f6" : "\ue7f4"
    toggledIconFontValue: ""
    label: (Weather.ok ? Weather.temp + "° | " : "") + Time.time
    tooltip: {
        const lines = [];
        if (Weather.ok) {
            lines.push(Weather.temp + Weather.unit + "  " + Weather.desc + (Weather.feels !== Weather.temp ? "  (feels " + Weather.feels + "°)" : "") + (Weather.place !== "" ? "  · " + Weather.place : ""));
            for (const d of Weather.days)
                lines.push(d.name + "  " + d.lo + "° / " + d.hi + "°  " + d.desc);
            lines.push("");
        }
        lines.push("Right click: Do Not Disturb " + (Config.settings.notifications.dnd ? "off" : "on"));
        return lines.join("\n");
    }
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
