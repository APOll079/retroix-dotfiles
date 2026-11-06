// Phone tab Send to phone (popups/PhoneTab.qml): the pure share command and status text, and the button label. The
// call itself (kdeshare.sh with a fake kdeconnect-cli) is tested in tests/scripts-r4a.py.
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
                Component.onCompleted: setSource("popups/PhoneTab.qml", { active: false })
            }
            Timer {
                interval: 700; running: true
                onTriggered: {
                    const t = shell.asVar(tabLoad.item);
                    const sh = Quickshell.shellDir + "/scripts/kdeshare.sh";
                    shell.check("shareCommand: id, then the path as one argument", JSON.stringify(t.shareCommand("abc_1", " ~/shot one.png ")) === JSON.stringify(["sh", sh, "abc_1", "~/shot one.png"]));
                    shell.check("shareCommand: a link", t.shareCommand("abc_1", "https://example.org/a?b=1")[3] === "https://example.org/a?b=1");
                    shell.check("shareCommand: bad ids, empty and dash-leading input give null", t.shareCommand("a b", "x") === null && t.shareCommand("", "x") === null
                        && t.shareCommand("a;b", "x") === null && t.shareCommand("abc", "") === null && t.shareCommand("abc", "-d") === null && t.shareCommand("abc", undefined) === null);
                    shell.check("sentMessage: file name or 'Sent link'", t.sentMessage("~/a/shot.png") === "Sent shot.png" && t.sentMessage("https://x.org/y") === "Sent link" && t.sentMessage("http://x.org") === "Sent link");
                    const btn = shell.find(t, it => it.text === "Send to phone" && it.clicked !== undefined);
                    shell.check("the button says Send to phone and is disabled without a phone", btn !== null && btn.enabled === false);
                    shell.check("the old Send file label is gone", shell.find(t, it => it.text === "Send file") === null);
                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
