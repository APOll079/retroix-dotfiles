import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// "Find: Files or Folders": the big version of the launcher's "/" search, a real window (an xdg toplevel Hyprland floats
// and centres, see windowrules.lua "find-window") like the Task Manager and the Lyrics window. Opened and closed by
// FindWindowState.qml (`qs ipc call find toggle|open|close`); the launcher's last "/" row opens it with the typed name.
// Named: part of a file or folder name. Look in: the folder to search ("~" by default; the script checks it is a folder).
// Find Now (the default button, also Enter in either field) starts the search, Stop ends it. The list shows Name and
// In Folder; double-click or Enter opens the file (xdg-open), Shift+Enter or the Open Folder button its folder.
// Escape closes the window. The search itself is the FileSearch singleton (scripts/filesearch.sh): names only, hidden
// files skipped, at most 50 results. Names that come from the disk are shown as plain text.
FloatingWindow {
    id: root

    // Hyprland matches this title (windowrules.lua "find-window")
    title: "Find: Files or Folders"

    implicitWidth: MenuStyle.windowWidth
    implicitHeight: MenuStyle.windowHeight
    minimumSize: Qt.size(MenuStyle.widthLarge, MenuStyle.widthMedium)
    color: Config.colors.base

    signal closeRequested()
    onClosed: root.closeRequested()

    // (through a var so the singleton's members are not lint errors)
    readonly property var fs: FileSearch
    readonly property bool live: !Quickshell.env("QS_NO_APPLY")
    property var openLog: []                     // paths handed to xdg-open under QS_NO_APPLY (tests)
    property alias named: namedBox.text
    property alias lookIn: lookBox.text
    readonly property var found: root.fs.results
    readonly property int cursor: list.currentIndex
    readonly property var current: root.found[root.cursor] || null
    readonly property Item namedItem: namedBox
    readonly property Item listItem: list
    readonly property Item emptyItem: empty
    readonly property Item findButton: findNow
    readonly property Item stopButton: stopButton
    readonly property Item openButton: openButton
    readonly property Item folderButton: folderButton

    // { text, kind } for the status bar
    function statusOf(searching, error, done, count) {
        if (error === "notool")
            return { text: "fd, plocate or find not available", kind: "error" };
        if (error === "badfolder")
            return { text: "Look in: that is not a folder", kind: "error" };
        if (error === "badquery")
            return { text: "That name cannot be searched (no leading dash, at most 100 characters)", kind: "error" };
        if (searching)
            return { text: "Searching...", kind: "message" };
        if (done)
            return { text: count + " file(s) found" + (count >= 50 ? " (the first 50)" : ""), kind: "message" };
        return { text: "Type a name and press Find Now", kind: "state" };
    }
    readonly property var status: root.statusOf(root.fs.searching, root.fs.error, root.fs.lastDone, root.found.length)

    // The list's empty text
    function emptyOf(searching, error, done) {
        if (searching)
            return "Searching...";
        if (error !== "")
            return "Nothing to show";
        return done ? "No files found" : "Nothing searched yet";
    }

    function findNow() {
        root.fs.stop();
        root.fs.search(namedBox.text, lookBox.text.trim() === "" ? "~" : lookBox.text);
        list.currentIndex = 0;
    }

    function stopSearch() {
        root.fs.stop();
    }

    function openPath(path) {
        if (root.live)
            Quickshell.execDetached(["xdg-open", path]);
        else
            root.openLog = root.openLog.concat([path]);
    }

    function openCurrent() {
        if (root.current)
            root.openPath(root.current.path);
    }

    function openFolder() {
        if (root.current)
            root.openPath(root.current.dirFull);
    }

    // FindWindowState hands over the name (from the launcher) and starts the search
    function startWith(name) {
        namedBox.text = name;
        if (name !== "")
            root.findNow();
        namedBox.focusInput();
    }

    // Our own toplevel: this title, this process (the address form TaskManager uses)
    function focusSelf() {
        const t = Hyprland.toplevels.values.find(w => w.title === root.title && w.lastIpcObject && w.lastIpcObject.pid === Quickshell.processId);
        if (t)
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + t.address + "\" })");
    }

    Component.onCompleted: namedBox.focusInput()
    onVisibleChanged: {
        if (!root.visible)
            root.fs.stop();
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()

        PopupWindowFrame {
            windowTitle: root.title
            windowTitleIcon: "\ue8b6"
            titleDrag: true
            onTitlePressed: root.startSystemMove()

            ColumnLayout {
                anchors.fill: parent
                spacing: MenuStyle.pad

                // The two fields on the left, Find Now and Stop on the right
                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.pad

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: MenuStyle.pad
                        rowSpacing: MenuStyle.gap

                        RetroText {
                            Layout.preferredWidth: MenuStyle.gamesLabelWidth
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            text: "Named:"
                        }
                        SearchBox {
                            id: namedBox
                            Layout.fillWidth: true
                            showIcon: false
                            onEscaped: root.closeRequested()
                            onKeyPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.findNow();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down && root.found.length > 0) {
                                    list.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }
                        }
                        RetroText {
                            Layout.preferredWidth: MenuStyle.gamesLabelWidth
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            text: "Look in:"
                        }
                        SearchBox {
                            id: lookBox
                            Layout.fillWidth: true
                            showIcon: false
                            text: "~"
                            onEscaped: root.closeRequested()
                            onKeyPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.findNow();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: MenuStyle.gap
                        BevelButton {
                            id: findNow
                            Layout.preferredWidth: MenuStyle.shotActionButtonWidth
                            text: "Find Now"
                            isDefault: true
                            focusPolicy: Qt.NoFocus
                            onClicked: root.findNow()
                        }
                        BevelButton {
                            id: stopButton
                            Layout.preferredWidth: MenuStyle.shotActionButtonWidth
                            text: "Stop"
                            enabled: root.fs.searching
                            focusPolicy: Qt.NoFocus
                            onClicked: root.stopSearch()
                        }
                    }
                }

                // Column labels, lined up with the columns of the rows below
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: MenuStyle.pad + MenuStyle.iconSize + MenuStyle.pad
                    Layout.rightMargin: MenuStyle.scrollBarWidth
                    spacing: 0
                    RetroText {
                        Layout.fillWidth: true
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: MenuStyle.bevelDark
                        text: "Name"
                    }
                    RetroText {
                        Layout.preferredWidth: list.folderColumn
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: MenuStyle.bevelDark
                        text: "In Folder"
                    }
                }

                SunkenField {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 2
                    clip: true

                    EmptyState {
                        id: empty
                        anchors.fill: parent
                        visible: root.found.length === 0
                        glyph: "\ue2c7"
                        text: root.emptyOf(root.fs.searching, root.fs.error, root.fs.lastDone)
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        model: root.found
                        currentIndex: 0
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        // the In Folder column: a third of the row, never less than the width of a short path
                        readonly property int folderColumn: Math.round(width / 3)
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                (event.modifiers & Qt.ShiftModifier) ? root.openFolder() : root.openCurrent();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.closeRequested();
                                event.accepted = true;
                            }
                        }
                        Keys.onUpPressed: event => {
                            if (list.currentIndex > 0)
                                list.currentIndex--;
                            else
                                namedBox.focusInput();      // Up from the first row goes back to the field
                        }
                        Keys.onDownPressed: event => { if (list.currentIndex < root.found.length - 1) list.currentIndex++; }

                        delegate: MenuRow {
                            id: row
                            required property var modelData
                            required property int index
                            width: list.width - (list.ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0)
                            hoverLit: false
                            selected: index === list.currentIndex
                            reserveIcon: true
                            glyph: row.modelData.isDir ? "\ue2c7" : "\ue873"
                            text: row.modelData.name
                            // the name column ends where the In Folder column starts
                            rightPadding: MenuStyle.pad + list.folderColumn
                            onClicked: list.currentIndex = row.index
                            onDoubleClicked: root.openCurrent()

                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                textFormat: Text.PlainText
                                anchors.right: parent.right
                                anchors.rightMargin: MenuStyle.pad
                                anchors.verticalCenter: parent.verticalCenter
                                width: list.folderColumn - MenuStyle.pad
                                elide: Text.ElideMiddle
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: row.lit ? MenuStyle.selectText : Config.colors.text
                                text: row.modelData.dir
                            }
                            HoverHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onHoveredChanged: {
                                    if (hovered)
                                        list.currentIndex = row.index;
                                }
                            }
                        }

                        ScrollBar.vertical: RetroScrollBar {}
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap
                    Item { Layout.fillWidth: true }
                    BevelButton {
                        id: openButton
                        Layout.preferredWidth: MenuStyle.shotActionButtonWidth
                        text: "Open"
                        enabled: root.current !== null
                        focusPolicy: Qt.NoFocus
                        onClicked: root.openCurrent()
                    }
                    BevelButton {
                        id: folderButton
                        Layout.preferredWidth: MenuStyle.shotActionButtonWidth
                        text: "Open Folder"
                        enabled: root.current !== null
                        focusPolicy: Qt.NoFocus
                        onClicked: root.openFolder()
                    }
                }

                StatusBar {
                    text: root.status.text
                    kind: root.status.kind
                }
            }
        }
    }
}
