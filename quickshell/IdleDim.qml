import QtQuick
import Quickshell
import Quickshell.Wayland

// Dims one screen while Idle.dimmed. Input passes straight through (empty mask), and any
// input ends idle, which removes the dim.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    visible: Idle.dimmed
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        anchors.fill: parent
        color: Config.colors.outline
        // Fades in over idleDimFade; when Idle.dimmed ends the window hides at once (input is never delayed)
        opacity: Idle.dimmed ? MenuStyle.idleDimOpacity : 0
        Behavior on opacity {
            enabled: MenuStyle.idleDimFade > 0
            NumberAnimation { duration: MenuStyle.idleDimFade; easing.type: Easing.InOutQuad }
        }
    }
}
