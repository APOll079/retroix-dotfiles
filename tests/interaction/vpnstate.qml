// Pure-function tests for the VPN status singleton (VpnState.qml): status parsing, the disconnect command and the
// tooltip. No tool runs (the runner sets QS_NO_APPLY). Run by scripts/run-interaction-tests.py.
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
        const V = VpnState;
        shell.check("parse: names from the script JSON", V.parse('{"up": true, "names": ["work", "home wg"]}').join("|") === "work|home wg");
        shell.check("parse: nothing active is an empty list", V.parse('{"up": false, "names": []}').length === 0);
        shell.check("parse: duplicates, empty and non-string names are dropped", V.parse('{"names":["a","a","",3,null,"b"]}').join(",") === "a,b");
        shell.check("parse: junk is null (the old status is kept)", V.parse("") === null && V.parse("x") === null && V.parse("{}") === null && V.parse('{"names":"a"}') === null && V.parse("null") === null);

        const known = ["work", "home wg"];
        shell.check("downCommand: a known name is one argv word", JSON.stringify(V.downCommand(known, "home wg")) === '["nmcli","connection","down","home wg"]');
        shell.check("downCommand: an unknown name is refused", V.downCommand(known, "other") === null && V.downCommand([], "work") === null);
        shell.check("downCommand: empty, non-string and option-like names are refused", V.downCommand(known, "") === null && V.downCommand(known, undefined) === null && V.downCommand(["-x"], "-x") === null);
        shell.check("downCommand: shell text in a name stays one word", (() => {
            const c = V.downCommand(["a; id"], "a; id");
            return c !== null && c.length === 4 && c[3] === "a; id";
        })());

        shell.check("tooltip: names and the click hint", V.tooltip(["work"]) === "VPN: work (click to disconnect)" && V.tooltip(["a", "b"]) === "VPN: a, b (click to disconnect)");
        shell.check("tooltip: none is empty", V.tooltip([]) === "");

        shell.check("starts down with an empty label", V.up === false && V.label === "");
        V.names = ["work", "b"];
        shell.check("up and label follow the names", V.up === true && V.label === "work");
        V.names = [];

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
