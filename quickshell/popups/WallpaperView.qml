import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import ".."
// Qt Controls has its own MenuSeparator; ours is reached through Local
import "." as Local
import "../utils" as Utils

// The wallpaper browser's content (the window is WallpaperBrowser.qml): a grid of the images in the
// wallpaper folder, which monitor(s) to set and how the image fits, and Set. The host owns the
// search box and feeds `query`; it forwards arrows / Enter to move() and activateKey().
// Data and the hyprpaper calls: WallpaperState.
Item {
    id: root

    property string query: ""
    signal focusSearch()

    property int cursor: 0
    property string target: "all"          // "all" or an output name
    property string fit: "cover"           // "" = the chosen monitors have different fits and none was picked yet
    property string seek: ""               // file name to put the cursor on once the list has it

    readonly property var fits: ["cover", "contain", "fill", "tile"]
    readonly property var prepared: WallpaperState.files.map(n => ({ name: Utils.Fuzzy.prepare(n), file: n }))
    readonly property var results: root.query === "" ? WallpaperState.files : Utils.Fuzzy.go(root.query, root.prepared, { all: true, key: "name" }).map(r => r.obj.file)
    readonly property string current: root.results[root.cursor] || ""

    onQueryChanged: root.cursor = 0
    onTargetChanged: root.loadFit()

    // The cursor goes to the picture the main monitor (DP-2, else the first saved one) shows. The list
    // may still be loading when the browser opens, so it is looked up again whenever it changes.
    function seekNow() {
        if (root.seek === "")
            return;
        const i = root.results.indexOf(root.seek);
        if (i < 0)
            return;
        root.seek = "";
        root.cursor = i;
        grid.positionViewAtIndex(i, GridView.Contain);
    }

    // The saved fit of the chosen monitor(s); different fits under "All" leave no fit chip checked
    function loadFit() {
        const saved = WallpaperState.monitors;
        const fits = [];
        for (const m of root.outputs()) {
            const f = saved[m] && saved[m].fit;
            if (f && fits.indexOf(f) === -1)
                fits.push(f);
        }
        root.fit = fits.length === 1 ? fits[0] : fits.length === 0 ? "cover" : "";
    }
    onResultsChanged: {
        root.seekNow();
        if (root.cursor >= root.results.length)
            root.cursor = Math.max(0, root.results.length - 1);
    }

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    readonly property var screenNames: Quickshell.screens.map(s => s.name).filter(n => n !== "")

    function outputs() {
        return root.target === "all" ? root.screenNames : [root.target];
    }

    // ~ for the home folder, so the status line stays short
    function tilde(path) {
        const home = Quickshell.env("HOME");
        return path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    function apply(name, colours) {
        if (name === "")
            return;
        WallpaperState.setWallpaper(WallpaperState.pathOf(name), root.outputs(), root.fit || "cover", colours === true);
    }

    function move(d) {
        if (root.results.length === 0)
            return;
        root.cursor = Math.max(0, Math.min(root.results.length - 1, root.cursor + d));
        grid.positionViewAtIndex(root.cursor, GridView.Contain);
    }

    // Enter sets the wallpaper, Shift+Enter also makes the colours from it
    function activateKey(event) {
        root.apply(root.current, event !== null && (event.modifiers & Qt.ShiftModifier) !== 0);
    }

    function reset() {
        root.cursor = 0;
        const saved = WallpaperState.monitors;
        const main = saved["DP-2"] ? "DP-2" : Object.keys(saved)[0];
        root.seek = main ? saved[main].path.split("/").pop() : "";
        root.seekNow();
        root.loadFit();
        WallpaperState.refresh();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: MenuStyle.pad

        // Grid
        SunkenField {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 2
            clip: true

            EmptyState {
                anchors.centerIn: parent
                width: parent.width - 4 * MenuStyle.pad
                visible: root.results.length === 0
                glyph: !WallpaperState.loaded ? "\ue88b" : (WallpaperState.folderSlow || WallpaperState.folderMissing) ? "\ue000" : root.query !== "" ? "\ue8b6" : "\ue1bc"
                text: !WallpaperState.loaded ? "Looking for wallpapers..."
                    : WallpaperState.folderSlow ? "Wallpaper folder is not answering\n" + WallpaperState.folder
                    : WallpaperState.folderMissing ? "No folder " + WallpaperState.folder + "\nMake it and put images in it (png, jpg, webp)"
                    : root.query !== "" ? "No matches"
                    : "No images in " + WallpaperState.folder
            }

            GridView {
                id: grid
                anchors.fill: parent
                readonly property int gutter: ScrollBar.vertical.visible ? MenuStyle.scrollBarWidth : 0
                cellWidth: (width - gutter) / MenuStyle.wallGridColumns
                ScrollBar.vertical: RetroScrollBar {}
                cellHeight: (cellWidth - 2 * MenuStyle.gap) * 9 / 16 + MenuStyle.rowHeight + 2 * MenuStyle.gap
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
                    readonly property string path: WallpaperState.pathOf(modelData)
                    readonly property var on: WallpaperState.shownOn(path)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: cell.isCurrent ? MenuStyle.selectBar : (cellMouse.containsMouse ? Config.colors.shadow : "transparent")

                        SunkenField {
                            id: thumb
                            x: MenuStyle.gap
                            y: MenuStyle.gap
                            width: parent.width - 2 * MenuStyle.gap
                            height: (width) * 9 / 16
                            padding: MenuStyle.spotifyInset
                            Image {
                                id: img
                                anchors.fill: parent
                                source: root.fileUrl(cell.path)
                                sourceSize.width: MenuStyle.wallThumbDecodeWidth
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                anchors.centerIn: parent
                                visible: img.status !== Image.Ready
                                font.family: MenuStyle.iconFont
                                font.pixelSize: MenuStyle.spotifyTileIcon
                                color: MenuStyle.bevelDark
                                text: img.status === Image.Error ? "\ue3ad" : "\ue3f4"
                            }
                        }
                        // Name, and the monitors showing it on the right
                        Item {
                            x: MenuStyle.gap
                            y: thumb.y + thumb.height
                            width: thumb.width
                            height: MenuStyle.rowHeight
                            Text {
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                textFormat: Text.PlainText
                                anchors.left: parent.left
                                anchors.right: onLabel.left
                                anchors.rightMargin: onLabel.text === "" ? 0 : MenuStyle.gap
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: cell.isCurrent ? MenuStyle.selectText : Config.colors.text
                                text: cell.modelData
                            }
                            Text {
                                id: onLabel
                                renderType: Text.NativeRendering
                                font.hintingPreference: Font.PreferFullHinting
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: MenuStyle.bodyFont
                                font.pixelSize: MenuStyle.fontSize
                                color: cell.isCurrent ? MenuStyle.selectText : MenuStyle.bevelDark
                                text: cell.on.join(" ")
                            }
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
                        onClicked: {
                            root.cursor = cell.index;
                            root.focusSearch();
                        }
                        onDoubleClicked: root.apply(cell.modelData, false)
                    }
                }
            }
        }

        // Monitor, fit, Set
        RowLayout {
            Layout.fillWidth: true
            spacing: MenuStyle.gap
            Repeater {
                model: ["all"].concat(root.screenNames)
                BevelButton {
                    text: modelData === "all" ? "All" : modelData
                    checked: root.target === modelData
                    focusPolicy: Qt.NoFocus
                    onClicked: root.target = modelData
                }
            }
            Local.MenuSeparator {
                vertical: true
            }
            Repeater {
                model: root.fits
                BevelButton {
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    checked: root.fit === modelData
                    focusPolicy: Qt.NoFocus
                    onClicked: root.fit = modelData
                }
            }
            Item { Layout.fillWidth: true }
            BevelButton {
                text: Config.settings.currentTheme === "wallpaper" ? "Set + theme" : "Set + colours"
                glyph: "\ue40a"
                enabled: root.current !== ""
                focusPolicy: Qt.NoFocus
                onClicked: root.apply(root.current, true)
            }
            BevelButton {
                text: "Set"
                glyph: "\ue876"
                enabled: root.current !== ""
                focusPolicy: Qt.NoFocus
                onClicked: root.apply(root.current, false)
            }
        }

        // Status: an error from hyprpaper (urgent icon, normal text: urgent text on base is
        // unreadable), else the selected file, else the folder
        RowLayout {
            Layout.fillWidth: true
            spacing: MenuStyle.gap
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                visible: WallpaperState.status !== ""
                font.family: MenuStyle.iconFont
                font.pixelSize: MenuStyle.iconSize
                color: Config.colors.urgent
                text: "error"
            }
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                textFormat: Text.PlainText
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                font.family: MenuStyle.bodyFont
                font.pixelSize: MenuStyle.fontSize
                color: WallpaperState.status !== "" ? Config.colors.text : MenuStyle.bevelDark
                text: WallpaperState.status !== "" ? WallpaperState.status
                    : WallpaperState.info !== "" ? WallpaperState.info
                    : root.current !== "" ? (root.cursor + 1) + " / " + root.results.length + "   " + root.current + "   in " + root.tilde(WallpaperState.folder)
                    : root.tilde(WallpaperState.folder)
            }
        }
    }
}
