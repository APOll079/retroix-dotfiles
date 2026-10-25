import QtQuick
import ".."

// Hover hint for a control: while the pointer is over the parent, the drawer's status bar shows `text`, and
// after a short rest a tooltip (SpotifyTooltip) shows it next to the control too.
// Put it inside the control: BevelButton { SpotifyHint { panel: ...; text: "Like" } }
// (a disabled control gets no pointer events: wrap it in a SpotifyReasonHost to say why it is disabled)
HoverHandler {
    id: hint
    required property var panel
    property string text: ""
    // the tooltip is for cut-off names and disabled controls; plain hints only go to the status bar
    property bool tooltip: false
    onHoveredChanged: {
        if (hovered && hint.text !== "") {
            panel.hint = hint.text;
            if (hint.tooltip)
                tipTimer.restart();
        } else if (!hovered) {
            if (panel.hint === hint.text)
                panel.hint = "";
            tipTimer.stop();
            if (panel.tip && panel.tip.item === hint.parent)
                panel.tip = null;
        }
    }
    // a hint that changes while the pointer is on it (Mute -> Unmute)
    onTextChanged: {
        if (hovered)
            panel.hint = hint.text;
    }
    // (a property, not a child: a handler has no default child list)
    property QtObject timer: Timer {
        id: tipTimer
        interval: MenuStyle.spotifyTipMs
        onTriggered: {
            if (hint.hovered && hint.text !== "")
                hint.panel.tip = { text: hint.text, item: hint.parent };
        }
    }
}
