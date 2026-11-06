// Caffeine persistence (Idle.qml): the state file in XDG_RUNTIME_DIR is read before first use and written on
// every change. The runner gives each test a private runtime dir. The IdleInhibitor itself needs a compositor
// and is not tested here (live test). Restart / reload / broken-JSON runs are driven from a scratch script.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property string file: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-caffeine.json"
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    // A previous run left caffeine on: written before Idle is first used
    FileView {
        id: seed
        path: shell.file
        blockWrites: true
    }
    Component.onCompleted: seed.setText("{\"caffeine\": true}\n")

    Process {
        id: reader
        command: ["cat", shell.file]
        stdout: StdioCollector {
            id: out
        }
    }

    Timer {
        id: first
        interval: 300
        running: true
        onTriggered: {
            shell.check("a saved caffeine = true is read at first use", Idle.caffeine === true);
            Idle.caffeine = false;
            second.start();
        }
    }
    Timer {
        id: second
        interval: 400
        onTriggered: {
            reader.running = true;
            third.start();
        }
    }
    Timer {
        id: third
        interval: 400
        onTriggered: {
            shell.check("turning it off is saved", /"caffeine":\s*false/.test(out.text));
            Idle.caffeine = !Idle.caffeine;
            fourth.start();
        }
    }
    Timer {
        id: fourth
        interval: 400
        onTriggered: {
            shell.check("the toggle used by the bar button works", Idle.caffeine === true);
            reader.running = true;
            fifth.start();
        }
    }
    Timer {
        id: fifth
        interval: 400
        onTriggered: {
            shell.check("turning it on is saved", /"caffeine":\s*true/.test(out.text));
            console.log("TEST done failures=" + shell.failures);
            Qt.quit();
        }
    }
}
