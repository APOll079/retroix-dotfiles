// Logic test for the launcher's colour preview (utils/ColorText.qml): pure functions, fixtures only.
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

    Component.onCompleted: {
        const a = Utils.ColorText.answer("#c950bb");
        shell.check("ColorText: #c950bb hex", a !== null && a.hex === "#c950bb");
        shell.check("ColorText: #c950bb rgb", a !== null && a.rgb === "rgb(201, 80, 187)");
        shell.check("ColorText: #c950bb hsl", a !== null && a.hsl === "hsl(307, 53%, 55%)");
        shell.check("ColorText: the sub line has both", a !== null && a.sub === "rgb(201, 80, 187) · hsl(307, 53%, 55%)");
        const b = Utils.ColorText.answer("#ABC");
        shell.check("ColorText: #abc expands, any case", b !== null && b.hex === "#aabbcc");
        const c = Utils.ColorText.answer("rgb(201,80,187)");
        shell.check("ColorText: rgb() gives the hex", c !== null && c.hex === "#c950bb");
        shell.check("ColorText: rgb() with spaces and spaces as separators", Utils.ColorText.answer("RGB( 1 2 3 )").hex === "#010203");
        shell.check("ColorText: white", Utils.ColorText.answer("#ffffff").hsl === "hsl(0, 0%, 100%)");
        shell.check("ColorText: pure red", Utils.ColorText.answer("#f00").hsl === "hsl(0, 100%, 50%)");
        shell.check("ColorText: pure blue", Utils.ColorText.answer("#0000ff").hsl === "hsl(240, 100%, 50%)");
        shell.check("ColorText: rgb above 255 is no colour", Utils.ColorText.answer("rgb(256,0,0)") === null);
        shell.check("ColorText: 4 digits is no colour", Utils.ColorText.answer("#abcd") === null);
        shell.check("ColorText: non-hex is no colour", Utils.ColorText.answer("#ggg") === null);
        shell.check("ColorText: a word is no colour", Utils.ColorText.answer("firefox") === null);
        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
