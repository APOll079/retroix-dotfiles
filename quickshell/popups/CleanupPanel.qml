import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Disk clean-up (Start > Clean up, or Start > Empty Trash which opens it with the Trash confirm showing). One row
// per thing that can be cleaned, with its size, measured BEFORE anything is deleted. "Clean" swaps the row for a
// ConfirmBar that names the size (verb "Clean up", "Empty Trash" for the Trash); nothing runs without it.
// Root items (package cache, orphans) open a terminal where doas asks for the password; the panel closes then.
// Up / Down select, Enter = Clean the selected row (or accept the confirm), Escape cancels the confirm, then closes.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    property string confirmId: ""          // the row waiting for its confirm, "" = none
    property int cursor: 0
    property bool pendingTrash: false      // openTrash(): confirm the Trash row as soon as the sizes are in

    readonly property var shown: CleanupState.visibleRows(CleanupState.rows)
    readonly property var confirmRow: root.shown.find(r => r.id === root.confirmId) || null
    readonly property int listHeight: Math.max(MenuStyle.rowHeight * 3, Math.min(MenuStyle.rowHeight * 2 * 6, list.contentHeight))

    onShownChanged: {
        root.cursor = Math.max(0, Math.min(root.cursor, root.shown.length - 1));
        if (root.confirmId !== "" && root.confirmRow === null)
            root.confirmId = "";
    }

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
        target: CleanupState
        function onRowsChanged() {
            if (!root.pendingTrash)
                return;
            root.pendingTrash = false;
            const i = root.shown.findIndex(r => r.id === "trash");
            if (i >= 0)
                root.ask(i);
        }
        function onTerminalOpened() {
            root.closeCallback();
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
            windowTitle: "Clean up"
            windowTitleIcon: "\ue872"

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
                    Layout.preferredHeight: root.shown.length === 0 ? MenuStyle.rowHeight * 4 : root.listHeight + 2 * padding
                    padding: 2
                    clip: true

                    EmptyState {
                        anchors.fill: parent
                        visible: root.shown.length === 0
                        glyph: CleanupState.loading ? "\ue5d5" : "\ue86c"
                        text: CleanupState.loading ? "Measuring..." : "Nothing to clean"
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        model: root.shown
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                        ScrollBar.vertical: RetroScrollBar {}
                        delegate: Item {
                            id: entry
                            required property int index
                            required property var modelData
                            readonly property bool asking: root.confirmId === modelData.id
                            width: list.width - list.gutter
                            height: asking ? ask.implicitHeight + MenuStyle.space4 : normal.implicitHeight

                            RowLayout {
                                id: normal
                                visible: !entry.asking
                                width: parent.width
                                spacing: MenuStyle.gap
                                MenuRow {
                                    Layout.fillWidth: true
                                    reserveIcon: true
                                    selected: entry.index === root.cursor
                                    glyph: entry.modelData.id === "trash" ? "\ue872" : "\ue2c7"
                                    text: entry.modelData.label
                                    subtext: CleanupState.detailText(entry.modelData)
                                    trailing: CleanupState.sizeText(entry.modelData)
                                    onClicked: root.cursor = entry.index
                                }
                                BevelButton {
                                    text: "Clean"
                                    focusPolicy: Qt.NoFocus
                                    enabled: root.confirmId === ""
                                    onClicked: root.ask(entry.index)
                                }
                            }
                            ConfirmBar {
                                id: ask
                                visible: entry.asking
                                width: parent.width
                                y: MenuStyle.space2
                                glyph: "\ue872"
                                message: CleanupState.confirmText(entry.modelData)
                                verb: CleanupState.confirmVerb(entry.modelData)
                                onAccepted: root.accept()
                                onCanceled: root.cancel()
                            }
                        }
                    }
                }

                StatusBar {
                    kind: CleanupState.result !== "" && !CleanupState.resultOk ? "error" : (CleanupState.result !== "" ? "message" : "state")
                    text: CleanupState.result !== "" ? CleanupState.result
                        : CleanupState.loading ? "Measuring..."
                        : root.shown.length === 0 ? "Nothing to clean"
                        : "Nothing is deleted until you confirm"
                    trailing: root.shown.length > 0 ? CleanupState.formatBytes(CleanupState.total(root.shown)) + " in total" : ""
                }
            }
        }
    }

    // --- actions ---

    // Shows the confirm for the row at `i`. Nothing runs yet.
    function ask(i) {
        if (i < 0 || i >= root.shown.length)
            return;
        root.cursor = i;
        root.confirmId = root.shown[i].id;
    }

    // The confirm's verb: runs the row once, then forgets the confirm
    function accept() {
        const id = root.confirmId;
        root.confirmId = "";
        if (id !== "")
            CleanupState.run(id);
    }

    function cancel() {
        root.confirmId = "";
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.confirmId !== "")
                root.cancel();
            else
                root.closeCallback();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.confirmId !== "")
                root.accept();
            else
                root.ask(root.cursor);
        } else if (event.key === Qt.Key_Down && root.confirmId === "") {
            root.cursor = Math.min(root.shown.length - 1, root.cursor + 1);
        } else if (event.key === Qt.Key_Up && root.confirmId === "") {
            root.cursor = Math.max(0, root.cursor - 1);
        } else {
            return;
        }
        event.accepted = true;
    }

    function openMenu() {
        root.confirmId = "";
        root.pendingTrash = false;
        CleanupState.clearResult();
        CleanupState.load();
        root.visible = true;
        keys.forceActiveFocus();
    }

    // Start > Empty Trash (size): opens the panel with the Trash row's confirm showing once the sizes are in
    function openTrash() {
        root.openMenu();
        root.pendingTrash = true;
    }

    function closeMenu() {
        root.visible = false;
        root.confirmId = "";
    }
}
