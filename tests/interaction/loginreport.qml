// Login report: LoginReport.qml pure functions (parse of loginreport.py output, total, time text, bar fraction) and the panel with
// fixture rows: one list row per step, the total in the status line, the EmptyState "No login timestamps yet" when there are none,
// Escape closes. LoginReportPanel is a layer-shell PanelWindow and can't be created offscreen, so this writes a scratch copy of it
// (PanelWindow -> FloatingWindow, layer-shell lines dropped) inside the runner's scratch tree and loads that. QS_NO_APPLY is set:
// LoginReport.load() starts nothing; the rows are put in with take().
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    property int closed: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function asVar(o: var): var {
        return o;
    }
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }

    FileView {
        id: src
        path: Quickshell.shellPath("popups/LoginReportPanel.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/LoginReportPanelTest.qml")
        blockWrites: true
    }

    readonly property string fixture: '[{"name":"waybar-up","ms":4200,"since_previous_ms":3000},{"name":"session-start","ms":0,"since_previous_ms":0},{"name":"hyprpaper","ms":1200,"since_previous_ms":1200}]'

    Component.onCompleted: {
        let t = src.text();
        t = t.replace("PanelWindow {", "FloatingWindow {");
        t = t.replace(/\n    anchors \{[\s\S]*?\n    \}/, "");
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0).join("\n");
        t = t.replace("property int screenHeight: 0", "property int screenHeight: MenuStyle.windowHeight\n    implicitWidth: MenuStyle.windowWidth\n    implicitHeight: MenuStyle.windowHeight");
        dst.setText(t);
        loader.setSource("popups/LoginReportPanelTest.qml", { bar: null, closeCallback: function () { shell.closed++; } });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const L = LoginReport;
            const rows = L.parse(shell.fixture);
            shell.check("parse keeps the three steps in the given order", rows.length === 3 && rows[0].name === "waybar-up" && rows[0].since === 3000 && rows[1].ms === 0);
            shell.check("parse of junk is []", L.parse("").length === 0 && L.parse("{}").length === 0 && L.parse("oops").length === 0
                && L.parse('[{"name":"x"},5,{"name":"","ms":1,"since_previous_ms":1}]').length === 0);
            shell.check("totalOf is the largest ms", L.totalOf(rows) === 4200 && L.totalOf([]) === 0);
            shell.check("msText: ms, seconds, minutes, junk", L.msText(850) === "850 ms" && L.msText(4200) === "4.2 s" && L.msText(72000) === "1 min 12 s" && L.msText(NaN) === "?" && L.msText(-1) === "?");
            shell.check("fraction: against the slowest, clamped, 0 without a slowest", L.fraction(1500, 3000) === 0.5 && L.fraction(5000, 3000) === 1 && L.fraction(10, 0) === 0);

            const panel = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", panel !== null && panel.listRows !== undefined);
            panel.visible = true;
            L.take("[]");
            tc.wait(150);
            shell.check("no rows: the EmptyState says No login timestamps yet", shell.find(panel.contentItem, c => c.visible && c.text === "No login timestamps yet", []).length >= 1);
            L.take(shell.fixture);
            tc.wait(150);
            shell.check("with rows the EmptyState is gone", shell.find(panel.contentItem, c => c.visible && c.text === "No login timestamps yet", []).length === 0);
            shell.check("one row per step with its time text", ["waybar-up", "hyprpaper", "session-start"].every(n => shell.find(panel.contentItem, c => c.visible && c.text === n, []).length === 1)
                && shell.find(panel.contentItem, c => c.visible && c.text === "3.0 s", []).length === 1);
            shell.check("the total is in the status line", shell.find(panel.contentItem, c => c.visible && c.text === "Total 4.2 s", []).length === 1);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Escape calls the close callback once", shell.closed === 1);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
