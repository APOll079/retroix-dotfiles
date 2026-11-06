// PhoneBattery.qml: the pure parse of scripts/phone.sh output, the label / tooltip and the harness gate (no tool runs
// under QS_NO_APPLY). The script itself is tested with fake kdeconnect-cli / busctl in tests/scripts-r4a.py.
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
        const P = PhoneBattery;
        const ok = P.parse('{"connected":true,"id":"abc_1","name":"Pixel 8","percent":78,"charging":true}\n');
        check("parse: a connected phone", ok.connected === true && ok.percent === 78 && ok.charging === true && ok.name === "Pixel 8");
        check("parse: not charging", P.parse('{"connected":true,"percent":5,"charging":false}').charging === false);
        check("parse: 0 and 100 are valid", P.parse('{"connected":true,"percent":0}').connected === true && P.parse('{"connected":true,"percent":100}').connected === true);
        check("parse: connected false", P.parse('{"connected":false}').connected === false);
        check("parse: junk is not connected", P.parse("").connected === false && P.parse("nope").connected === false && P.parse("[]").connected === false);
        check("parse: out of range or fractional percent is not connected", P.parse('{"connected":true,"percent":101}').connected === false
            && P.parse('{"connected":true,"percent":-1}').connected === false && P.parse('{"connected":true,"percent":7.5}').connected === false
            && P.parse('{"connected":true,"percent":"x"}').connected === false && P.parse('{"connected":true}').connected === false);
        check("tooltip names the phone and the charge", P.tooltipFor("Pixel 8", 78, true) === "Pixel 8: 78%, charging" && P.tooltipFor("", 40, false) === "Phone: 40%");
        check("starts disconnected with an empty label", P.connected === false && P.label === "" && P.tooltip === "");
        P.apply(P.parse('{"connected":true,"name":"Pixel 8","percent":78,"charging":false}'));
        check("apply sets connected, label '78%' and the tooltip", P.connected === true && P.percent === 78 && P.label === "78%" && P.tooltip === "Pixel 8: 78%");
        P.apply(P.parse('{"connected":false}'));
        check("apply with a lost phone clears the label", P.connected === false && P.label === "");
        check("inactive under the harness (no process)", P.active === false && (P.refresh(), true));
        console.log("TEST done failures=" + shell.failures);
        Qt.quit();
    }
}
