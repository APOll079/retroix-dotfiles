pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Idle handling (settings.json "idle"): dim, then lock with hyprlock, then screens off.
// All three respect idle inhibitors, so caffeine (or a fullscreen video that inhibits) pauses
// them. A step with 0 minutes is off.
Singleton {
    id: root

    readonly property var cfg: Config.settings.idle
    // Caffeine: Bar.qml holds an IdleInhibitor bound to this. It survives a Quickshell reload and restart
    // (qs-caffeine.json in XDG_RUNTIME_DIR, which the system clears at logout). Without a runtime dir it
    // just isn't remembered. Read and write it like a plain property.
    property bool caffeine: false
    onCaffeineChanged: {
        if (root.runDir !== "" && saved.caffeine !== root.caffeine)
            saved.caffeine = root.caffeine;
    }

    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    // Read before the first use, so the bar's inhibitor and button never flash the wrong state
    GuardedFileView {
        id: store
        path: root.runDir !== "" ? root.runDir + "/qs-caffeine.json" : ""
        blockLoading: true
        printErrors: false
        onLoaded: root.caffeine = saved.caffeine
        JsonAdapter {
            id: saved
            property bool caffeine: false
        }
    }
    // blockLoading makes text() wait for the file; the adapter itself fills in a moment later (onLoaded)
    Component.onCompleted: {
        try {
            root.caffeine = JSON.parse(store.text()).caffeine === true;
        } catch (e) {}
    }

    readonly property bool dimmed: cfg.enabled && cfg.dimMinutes > 0 && dimMonitor.isIdle

    IdleMonitor {
        id: dimMonitor
        enabled: root.cfg.enabled && root.cfg.dimMinutes > 0
        respectInhibitors: true
        timeout: root.cfg.dimMinutes * 60
    }

    IdleMonitor {
        id: lockMonitor
        enabled: root.cfg.enabled && root.cfg.lockMinutes > 0
        respectInhibitors: true
        timeout: root.cfg.lockMinutes * 60
        onIsIdleChanged: {
            if (isIdle)
                Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock"]);
        }
    }

    IdleMonitor {
        id: screenMonitor
        enabled: root.cfg.enabled && root.cfg.screenOffMinutes > 0
        respectInhibitors: true
        timeout: root.cfg.screenOffMinutes * 60
        onIsIdleChanged: Hyprland.dispatch(isIdle ? "hl.dsp.dpms({ action = \"disable\" })" : "hl.dsp.dpms({ action = \"enable\" })")
    }
}
