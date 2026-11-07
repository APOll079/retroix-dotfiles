pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "popups" as Popups

// The three reference windows you keep open while you work: the cheat sheet ("keys", title "Keys"), the Network page
// ("network") and the Services panel ("services"). Each is a real window (an xdg toplevel Hyprland floats, centres, moves
// and resizes; rules "keys-window", "network-window", "services-window" in windowrules.lua), ONE for the whole desktop,
// not one per monitor. Everything goes through open(id) / close(id) / toggle(id); isOpen(id) and the three `*Visible`
// properties are readable. Opening an open window focuses it where it is, never a second window. Closing hides it (Esc,
// Super+Q, toggle); the next open resets its state and re-reads its data (binds, the service list, the network answers).
// Callers: the IpcHandlers in shell.qml (`keys`, `network`, `services`, and the old per-monitor target names), Start >
// Keys, the ETH button, Settings > System tools, and the failed-service toast's Details (showServiceDetails).
Singleton {
    id: root

    readonly property bool keysVisible: keys.visible
    readonly property bool networkVisible: network.visible
    readonly property bool servicesVisible: services.visible

    // id: "keys" | "network" | "services"
    function win(id) {
        return id === "keys" ? keys : id === "network" ? network : id === "services" ? services : null;
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
}
