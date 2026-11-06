import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
import "../utils" as Utils

// The games content shared by the standalone Games menu (GamesMenu.qml) and the launcher's Games
// tab (AppLauncher.qml): filter chips, a grid of cover art, the selected game's buttons, and the
// Add game form. The host owns the window and the search box and feeds `query`; it forwards
// arrow / Enter / Escape from its search field to move(), activateKey() and goBack().
// Data comes from GamesState / scripts/games.py.
Item {
    id: root

    property string query: ""
    property var closeCallback: function () {}
    signal focusSearch()                   // ask the host to put the keyboard back in its search box

    property string filter: "all"          // all | recent | steam | other | hidden
    property int cursor: 0
    property var optionsFor: null          // game whose buttons are showing
    property bool confirmRemove: false     // Remove asked: the ConfirmBar replaces the buttons
    property bool addMode: false
    property var form: ({ name: "", command: "", dir: "", cover: "" })
    property real now: Math.floor(Date.now() / 1000)
    property var nameInput: null

    readonly property var chips: [
        { key: "all", text: "All" },
        { key: "recent", text: "Recent" },
        { key: "steam", text: "Steam" },
        { key: "other", text: "Other" }
    ]
    readonly property int hiddenCount: GamesState.games.filter(g => GamesState.isHidden(g.id)).length
    readonly property var shown: GamesState.games.filter(g => root.passes(g))
    readonly property var prepared: root.shown.map(g => ({ title: Utils.Fuzzy.prepare(g.title + " "), game: g }))
    readonly property var results: root.query === "" ? root.shown : Utils.Fuzzy.go(root.query, root.prepared, { all: true, key: "title" }).map(r => r.obj.game)
    readonly property var current: root.results[root.cursor] || null

    onQueryChanged: {
        root.cursor = 0;
        root.optionsFor = null;
        root.confirmRemove = false;
    }
    onResultsChanged: {
        if (root.cursor >= root.results.length)
            root.cursor = Math.max(0, root.results.length - 1);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: MenuStyle.pad

        // Filter chips + Add game
        RowLayout {
            Layout.fillWidth: true
            visible: !root.addMode
            spacing: MenuStyle.gap
            Repeater {
                model: root.chips
                BevelButton {
                    implicitWidth: MenuStyle.gamesChipWidth
                    text: modelData.text
                    checked: root.filter === modelData.key
                    focusPolicy: Qt.NoFocus
                    onClicked: root.setFilter(modelData.key)
                }
            }
            BevelButton {
                visible: root.hiddenCount > 0 || root.filter === "hidden"
                implicitWidth: MenuStyle.gamesChipWidth + MenuStyle.shotFilterButtonWidth / 2
                text: "Hidden (" + root.hiddenCount + ")"
                checked: root.filter === "hidden"
                focusPolicy: Qt.NoFocus
                onClicked: root.setFilter("hidden")
            }
            Item { Layout.fillWidth: true }
            BevelButton {
                text: "Add game"
                glyph: "\ue145"
                focusPolicy: Qt.NoFocus
                onClicked: root.openForm()
            }
        }

        // Grid
        SunkenField {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.addMode
            padding: 2
            clip: true

            EmptyState {
                anchors.fill: parent
                visible: root.results.length === 0
                glyph: !GamesState.loaded ? "\ue88b" : (root.query !== "" ? "\ue8b6" : "\uea28")
                text: !GamesState.loaded ? "Looking for games..." : (root.query !== "" ? "No matches" : (root.filter === "hidden" ? "Nothing hidden" : (root.filter === "all" ? "No games found\nUse Add game for anything that isn't in Steam" : "Nothing here")))
            }

            GridView {
                id: grid
                anchors.fill: parent
                readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                cellWidth: (width - gutter) / MenuStyle.gamesGridColumns
                ScrollBar.vertical: RetroScrollBar {}
                cellHeight: Math.round((cellWidth - 2 * MenuStyle.gap) * 3 / 2) + MenuStyle.gamesTitleHeight + 2 * MenuStyle.gap
                clip: true
                currentIndex: root.cursor
                highlightFollowsCurrentItem: false
                model: root.results
                delegate: Item {
                    id: cell
                    required property int index
                    required property var modelData
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool isCurrent: root.cursor === index

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: cell.isCurrent ? MenuStyle.selectBar : (cellMouse.containsMouse ? Config.colors.shadow : "transparent")

                        // Cover, or a letter tile when there is no art
                        Item {
                            id: cover
                            x: MenuStyle.gap
                            y: MenuStyle.gap
                            width: parent.width - 2 * MenuStyle.gap
                            height: Math.round(width * 3 / 2)
                            clip: true
                            Image {
                                id: art
                                anchors.fill: parent
                                source: cell.modelData.art ? "file://" + cell.modelData.art : ""
                                sourceSize.width: MenuStyle.gamesCoverDecodeWidth
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: art.status !== Image.Ready
                                color: cell.isCurrent ? Config.colors.base : MenuStyle.selectBar
                                Text {
                                    renderType: Text.NativeRendering
                                    font.hintingPreference: Font.PreferFullHinting
                                    anchors.centerIn: parent
                                    font.family: MenuStyle.titleFont
                                    font.pixelSize: Math.round(parent.width / 2)
                                    color: cell.isCurrent ? Config.colors.text : MenuStyle.selectText
                                    textFormat: Text.PlainText
                                    text: cell.modelData.title.charAt(0).toUpperCase()
                                }
                            }
                        }
                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            x: MenuStyle.gap
                            y: cover.y + cover.height + MenuStyle.gap
                            width: parent.width - 2 * MenuStyle.gap
                            height: MenuStyle.gamesTitleHeight
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: cell.isCurrent ? MenuStyle.selectText : Config.colors.text
                            textFormat: Text.PlainText
                            text: cell.modelData.title
                        }
                        FocusRect {
                            anchors.fill: parent
                            anchors.margins: 1
                            visible: cell.isCurrent
                            color: MenuStyle.selectText
                        }
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // A click selects the game and shows its buttons below
                        onClicked: {
                            root.cursor = cell.index;
                            root.optionsFor = cell.modelData;
                            root.focusSearch();
                        }
                        onDoubleClicked: root.launch(cell.modelData)
                    }
                }
            }
        }

        // Add game form
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.addMode
            spacing: MenuStyle.pad

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: Config.colors.text
                text: "Add a game that isn't in Steam. The command runs through sh, so a script path or a full command line both work. Games added to Steam as shortcuts show up on their own."
            }
            Repeater {
                model: [
                    { key: "name", label: "Name", hint: "Display name" },
                    { key: "command", label: "Command", hint: "e.g. ~/Games/thing/run.sh --fullscreen" },
                    { key: "dir", label: "Folder", hint: "Working folder (optional)" },
                    { key: "cover", label: "Cover", hint: "Image file (optional)" }
                ]
                RowLayout {
                    id: formRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        Layout.preferredWidth: MenuStyle.gamesLabelWidth
                        font.family: MenuStyle.titleFont
                        font.pixelSize: MenuStyle.fontSize
                        color: Config.colors.text
                        text: formRow.modelData.label
                    }
                    SunkenField {
                        Layout.fillWidth: true
                        implicitHeight: MenuStyle.searchHeight
                        padding: 4
                        TextField {
                            id: formInput
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            anchors.fill: parent
                            placeholderText: formRow.modelData.hint
                            placeholderTextColor: MenuStyle.bevelDark
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            selectionColor: Config.colors.shadow
                            padding: 0
                            verticalAlignment: Text.AlignVCenter
                            background: Item {}
                            text: root.form[formRow.modelData.key]
                            onTextEdited: {
                                const f = Object.assign({}, root.form);
                                f[formRow.modelData.key] = text;
                                root.form = f;
                            }
                            Keys.onEscapePressed: root.goBack()
                            Keys.onReturnPressed: root.submitForm()
                            Component.onCompleted: if (formRow.index === 0) root.nameInput = formInput
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // The game's buttons. The row always keeps its height (only fades out) so the grid never changes size
        RowLayout {
            Layout.fillWidth: true
            spacing: MenuStyle.gap
            visible: !root.addMode && !root.confirmRemove
            opacity: root.optionsFor !== null ? 1 : 0
            enabled: root.optionsFor !== null

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: Config.colors.text
                textFormat: Text.PlainText
                text: root.optionsFor ? root.optionsFor.title : ""
            }
            BevelButton {
                text: "Launch"
                glyph: "\ue037"
                focusPolicy: Qt.NoFocus
                onClicked: root.launch(root.optionsFor)
            }
            BevelButton {
                text: root.optionsFor && GamesState.isHidden(root.optionsFor.id) ? "Unhide" : "Hide"
                glyph: root.optionsFor && GamesState.isHidden(root.optionsFor.id) ? "\ue8f4" : "\ue8f5"
                focusPolicy: Qt.NoFocus
                onClicked: {
                    GamesState.setHidden(root.optionsFor.id, !GamesState.isHidden(root.optionsFor.id));
                    root.optionsFor = null;
                    root.focusSearch();
                }
            }
            BevelButton {
                visible: root.optionsFor !== null && root.optionsFor.dir !== ""
                text: "Folder"
                glyph: "\ue2c8"
                focusPolicy: Qt.NoFocus
                onClicked: {
                    Quickshell.execDetached(["xdg-open", root.optionsFor.dir]);
                    root.optionsFor = null;
                    root.focusSearch();
                }
            }
            BevelButton {
                visible: root.optionsFor !== null && root.optionsFor.source === "custom"
                text: "Remove"
                glyph: "\ue872"
                focusPolicy: Qt.NoFocus
                onClicked: {
                    root.confirmRemove = true;
                    root.focusSearch();
                }
            }
            BevelButton {
                text: "Back"
                glyph: "\ue5c4"
                focusPolicy: Qt.NoFocus
                onClicked: {
                    root.optionsFor = null;
                    root.focusSearch();
                }
            }
        }
        // Remove asks first, in place of the buttons
        ConfirmBar {
            id: removeBar
            Layout.fillWidth: true
            visible: !root.addMode && root.confirmRemove && root.optionsFor !== null
            glyph: "\ue002"
            message: "Remove " + (root.optionsFor ? root.optionsFor.title : "") + " from the list?"
            verb: "Remove"
            onAccepted: root.doRemove()
            onCanceled: root.confirmRemove = false
        }
        // Status: the highlighted game, else how many there are
        StatusBar {
            visible: !root.addMode
            kind: root.current ? "message" : "state"
            text: root.current ? root.current.title + " - " + root.sourceName(root.current) : "No game selected"
            trailing: root.results.length + (root.results.length === 1 ? " game" : " games")
        }
        // Form buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: MenuStyle.gap
            visible: root.addMode
            Item { Layout.fillWidth: true }
            BevelButton {
                text: "Add"
                glyph: "\ue145"
                enabled: root.form.name.trim() !== "" && root.form.command.trim() !== ""
                focusPolicy: Qt.NoFocus
                onClicked: root.submitForm()
            }
            BevelButton {
                text: "Cancel"
                focusPolicy: Qt.NoFocus
                onClicked: root.goBack()
            }
        }
    }

    // --- helpers ---

    function passes(g) {
        const hidden = GamesState.isHidden(g.id);
        if (root.filter === "hidden")
            return hidden;
        if (hidden)
            return false;
        if (root.filter === "recent")
            return g.lastPlayed > root.now - MenuStyle.gamesRecentDays * 86400;
        if (root.filter === "steam")
            return g.source === "steam";
        if (root.filter === "other")
            return g.source !== "steam";
        return true;
    }

    function sourceName(g) {
        return g.source === "steam" ? "Steam" : (g.source === "shortcut" ? "Steam shortcut" : "Local");
    }

    function setFilter(f) {
        root.filter = f;
        root.cursor = 0;
        root.optionsFor = null;
        root.focusSearch();
    }

    function launch(g) {
        if (!g)
            return;
        GamesState.launch(g);
        root.closeCallback();
    }

    // --- called by the host's search field ---

    function move(d) {
        if (root.results.length === 0)
            return;
        root.optionsFor = null;
        root.confirmRemove = false;
        root.cursor = Math.max(0, Math.min(root.results.length - 1, root.cursor + d));
        grid.positionViewAtIndex(root.cursor, GridView.Contain);
    }

    function doRemove() {
        const g = root.optionsFor;
        root.confirmRemove = false;
        root.optionsFor = null;
        if (g && g.source === "custom")
            GamesState.removeCustom(g.title);
        root.focusSearch();
    }

    function activateKey(event) {
        if (root.confirmRemove && root.optionsFor !== null) {
            removeBar.accept();
            return;
        }
        if (!root.current)
            return;
        if (event.modifiers & Qt.ShiftModifier)
            root.optionsFor = root.current;
        else
            root.launch(root.current);
    }

    // Escape: undo one step. True when it did something; the host then clears its search / closes.
    function goBack() {
        if (root.addMode) {
            root.addMode = false;
            root.focusSearch();
            return true;
        }
        if (root.confirmRemove) {
            root.confirmRemove = false;
            return true;
        }
        if (root.optionsFor !== null) {
            root.optionsFor = null;
            return true;
        }
        if (root.filter !== "all" && root.query === "") {
            root.filter = "all";
            return true;
        }
        return false;
    }

    function openForm() {
        root.form = { name: "", command: "", dir: "", cover: "" };
        root.optionsFor = null;
        root.addMode = true;
        if (root.nameInput)
            root.nameInput.forceActiveFocus();
    }

    function submitForm() {
        const f = root.form;
        if (f.name.trim() === "" || f.command.trim() === "")
            return;
        GamesState.addCustom({ name: f.name.trim(), command: f.command.trim(), dir: f.dir.trim(), cover: f.cover.trim() });
        root.addMode = false;
        root.focusSearch();
    }

    // Fresh state each time the host opens
    function reset() {
        root.addMode = false;
        root.filter = "all";
        root.optionsFor = null;
        root.confirmRemove = false;
        root.cursor = 0;
        root.now = Math.floor(Date.now() / 1000);
        GamesState.refresh();
    }
}
