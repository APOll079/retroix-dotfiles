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

    // Stay awake during video: with settings idle.stayAwakeInFullscreen (default true; a missing key counts as true)
    // the dim / lock / screen-off monitors are off while the focused window is fullscreen (a video). The wlr
    // foreign-toplevel `fullscreen` flag is live, unlike Hyprland's workspace IPC snapshot. Caffeine is separate:
    // it is the IdleInhibitor in Bar.qml and works whatever this says.
    // Pure: should a fullscreen window keep the screen awake?
    // Only video and games count: the focused fullscreen window's app id must match one of idle.stayAwakeApps (regexes,
    // case-insensitive; a missing or empty list uses the defaults). A browser left fullscreen on a page does not hold the screen.
    readonly property var defaultAwakeApps: ["^steam_app_[0-9]+$", "\\.exe$", "^gamescope$", "^mpv$", "^vlc$", "^zen$"]
    function stayAwakeDecision(fullscreen, setting, appId, patterns) {
        if (fullscreen !== true || setting === false)
            return false;
        const list = (patterns && patterns.length > 0) ? patterns : root.defaultAwakeApps;
        for (let i = 0; i < list.length; i++) {
            try {
                if (new RegExp(String(list[i]), "i").test(String(appId || "")))
                    return true;
            } catch (e) {}
        }
        return false;
    }
    readonly property bool fullscreenFocused: ToplevelManager.activeToplevel !== null && ToplevelManager.activeToplevel.fullscreen === true
    readonly property bool videoAwake: root.stayAwakeDecision(root.fullscreenFocused, cfg.stayAwakeInFullscreen, ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.appId : "", cfg.stayAwakeApps)

    readonly property bool dimmed: cfg.enabled && cfg.dimMinutes > 0 && !root.videoAwake && dimMonitor.isIdle

    IdleMonitor {
        id: dimMonitor
        enabled: root.cfg.enabled && root.cfg.dimMinutes > 0 && !root.videoAwake
        respectInhibitors: true
        timeout: root.cfg.dimMinutes * 60
    }

    IdleMonitor {
        id: lockMonitor
        enabled: root.cfg.enabled && root.cfg.lockMinutes > 0 && !root.videoAwake
        respectInhibitors: true
        timeout: root.cfg.lockMinutes * 60
        onIsIdleChanged: {
            if (isIdle)
                Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock"]);
        }
    }

    IdleMonitor {
        id: screenMonitor
        enabled: root.cfg.enabled && root.cfg.screenOffMinutes > 0 && !root.videoAwake
        respectInhibitors: true
        timeout: root.cfg.screenOffMinutes * 60
        onIsIdleChanged: Hyprland.dispatch(isIdle ? "hl.dsp.dpms({ action = \"disable\" })" : "hl.dsp.dpms({ action = \"enable\" })")
    }
}
