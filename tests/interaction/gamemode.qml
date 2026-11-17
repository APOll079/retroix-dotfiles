// Game mode, the Quickshell half (GameModeState.qml): pure helpers, and the enter / leave rule with recorded signals (QS_NO_APPLY:
// nothing is stopped, pkill is never run). The Hyprland half (hypr/inputs.lua) needs a compositor: live test.
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
    Timer { id: starter; interval: 400; onTriggered: shell.run() }

    function run() {
        const G = GameModeState;
        check("safeProgram accepts plain names and rejects shell text", G.safeProgram("ollama") && G.safeProgram("syncthing") && G.safeProgram("a.b-c_d+1") && !G.safeProgram("a b") && !G.safeProgram("a;rm") && !G.safeProgram("") && !G.safeProgram("-x") && !G.safeProgram("waytoolongprogramname") && !G.safeProgram(5));
        check("programs: junk and duplicates dropped, order kept", JSON.stringify(G.programs(["ollama", "bad name", "ollama", "x;y", "sync"])) === JSON.stringify(["ollama", "sync"]) && G.programs(null).length === 0);
        check("restoreOf gives back exactly what was saved", G.restoreOf({ caffeine: true, dnd: false }).caffeine === true && G.restoreOf({ caffeine: true, dnd: false }).dnd === false && G.restoreOf({}).caffeine === false);

        check("starts off", G.on === false);
        Config.settings.gameMode.pause = ["ollama", "bad name"];
        Idle.caffeine = true;                                   // caffeine was ALREADY on
        Config.settings.notifications.dnd = false;
        G.set(true);
        check("on: caffeine and DND on, the safe program is stopped (recorded), the bad name is not", G.on === true && Idle.caffeine === true && Config.settings.notifications.dnd === true && G.signalLog.join() === "pkill -STOP -x ollama");
        G.set(true);
        check("turning on twice does nothing more", G.signalLog.length === 1);
        G.set(false);
        check("off: caffeine stays on (it was on before), DND back off, the program resumed", G.on === false && Idle.caffeine === true && Config.settings.notifications.dnd === false && G.signalLog.join() === "pkill -STOP -x ollama,pkill -CONT -x ollama");
        Idle.caffeine = false;
        Config.settings.notifications.dnd = true;               // DND was already on
        G.set(true);
        G.set(false);
        check("off again: caffeine back off, DND stays on (it was on before)", Idle.caffeine === false && Config.settings.notifications.dnd === true);
        G.toggle();
        check("toggle flips it", G.on === true);
        G.toggle();
        check("and back", G.on === false);
        Config.settings.gameMode.pause = [];
        console.log("TEST done failures=" + shell.failures);
        Qt.quit();
    }
}
