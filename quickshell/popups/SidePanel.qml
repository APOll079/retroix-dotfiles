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
    margins.right: MenuStyle.gap
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
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

    // Shared with the launcher and the session panel (Session.qml)
    readonly property var actions: Session.builtins

    PopupWindowFrame {
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
                        Layout.fillWidth: true
                        glyph: modelData.icon
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

            // Inline confirm
            RowLayout {
                Layout.fillWidth: true
                visible: !!root.pending
                spacing: MenuStyle.gap
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    Layout.fillWidth: true
                    font.family: MenuStyle.bodyFont
                    font.pixelSize: MenuStyle.fontSize
                    color: Config.colors.text
                    text: root.pending ? root.pending.prompt : ""
                }
                BevelButton {
                    text: root.pending ? root.pending.verb : ""
                    onClicked: root.run(root.pending)
                }
                BevelButton {
                    text: "Cancel"
                    onClicked: root.pending = null
                }
            }

            MenuSeparator { Layout.fillWidth: true }

            // Tabs
            RowLayout {
                Layout.fillWidth: true
                spacing: MenuStyle.gap
                BevelButton {
                    Layout.fillWidth: true
                    text: "Home"
                    checked: root.tab === 0
                    onClicked: root.tab = 0
                }
                BevelButton {
                    Layout.fillWidth: true
                    text: "Calendar"
                    checked: root.tab === 1
                    onClicked: root.tab = 1
                }
                BevelButton {
                    Layout.fillWidth: true
                    text: "Phone"
                    checked: root.tab === 2
                    onClicked: root.tab = 2
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Calendar / Phone: their own height (Home fills the full-height panel)
                Layout.preferredHeight: root.tab === 1 ? calendarTab.implicitHeight : root.tab === 2 ? phoneTab.implicitHeight : -1
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

    function run(action) {
        root.pending = null
        Session.run(action)
        root.closeCallback()
    }
    function openMenu() { root.pending = null; root.visible = true }
    function closeMenu() { root.pending = null; root.visible = false }
}
