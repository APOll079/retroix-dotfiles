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
        check("fullscreen with the setting on stays awake", I.stayAwakeDecision(true, true) === true);
        check("fullscreen with the setting off does not", I.stayAwakeDecision(true, false) === false);
        check("no fullscreen never stays awake", I.stayAwakeDecision(false, true) === false);
        check("a missing setting counts as on", I.stayAwakeDecision(true, undefined) === true);
        check("a missing fullscreen flag counts as off", I.stayAwakeDecision(undefined, true) === false && I.stayAwakeDecision(null, true) === false);
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
