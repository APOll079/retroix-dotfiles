// Component gallery (F1): every shared component in every state it can be forced into, on one page.
// Never part of the running shell. Render it with scripts/render-gallery.sh (offscreen, scratch
// copy, one PNG per theme). Hover can't be forced from outside a Button, so BarButton and
// BevelButton hover is not shown here; MenuRow's selected state is the same look and is.
import QtQuick
import QtQuick.Layouts
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
            implicitHeight: Math.max(col1.implicitHeight, col2.implicitHeight, col3.implicitHeight) + outer * 2
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
                            Popups.MenuRow { Layout.fillWidth: true; text: "Normal"; glyph: "\ue88a" }
                            Popups.MenuRow { Layout.fillWidth: true; text: "Selected"; glyph: "\ue88a"; selected: true }
                            Popups.MenuRow { Layout.fillWidth: true; text: "Disabled"; glyph: "\ue88a"; enabled: false }
                            Popups.MenuRow { Layout.fillWidth: true; text: "Marked"; glyph: "\ue88a"; marked: true }
                            Popups.MenuRow { Layout.fillWidth: true; text: "Trailing"; trailing: "Ctrl+Q" }
                            Popups.MenuRow { Layout.fillWidth: true; text: "Two lines"; subtext: "second line, dim"; glyph: "\ue88a" }
                            Popups.MenuSeparator { Layout.fillWidth: true }
                            Popups.MenuRow { Layout.fillWidth: true; text: "No icon, long text that has to be cut off" }
                        }
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
                Cap { text: "Liberation Sans 14 centre"; font.family: MenuStyle.barStrongFont; font.pixelSize: MenuStyle.barStrongFontSize }
                Row {
                    spacing: MenuStyle.pad
                    Cap { text: "icons 16 / 20"; anchors.verticalCenter: parent.verticalCenter }
                    Cap { text: "\ue8b8"; font.family: MenuStyle.iconFont; font.pixelSize: MenuStyle.iconSize }
                    Cap { text: "\ue8b8"; font.family: MenuStyle.iconFont; font.pixelSize: MenuStyle.iconSizeLarge }
                }
                RetroText { text: "RetroText disabledLook"; disabledLook: true; font.family: MenuStyle.bodyFont; font.pixelSize: MenuStyle.fontSize }
                Item { Layout.fillHeight: true }
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
