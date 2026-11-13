// Stay awake during video (Idle.qml): the pure decision, the setting default and the offscreen state (no compositor, so
// no focused fullscreen window). Caffeine stays independent. The IdleMonitors themselves need a compositor (live test).
import QtQuick
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    Component.onCompleted: starter.start()
    Timer { id: starter; interval: 300; onTriggered: shell.run() }

    function run() {
        const I = Idle;
        check("fullscreen with the setting on stays awake", I.stayAwakeDecision(true, true, "mpv") === true);
        check("fullscreen with the setting off does not", I.stayAwakeDecision(true, false, "mpv") === false);
        check("no fullscreen never stays awake", I.stayAwakeDecision(false, true, "mpv") === false);
        check("a missing setting counts as on", I.stayAwakeDecision(true, undefined, "mpv") === true);
        check("a missing fullscreen flag counts as off", I.stayAwakeDecision(undefined, true, "mpv") === false && I.stayAwakeDecision(null, true, "mpv") === false);
        check("games and players stay awake", I.stayAwakeDecision(true, true, "steam_app_123") && I.stayAwakeDecision(true, true, "Game.exe") && I.stayAwakeDecision(true, true, "zen") && I.stayAwakeDecision(true, true, "gamescope"));
        check("other fullscreen windows do not", !I.stayAwakeDecision(true, true, "kitty") && !I.stayAwakeDecision(true, true, "nemo") && !I.stayAwakeDecision(true, true, ""));
        check("custom patterns replace the defaults", I.stayAwakeDecision(true, true, "kitty", ["^kitty$"]) && !I.stayAwakeDecision(true, true, "mpv", ["^kitty$"]));
        check("a broken pattern is skipped", I.stayAwakeDecision(true, true, "mpv", ["(", "^mpv$"]) === true);
        check("the setting exists and defaults to true", Config.settings.idle.stayAwakeInFullscreen === true);
        check("without a focused fullscreen window videoAwake is false", I.fullscreenFocused === false && I.videoAwake === false);
        const before = I.caffeine;
        I.caffeine = !before;
        check("caffeine is independent of videoAwake", I.caffeine === !before && I.videoAwake === false);
        I.caffeine = before;
        console.log("TEST done failures=" + shell.failures);
        Qt.quit();
    }
}
