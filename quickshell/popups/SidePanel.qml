import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".."

// One panel for notifications + calendar, audio, and power. Anchored to the right edge. Home runs
// from the bar down to sidePanelBottomMargin above the screen's bottom and the notification history
// takes all the height the audio part leaves; Calendar and Phone keep their natural height.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar
    property var closeCallback: function() {}
    // 0 = Home (audio + notifications), 1 = Calendar, 2 = Phone (KDE Connect)
    property int tab: 0
    // The power action waiting for its verb button (Session.qml policy)
    property var pending: null

    // An Overlay-layer panel (not a popup of the bar), so Super+N over a fullscreen app gets the clicks
    anchors {
        top: true
        right: true
    }
    margins.top: MenuStyle.barHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: false
    implicitWidth: MenuStyle.widthLarge
    implicitHeight: root.tab === 0 && root.screen ? root.screen.height - MenuStyle.barHeight - MenuStyle.sidePanelBottomMargin : MenuStyle.chromeHeight + column.implicitHeight
    color: "transparent"

    // Tell the toast window this screen's Home tab is showing (no toasts there; see NotificationDaemon)
    readonly property bool homeShowing: root.visible && root.tab === 0
    onHomeShowingChanged: root.reportHome()
    onScreenChanged: root.reportHome()
    Component.onDestruction: {
        if (root.screen)
            root.setHome(root.screen.name, false);
    }
    function setHome(name, on) {
        if (!!NotificationStore.homeOpenOn[name] === on)
            return;
        const m = Object.assign({}, NotificationStore.homeOpenOn);
        m[name] = on;
        NotificationStore.homeOpenOn = m;
    }
    function reportHome() {
        if (root.screen)
            root.setHome(root.screen.name, root.homeShowing);
    }

    // Shared with the launcher and the session panel (Session.qml), your own actions included
    readonly property var actions: Session.all

    // Escape closes the panel (a pending power action is cancelled first). The frame takes the keyboard when the panel opens.
    onVisibleChanged: if (root.visible) frame.forceActiveFocus()

    PopupWindowFrame {
        id: frame
        focus: true
        Keys.onEscapePressed: {
            if (root.pending)
                root.pending = null;
            else
                root.closeCallback();
        }
        windowTitle: root.tab === 0 ? "Home" : root.tab === 1 ? "Calendar" : "Phone"
        windowTitleIcon: root.tab === 0 ? "\ue7f4" : root.tab === 1 ? "\ue935" : "\ue324"

        ColumnLayout {
            id: column
            anchors.fill: parent
            spacing: MenuStyle.pad

            // Quick power buttons
            RowLayout {
                Layout.fillWidth: true
                visible: !root.pending
                spacing: MenuStyle.gap
                Repeater {
                    model: root.actions
                    BevelButton {
                        // Equal widths whatever the content. Your own actions show their name: their
                        // icon is a generic tick unless you set one, and a tick alone says nothing
                        readonly property bool custom: !Session.builtins.some(b => b.name === modelData.name)
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        glyph: custom ? "" : modelData.icon
                        text: custom ? modelData.name : ""
                        onClicked: {
                            if (modelData.confirm) {
                                root.pending = modelData
                            } else {
                                root.run(modelData)
                            }
                        }
                    }
                }
            }

            // Inline confirm: the verb is the default button
            ConfirmBar {
                id: confirmBar
                Layout.fillWidth: true
                visible: !!root.pending
                glyph: "\ue002"
                message: root.pending ? root.pending.prompt : ""
                verb: root.pending ? root.pending.verb : ""
                onAccepted: root.run(root.pending)
                onCanceled: root.pending = null
            }

            MenuSeparator { Layout.fillWidth: true }

            // Tabs on one raised page; Calendar / Phone take their own height, Home fills the full-height panel
            TabPage {
                id: tabs
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: root.tab === 0 ? -1 : tabs.frameTop + 2 * (3 + MenuStyle.tabPagePad) + (root.tab === 1 ? calendarTab.implicitHeight : phoneTab.implicitHeight)
                tabs: [{ key: "home", text: "Home" }, { key: "calendar", text: "Calendar" }, { key: "phone", text: "Phone" }]
                current: root.tab === 0 ? "home" : root.tab === 1 ? "calendar" : "phone"
                onTabClicked: key => root.tab = key === "home" ? 0 : key === "calendar" ? 1 : 2

                StackLayout {
                    anchors.fill: parent
                    currentIndex: root.tab

                    ColumnLayout {
                        id: homeTab
                        spacing: MenuStyle.pad
                        AudioTab {
                            Layout.fillWidth: true
                            active: root.visible && root.tab === 0
                        }
                        MenuSeparator { Layout.fillWidth: true }
                        NotificationList {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            active: root.visible && root.tab === 0
                        }
                    }
                    CalendarTab { id: calendarTab; active: root.visible && root.tab === 1 }
                    PhoneTab { id: phoneTab; active: root.visible && root.tab === 2 }
                }
            }
        }
    }

    function run(action) {
        root.pending = null
        Session.run(action)
        root.closeCallback()
    }
    function openMenu() { root.pending = null; root.visible = true }
    function closeMenu() { root.pending = null; root.visible = false }
}
