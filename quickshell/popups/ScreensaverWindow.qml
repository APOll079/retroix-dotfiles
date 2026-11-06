import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// One screen of the screensaver: an Overlay-layer window over the whole screen (bar included) that takes the keyboard,
// so the wake key never reaches another program. Created and destroyed per run by ScreensaverState.qml. The look and
// the wake-up input are in ScreensaverView.qml.
PanelWindow {
    id: root

    property string style: "starfield"
    property real startedAt: 0
    property int graceMs: 500
    signal wake()

    color: Config.colors.outline
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-screensaver"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    ScreensaverView {
        anchors.fill: parent
        style: root.style
        startedAt: root.startedAt
        graceMs: root.graceMs
        onWake: root.wake()
    }
}
