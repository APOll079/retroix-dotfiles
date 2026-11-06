import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Calendar tab of the side panel. `active` is true while this tab is showing.
ColumnLayout {
    id: root
    property bool active: false
    spacing: MenuStyle.pad

    property int viewMonth: new Date().getMonth()
    property int viewYear: new Date().getFullYear()
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    onActiveChanged: {
        if (active) {
            var now = new Date()
            root.viewMonth = now.getMonth()
            root.viewYear = now.getFullYear()
            TodoState.refreshToday()
        }
    }

    // Weather (Weather.qml): now, then the next days; a plain line while it can't be fetched
    Text {
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        Layout.fillWidth: true
        visible: !Weather.ok && Weather.failed
        font.family: MenuStyle.bodyFont
        font.pixelSize: MenuStyle.fontSize
        color: MenuStyle.bevelDark
        text: "Weather unavailable"
    }
    SunkenField {
        Layout.fillWidth: true
        visible: Weather.ok
        implicitHeight: weatherCol.implicitHeight + 2 * padding
        ColumnLayout {
            id: weatherCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: MenuStyle.gap
            RowLayout {
                Layout.fillWidth: true
                spacing: MenuStyle.pad
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    font.family: MenuStyle.iconFont
                    font.pixelSize: MenuStyle.iconSize
                    color: Config.colors.text
                    text: Weather.icon
                }
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: MenuStyle.titleFont
                    font.pixelSize: MenuStyle.fontSize
                    color: Config.colors.text
                    textFormat: Text.PlainText
                    text: Weather.temp + Weather.unit + "  " + Weather.desc
                }
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    Layout.maximumWidth: weatherCol.width / 3
                    elide: Text.ElideRight
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: Config.colors.text
                    textFormat: Text.PlainText
                    text: Weather.place
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: MenuStyle.pad
                Repeater {
                    model: Weather.days
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: MenuStyle.gap
                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            font.family: MenuStyle.iconFont
                            font.pixelSize: MenuStyle.iconSize
                            color: Config.colors.text
                            text: modelData.icon
                        }
                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: MenuStyle.bodyFont
                            font.pixelSize: MenuStyle.fontSize
                            color: Config.colors.text
                            textFormat: Text.PlainText
                            text: modelData.name + " " + modelData.lo + "/" + modelData.hi + Weather.unit
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: MenuStyle.pad
        BevelButton {
            implicitWidth: MenuStyle.rowHeight + MenuStyle.gap
            glyph: "\ue5cb"
            onClicked: root.shiftMonth(-1)
        }
        Text {
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.family: MenuStyle.titleFont
            font.pixelSize: MenuStyle.fontSize
            color: Config.colors.text
            text: root.monthNames[root.viewMonth] + " " + root.viewYear
        }
        BevelButton {
            implicitWidth: MenuStyle.rowHeight + MenuStyle.gap
            glyph: "\ue5cc"
            onClicked: root.shiftMonth(1)
        }
    }

    SunkenField {
        Layout.fillWidth: true
        implicitHeight: dayRow.implicitHeight + grid.implicitHeight + 2 * padding
        padding: 4

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            DayOfWeekRow {
                id: dayRow
                Layout.fillWidth: true
                locale: Qt.locale("en_GB")
                delegate: Item {
                    implicitWidth: MenuStyle.calendarCell
                    implicitHeight: dayLabel.implicitHeight + 2
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        id: dayLabel
                        anchors.centerIn: parent
                        font.family: MenuStyle.titleFont
                        font.pixelSize: MenuStyle.fontSize
                        color: Config.colors.text
                        text: model.shortName
                    }
                }
            }

            MonthGrid {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                month: root.viewMonth
                year: root.viewYear
                locale: Qt.locale("en_GB")
                delegate: Item {
                    id: cell
                    readonly property string key: TodoState.ymd(model.year, model.month, model.day)
                    readonly property bool due: TodoState.dueDays[cell.key] === true
                    readonly property bool picked: root.dueFor !== "" && root.dueFor === cell.key
                    implicitWidth: MenuStyle.calendarCell
                    implicitHeight: MenuStyle.rowHeight - 2
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: model.today ? MenuStyle.selectBar : "transparent"
                        // the day picked as the next task's due date: an outline (inside the fill on today)
                        border.width: cell.picked ? 1 : 0
                        border.color: model.today ? MenuStyle.selectText : MenuStyle.selectBar
                    }
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        anchors.centerIn: parent
                        font.family: MenuStyle.bodyFont
                        font.pixelSize: MenuStyle.fontSize
                        color: model.today ? MenuStyle.selectText : (model.month === grid.month ? Config.colors.text : Config.colors.shadow)
                        text: model.day
                    }
                    // an open task is due this day: a short bar under the number
                    Rectangle {
                        objectName: "dueMark"
                        visible: cell.due
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: MenuStyle.space2 + 1
                        width: MenuStyle.space8
                        height: MenuStyle.space2
                        color: model.today ? MenuStyle.selectText : MenuStyle.selectBar
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.pickDay(model.year, model.month, model.day)
                    }
                }
            }
        }
    }

    // ---- to-do list (TodoState: todo.txt in the state dir) ----

    // The list always shows this many rows, so the tab never changes height as tasks come and go
    // The day picked on the grid as the due date of the next added task ("" = none)
    property string dueFor: ""

    function pickDay(y, m, d) {
        if (addBox.text !== "")
            return;
        root.dueFor = TodoState.ymd(y, m, d);
    }
    // Enter in the add field: a leading yyyy-MM-dd is the due date, else the picked day
    function submit() {
        const t = TodoState.splitInput(addBox.text);
        if (t.text === "")
            return;
        TodoState.add(t.text, t.due !== "" ? t.due : root.dueFor);
        addBox.text = "";
        root.dueFor = "";
    }

    SunkenField {
        Layout.fillWidth: true
        Layout.preferredHeight: MenuStyle.todoRows * MenuStyle.rowHeight + 2 * padding
        padding: MenuStyle.space2

        EmptyState {
            anchors.fill: parent
            visible: TodoState.items.length === 0
            glyph: "\ue834"
            text: "No tasks"
        }

        ListView {
            id: todoList
            objectName: "todoList"
            anchors.fill: parent
            visible: TodoState.items.length > 0
            model: TodoState.items
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: RetroScrollBar { id: todoBar }
            readonly property int barRoom: todoBar.visible ? MenuStyle.scrollBarWidth : 0
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool overdue: TodoState.isOverdue(row.modelData, TodoState.today)
                width: todoList.width - todoList.barRoom
                height: MenuStyle.rowHeight

                // The row (hover, click, the box); its text is drawn over it so a done task can be struck out
                MenuRow {
                    id: mr
                    anchors.fill: parent
                    reserveIcon: true
                    glyph: row.modelData.done ? "\ue834" : "\ue835"
                    onClicked: TodoState.toggle(row.index)
                }
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    anchors.left: parent.left
                    anchors.leftMargin: MenuStyle.pad + MenuStyle.iconSize + MenuStyle.pad
                    anchors.right: dueText.visible ? dueText.left : parent.right
                    anchors.rightMargin: MenuStyle.pad
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    font.strikeout: row.modelData.done
                    color: mr.lit ? MenuStyle.selectText : (row.modelData.done ? Config.colors.shadow : Config.colors.text)
                    textFormat: Text.PlainText
                    text: row.modelData.text
                }
                Text {
                    id: dueText
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    visible: row.modelData.due !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: MenuStyle.pad
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: mr.lit ? MenuStyle.selectText : (row.overdue ? Config.colors.urgent : Config.colors.shadow)
                    textFormat: Text.PlainText
                    text: row.modelData.due
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: mouse => {
                        const i = row.index;
                        todoMenu.model = [{ text: "Delete", glyph: "\ue872", action: () => TodoState.remove(i) }];
                        todoMenu.openAt(row, mouse.x, mouse.y);
                    }
                }
            }
        }
    }

    // the right-click menu of a task row (Delete)
    readonly property var rowMenu: todoMenu
    PopupMenu {
        id: todoMenu
    }

    // The add field; the picked due date sits beside it as a button that clears it
    RowLayout {
        Layout.fillWidth: true
        spacing: MenuStyle.gap
        SearchBox {
            id: addBox
            objectName: "addBox"
            Layout.fillWidth: true
            showIcon: false
            placeholder: root.dueFor !== "" ? "Add a task" : "Add a task, e.g. 2026-11-10 buy milk"
            onEscaped: addBox.input.focus = false
            onKeyPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.submit();
                    event.accepted = true;
                }
            }
        }
        BevelButton {
            id: dueChip
            objectName: "dueChip"
            visible: root.dueFor !== ""
            Layout.preferredHeight: addBox.height
            text: root.dueFor
            glyph: "\ue5cd"
            focusPolicy: Qt.NoFocus
            onClicked: root.dueFor = ""
        }
    }

    function shiftMonth(delta) {
        var m = root.viewMonth + delta
        var y = root.viewYear
        if (m < 0) { m = 11; y -= 1 }
        else if (m > 11) { m = 0; y += 1 }
        root.viewMonth = m
        root.viewYear = y
    }

    Item { Layout.fillHeight: true }
}
