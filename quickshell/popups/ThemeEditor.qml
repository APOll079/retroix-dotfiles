import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
import "../theme/themecolors.js" as TC

// The theme editor (Themes > Edit theme...): the eight palette roles of theme/themes.json, each with a swatch, a hex field
// (#rrggbb) and a Pick button (scripts/colorpick.sh, hyprpicker). Under them the live contrast lines, with the same numbers
// and formulas as theme/apply.py (theme/themecolors.js): a failing line says what apply.py would refuse. Starts from the
// current theme's colours.
//   Save   writes custom-theme.json (state dir) when every role is a colour; it may fail the contrast rules.
//   Apply  saves and makes "custom" the current theme. Off while apply.py would refuse the palette (the status line says why).
//   Reset  back to the current theme's colours.        Close / Escape / a click outside closes.
// The "custom" palette is read from that file by Config.qml exactly like "wallpaper" from wallpaper-theme.json.
// An Overlay-layer panel, not a popup of the bar (see ServicesPanel).
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    // The command behind a Pick button; empty (nothing runs) under QS_NO_APPLY unless a test sets it
    property var pickCommand: root.live ? ["sh", Quickshell.shellDir + "/scripts/colorpick.sh"] : []
    property string pickRole: ""
    property var pickLog: []
    readonly property string statePath: Quickshell.statePath("custom-theme.json")

    // role -> the text in its field
    property var texts: ({})
    property string note: ""
    property string noteKind: "state"

    // the valid colours typed so far (lower-case #rrggbb), the contrast lines and what keeps Apply off
    readonly property var valid: {
        const o = {};
        for (const k of TC.ROLES) {
            const v = TC.normalise(root.texts[k] || "");
            if (v !== "")
                o[k] = v;
        }
        return o;
    }
    readonly property var missing: TC.missingRoles(root.valid)
    readonly property var rows: TC.checkRows(root.valid)
    readonly property var blockers: TC.blockers(root.valid)
    readonly property bool canSave: root.missing.length === 0
    readonly property bool canApply: root.canSave && root.blockers.length === 0
    readonly property string why: root.missing.length > 0 ? root.missing[0] + " is not a #rrggbb colour" : (root.blockers.length > 0 ? root.blockers[0] : "")

    readonly property var roleLabels: ({
        base: "Base (face)", shadow: "Shadow", highlight: "Highlight", urgent: "Urgent", accent: "Accent",
        text: "Text", outline: "Outline", outlineGradientFade: "Outline fade"
    })

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: false
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.closeCallback()
    }

    Item {
        id: frame
        width: MenuStyle.widthLarge
        height: content.implicitHeight + MenuStyle.chromeTop + MenuStyle.chromeBottom
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.screenHeight / 2 - height / 2)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupWindowFrame {
            windowTitle: "Edit theme"
            windowTitleIcon: "\ue40a"

            ColumnLayout {
                id: content
                anchors.fill: parent
                spacing: MenuStyle.pad

                FocusScope {
                    id: keys
                    Layout.preferredWidth: 0
                    Layout.preferredHeight: 0
                    focus: true
                    Keys.onPressed: event => root.handleKey(event)
                }

                GroupFrame {
                    Layout.fillWidth: true
                    title: "Colours"

                    Repeater {
                        model: TC.ROLES
                        RowLayout {
                            id: roleRow
                            required property string modelData
                            readonly property string shown: TC.normalise(root.texts[roleRow.modelData] || "")
                            objectName: "role-" + roleRow.modelData
                            Layout.fillWidth: true
                            spacing: MenuStyle.pad

                            Rectangle {
                                objectName: "swatch"
                                Layout.preferredWidth: MenuStyle.iconSizeLarge
                                Layout.preferredHeight: MenuStyle.iconSizeLarge
                                color: roleRow.shown !== "" ? roleRow.shown : "transparent"
                                border.width: 1
                                border.color: Config.colors.outline
                            }
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                Layout.preferredWidth: MenuStyle.rowHeight * 5
                                elide: Text.ElideRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: Config.colors.text
                                textFormat: Text.PlainText
                                text: root.roleLabels[roleRow.modelData]
                            }
                            SearchBox {
                                objectName: "hex"
                                Layout.fillWidth: true
                                Layout.preferredHeight: MenuStyle.rowHeight + MenuStyle.gap
                                implicitHeight: MenuStyle.rowHeight + MenuStyle.gap
                                showIcon: false
                                placeholder: "#rrggbb"
                                text: root.texts[roleRow.modelData] || ""
                                onEdited: root.setText(roleRow.modelData, text)
                                onKeyPressed: event => {
                                    if (event.key === Qt.Key_Escape) {
                                        root.closeCallback();
                                        event.accepted = true;
                                    }
                                }
                            }
                            BevelButton {
                                objectName: "pick"
                                text: "Pick"
                                focusPolicy: Qt.NoFocus
                                onClicked: root.pick(roleRow.modelData)
                            }
                        }
                    }
                }

                GroupFrame {
                    Layout.fillWidth: true
                    title: "Contrast"

                    Repeater {
                        model: root.rows
                        RowLayout {
                            id: ruleRow
                            required property var modelData
                            objectName: "rule-" + ruleRow.modelData.key
                            Layout.fillWidth: true
                            spacing: MenuStyle.pad

                            Text {
                                objectName: "mark"
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                font.family: MenuStyle.iconFont
                                font.pixelSize: MenuStyle.iconSize
                                color: ruleRow.modelData.ok ? Config.colors.text : Config.colors.urgent
                                text: ruleRow.modelData.ok ? "\ue5ca" : "\ue5cd"
                            }
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: ruleRow.modelData.ok ? Config.colors.text : Config.colors.urgent
                                textFormat: Text.PlainText
                                text: ruleRow.modelData.label
                            }
                            Text {
                                objectName: "ratio"
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: ruleRow.modelData.ok ? Config.colors.text : Config.colors.urgent
                                textFormat: Text.PlainText
                                text: ruleRow.modelData.value.toFixed(2) + ":1 (needs " + ruleRow.modelData.min + ")"
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap

                    BevelButton {
                        objectName: "save"
                        Layout.fillWidth: true
                        text: "Save"
                        glyph: "\ue161"
                        enabled: root.canSave
                        focusPolicy: Qt.NoFocus
                        onClicked: root.save()
                    }
                    BevelButton {
                        objectName: "apply"
                        Layout.fillWidth: true
                        text: "Apply"
                        glyph: "\ue86c"
                        enabled: root.canApply
                        focusPolicy: Qt.NoFocus
                        onClicked: root.apply()
                    }
                    BevelButton {
                        objectName: "reset"
                        Layout.fillWidth: true
                        text: "Reset"
                        glyph: "\ue5d5"
                        focusPolicy: Qt.NoFocus
                        onClicked: root.reset()
                    }
                    BevelButton {
                        objectName: "close"
                        Layout.fillWidth: true
                        text: "Close"
                        focusPolicy: Qt.NoFocus
                        onClicked: root.closeCallback()
                    }
                }

                StatusBar {
                    objectName: "status"
                    kind: root.note !== "" ? root.noteKind : (root.why !== "" ? "error" : "state")
                    text: root.note !== "" ? root.note : (root.why !== "" ? "Apply is off: " + root.why : "Every rule passes")
                }
            }
        }
    }

    // custom-theme.json: Config.qml reads it as the "custom" palette. Plain GuardedFileView (no adapter): save(text) writes
    // it, a missing file stays missing until the first Save, a broken one is kept as .bad-<time> and not overwritten.
    GuardedFileView {
        id: file
        path: root.statePath
        printErrors: false
    }

    Process {
        id: picker
        command: root.pickCommand
        stdout: StdioCollector {
            onStreamFinished: {
                const c = TC.normalise(text);
                if (c !== "" && root.pickRole !== "")
                    root.setText(root.pickRole, c);
                else
                    root.say("No colour picked", "state");
            }
        }
    }

    // --- actions ---

    function say(text, kind) {
        root.note = text;
        root.noteKind = kind || "message";
    }

    function setText(role, value) {
        const o = Object.assign({}, root.texts);
        o[role] = value;
        root.texts = o;
        root.note = "";
    }

    function pick(role) {
        root.pickRole = role;
        if (root.pickCommand.length === 0) {
            root.pickLog = root.pickLog.concat([role]);
            return;
        }
        root.say("Pick a colour on the screen...", "state");
        picker.running = true;
    }

    function reset() {
        root.texts = TC.startingPalette(Config.colors);
        root.note = "";
    }

    function save() {
        if (!root.canSave)
            return false;
        if (!file.save(JSON.stringify(TC.toFile(root.valid), null, 2) + "\n")) {
            root.say("custom-theme.json could not be read, so it was not overwritten", "error");
            return false;
        }
        root.say("Saved custom-theme.json", "message");
        return true;
    }

    function apply() {
        if (!root.canApply)
            return;
        if (!root.save())
            return;
        Config.settings.currentTheme = "custom";
        root.say("Applied: the current theme is now custom", "message");
    }

    function handleKey(event) {
        if (event.key !== Qt.Key_Escape)
            return;
        root.closeCallback();
        event.accepted = true;
    }

    function openMenu() {
        root.reset();
        root.visible = true;
        keys.forceActiveFocus();
    }

    function closeMenu() {
        root.visible = false;
        root.note = "";
    }
}
