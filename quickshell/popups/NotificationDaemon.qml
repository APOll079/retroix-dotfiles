import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import ".."

Scope {
    id: root

    readonly property var cfg: Config.settings.notifications
    readonly property int maxVisible: cfg.maxVisible > 0 ? cfg.maxVisible : MenuStyle.notificationMaxVisible
    readonly property string pos: cfg.position
    readonly property bool atBottom: pos.startsWith("bottom")
    // Toasts with their reply field open: the toast window takes the keyboard while > 0
    property int replying: 0

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        imageSupported: true
        // Needed for click-to-open: apps send a "default" action that a left-click invokes
        actionsSupported: true
        // Chat apps can offer a reply box (toast: Reply button)
        inlineReplySupported: true

        onNotification: notification => {
            // Track changes belong to the bar's now-playing text, not to toasts or history
            if (notification.appName.toLowerCase() === "spotify") {
                notification.dismiss();
                return;
            }
            notification.tracked = true;
            NotificationStore.add(notification);
        }
    }

    Connections {
        target: NotificationStore
        function onToastsChanged() {
            if (notifWindow.homeOpen && NotificationStore.toasts.length > 0)
                NotificationStore.dropToasts();
        }
    }

    PanelWindow {
        id: notifWindow
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.replying > 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // No toast on a monitor whose side panel Home tab is open: the history is right there.
        // (The notification stays in the store; toasts that show up meanwhile are dropped.)
        readonly property bool homeOpen: notifWindow.screen ? !!NotificationStore.homeOpenOn[notifWindow.screen.name]
            : Object.keys(NotificationStore.homeOpenOn).some(k => NotificationStore.homeOpenOn[k])
        onHomeOpenChanged: if (homeOpen) NotificationStore.dropToasts()

        visible: NotificationStore.toasts.length > 0 && !notifWindow.homeOpen

        // Monitor: a named output, "focused" (Hyprland's focused monitor), or "" for the default
        screen: {
            const want = root.cfg.monitor === "focused" ? (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "") : root.cfg.monitor;
            return Quickshell.screens.find(s => s.name === want) || null;
        }

        // Position: top-right (default), top-left, top, bottom-right, bottom-left, bottom.
        // Anchoring only top or bottom centres the stack.
        anchors {
            top: !root.atBottom
            bottom: root.atBottom
            right: root.pos.endsWith("right")
            left: root.pos.endsWith("left")
        }
        margins.top: MenuStyle.barHeight + MenuStyle.notificationMargin
        margins.bottom: MenuStyle.notificationMargin
        margins.right: MenuStyle.notificationMargin
        margins.left: MenuStyle.notificationMargin

        implicitWidth: MenuStyle.widthMedium
        implicitHeight: Math.max(1, notifColumn.implicitHeight)

        Column {
            id: notifColumn
            width: parent.width
            spacing: MenuStyle.pad

            Repeater {
                // ScriptModel diffs the array, so a new toast doesn't rebuild (and re-time) the others
                model: ScriptModel {
                    values: NotificationStore.toasts
                }

                Item {
                    id: notifItem
                    required property var modelData
                    required property int index
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property int count: NotificationStore.toastCounts[modelData.appName] || 1
                    readonly property real progress: NotificationStore.progressOf(modelData)
                    property bool replyOpen: false
                    onReplyOpenChanged: root.replying += replyOpen ? 1 : -1
                    Component.onDestruction: {
                        if (replyOpen)
                            root.replying -= 1;
                    }
                    readonly property var extraActions: Array.from(modelData.actions).filter(a => a.identifier !== "default" && a.text !== "")
                    readonly property string iconSource: {
                        if (modelData.image !== "")
                            return modelData.image;
                        if (modelData.appIcon !== "")
                            return Quickshell.iconPath(modelData.appIcon, true);
                        return "";
                    }

                    visible: index < root.maxVisible
                    width: MenuStyle.widthMedium
                    height: visible ? MenuStyle.chromeHeight + Math.max(content.implicitHeight, 32) : 0

                    // Fade out, then hide the toast. The notification itself stays alive in the
                    // history so it can still be opened from there.
                    function close() {
                        fadeOut.start();
                    }

                    // Never shorter than the default, so short app timeouts don't flash by; paused
                    // while you type a reply or while the toast is past maxVisible. expireTimeout is
                    // in seconds; 0 (never expire) and critical toasts stay until dismissed.
                    HoverHandler {
                        id: hover
                    }

                    Timer {
                        running: notifItem.visible && !hover.hovered && !notifItem.replyOpen && !notifItem.critical && notifItem.modelData.expireTimeout !== 0
                        interval: notifItem.modelData.expireTimeout > 0 ? Math.max(notifItem.modelData.expireTimeout * 1000, MenuStyle.notificationTimeout) : MenuStyle.notificationTimeout
                        onTriggered: notifItem.close()
                    }

                    NumberAnimation {
                        id: fadeOut
                        target: notifItem
                        property: "opacity"
                        to: 0
                        duration: MenuStyle.notificationFade
                        easing.type: MenuStyle.animEasing
                        onFinished: NotificationStore.hideToast(notifItem.modelData)
                    }

                    PopupWindowFrame {
                        // App name (+ how many arrived from it meanwhile); the summary is the first body line
                        windowTitle: (notifItem.modelData.appName || notifItem.modelData.summary) + (notifItem.count > 1 ? " \u00b7 " + notifItem.count : "")
                        active: false
                        windowTitleIcon: "\ue7f4"
                        titleColor: notifItem.critical ? MenuStyle.urgentBar : "transparent"
                        titleTextColor: notifItem.critical ? MenuStyle.urgentText : Config.colors.text
                        
                        // Left-click opens it (the app's default action, e.g. the Discord chat);
                        // right-click just hides the toast. Below the content so action buttons win.
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton)
                                    NotificationStore.activate(notifItem.modelData);
                                else
                                    notifItem.close();
                            }
                        }

                        ColumnLayout {
                            id: content
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: MenuStyle.pad

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: MenuStyle.pad

                                Image {
                                    Layout.preferredWidth: MenuStyle.notificationIconSize
                                    Layout.preferredHeight: MenuStyle.notificationIconSize
                                    Layout.alignment: Qt.AlignTop
                                    visible: status === Image.Ready
                                    asynchronous: true
                                    smooth: false
                                    fillMode: Image.PreserveAspectFit
                                    source: notifItem.iconSource
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        Layout.fillWidth: true
                                        visible: text !== "" && notifItem.modelData.appName !== ""
                                        // Same as the history: the title at 16 px, the body at 12
                                        font.family: MenuStyle.bodyFont
                                        font.pixelSize: MenuStyle.notificationTitleSize
                                        color: Config.colors.text
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                        text: notifItem.modelData.summary
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        font.hintingPreference: Font.PreferFullHinting
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        font.family: MenuStyle.bodyFont
                                        font.pixelSize: MenuStyle.fontSize
                                        color: Config.colors.text
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                        maximumLineCount: MenuStyle.notificationToastBodyLines
                                        textFormat: Text.PlainText
                                        text: notifItem.modelData.body
                                    }
                                }
                            }

                            // Progress (downloads, copies): the "value" hint, 0-100
                            SegmentBar {
                                Layout.fillWidth: true
                                visible: notifItem.progress >= 0
                                implicitHeight: MenuStyle.rowHeight - 6
                                value: notifItem.progress / 100
                            }

                            // Any actions besides the click ("default") get their own buttons,
                            // plus Reply for apps that offer an inline reply
                            RowLayout {
                                Layout.fillWidth: true
                                visible: (notifItem.extraActions.length > 0 || notifItem.modelData.hasInlineReply) && !notifItem.replyOpen
                                spacing: MenuStyle.gap
                                Repeater {
                                    model: notifItem.extraActions
                                    BevelButton {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        onClicked: NotificationStore.runAction(notifItem.modelData, modelData)
                                    }
                                }
                                BevelButton {
                                    Layout.fillWidth: true
                                    visible: notifItem.modelData.hasInlineReply
                                    text: "Reply"
                                    glyph: "\ue15e"
                                    onClicked: {
                                        notifItem.replyOpen = true;
                                        replyBox.focusInput();
                                    }
                                }
                            }

                            // Inline reply: Enter sends, Escape cancels
                            SearchBox {
                                id: replyBox
                                Layout.fillWidth: true
                                visible: notifItem.replyOpen
                                showIcon: false
                                placeholder: notifItem.modelData.inlineReplyPlaceholder || "Reply"
                                onEscaped: notifItem.replyOpen = false
                                onKeyPressed: event => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        NotificationStore.reply(notifItem.modelData, replyBox.text);
                                        notifItem.replyOpen = false;
                                        event.accepted = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
