import QtQuick
import QtQuick.Layouts

import ".."

// The top half of the win95 lock screen (LockScreen.qml): the "Locked" panel, kept low: one row with the
// big clock on the left and the date on the right, in a sunken well (like the tray clock) in a PopupWindowFrame. No avatar. The Win95 logon box
// (LoginDialog.qml) sits under it as its own whole window.
Item {
    id: root

    property date date: new Date()

    implicitWidth: MenuStyle.lockWidth
    implicitHeight: row.implicitHeight + 2 * MenuStyle.pad + MenuStyle.chromeTop + MenuStyle.chromeBottom
    width: implicitWidth
    height: implicitHeight

    PopupWindowFrame {
        windowTitle: "Locked"

        // the clock in a sunken well, like the taskbar tray clock
        SunkenField {
            id: well
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: row.implicitHeight + 2 * well.padding
            padding: MenuStyle.pad

        RowLayout {
            id: row
            anchors.fill: parent
            spacing: MenuStyle.space12

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.lockClockSize
                color: Config.colors.text
                text: Qt.formatDateTime(root.date, Config.settings.militaryTimeClockFormat ? "hh:mm" : "h:mm AP")
            }
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.searchFontSize
                color: Config.colors.text
                text: Qt.formatDateTime(root.date, "dddd, d MMMM yyyy")
            }
        }
        }
    }
}
