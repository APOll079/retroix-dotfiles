import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."

// Login time report (Start > Login report): how long each step of the last login took, slowest first, with a bar per step
// and the total at the bottom. Data: LoginReport.qml (scripts/loginreport.py reading the timestamps hypr/autostart.lua writes).
// Refresh reloads; Escape, a click outside or the Start row again close.
PanelWindow {
    id: root
    // The bar window this popup hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    readonly property int listRows: 8

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
            windowTitle: "Login report"
            windowTitleIcon: "\ue8b5"

            ColumnLayout {
                id: content
                anchors.fill: parent
                spacing: MenuStyle.pad

                FocusScope {
                    id: keys
                    Layout.preferredWidth: 0
                    Layout.preferredHeight: 0
                    focus: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.closeCallback();
                            event.accepted = true;
                        }
                    }
                }

                SunkenField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: MenuStyle.rowHeight * root.listRows + 2 * padding
                    padding: 2
                    clip: true

                    EmptyState {
                        anchors.fill: parent
                        visible: LoginReport.rows.length === 0
                        glyph: LoginReport.loaded ? "\ue8b5" : "\ue88b"
                        text: LoginReport.loaded ? "No login timestamps yet" : "Reading..."
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        model: LoginReport.rows
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                        ScrollBar.vertical: RetroScrollBar {}
                        delegate: RowLayout {
                            required property var modelData
                            width: list.width - list.gutter
                            height: MenuStyle.rowHeight
                            spacing: MenuStyle.gap
                            Text {
                                Layout.preferredWidth: MenuStyle.widthSmall / 2
                                Layout.leftMargin: MenuStyle.gap
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: Config.colors.text
                                text: modelData.name
                            }
                            SegmentBar {
                                Layout.fillWidth: true
                                Layout.preferredHeight: MenuStyle.rowHeight - MenuStyle.space6
                                value: LoginReport.fraction(modelData.since, LoginReport.slowestMs)
                            }
                            Text {
                                Layout.preferredWidth: MenuStyle.rowHeight * 3
                                Layout.rightMargin: MenuStyle.gap
                                horizontalAlignment: Text.AlignRight
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                textFormat: Text.PlainText
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: Config.colors.text
                                text: LoginReport.msText(modelData.since)
                            }
                        }
                    }
                }

                StatusBar {
                    kind: LoginReport.rows.length > 0 ? "message" : "state"
                    text: LoginReport.rows.length > 0 ? "Time each step took, slowest first" : "Written by hypr/autostart.lua while you log in"
                    trailing: LoginReport.rows.length > 0 ? "Total " + LoginReport.msText(LoginReport.totalMs) : ""
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: MenuStyle.gap
                    Item {
                        Layout.fillWidth: true
                    }
                    BevelButton {
                        text: "Refresh"
                        glyph: "\ue5d5"
                        focusPolicy: Qt.NoFocus
                        onClicked: LoginReport.load()
                    }
                }
            }
        }
    }

    function openMenu() {
        LoginReport.load();
        root.visible = true;
        keys.forceActiveFocus();
    }

    function closeMenu() {
        root.visible = false;
    }
}
