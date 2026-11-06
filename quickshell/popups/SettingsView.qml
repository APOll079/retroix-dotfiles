import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell

import ".."
import "SettingsSchema.js" as Schema

// The launcher's Settings tab (content only; the launcher draws the raised page around it). Fill the tab page with it.
// Left: the categories (MenuRows). Right: the rows of the picked category, a SettingRow each, in a scrolling list.
// Bottom: a StatusBar (what was saved / refused) and an "Open settings.json" button.
// API for the embedding launcher:
//   property string query   the launcher's search text. Non-empty: the right side lists the matching rows of ALL
//                           categories (label, hint or path contains it, case-insensitive) and the category list
//                           shows how many matched per category and is dimmed (not clickable).
//   signal focusSearch()    Escape inside a field with nothing to revert, or Escape on the category list:
//                           give the keys back to the launcher's search box.
//   function focusFirst()   the launcher's Down key: moves keyboard focus into the first control of the list
//                           (the category list when there is no row).
//   function handleKey(event)  true if the view consumed a key the launcher forwarded (Down -> focusFirst()).
// Tab moves between controls; the mouse wheel scrolls. Values are read from and written to `settingsObject`
// (Config.settings; tests pass a fixture). The adapter behind Config.settings saves settings.json by itself.
Item {
    id: root

    property string query: ""
    property var settingsObject: Config.settings
    property var schema: Schema.SCHEMA
    property bool dryRun: false          // tests: "Open settings.json" only emits opened() instead of running xdg-open
    // LOCAL size (no MenuStyle token yet): width of the category column
    readonly property int categoryWidth: MenuStyle.settingsCategoryWidth

    signal focusSearch()
    signal actionRequested(string id)   // an "Open" row of System tools was clicked (the launcher closes and opens the tool)
    signal opened()

    readonly property var categoryNames: Schema.categories(schema)
    property string category: categoryNames.length > 0 ? categoryNames[0] : ""
    readonly property bool searching: query.trim() !== ""
    readonly property var shown: searching ? Schema.search(schema, query) : Schema.entriesFor(schema, category)
    readonly property var themeNames: Object.keys(Config.themes)

    property string statusText: ""
    property string statusKind: "state"

    function countIn(cat: string): int {
        return Schema.search(root.schema, root.query).filter(s => s.category === cat).length;
    }

    function asVar(o: var): var {
        return o;
    }

    function focusFirst() {
        const first = root.asVar(list.itemAtIndex(0));
        if (first && first.focusFirstControl())
            return;
        catBox.forceActiveFocus();
    }

    function handleKey(event): bool {
        if (event.key === Qt.Key_Down) {
            root.focusFirst();
            return true;
        }
        return false;
    }

    function openFile() {
        if (root.dryRun)
            root.opened();
        else
            Quickshell.execDetached(["xdg-open", Quickshell.shellPath("settings.json")]);
    }

    function note(text: string, kind: string) {
        root.statusText = text;
        root.statusKind = kind;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: MenuStyle.gap

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: MenuStyle.gap

            // categories
            FocusScope {
                id: catBox
                Layout.preferredWidth: root.categoryWidth
                Layout.fillHeight: true
                activeFocusOnTab: true

                function step(d: int) {
                    const names = root.categoryNames;
                    const i = Math.max(0, Math.min(names.length - 1, names.indexOf(root.category) + d));
                    root.category = names[i];
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.focusSearch();
                    } else if (event.key === Qt.Key_Up && !root.searching) {
                        step(-1);
                    } else if (event.key === Qt.Key_Down && !root.searching) {
                        step(1);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.focusFirst();
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                Column {
                    anchors.fill: parent
                    Repeater {
                        model: root.categoryNames
                        delegate: MenuRow {
                            required property string modelData
                            width: catBox.width
                            text: modelData
                            focusPolicy: Qt.NoFocus
                            reserveIcon: false
                            hoverLit: !root.searching
                            selected: !root.searching && modelData === root.category
                            enabled: !root.searching
                            trailing: root.searching ? String(root.countIn(modelData)) : ""
                            onClicked: {
                                root.category = modelData;
                                catBox.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // the rows
            SunkenField {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 2

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    model: root.shown
                    cacheBuffer: 4000       // keep every row of a category alive so Tab reaches them all
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: RetroScrollBar { id: bar }
                    readonly property int barRoom: bar.visible ? MenuStyle.scrollBarWidth : 0

                    delegate: SettingRow {
                        required property var modelData
                        width: list.width - list.barRoom
                        entry: modelData
                        settings: root.settingsObject
                        themeNames: root.themeNames
                        onWritten: (path, restart) => root.note(message, "message")
                        onRefused: text => root.note(text, "error")
                        onEscaped: root.focusSearch()
                        onActionRequested: id => root.actionRequested(id)
                    }
                }
                EmptyState {
                    anchors.fill: parent
                    visible: root.shown.length === 0
                    glyph: "\ue8b6"
                    text: "No settings match"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: MenuStyle.gap
            StatusBar {
                Layout.fillWidth: true
                text: root.statusText !== "" ? root.statusText : root.shown.length + (root.shown.length === 1 ? " setting" : " settings")
                kind: root.statusText !== "" ? root.statusKind : "state"
            }
            BevelButton {
                text: "Open settings.json"
                onClicked: root.openFile()
            }
        }
    }
}
