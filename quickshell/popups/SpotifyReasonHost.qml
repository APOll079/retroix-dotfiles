import QtQuick
import ".."

// Holds one control that can be disabled and says why while it is: a disabled control gets no hover, so the
// hint lives here, on the host. `reason` is empty while the control works (it has its own hint then).
//   SpotifyReasonHost { panel: ...; reason: noTrack ? "Nothing is playing" : ""; BevelButton { ... } }
Item {
    id: host
    required property var panel
    property string reason: ""
    default property alias content: host.data
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
    SpotifyHint { panel: host.panel; text: host.reason; tooltip: true }
}
