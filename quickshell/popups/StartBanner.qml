import QtQuick
import QtQuick.Layouts

import ".."

// The Win95 "Windows 95" side banner: a vertical accent stripe with the current theme's name written up it
// (bold, selectText on selectBar). Down the left of the Start menu and the launcher.
Rectangle {
    id: root

    readonly property string themeName: {
        const t = Config.settings.currentTheme || "";
        return t.charAt(0).toUpperCase() + t.slice(1);
    }

    Layout.preferredWidth: MenuStyle.bannerWidth
    Layout.fillHeight: true
    color: MenuStyle.selectBar

    Text {
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        rotation: -90
        transformOrigin: Item.TopLeft
        x: Math.round((parent.width - implicitHeight) / 2)
        y: parent.height - MenuStyle.pad
        font.family: MenuStyle.titleFont
        font.pixelSize: MenuStyle.iconSize
        font.bold: true
        color: MenuStyle.selectText
        textFormat: Text.PlainText
        text: root.themeName
    }
}
