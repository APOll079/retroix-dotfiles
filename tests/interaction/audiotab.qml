// Home tab audio additions (popups/AudioTab.qml, AudioState.qml): the Test mic button (label, sunken state, nothing
// runs under the harness) and the per-app Play on menu model (outputs, check mark, the move-sink call arguments).
// The scripts themselves are tested with fakes in tests/scripts-r4a.py; PipeWire has no devices offscreen.
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property int winW: 480
    readonly property int winH: 600
    function asVar(o: var): var {
        return o;
    }
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function find(it: var, pred: var): var {
        if (pred(it))
            return it;
        for (const c of it.children) {
            const r = shell.find(c, pred);
            if (r)
                return r;
        }
        return null;
    }

    FloatingWindow {
        implicitWidth: shell.winW; implicitHeight: shell.winH
        Rectangle {
            anchors.fill: parent
            color: Config.colors.base
            Loader {
                id: tabLoad
                x: 10; y: 10
                width: shell.winW - 20
                height: shell.winH - 20
                Component.onCompleted: setSource("popups/AudioTab.qml", { active: true })
            }
            TestCase { id: tc; name: "sim"; when: false }
            Timer {
                interval: 900; running: true
                onTriggered: {
                    const A = AudioState;
                    const tab = shell.asVar(tabLoad.item);
                    shell.check("micTestLabel", A.micTestLabel(false) === "Test mic" && A.micTestLabel(true) === "Stop test");
                    const btn = shell.find(tab, it => it.objectName === "micTestButton");
                    shell.check("the Test mic button exists with its label, not sunken", btn !== null && btn.text === "Test mic" && btn.checked === false);
                    shell.check("toggling under the harness runs nothing", A.live === false && (A.toggleMicTest(), A.stopMicTest(), A.micTesting === false));

                    // ---- Play on ----
                    const outs = [{ id: 7, description: "DAC", name: "alsa_a" }, { id: 9, description: "Headphones", name: "bluez_b" }];
                    const m = tab.playOnEntries(outs, outs[1], [{ id: 31 }, { id: 32 }]);
                    shell.check("Play on: a header, then one entry per output, the current one checked", m.length === 4 && m[0].text === "Play on" && m[0].enabled === false && m[1].separator === true && m[2].text === "DAC" && m[2].checked === false && m[3].text === "Headphones" && m[3].checked === true);
                    shell.check("Play on: no outputs gives a disabled note", tab.playOnEntries([], null, [{ id: 31 }]).length === 1 && tab.playOnEntries([], null, [{ id: 31 }])[0].enabled === false);
                    shell.check("Play on: the move calls are one per stream, with integer ids", JSON.stringify(tab.moveCommands([{ id: 31 }, { id: 32 }], outs[0])) === '[["sh","' + Quickshell.shellDir + '/scripts/move-sink.sh","31","7"],["sh","' + Quickshell.shellDir + '/scripts/move-sink.sh","32","7"]]');
                    shell.check("Play on: a stream or sink without an integer id is skipped", tab.moveCommands([{ id: "x" }, { id: 5 }], outs[0]).length === 1 && tab.moveCommands([{ id: 5 }], { id: undefined }).length === 0);
                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
