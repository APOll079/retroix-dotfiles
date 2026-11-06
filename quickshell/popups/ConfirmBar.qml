import QtQuick
import QtQuick.Layouts

import ".."

// The one confirm template, shown in place of the row or button that asked: an optional warning glyph,
// the question on the left, Cancel and the verb on the right. The verb ("Reboot", "End task", "Forget",
// never Yes / No) is the default button (Win95's extra outline ring): it is what Enter does. The host keeps
// its own keys and calls accept() / cancel(); clicking the buttons does the same. A long question wraps
// (never cut: it is the thing being asked).
RowLayout {
    id: root

    property string message: ""
    property string verb: ""
    property string cancelText: "Cancel"
    property string glyph: ""
    property bool verbEnabled: true

    signal accepted()
    signal canceled()

    function accept() {
        if (root.verbEnabled)
            root.accepted();
    }
    function cancel() {
        root.canceled();
    }

    spacing: MenuStyle.gap

    RetroText {
        visible: root.glyph !== ""
        Layout.alignment: Qt.AlignVCenter
        font.family: MenuStyle.iconFont
        font.pixelSize: MenuStyle.iconSizeLarge
        color: Config.colors.urgent
        text: root.glyph
    }
    RetroText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: root.glyph === "" ? MenuStyle.space2 : 0
        wrapMode: Text.Wrap
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        text: root.message
    }
    BevelButton {
        text: root.cancelText
        focusPolicy: Qt.NoFocus
        onClicked: root.cancel()
    }
    BevelButton {
        text: root.verb
        isDefault: true
        enabled: root.verbEnabled
        focusPolicy: Qt.NoFocus
        onClicked: root.accept()
    }
}
