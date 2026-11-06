// System-scope terminal command of the Services panel (ServicesPanel.dialogCommand): settings in, argument array out.
// ServicesPanel is a layer-shell PanelWindow and can't be created offscreen ("No PanelWindow backend loaded"), so this
// reads popups/ServicesPanel.qml, cuts out the real dialogCommand function text and evaluates that. No terminal is started.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    FileView {
        id: src
        path: Quickshell.shellPath("popups/ServicesPanel.qml")
        blockLoading: true
    }
    // the function text between "function dialogCommand" and its closing brace at the same indent
    readonly property var m: /function dialogCommand\(([^)]*)\) \{[\s\S]*?\n    \}/.exec(src.text())
    readonly property var panel: ({ dialogCommand: m ? eval("(" + m[0] + ")") : null })

    readonly property string script: "doas dinitctl --system $argv[1] $argv[2]; echo; read -P 'Press Enter to close'"

    Timer {
        interval: 900; running: true
        onTriggered: {
            const J = JSON.stringify;
            shell.check("ServicesPanel: dialogCommand found in the source", shell.m !== null && typeof shell.panel.dialogCommand === "function");
            shell.check("ServicesPanel: defaults give the old kitty array", J(panel.dialogCommand(Config.settings.execCommands.terminal, Config.settings.execCommands.terminalClassFlag, "restart", "pipewire")) === J(["kitty", "--class", "qs-dialog", "fish", "-c", shell.script, "restart", "pipewire"]));
            shell.check("ServicesPanel: foot names its window with --app-id", J(panel.dialogCommand("foot", "--app-id", "stop", "x")) === J(["foot", "--app-id", "qs-dialog", "fish", "-c", shell.script, "stop", "x"]));
            shell.check("ServicesPanel: an empty flag leaves the window unnamed", J(panel.dialogCommand("foot", "", "start", "x")) === J(["foot", "fish", "-c", shell.script, "start", "x"]));
            const odd = "my svc \"q\" 'a'; rm -rf $HOME";
            const c = panel.dialogCommand("kitty", "--class", "stop", odd);
            shell.check("ServicesPanel: a name with spaces and quotes stays one last argument", c.length === 8 && c[7] === odd && c[6] === "stop");
            shell.check("ServicesPanel: verb and name never enter the script text", c[5] === shell.script && c[5].indexOf("stop") < 0 && c[5].indexOf("svc") < 0);
            console.log("TEST done failures=" + shell.failures);
            Qt.quit();
        }
    }
}
