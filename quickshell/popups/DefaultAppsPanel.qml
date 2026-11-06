import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Default applications (Start > Default apps), centred like Services: for the web browser, image viewer, video player, file manager
// and text editor, the current default and the installed applications that can take over, with a Make default button on each.
// Data and the only writes: DefaultApps.qml / scripts/defaultapps.sh. Up / Down move between applications, Enter = Make default,
// Escape, a click outside or the Start row again close. Nothing changes until Make default is clicked.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    property int cursor: -1                 // index into DefaultApps.rows, -1 = none
    readonly property int listRows: 12
    readonly property var current: root.cursor >= 0 ? DefaultApps.rows[root.cursor] || null : null

    // An Overlay-layer panel, not a popup of the bar (see ServicesPanel)
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

    Connections {
        target: DefaultApps
        function onRowsChanged() {
            const p = DefaultApps.pickable(DefaultApps.rows);
            if (root.cursor >= DefaultApps.rows.length || p.indexOf(root.cursor) < 0)
                root.cursor = p.length > 0 ? p[0] : -1;
        }
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
            windowTitle: "Default apps"
            windowTitleIcon: "\ue8b8"

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

                SunkenField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: MenuStyle.rowHeight * root.listRows + 2 * padding
                    padding: 2
                    clip: true

                    EmptyState {
                        anchors.fill: parent
                        visible: DefaultApps.rows.length === 0
                        glyph: DefaultApps.loaded ? "\ue8b6" : "\ue88b"
                        text: DefaultApps.loaded ? "No applications found" : "Reading..."
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        model: DefaultApps.rows
                        currentIndex: root.cursor
                        onCurrentIndexChanged: positionViewAtIndex(Math.max(0, currentIndex), ListView.Contain)
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                        ScrollBar.vertical: RetroScrollBar {}
                        delegate: Item {
                            id: entry
                            required property int index
                            required property var modelData
                            width: list.width - list.gutter
                            height: MenuStyle.rowHeight

                            // Head row: the kind and what it is now
                            RowLayout {
                                visible: entry.modelData.head
                                anchors.fill: parent
                                anchors.leftMargin: MenuStyle.pad
                                anchors.rightMargin: MenuStyle.pad
                                spacing: MenuStyle.gap
                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    textFormat: Text.PlainText
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    font.bold: true
                                    color: Config.colors.text
                                    text: entry.modelData.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: MenuStyle.widthSmall
                                    font.family: MenuStyle.bodyFont
                                    font.pixelSize: MenuStyle.fontSize
                                    color: MenuStyle.bevelDark
                                    text: entry.modelData.sub
                                }
                            }

                            // Application row: name, id, and the button
                            RowLayout {
                                visible: !entry.modelData.head
                                anchors.fill: parent
                                spacing: MenuStyle.gap
                                MenuRow {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    hoverLit: false
                                    reserveIcon: true
                                    enabled: !entry.modelData.none
                                    selected: entry.index === root.cursor
                                    glyph: entry.modelData.isDefault ? "\ue5ca" : ""
                                    text: entry.modelData.text
                                    trailing: entry.modelData.isDefault ? "default" : ""
                                    onClicked: {
                                        if (!entry.modelData.isDefault && !entry.modelData.none)
                                            root.cursor = entry.index;
                                    }
                                }
                                BevelButton {
                                    visible: !entry.modelData.none && !entry.modelData.isDefault
                                    text: "Make default"
                                    focusPolicy: Qt.NoFocus
                                    enabled: !DefaultApps.busy
                                    onClicked: {
                                        root.cursor = entry.index;
                                        root.apply();
                                    }
                                }
                            }
                        }
                    }
                }

                StatusBar {
                    kind: DefaultApps.result !== "" && !DefaultApps.resultOk ? "error" : (DefaultApps.result !== "" || DefaultApps.busy ? "message" : "state")
                    text: DefaultApps.busy ? "Working..." : (DefaultApps.result !== "" ? DefaultApps.result
                        : root.current ? "Make " + root.current.text + " the default " + root.kindLabel(root.current.key).toLowerCase() : "Nothing changes until you click Make default")
                }
            }
        }
    }

    function kindLabel(key) {
        const c = DefaultApps.categories.find(x => x.key === key);
        return c ? c.label : "";
    }

    // Make default for the application under the cursor
    function apply() {
        const r = root.current;
        if (r && !r.head && !r.none && !r.isDefault)
            DefaultApps.makeDefault(r.key, r.id);
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            root.closeCallback();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.apply();
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            const p = DefaultApps.pickable(DefaultApps.rows);
            const at = p.indexOf(root.cursor);
            const to = event.key === Qt.Key_Down ? Math.min(p.length - 1, at + 1) : Math.max(0, at - 1);
            if (p.length > 0)
                root.cursor = p[to];
        } else {
            return;
        }
        event.accepted = true;
    }

    function openMenu() {
        root.cursor = -1;
        DefaultApps.clearResult();
        DefaultApps.load();
        root.visible = true;
        keys.forceActiveFocus();
    }

    function closeMenu() {
        root.visible = false;
    }
}
