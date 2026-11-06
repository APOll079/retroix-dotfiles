import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import ".."

// Workspace overview (`qs ipc call overview_<mon> toggle`): the screen dimmed with the base colour and one framed card
// per workspace of this monitor (title "2 - 3 windows"), each holding its windows as live thumbnails (ScreencopyView; a
// labelled box with the class and title when nothing can be captured). The workspace shown on this monitor has the accent
// title bar and an accent outline. Click a card = switch to that workspace; click a thumbnail = focus that window;
// both close it. Arrow keys move the dotted selection, Enter switches, Escape or a click outside closes.
// The data is Hyprland.workspaces / Hyprland.toplevels turned into plain objects by OverviewState (also the layout, the
// selection moves and the commands); this file only draws them. Names that come from windows are plain text.
// An Overlay-layer panel, like the Services panel: the bar sits below fullscreen windows.
PanelWindow {
    id: root
    // The bar window this panel hangs off (set by Bar.qml)
    required property var bar

    property int screenHeight: 0
    property var closeCallback: function () {}

    property int cursor: 0
    readonly property var scr: root.screen         // (through a var so the screen's members are not lint errors)
    readonly property var os: OverviewState        // (through a var so the singleton's members are not lint errors)
    readonly property var workspaces: root.visible ? Hyprland.workspaces.values.map(w => root.os.wsOf(w)) : []
    readonly property var windows: root.visible ? Hyprland.toplevels.values.map(t => root.os.windowOf(t)).filter(w => w !== null) : []
    readonly property var ownCards: root.os.cardsFor(root.scr ? root.scr.name : "", root.workspaces, root.windows)
    // normally this monitor's workspaces; if none matches this screen's name, all of them (never an empty dim)
    readonly property var cards: root.ownCards.length > 0 ? root.ownCards : root.os.cardsFor("*", root.workspaces, root.windows)
    // the card grid sits between the top edge and the bar, MenuStyle.space12 from the sides
    readonly property int areaW: root.width - 2 * MenuStyle.space12
    readonly property int areaH: root.screenHeight - 2 * MenuStyle.barHeight - 2 * MenuStyle.space12
    readonly property real aspect: root.scr && root.scr.height > 0 ? root.scr.width / root.scr.height : MenuStyle.windowLargeWidth / MenuStyle.windowLargeHeight
    // cards are at most this wide, so one or two do not fill the screen
    readonly property var fit: root.os.gridFit(root.cards.length, root.areaW, root.areaH, MenuStyle.space12, root.aspect, MenuStyle.windowLargeWidth / 2)
    // the dim: the base colour, mostly opaque (a proposed MenuStyle token overviewDimOpacity)
    readonly property real dimOpacity: 1 - MenuStyle.shareDimOpacity

    onCardsChanged: root.cursor = Math.max(0, Math.min(root.cursor, root.cards.length - 1))

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

    function switchTo(id) {
        const cmd = root.os.workspaceCommand(id);
        if (cmd !== "")
            Hyprland.dispatch(cmd);
        root.closeCallback();
    }
    function focusWindow(address) {
        const cmd = root.os.windowCommand(address);
        if (cmd !== "")
            Hyprland.dispatch(cmd);
        root.closeCallback();
    }

    function handleKey(event) {
        const names = {};
        names[Qt.Key_Left] = "left";
        names[Qt.Key_Right] = "right";
        names[Qt.Key_Up] = "up";
        names[Qt.Key_Down] = "down";
        names[Qt.Key_Home] = "home";
        names[Qt.Key_End] = "end";
        if (event.key === Qt.Key_Escape) {
            root.closeCallback();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cards.length > 0)
                root.switchTo(root.cards[root.cursor].id);
        } else if (names[event.key] !== undefined) {
            root.cursor = root.os.moveSelection(root.cursor, names[event.key], root.fit.cols, root.cards.length);
        } else {
            return;
        }
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        z: -2
        color: Config.colors.base
        opacity: root.dimOpacity
    }
    // Click outside the cards closes
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.closeCallback()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => root.handleKey(event)
    }

    // Nothing to show: say so, with the numbers that explain it (what Hyprland gave, which screen this is)
    EmptyState {
        anchors.centerIn: parent
        width: Math.min(parent.width, MenuStyle.windowWidth)
        visible: root.cards.length === 0
        glyph: "\ue8f5"
        text: "No workspaces found\n" + root.workspaces.length + " from Hyprland, screen " + (root.scr ? root.scr.name : "?")
    }

    // The cards
    Item {
        x: MenuStyle.space12
        y: MenuStyle.barHeight + MenuStyle.space12
        width: root.areaW
        height: root.areaH

        Repeater {
            model: root.cards

            Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool selected: index === root.cursor
                readonly property var pos: root.os.cellPos(index, root.cards.length, root.fit, MenuStyle.space12)
                x: pos.x
                y: pos.y
                width: root.fit.cellW
                height: root.fit.cellH

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.switchTo(card.modelData.id)
                }

                PopupWindowFrame {
                    windowTitle: root.os.cardTitle(card.modelData)
                    active: card.modelData.active

                    EmptyState {
                        anchors.fill: parent
                        visible: card.modelData.windows.length === 0
                        glyph: "\ue8f5"
                        text: "No windows"
                    }

                    // The windows as thumbnails in a grid that keeps the monitor's shape
                    Item {
                        id: thumbs
                        anchors.fill: parent
                        readonly property var windows: card.modelData.windows
                        readonly property var tfit: root.os.gridFit(windows.length, width, height, MenuStyle.gap, root.aspect, 0)

                        Repeater {
                            model: thumbs.windows

                            Item {
                                id: cell
                                required property var modelData
                                required property int index
                                readonly property var pos: root.os.cellPos(index, thumbs.windows.length, thumbs.tfit, MenuStyle.gap)
                                x: pos.x
                                y: pos.y
                                width: thumbs.tfit.cellW
                                height: thumbs.tfit.cellH

                                Rectangle {
                                    anchors.fill: parent
                                    color: Config.colors.outline
                                    clip: true

                                    ScreencopyView {
                                        id: shot
                                        anchors.centerIn: parent
                                        live: true
                                        constraintSize: Qt.size(cell.width, cell.height)
                                        captureSource: root.visible ? cell.modelData.wayland : null
                                    }
                                    // Nothing to show (no capture): class and title, plain text
                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 2 * MenuStyle.gap
                                        visible: !shot.hasContent
                                        spacing: MenuStyle.space2

                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            textFormat: Text.PlainText
                                            font.family: MenuStyle.bodyFont
                                            font.pixelSize: MenuStyle.fontSize
                                            font.bold: true
                                            color: Config.colors.accent
                                            text: cell.modelData.cls
                                        }
                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            renderType: Text.NativeRendering
                                            font.hintingPreference: Font.PreferFullHinting
                                            textFormat: Text.PlainText
                                            font.family: MenuStyle.bodyFont
                                            font.pixelSize: MenuStyle.fontSize
                                            color: Config.colors.base
                                            text: cell.modelData.title
                                        }
                                    }
                                }
                                // the hovered thumbnail gets the accent outline
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.width: 2
                                    border.color: MenuStyle.selectBar
                                    visible: thumbMouse.containsMouse
                                }
                                MouseArea {
                                    id: thumbMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.focusWindow(cell.modelData.address)
                                }
                            }
                        }
                    }
                }

                // The workspace shown on this monitor: an accent outline around the whole card
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: MenuStyle.selectBar
                    visible: card.modelData.active
                }
                // The keyboard selection: the dotted rectangle
                FocusRect {
                    anchors.fill: parent
                    anchors.margins: MenuStyle.space4
                    color: Config.colors.accent
                    visible: card.selected
                }
            }
        }
    }

    function openMenu() {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        root.visible = true;
        root.cursor = root.os.startIndex(root.cards);
        keys.forceActiveFocus();
    }

    function closeMenu() {
        root.visible = false;
    }
}
