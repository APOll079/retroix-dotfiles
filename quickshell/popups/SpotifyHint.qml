import QtQuick

// Hover hint for a control: while the pointer is over the parent, the drawer's status bar shows `text`.
// Put it inside the control: BevelButton { SpotifyHint { panel: ...; text: "Like" } }
HoverHandler {
    id: hint
    required property var panel
    property string text: ""
    onHoveredChanged: {
        if (hovered && hint.text !== "")
            panel.hint = hint.text;
        else if (!hovered && panel.hint === hint.text)
            panel.hint = "";
    }
    // a hint that changes while the pointer is on it (Mute -> Unmute)
    onTextChanged: {
        if (hovered)
            panel.hint = hint.text;
    }
}
