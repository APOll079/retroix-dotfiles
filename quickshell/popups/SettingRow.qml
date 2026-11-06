import QtQuick
import QtQuick.Controls.Basic

import ".."
import "SettingsSchema.js" as Schema

// One row of the Settings tab: label + hint on the left, the control for the entry's type on the right.
//   entry     a SettingsSchema entry; settings  the object holding the values (Config.settings, or a fixture)
//   themeNames the keys offered by a choice with choicesFrom: "themes"
// bool = On / Off button; int = digits field, refuses out-of-range text (message, not written); string = field;
// list = comma-separated field; choice = a button per value; json-note = "Edit in settings.json".
// Fields save on Enter and when they lose focus, only if the text changed; Escape reverts the text, and with
// nothing to revert emits escaped(). `message` (+ messageIsError) is what the view shows in its StatusBar.
Item {
    id: root

    property var entry: ({})
    property var settings: null
    property var themeNames: []
    property string message: ""
    property bool messageIsError: false

    signal written(string path, bool restart)
    signal refused(string text)
    signal escaped()

    readonly property string type: entry.type || ""
    readonly property var current: settings ? Schema.valueOf(settings, entry.path) : undefined
    readonly property string fieldText: Schema.toText(entry, current)
    readonly property bool isField: type === "int" || type === "string" || type === "list"
    readonly property var choices: entry.choices ? entry.choices : (entry.choicesFrom === "themes" ? themeNames : [])
    // label column ~42% of the row; the control gets the rest
    readonly property int labelWidth: Math.round(width * 0.42)
    readonly property int controlHeight: MenuStyle.rowHeight + MenuStyle.gap

    implicitHeight: Math.max(((entry.hint || "") !== "" ? MenuStyle.rowHeight * 3 / 2 : MenuStyle.rowHeight) + MenuStyle.gap,
                             (type === "choice" ? flow.implicitHeight : controlHeight) + MenuStyle.gap)
    height: implicitHeight

    function write(value) {
        if (!Schema.setValue(root.settings, entry.path, value)) {
            root.messageIsError = true;
            root.message = "Could not save " + entry.label;
            root.refused(root.message);
            return;
        }
        root.messageIsError = false;
        root.message = entry.restart ? "Saved " + entry.label + ": applies after a Quickshell restart" : "Saved " + entry.label;
        root.written(entry.path, entry.restart === true);
    }

    function revert() {
        input.text = root.fieldText;
    }

    // Enter / focus loss: save the text if it changed and parses
    function commit(leaving) {
        if (!root.isField || input.text === root.fieldText)
            return;
        const r = Schema.fromText(entry, input.text);
        if (!r.ok) {
            root.messageIsError = true;
            root.message = entry.label + ": " + r.message;
            root.refused(root.message);
            if (leaving)
                root.revert();
            return;
        }
        if (Schema.sameValue(r.value, root.current)) {
            root.revert();
            return;
        }
        root.write(r.value);
        root.revert();
    }

    // The first control that takes keyboard focus (the view's focusFirst)
    function focusFirstControl(): bool {
        if (root.isField) {
            input.forceActiveFocus();
            return true;
        }
        const target = root.type === "bool" ? toggle : (root.type === "choice" && repeater.count > 0 ? repeater.itemAt(0) : null);
        if (!target)
            return false;
        target.forceActiveFocus();
        return true;
    }

    onFieldTextChanged: if (!input.activeFocus) root.revert()
    Component.onCompleted: root.revert()

    Column {
        anchors.left: parent.left
        anchors.leftMargin: MenuStyle.pad
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelWidth - MenuStyle.pad
        RetroText {
            width: parent.width
            elide: Text.ElideRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            text: root.entry.label || ""
        }
        Text {
            width: parent.width
            visible: (root.entry.hint || "") !== ""
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            font.hintingPreference: Font.PreferFullHinting
            elide: Text.ElideRight
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: MenuStyle.bevelDark   // the shell's quiet-text colour (shadow itself is only 1.5:1 on the base)
            text: root.entry.hint || ""
        }
    }

    BevelButton {
        id: toggle
        visible: root.type === "bool"
        anchors.left: parent.left
        anchors.leftMargin: root.labelWidth
        anchors.verticalCenter: parent.verticalCenter
        checked: root.current === true
        text: checked ? "On" : "Off"
        onClicked: root.write(!(root.current === true))
    }

    Flow {
        id: flow
        visible: root.type === "choice"
        anchors.left: parent.left
        anchors.leftMargin: root.labelWidth
        anchors.right: parent.right
        anchors.rightMargin: MenuStyle.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: MenuStyle.gap
        Repeater {
            id: repeater
            model: root.type === "choice" ? root.choices : []
            delegate: BevelButton {
                required property var modelData
                checked: root.current === modelData
                text: String(modelData)
                onClicked: root.write(modelData)
            }
        }
    }

    SunkenField {
        visible: root.isField
        anchors.left: parent.left
        anchors.leftMargin: root.labelWidth
        anchors.right: parent.right
        anchors.rightMargin: MenuStyle.pad
        anchors.verticalCenter: parent.verticalCenter
        height: root.controlHeight
        padding: MenuStyle.space4
        TextField {
            id: input
            anchors.fill: parent
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            font.family: MenuStyle.bodyFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            selectionColor: Config.colors.shadow
            selectedTextColor: Config.colors.text
            selectByMouse: true
            padding: 0
            verticalAlignment: Text.AlignVCenter
            background: Item {}
            // an int field takes digits only (and a leading minus when the range goes below 0)
            validator: RegularExpressionValidator {
                regularExpression: root.type === "int" ? ((root.entry.min !== undefined && root.entry.min < 0) ? /-?\d*/ : /\d*/) : /.*/
            }
            onAccepted: root.commit(false)
            onActiveFocusChanged: if (!activeFocus) root.commit(true)
            Keys.onPressed: event => {
                if (event.key !== Qt.Key_Escape)
                    return;
                event.accepted = true;
                if (input.text !== root.fieldText) {
                    root.revert();
                    root.message = "";
                    root.messageIsError = false;
                } else {
                    root.escaped();
                }
            }
        }
    }

    RetroText {
        visible: root.type === "json-note"
        anchors.left: parent.left
        anchors.leftMargin: root.labelWidth
        anchors.right: parent.right
        anchors.rightMargin: MenuStyle.pad
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        color: MenuStyle.bevelDark
        text: "Edit in settings.json"
    }
}
