// Logitech mouse battery state (MouseState.qml): parse of solaar.sh output, label and tooltip. Pure functions; the
// runner sets QS_NO_APPLY so no Solaar call ever runs. scripts/solaar.sh itself is tested in tests/scripts-r4b.py.
import QtQuick
import Quickshell

ShellRoot {
    id: shell
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    Component.onCompleted: {
        const M = MouseState;
        const ok = M.parse('{"present": true, "name": "MX Master 3", "percent": 80, "charging": false}');
        shell.check("parse reads a present mouse", ok.present && ok.name === "MX Master 3" && ok.percent === 80 && ok.charging === false);
        shell.check("parse: charging flag", M.parse('{"present":true,"name":"x","percent":55,"charging":true}').charging === true);
        for (const bad of ["", "oops", "{}", '{"present":false}', '{"present":true,"percent":null}', '{"present":true,"percent":150}', '{"present":true,"percent":"80"}', "[1]", "null"])
            shell.check("parse of " + JSON.stringify(bad) + " is not present", M.parse(bad).present === false && M.parse(bad).percent === -1);
        shell.check("cleanName strips control characters and cuts long names", M.cleanName("A\u0001B\nC") === "A B C" && M.cleanName("x".repeat(60)).length === 40 && M.cleanName(null) === "");
        shell.check("label: percent, plus while charging, empty when hidden", M.labelFor(true, 80, false) === "80%" && M.labelFor(true, 55, true) === "55%+" && M.labelFor(false, 80, false) === "");
        shell.check("tooltip: name, percent, charging; falls back to Mouse", M.tooltipFor(true, "MX Master 3", 80, false) === "MX Master 3: 80%"
            && M.tooltipFor(true, "", 55, true) === "Mouse: 55%, charging" && M.tooltipFor(false, "x", 1, false) === "");
        shell.check("inactive under the harness and nothing shown", M.active === false && M.visibleInBar === false && M.label === "" && M.percent === -1);
        M.take('{"present":true,"name":"G502","percent":42,"charging":false}');
        shell.check("take fills the state and the bar flag", M.visibleInBar && M.label === "42%" && M.tooltip === "G502: 42%");
        M.take("");
        shell.check("take of nothing clears it", !M.visibleInBar && M.label === "");
        shell.check("settings.mouse.enabled defaults to true", Config.settings.mouse.enabled === true);

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
