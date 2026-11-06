// Logic test for the launcher's unit conversions (utils/Units.qml): pure functions, fixtures only.
// Run by scripts/run-interaction-tests.py (see components.qml for how these files work).
import QtQuick
import Quickshell
import "utils" as Utils

ShellRoot {
    id: shell
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function text(q) {
        const a = Utils.Units.answer(q);
        return a === null ? "null" : a.text;
    }
    function num(q) {
        const a = Utils.Units.answer(q);
        return a === null ? "null" : a.number;
    }

    Component.onCompleted: {
        shell.check("Units: 5 km in mi", shell.text("5 km in mi") === "5 km = 3.10686 mi");
        shell.check("Units: 180 cm in ft", shell.num("180 cm in ft") === "5.90551");
        shell.check("Units: 72 f in c", shell.num("72 f in c") === "22.2222");
        shell.check("Units: 3 kg to lb", shell.num("3 kg to lb") === "6.61387");
        shell.check("Units: 2 l in gal", shell.num("2 l in gal") === "0.528344");
        shell.check("Units: 100 mph in kmh", shell.num("100 mph in kmh") === "160.934");
        shell.check("Units: upper case and decimal comma", shell.num("1,5 KM IN M") === "1500");
        shell.check("Units: decimal point", shell.num("2.5 h to min") === "150");
        shell.check("Units: negative temperature", shell.num("-40 c in f") === "-40");
        shell.check("Units: 1 cup in tbsp", shell.num("1 cup in tbsp") === "16");
        shell.check("Units: data is decimal", shell.num("2 gb to mb") === "2000");
        shell.check("Units: knots", shell.num("10 kn to kmh") === "18.52");
        shell.check("Units: ms is metres per second next to kmh", shell.num("10 ms in kmh") === "36");
        shell.check("Units: ms is milliseconds next to s", shell.num("500 ms in s") === "0.5");
        shell.check("Units: inch is not the word in", shell.num("2 in in cm") === "5.08");
        shell.check("Units: mixed dimensions give no row", shell.text("5 km in kg") === "null");
        shell.check("Units: unknown unit gives no row", shell.text("5 foo in km") === "null");
        shell.check("Units: plain maths gives no row", shell.text("2+2") === "null");
        shell.check("Units: plain words give no row", shell.text("firefox") === "null");
        shell.check("Units: constructor name is not a unit", shell.text("5 constructor in km") === "null");
        shell.check("Units: tiny value uses no exponent", shell.num("1 mm in km") === "0.000001");
        shell.check("Units: the calculator still works", Utils.Calc.evaluate("2+2*3") === "8");
        shell.check("Units: the calculator still converts other units", Utils.Calc.evaluate("1 mib to kib") === "1024 kib");
        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
