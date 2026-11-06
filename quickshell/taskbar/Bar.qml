import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "../popups" as Popups
import ".."

Scope {
Variants {
model: Quickshell.screens
Item {
id: root
required property var modelData
property int currentPopup: Config.SystemPopup.None
onCurrentPopupChanged: MenuState.setOpen(root.modelData.name, root.currentPopup != Config.SystemPopup.None)
// An unplugged monitor must not leave its flag set (the other bar's click catcher would stay up)
Component.onDestruction: MenuState.setOpen(root.modelData.name, false)
// A click on any monitor's click catcher closes the menus of every bar
Connections {
target: MenuState
function onCloseAll() {
if (root.currentPopup != Config.SystemPopup.None)
taskbar.closeAllPopups();
}
}

PanelWindow {
id: taskbar
screen: root.modelData
WlrLayershell.layer: WlrLayer.Bottom
WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
anchors {
top: true
left: true
right: true
}
implicitHeight: MenuStyle.barHeight

color: Config.colors.base

// Caffeine: keeps the idle timers (dim, lock, screens off) from firing while on
IdleInhibitor {
window: taskbar
enabled: Idle.caffeine
}
Item {
id: taskbarBackground
anchors.fill: parent
NewBorder {
commonBorderWidth: 4
commonBorder: false
lBorderwidth: 10
rBorderwidth: 1
tBorderwidth: 10
bBorderwidth: 1
borderColor: Config.colors.shadow
}
NewBorder {
commonBorderWidth: 4
commonBorder: false
lBorderwidth: 10
rBorderwidth: 10
tBorderwidth: 1
bBorderwidth: 10
borderColor: Config.colors.highlight
}
Rectangle {
id: barBackground
anchors {
fill: parent
margins: 0
}
color: "transparent"
radius: 0
border.width: 1
border.color: Config.colors.outline
}
}

// Left section: gripper, workspaces (plain raised buttons, the active one sunken), etched divider before Start/Theme
Gripper {
id: leftGripper
anchors.verticalCenter: parent.verticalCenter
anchors.left: parent.left
anchors.leftMargin: 8
}
Workspaces {
id: workspaces
anchors.verticalCenter: parent.verticalCenter
anchors.left: leftGripper.right
anchors.leftMargin: MenuStyle.gap
}
Popups.MenuSeparator {
id: leftDivider
vertical: true
anchors.verticalCenter: parent.verticalCenter
anchors.left: workspaces.right
anchors.leftMargin: MenuStyle.gap
}

Popups.StartMenu {
id: startMenu
bar: taskbar
menuWidth: startmenuButton.x
closeCallback: taskbar.closeAllPopups
openPowerMenuCallback: function() { taskbar.toggleMenu(sessionPanel, Config.SystemPopup.SessionPanel, startmenuButton, "left") }
openKeysCallback: function() { taskbar.toggleMenu(cheatSheet, Config.SystemPopup.CheatSheet, null, "keep") }
openSettingsCallback: function() { taskbar.openLauncherMode("settings") }
openUpdatesCallback: function() { taskbar.toggleMenu(updatesMenu, Config.SystemPopup.Updates, null, "keep") }
}
Popups.ThemeMenu {
id: themeMenu
bar: taskbar
menuWidth: themeMenuButton.x
openWallpapers: function() { taskbar.toggleMenu(wallpaperBrowser, Config.SystemPopup.Wallpapers, null, "keep") }
openEditor: function() { taskbar.toggleMenu(themeEditor, Config.SystemPopup.ThemeEditor, null, "keep") }
}
// ThemeMenu has no closeCallback; when it closes itself (picking a theme), reset the shared state.
Connections {
target: themeMenu
function onVisibleChanged() {
if (!themeMenu.visible && root.currentPopup == Config.SystemPopup.ThemePicker) {
root.currentPopup = Config.SystemPopup.None;
}
}
}
Popups.AppLauncher {
id: appLauncher
bar: taskbar
screen: root.modelData
closeCallback: taskbar.closeAllPopups
screenHeight: modelData.height
runAction: function(id) { if (taskbar.toolActions[id]) taskbar.toolActions[id](); }
}

Popups.BluetoothMenu { bar: taskbar; id: bluetoothMenu; closeCallback: taskbar.closeAllPopups }
Popups.SysMonMenu { bar: taskbar; id: sysMonMenu; closeCallback: taskbar.closeAllPopups; openTaskManager: function() { TaskWindow.open("") } }
Popups.SessionPanel { bar: taskbar; id: sessionPanel; closeCallback: taskbar.closeAllPopups }
Popups.ScreenshotPanel { screen: root.modelData; bar: taskbar; id: screenshotPanel; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.ScreenshotOverlay {
id: screenshotOverlay
screen: modelData
historyCallback: function() { taskbar.toggleMenu(screenshotPanel, Config.SystemPopup.Screenshot, null, "keep"); }
}
Popups.GamesMenu { screen: root.modelData; bar: taskbar; id: gamesMenu; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.CheatSheet { screen: root.modelData; bar: taskbar; id: cheatSheet; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.Overview { screen: root.modelData; bar: taskbar; id: overviewPanel; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.ServicesPanel { screen: root.modelData; bar: taskbar; id: servicesPanel; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.UpdatesPanel { screen: root.modelData; bar: taskbar; id: updatesMenu; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.CleanupPanel { screen: root.modelData; bar: taskbar; id: cleanupMenu; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.ColorHistoryPanel { screen: root.modelData; bar: taskbar; id: colorHistoryMenu; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.NetworkPage { screen: root.modelData; bar: taskbar; id: networkPanel; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.ThemeEditor { screen: root.modelData; bar: taskbar; id: themeEditor; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.DefaultAppsPanel { screen: root.modelData; bar: taskbar; id: defaultAppsMenu; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.FixPanel { screen: root.modelData; bar: taskbar; id: fixMenu; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.LoginReportPanel { screen: root.modelData; bar: taskbar; id: loginReportMenu; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.SpotifyPanel { id: spotifyPanel; screen: root.modelData; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }
Popups.SidePanel { screen: root.modelData; bar: taskbar; id: sidePanel; closeCallback: taskbar.closeAllPopups }
Popups.WallpaperBrowser { screen: root.modelData; bar: taskbar; id: wallpaperBrowser; closeCallback: taskbar.closeAllPopups; screenHeight: modelData.height }

// Every menu this bar owns; each has closeMenu()
// The tools the launcher's Settings tab opens (System tools rows; the ids are in popups/SettingsSchema.js, a test checks each one is here)
readonly property var toolActions: ({
defaultApps: function() { taskbar.toggleMenu(defaultAppsMenu, Config.SystemPopup.DefaultApps, null, "keep") },
network: function() { taskbar.toggleMenu(networkPanel, Config.SystemPopup.Network, null, "keep") },
services: function() { taskbar.toggleMenu(servicesPanel, Config.SystemPopup.Services, null, "keep") },
troubleshoot: function() { taskbar.toggleMenu(fixMenu, Config.SystemPopup.Troubleshoot, null, "keep") },
loginReport: function() { taskbar.toggleMenu(loginReportMenu, Config.SystemPopup.LoginReport, null, "keep") },
cleanUp: function() { taskbar.toggleMenu(cleanupMenu, Config.SystemPopup.Cleanup, null, "keep") },
colours: function() { taskbar.toggleMenu(colorHistoryMenu, Config.SystemPopup.ColorHistory, null, "keep") },
updates: function() { taskbar.toggleMenu(updatesMenu, Config.SystemPopup.Updates, null, "keep") }
})

readonly property var menus: [startMenu, themeMenu, appLauncher, bluetoothMenu, sysMonMenu, sessionPanel, screenshotPanel, gamesMenu, cheatSheet, servicesPanel, updatesMenu, cleanupMenu, colorHistoryMenu, defaultAppsMenu, fixMenu, loginReportMenu, networkPanel, overviewPanel, themeEditor, spotifyPanel, sidePanel, wallpaperBrowser]

function closeAllPopups() {
for (var m of taskbar.menus)
if (m.visible)
m.closeMenu();
root.currentPopup = Config.SystemPopup.None;
}

// Open a menu under `item`, or close it if it is already open.
// align: "center" (default, centred on the item, kept on screen), "left" (left edge of the
// item), "right" (flush with the right screen edge) or "keep" (the menu positions itself,
// e.g. the centred launcher).
function toggleMenu(menu, popup, item, align) {
if (menu.visible) {
taskbar.closeAllPopups();
return;
}
// Popups are placed under their bar item; layer-shell panels (launcher, side panel, Spotify
// drawer, ...) place themselves and have no anchor
if (menu.anchor) {
if (align === "right") {
menu.anchor.rect.x = taskbar.width - menu.implicitWidth - 4;
} else if (align !== "keep") {
var pos = item.mapToItem(taskbar.contentItem, 0, 0);
if (align === "left") {
menu.anchor.rect.x = pos.x;
} else {
var x = Math.round(pos.x + item.width / 2 - menu.implicitWidth / 2);
menu.anchor.rect.x = Math.max(4, Math.min(x, taskbar.width - menu.implicitWidth - 4));
}
}
menu.anchor.rect.y = taskbar.implicitHeight;
}
taskbar.closeAllPopups();
root.currentPopup = popup;
menu.openMenu();
}

// Open the launcher in another mode (clipboard, windows); toggles it off if already there
function openLauncherMode(mode, standalone) {
if (appLauncher.visible && appLauncher.mode === mode) {
taskbar.closeAllPopups();
return;
}
taskbar.closeAllPopups();
root.currentPopup = Config.SystemPopup.AppLauncher;
appLauncher.open(mode, standalone === true);
}

// Toggle the side panel; when it opens, it opens on `tab`.
function openSidePanel(tab, item) {
if (!sidePanel.visible) {
sidePanel.tab = tab;
}
taskbar.toggleMenu(sidePanel, Config.SystemPopup.SidePanel, item, "right");
}

BarButton {
id: startmenuButton
toggledIconFontValue: ""
isToggled: root.currentPopup == Config.SystemPopup.Startmenu
label: "Start"
anchors.left: leftDivider.right
anchors.verticalCenter: parent.verticalCenter
anchors.leftMargin: MenuStyle.gap
onClicked: taskbar.toggleMenu(startMenu, Config.SystemPopup.Startmenu, startmenuButton, "left")
}
BarButton {
id: themeMenuButton
toggledIconFontValue: ""
isToggled: root.currentPopup == Config.SystemPopup.ThemePicker
iconFontValue: "\ue3ae"
label: "Themes"
anchors.left: startmenuButton.right
anchors.verticalCenter: parent.verticalCenter
anchors.leftMargin: 4
onClicked: taskbar.toggleMenu(themeMenu, Config.SystemPopup.ThemePicker, themeMenuButton, "left")
}
// Wallpapers live in the Themes menu ("Wallpapers..."), Services in the Start menu (Services); neither has its own bar button.
// Bar middle: the current Spotify lyric line (Lyrics.qml), else "Artist - Title"; dimmed while
// paused. With no Spotify, another playing MPRIS player (YouTube in Zen, VLC...) is shown instead (Media.barPlayer).
BarButton {
id: nowPlaying
visible: Media.text !== ""
anchors.centerIn: parent
iconFontValue: ""
interactive: false
tucked: true
strong: true
dim: Media.paused
label: Lyrics.line !== "" && !Media.paused ? Lyrics.line : Media.text
maxLabelWidth: Math.max(0, Math.min(MenuStyle.barMediaMaxWidth, taskbar.centreRoom(trayWell.x)))
// Left click: the Spotify drawer; middle click: play / pause (Spotify, else the other player shown); right click:
// Like / Unlike and Add to playlist for the current Spotify song
MouseArea {
anchors.fill: parent
acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
cursorShape: Qt.PointingHandCursor
onClicked: mouse => {
if (mouse.button === Qt.MiddleButton) {
const p = Media.barPlayer;
if (p && p.canTogglePlaying)
p.togglePlaying();
} else if (mouse.button === Qt.RightButton) {
Media.likeMenu(() => {
if (!spotifyPanel.visible)
taskbar.toggleMenu(spotifyPanel, Config.SystemPopup.Spotify, null, "keep");
spotifyPanel.toggleAddMode();
}, m => {
likeMenu.model = m;
likeMenu.openAt(nowPlaying, mouse.x, mouse.y);
});
} else {
taskbar.toggleMenu(spotifyPanel, Config.SystemPopup.Spotify, null, "keep");
}
}
}
Popups.PopupMenu {
id: likeMenu
}
}

IpcHandler {
target: "appLauncher_" + taskbar.screen.name
function toggleAppLauncher() {
taskbar.toggleMenu(appLauncher, Config.SystemPopup.AppLauncher, null, "keep");
}
// Super+Shift+comma: the launcher on its Settings tab
function settings() {
taskbar.openLauncherMode("settings");
}
// Super+V: clipboard history in the launcher
function clipboard() {
taskbar.openLauncherMode("clipboard", true);
}
// Super+Tab: open windows in the launcher (type to filter, Enter focuses)
function windows() {
taskbar.openLauncherMode("windows");
}
}

// The Task Manager is one window for every monitor (TaskWindow.qml); this old target still
// opens / focuses it
IpcHandler {
target: "taskmanager_" + taskbar.screen.name
function toggle() {
TaskWindow.open("");
}
}

// Super+Q: close an open menu (or the snipping overlay) instead of the window behind it.
// Answers "true" when it closed something, so the bind knows not to close the window.
IpcHandler {
target: "menus_" + taskbar.screen.name
function closeAny(): string {
if (screenshotOverlay.visible) {
screenshotOverlay.close();
return "true";
}
if (!taskbar.menus.some(function(m) { return m.visible; }))
return "false";
taskbar.closeAllPopups();
return "true";
}
}

IpcHandler {
target: "screenshot_" + taskbar.screen.name
// Snipping overlay (Super+Shift+S, Print)
function toggle() {
if (screenshotOverlay.visible) {
screenshotOverlay.close();
return;
}
// Open menus stay open, so they end up in the frozen frame
screenshotOverlay.open();
}
// History grid
function history() {
taskbar.toggleMenu(screenshotPanel, Config.SystemPopup.Screenshot, null, "keep");
}
}

IpcHandler {
target: "games_" + taskbar.screen.name
function toggle() {
taskbar.toggleMenu(gamesMenu, Config.SystemPopup.Games, null, "keep");
}
}

IpcHandler {
target: "themeeditor_" + root.modelData.name
function toggle() {
taskbar.toggleMenu(themeEditor, Config.SystemPopup.ThemeEditor, null, "keep");
}
}

IpcHandler {
target: "overview_" + root.modelData.name
function toggle() {
taskbar.toggleMenu(overviewPanel, Config.SystemPopup.Overview, null, "keep");
}
}

IpcHandler {
target: "network_" + root.modelData.name
function toggle() {
taskbar.toggleMenu(networkPanel, Config.SystemPopup.Network, null, "keep");
}
}

IpcHandler {
target: "mic_" + root.modelData.name
function toggle() {
AudioState.toggleMic();
}
}

IpcHandler {
target: "colorhistory_" + root.modelData.name
function toggle() {
taskbar.toggleMenu(colorHistoryMenu, Config.SystemPopup.ColorHistory, null, "keep");
}
}

IpcHandler {
target: "record_" + root.modelData.name
function toggle() {
if (RecordState.recording) {
RecordState.stop();
return;
}
screenshotOverlay.open();
screenshotOverlay.setRecord(true);
}
function stopRecord() {
RecordState.stop();
}
function pauseToggle() {
RecordState.togglePause();
}
function replayToggle() {
RecordState.replayToggle(root.modelData.name);
}
function replaySave() {
RecordState.replaySave();
}
}

IpcHandler {
target: "cheatsheet_" + taskbar.screen.name
function toggle() {
taskbar.toggleMenu(cheatSheet, Config.SystemPopup.CheatSheet, null, "keep");
}
}

IpcHandler {
target: "spotify_" + taskbar.screen.name
function toggle() {
taskbar.toggleMenu(spotifyPanel, Config.SystemPopup.Spotify, null, "keep");
}
}

// A failed-service toast's Details: the Services panel on the focused monitor, on that service's log
Connections {
target: ServiceWatch
function onDetailsRequested(name) {
if (!Hyprland.focusedMonitor || Hyprland.focusedMonitor.name !== root.modelData.name)
return;
if (!servicesPanel.visible)
taskbar.toggleMenu(servicesPanel, Config.SystemPopup.Services, null, "keep");
servicesPanel.showDetails(name);
}
}

IpcHandler {
target: "services_" + taskbar.screen.name
function toggle() {
taskbar.toggleMenu(servicesPanel, Config.SystemPopup.Services, null, "keep");
}
}

IpcHandler {
target: "session_" + taskbar.screen.name
function toggle() {
taskbar.toggleMenu(sessionPanel, Config.SystemPopup.SessionPanel, startmenuButton, "left");
}
}

IpcHandler {
target: "notifications_" + taskbar.screen.name
function toggle() {
taskbar.openSidePanel(0, null);
}
}

// Room for the centre text's label: it is centred, so twice the smaller distance from the middle
// to either side, minus its own padding and a gap of clearance on each side. Never overlaps.
function centreRoom(rightStart) {
var leftEnd = themeMenuButton.x + themeMenuButton.width;
return 2 * Math.min(taskbar.width / 2 - leftEnd, rightStart - taskbar.width / 2) - 4 * MenuStyle.gap;
}
// The sysmon button's GPU part goes first when the centre text needs more room than is left
// (up to barMediaMinWidth; a short title never costs the GPU part).
// Worked out as if the GPU part were shown (so hiding it can't flip it back): where the right
// section's gripper would start then.
readonly property real rightStartWithGpu: taskbar.width - trayWell.anchors.rightMargin - laptopControls.widthWithGpu - trayRest.width - sysTray.width - 2 * MenuStyle.barWellPad - 2 - 2 * MenuStyle.gap
TextMetrics {
id: nowPlayingMetrics
font.family: MenuStyle.barStrongFont
font.pixelSize: MenuStyle.barStrongFontSize
text: nowPlaying.label
}

// Right section: raised, boxed buttons with a gap between them (the BarWell is plain, no sunken frame):
// [privacy, caffeine] [sysmon] [ETH] [Bluetooth] | tray icons | [bell + weather + clock]
BarWell {
id: trayWell
plain: true
spacing: MenuStyle.gap
anchors.verticalCenter: parent.verticalCenter
anchors.right: parent.right
anchors.rightMargin: MenuStyle.gap
LaptopControls {
id: laptopControls
currentPopup: root.currentPopup
toggleMenu: taskbar.toggleMenu
openPhoneTab: function(item) { taskbar.openSidePanel(2, item) }
openNetwork: function() { taskbar.toggleMenu(networkPanel, Config.SystemPopup.Network, null, "keep") }
bluetoothMenuRef: bluetoothMenu
sysMonMenuRef: sysMonMenu
showGpu: Media.text === "" || taskbar.centreRoom(taskbar.rightStartWithGpu) >= Math.min(MenuStyle.barMediaMinWidth, nowPlayingMetrics.advanceWidth)
}
Popups.MenuSeparator {
id: trayRest
vertical: true
}
SysTray {
id: sysTray
clockToggled: root.currentPopup == Config.SystemPopup.SidePanel
onClockClicked: item => taskbar.openSidePanel(0, item)
}
}
}

PanelWindow {
id: overlay
screen: root.modelData
color: "transparent"
anchors {
top: true
bottom: true
left: true
right: true
}
// Shown on every monitor while any bar has a menu open, so a click on either screen closes it
visible: root.currentPopup != Config.SystemPopup.None || MenuState.anyOpen
exclusionMode: ExclusionMode.Ignore
// Leave the bar itself uncovered so its buttons keep their hover and clicks while a menu is open
margins.top: MenuStyle.barHeight
MouseArea {
id: popupArea
anchors.fill: parent
onClicked: MenuState.closeAll()
}
}
}
}
}