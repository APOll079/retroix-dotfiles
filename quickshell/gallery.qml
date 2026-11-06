// Component gallery (F1): every shared component in every state it can be forced into, on one page.
// Never part of the running shell. Render it with scripts/render-gallery.sh (offscreen, scratch
// copy, one PNG per theme). Hover can't be forced from outside a Button, so BarButton and
// BevelButton hover is not shown here; MenuRow's selected state is the same look and is.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import "popups" as Popups

ShellRoot {
    FloatingWindow {
        id: win
        implicitWidth: page.implicitWidth
        implicitHeight: page.implicitHeight
        color: Config.colors.base

        Rectangle {
            id: page
            // gallery layout only, not shell sizes
            readonly property int colW: 300
            readonly property int capW: 96
            readonly property int outer: 12
            readonly property int frameH: 172
            readonly property int nameW: 88
            readonly property int swatchW: 42
            readonly property int swatchH: 22

            implicitWidth: outer * 3 + colW * 3 + outer * 2
            readonly property int columnsHeight: Math.max(col1.implicitHeight, col2.implicitHeight, col3.implicitHeight)
            implicitHeight: columnsHeight + outer * 3 + barStrip.implicitHeight
            color: Config.colors.base

            component Cap: Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: Config.colors.text
                textFormat: Text.PlainText
            }
            component Head: Cap {
                font.bold: true
                Layout.topMargin: MenuStyle.pad
            }
            // caption on the left, the control on the right
            component Line: RowLayout {
                id: line
                property string cap: ""
                default property alias items: slot.data
                spacing: MenuStyle.pad
                Cap { text: line.cap; Layout.preferredWidth: page.capW; color: MenuStyle.bevelDark }
                Row { id: slot; spacing: MenuStyle.gap }
            }

            // ---------- column 1: bar buttons, tokens ----------
            ColumnLayout {
                id: col1
                x: page.outer; y: page.outer
                width: page.colW
                spacing: MenuStyle.gap

                Head { text: "BarButton" }
                Rectangle {
                    // a stretch of bar: the real bar is a solid base strip
                    Layout.fillWidth: true
                    implicitHeight: MenuStyle.barHeight
                    color: Config.colors.base
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: MenuStyle.gap
                        spacing: MenuStyle.gap
                        Gripper { anchors.verticalCenter: parent.verticalCenter }
                        BarButton { label: "Start"; iconFontValue: "\ue5c3" }
                        Popups.MenuSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }
                        BarButton { label: "Services"; iconFontValue: "\ue8b8" }
                    }
                }
                Line { cap: "normal"; BarButton { label: "Wallpapers"; iconFontValue: "\ue3f4" } }
                Line { cap: "pressed"; BarButton { label: "Wallpapers"; iconFontValue: "\ue1bc"; down: true } }
                Line { cap: "toggled"; BarButton { label: "Wallpapers"; iconFontValue: "\ue3f4"; isToggled: true; toggledIconFontValue: "\ue3f4" } }
                Line { cap: "disabled"; BarButton { label: "Wallpapers"; iconFontValue: "\ue3f4"; enabled: false } }
                Line { cap: "urgent"; BarButton { label: "Bluetooth"; iconFontValue: "\ue1a7"; urgent: true } }
                Line { cap: "glyph on"; BarButton { iconFontValue: "\ue541"; glyphOn: true } BarButton { iconFontValue: "\ue541" } }
                Line { cap: "icon only"; BarButton { iconFontValue: "\ue8b8" } BarButton { iconFontValue: "\ue1a7" } }
                Line { cap: "indicator"; BarButton { label: "ETH"; iconFontValue: ""; interactive: false; dim: true } }
                Line { cap: "tucked"; BarButton { label: "28%"; iconFontValue: "\ue050"; tucked: true } }
                Line { cap: "numbers"; BarButton { label: "CPU 2% 46° GPU 36° RAM 30%"; iconFontValue: "" } }

                Head { text: "Palette" }
                Repeater {
                    model: ["base", "shadow", "highlight", "accent", "text", "outline", "urgent"]
                    delegate: RowLayout {
                        required property string modelData
                        spacing: MenuStyle.pad
                        Rectangle {
                            implicitWidth: page.swatchW; implicitHeight: page.swatchH
                            color: Config.colors[modelData]
                            border.width: 1; border.color: Config.colors.outline
                        }
                        Cap { text: modelData; Layout.preferredWidth: page.nameW }
                        Cap { text: String(Config.colors[modelData]); color: MenuStyle.bevelDark }
                    }
                }
                Head { text: "Derived" }
                Repeater {
                    model: [
                        { n: "bevelLight", c: MenuStyle.bevelLight },
                        { n: "bevelDark", c: MenuStyle.bevelDark },
                        { n: "selectBar", c: MenuStyle.selectBar },
                        { n: "selectText", c: MenuStyle.selectText }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        spacing: MenuStyle.pad
                        Rectangle {
                            implicitWidth: page.swatchW; implicitHeight: page.swatchH
                            color: modelData.c
                            border.width: 1; border.color: Config.colors.outline
                        }
                        Cap { text: modelData.n; Layout.preferredWidth: page.nameW }
                        Cap { text: String(modelData.c); color: MenuStyle.bevelDark }
                    }
                }
                Head { text: "Contrast (want: text >= 4.5, edge >= 1.35)" }
                Cap { text: "text / base       " + MenuStyle.contrast(Config.colors.text, Config.colors.base).toFixed(2) }
                Cap { text: "text / highlight  " + MenuStyle.contrast(Config.colors.text, Config.colors.highlight).toFixed(2) }
                Cap { text: "base -> highlight " + MenuStyle.contrast(Config.colors.base, Config.colors.highlight).toFixed(2) }
                Cap { text: "base -> bevelLight " + MenuStyle.contrast(Config.colors.base, MenuStyle.bevelLight).toFixed(2) }
                Cap { text: "selectText / bar  " + MenuStyle.contrast(MenuStyle.selectText, MenuStyle.selectBar).toFixed(2) }
                Cap { text: "urgent / base     " + MenuStyle.contrast(Config.colors.urgent, Config.colors.base).toFixed(2) + " (want >= 3)" }
                Cap { text: "urgentText / bar  " + MenuStyle.contrast(MenuStyle.urgentText, MenuStyle.urgentBar).toFixed(2) }
                Item { Layout.fillHeight: true }
            }

            // ---------- column 2: buttons, menu frame ----------
            ColumnLayout {
                id: col2
                x: page.outer * 2 + page.colW; y: page.outer
                width: page.colW
                spacing: MenuStyle.gap

                Head { text: "BevelButton" }
                Line { cap: "normal"; Popups.BevelButton { text: "Cancel" } }
                Line { cap: "glyph + text"; Popups.BevelButton { text: "Reboot"; glyph: "\ue5d5" } }
                Line { cap: "icon only"; Popups.BevelButton { glyph: "\ue037" } Popups.BevelButton { glyph: "\ue034" } }
                Line { cap: "pressed"; Popups.BevelButton { text: "Cancel"; down: true } }
                Line { cap: "default"; Popups.BevelButton { text: "Reboot"; isDefault: true } Popups.BevelButton { text: "Reboot"; isDefault: true; down: true } }
                Line { cap: "checked"; Popups.BevelButton { text: "Mute"; checkable: true; checked: true } }
                Line { cap: "disabled"; Popups.BevelButton { text: "Forget"; enabled: false } Popups.BevelButton { glyph: "\ue037"; enabled: false } }
                Line {
                    cap: "focused"
                    Popups.BevelButton {
                        id: focusBtn
                        text: "Pair"
                        Timer { interval: 200; running: true; onTriggered: focusBtn.forceActiveFocus(Qt.TabFocusReason) }
                    }
                }

                Head { text: "PopupWindowFrame + MenuRow" }
                Item {
                    Layout.preferredWidth: MenuStyle.widthSmall
                    Layout.preferredHeight: page.frameH + MenuStyle.rowHeight * 2
                    Popups.PopupWindowFrame {
                        windowTitle: "Gallery"
                        windowTitleIcon: "\ue8b8"
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0
                            Popups.MenuRow { Layout.fillWidth: true; reserveIcon: true; text: "Normal"; glyph: "\ue88a" }
                            Popups.MenuRow { Layout.fillWidth: true; reserveIcon: true; text: "Selected"; glyph: "\ue88a"; selected: true }
                            Popups.MenuRow { Layout.fillWidth: true; reserveIcon: true; text: "Disabled"; glyph: "\ue88a"; enabled: false }
                            Popups.MenuRow { Layout.fillWidth: true; reserveIcon: true; text: "Marked"; glyph: "\ue88a"; marked: true }
                            Popups.MenuRow { Layout.fillWidth: true; reserveIcon: true; text: "Trailing"; trailing: "Ctrl+Q" }
                            Popups.MenuRow { Layout.fillWidth: true; reserveIcon: true; text: "Two lines"; subtext: "second line, dim"; glyph: "\ue88a" }
                            Popups.MenuSeparator { Layout.fillWidth: true }
                            Popups.MenuRow { Layout.fillWidth: true; reserveIcon: true; text: "No icon, long text that has to be cut off" }
                        }
                    }
                }
                Head { text: "PopupWindowFrame (inactive, critical)" }
                Item {
                    Layout.preferredWidth: MenuStyle.widthSmall
                    Layout.preferredHeight: MenuStyle.chromeHeight + MenuStyle.rowHeight
                    Popups.PopupWindowFrame {
                        active: false
                        windowTitle: "Battery low"
                        windowTitleIcon: "\ue7f4"
                        titleColor: MenuStyle.urgentBar
                        titleTextColor: MenuStyle.urgentText
                        Popups.MenuRow { width: parent.width; text: "Critical toast title" }
                    }
                }
                Head { text: "PopupWindowFrame (inactive)" }
                Item {
                    Layout.preferredWidth: MenuStyle.widthSmall
                    Layout.preferredHeight: MenuStyle.chromeHeight + MenuStyle.rowHeight
                    Popups.PopupWindowFrame {
                        active: false
                        windowTitle: "Toast"
                        Popups.MenuRow { width: parent.width; text: "Muted title bar" }
                    }
                }
                Head { text: "GroupBox" }
                Popups.GroupBox {
                    Layout.fillWidth: true
                    title: "Output"
                    Popups.MenuRow { Layout.fillWidth: true; text: "DM15 Analog Stereo"; glyph: "\ue32d"; marked: true }
                    Popups.MenuRow { Layout.fillWidth: true; text: "HDMI / DisplayPort"; glyph: "\ue30c" }
                    Popups.RetroSlider { Layout.fillWidth: true; value: 0.6 }
                }
                Head { text: "EmptyState" }
                Popups.SunkenField {
                    Layout.fillWidth: true
                    implicitHeight: MenuStyle.rowHeight * 3
                    Popups.EmptyState { anchors.centerIn: parent; width: parent.width; glyph: "\ue7f6"; text: "No notifications" }
                }
                Head { text: "ContextMenuBody" }
                Popups.ContextMenuBody {
                    currentIndex: 1
                    model: [
                        { text: "Open", glyph: "\ue2c8" },
                        { text: "Open with...", trailing: "Shift+Enter" },
                        { separator: true },
                        { text: "Pinned", checked: true },
                        { text: "Uninstall", glyph: "\ue872", enabled: false },
                        { separator: true },
                        { text: "Properties" }
                    ]
                }
                Item { Layout.fillHeight: true }
            }

            // ---------- column 3: fields, meters ----------
            ColumnLayout {
                id: col3
                x: page.outer * 3 + page.colW * 2; y: page.outer
                width: page.colW
                spacing: MenuStyle.gap

                Head { text: "SearchBox" }
                Popups.SearchBox { Layout.fillWidth: true; placeholder: "Search..." }
                Popups.SearchBox { Layout.fillWidth: true; text: "some text" }
                Head { text: "SunkenField" }
                Popups.SunkenField {
                    Layout.fillWidth: true
                    implicitHeight: MenuStyle.rowHeight * 2
                    Cap { text: "plain sunken well" }
                }
                Head { text: "SegmentBar" }
                Popups.SegmentBar { Layout.fillWidth: true; implicitHeight: MenuStyle.rowHeight; value: 0 }
                Popups.SegmentBar { Layout.fillWidth: true; implicitHeight: MenuStyle.rowHeight; value: 0.5 }
                Popups.SegmentBar { Layout.fillWidth: true; implicitHeight: MenuStyle.rowHeight; value: 1 }
                Popups.SegmentBar { Layout.fillWidth: true; implicitHeight: MenuStyle.rowHeight; value: 0.7; dim: true }
                Head { text: "RetroSlider" }
                Popups.RetroSlider { Layout.fillWidth: true; value: 0.6 }
                Popups.RetroSlider { Layout.fillWidth: true; value: 0.3; dim: true }
                Popups.RetroSlider { Layout.fillWidth: true; value: 0.45; fill: true }
                Head { text: "RetroScrollBar" }
                Popups.SunkenField {
                    Layout.fillWidth: true
                    implicitHeight: MenuStyle.rowHeight * 5 + 2 * padding
                    padding: MenuStyle.space2
                    ListView {
                        id: galleryList
                        anchors.fill: parent
                        clip: true
                        model: 20
                        contentY: MenuStyle.rowHeight * 6
                        delegate: Popups.MenuRow {
                            required property int index
                            width: galleryList.width - MenuStyle.scrollBarWidth
                            text: "Row " + (index + 1)
                            glyph: "\ue873"
                            selected: index === 7
                        }
                        ScrollBar.vertical: Popups.RetroScrollBar {}
                    }
                }
                Head { text: "ConfirmBar" }
                Popups.ConfirmBar { Layout.fillWidth: true; message: "Reboot now?"; verb: "Reboot" }
                Popups.ConfirmBar { Layout.fillWidth: true; message: "End pipewire? It is a core process."; verb: "End anyway"; glyph: "\ue002" }
                Head { text: "TabPage" }
                Popups.TabPage {
                    Layout.fillWidth: true
                    implicitHeight: MenuStyle.tabHeight + MenuStyle.rowHeight * 2
                    tabs: [{ key: "home", text: "Home" }, { key: "cal", text: "Calendar" }, { key: "phone", text: "Phone" }]
                    current: "cal"
                    Popups.MenuRow { width: parent.width; text: "Page content"; glyph: "\ue935" }
                }
                Head { text: "StatusBar" }
                Popups.StatusBar { text: "Ready"; trailing: "42 games" }
                Popups.StatusBar { text: "Steam library not found"; kind: "error" }
                Popups.StatusBar { text: "Playing on Phone"; highlighted: true }
                Head { text: "MenuSeparator / Gripper / FocusRect" }
                Popups.MenuSeparator { Layout.fillWidth: true }
                Row {
                    spacing: MenuStyle.pad
                    Gripper {}
                    Popups.MenuSeparator { vertical: true }
                    Rectangle {
                        implicitWidth: page.swatchW * 2; implicitHeight: MenuStyle.rowHeight
                        color: Config.colors.base
                        FocusRect { anchors.fill: parent; anchors.margins: 2; color: Config.colors.text }
                    }
                }
                Head { text: "Text" }
                Cap { text: "Monaco 12: The quick brown fox" }
                Cap { text: "Monaco 16: The quick brown"; font.pixelSize: MenuStyle.lyricsFontSize }
                Cap { text: "Charcoal title"; font.family: MenuStyle.titleFont; font.bold: true }
                Cap { text: "Bar centre font (barStrongFont)"; font.family: MenuStyle.barStrongFont; font.pixelSize: MenuStyle.barStrongFontSize }
                Row {
                    spacing: MenuStyle.pad
                    Cap { text: "icons 16 / 20"; anchors.verticalCenter: parent.verticalCenter }
                    Cap { text: "\ue8b8"; font.family: MenuStyle.iconFont; font.pixelSize: MenuStyle.iconSize }
                    Cap { text: "\ue8b8"; font.family: MenuStyle.iconFont; font.pixelSize: MenuStyle.iconSizeLarge }
                }
                RetroText { text: "RetroText disabledLook"; disabledLook: true; font.family: MenuStyle.bodyFont; font.pixelSize: MenuStyle.fontSize }
                Item { Layout.fillHeight: true }
            }

            // ---------- full width: the bar's right side, boxes (today) vs one tray well (B1) ----------
            ColumnLayout {
                id: barStrip
                x: page.outer
                y: page.outer * 2 + page.columnsHeight
                width: page.width - 2 * page.outer
                spacing: MenuStyle.gap
                Head { text: "Bar centre title (strong)" }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: MenuStyle.barHeight
                    color: Config.colors.base
                    BarButton {
                        anchors.centerIn: parent
                        iconFontValue: ""; interactive: false; tucked: true; strong: true; dim: false
                        label: "The Books - Smells Like Content"
                    }
                }
                Head { text: "Bar right side: a box per item (today) / one tray well (B1)" }
                component BarStrip: Rectangle {
                    default property alias items: stripRow.data
                    Layout.fillWidth: true
                    implicitHeight: MenuStyle.barHeight
                    color: Config.colors.base
                    Row {
                        id: stripRow
                        anchors.right: parent.right
                        anchors.rightMargin: MenuStyle.space8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: MenuStyle.gap
                    }
                }
                BarStrip {
                    Gripper { anchors.verticalCenter: parent.verticalCenter }
                    BarButton { iconFontValue: "\uefef" }
                    BarButton { iconFontValue: ""; label: "CPU   2% 46\u00b0 GPU 36\u00b0 RAM 30%" }
                    BarButton { iconFontValue: "\ue1b2"; label: "ETH"; interactive: false; dim: true }
                    BarButton { iconFontValue: "\ue1a7"; label: "ON"; isToggled: true; toggledIconFontValue: "" }
                    BarButton { iconFontValue: "\ue7f4"; label: "4\u00b0C | Fri 6 Nov | 00:33" }
                }
                BarStrip {
                    BarWell {
                        anchors.verticalCenter: parent.verticalCenter
                        BarButton { flat: true; iconFontValue: "\uefef" }
                        Popups.MenuSeparator { vertical: true }
                        BarButton { flat: true; iconFontValue: ""; label: "CPU   2% 46\u00b0 GPU 36\u00b0 RAM 30%" }
                        Popups.MenuSeparator { vertical: true }
                        BarButton { flat: true; iconFontValue: "\ue1b2"; label: "ETH"; interactive: false; dim: true }
                        Popups.MenuSeparator { vertical: true }
                        BarButton { flat: true; iconFontValue: "\ue1a7"; label: "ON"; isToggled: true; toggledIconFontValue: "" }
                        Popups.MenuSeparator { vertical: true }
                        BarButton { flat: true; iconFontValue: "\ue7f4"; label: "4\u00b0C  Fri 6 Nov  00:33" }
                    }
                }
            }

            // Save the page once everything has settled, then quit (QS_GALLERY_OUT = the PNG path)
            Timer {
                interval: 900
                running: true
                onTriggered: page.grabToImage(function (r) {
                    console.log("gallery saved:", r.saveToFile(Quickshell.env("QS_GALLERY_OUT")));
                    Qt.quit();
                })
            }
        }
    }
}
