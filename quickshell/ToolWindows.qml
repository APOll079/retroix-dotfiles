pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "popups" as Popups

// The reference windows you keep open while you work: the cheat sheet ("keys", title "Keys"), the Network page
// ("network"), the Services panel ("services") and Settings ("settings"). Each is a real window (an xdg toplevel Hyprland floats, centres, moves
// and resizes; rules "keys-window", "network-window", "services-window", "settings-window" in windowrules.lua), ONE for the whole desktop,
// not one per monitor. Everything goes through open(id) / close(id) / toggle(id); isOpen(id) and the three `*Visible`
// properties are readable. Opening an open window focuses it where it is, never a second window. Closing hides it (Esc,
// Super+Q, toggle); the next open resets its state and re-reads its data (binds, the service list, the network answers).
// Callers: the IpcHandlers in shell.qml (`keys`, `network`, `services`, and the old per-monitor target names), Start >
// Keys / Settings, the ETH button, Settings > System tools, and the failed-service toast's Details (showServiceDetails).
// Settings' System tools rows that are popups of a bar (Default apps, Troubleshoot, ...) go through runTool(id): every Bar
// registers its toolActions here (registerTools), and the one on the focused monitor opens the tool.
Singleton {
    id: root

    readonly property bool keysVisible: keys.visible
    readonly property bool networkVisible: network.visible
    readonly property bool servicesVisible: services.visible
    readonly property bool settingsVisible: settings.visible

    // monitor name -> that bar's toolActions ({ id: function })
    property var toolSets: ({})
    function registerTools(monitor: string, actions: var) {
        const t = Object.assign({}, root.toolSets);
        t[monitor] = actions;
        root.toolSets = t;
    }
    function unregisterTools(monitor: string) {
        const t = Object.assign({}, root.toolSets);
        delete t[monitor];
        root.toolSets = t;
    }
    // Opens a System tool by id (SettingsSchema.js action ids), through the focused monitor's bar (else the first one)
    function runTool(id: string) {
        const names = Object.keys(root.toolSets);
        if (names.length === 0)
            return;
        const fm = Hyprland.focusedMonitor;
        const set = root.toolSets[fm && names.indexOf(fm.name) >= 0 ? fm.name : names[0]];
        if (set && set[id])
            set[id]();
    }

    // id: "keys" | "network" | "services" | "settings"
    function win(id) {
        return id === "keys" ? keys : id === "network" ? network : id === "services" ? services : id === "settings" ? settings : null;
    }

    function isOpen(id) {
        const w = root.win(id);
        return w !== null && w.visible;
    }

    function open(id) {
        const w = root.win(id);
        if (!w)
            return;
        if (w.visible)
            root.focusWindow(w);
        else
            w.openMenu();
    }

    function close(id) {
        const w = root.win(id);
        if (w)
            w.closeMenu();
    }

    function toggle(id) {
        if (root.isOpen(id))
            root.close(id);
        else
            root.open(id);
    }

    // The toast's Details: the Services window on that service's log (opens it, or re-points the open one)
    function showServiceDetails(name) {
        services.showDetails(name);
        root.focusWindow(services);
    }

    // The window's own toplevel: this title, this process (the address form TaskManager uses)
    function focusWindow(w) {
        const t = Hyprland.toplevels.values.find(x => x.title === w.title && x.lastIpcObject && x.lastIpcObject.pid === Quickshell.processId);
        if (t)
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + t.address + "\" })");
    }

    Popups.CheatSheet {
        id: keys
    }
    Popups.NetworkPage {
        id: network
    }
    Popups.ServicesPanel {
        id: services
    }
    Popups.SettingsWindow {
        id: settings
        runTool: function (id) { root.runTool(id); }
    }
}
