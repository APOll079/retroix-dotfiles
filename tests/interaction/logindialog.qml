// The lock / login password box (popups/LoginDialog.qml) with real simulated keys and clicks, offscreen, in both
// modes: Enter and OK submit (accepted(user, password)), an empty password submits nothing, Escape clears the
// password and emits cancelled() (nothing closes; there is no Cancel button), busy blocks submitting and shows "Checking...", clear(), Tab
// from the user field to the password field in greeter mode. PAM and the real session lock are not involved (they
// need a compositor: live test).
import QtQuick
import QtTest
import QtQuick.Controls.Basic
import Quickshell
import "popups" as Popups

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    property var got: []
    property int cancels: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }
    function button(d, text) {
        return shell.find(d, c => c.visible && c.text === text && c.clicked !== undefined, [])[0];
    }
    function fields(d) {
        return shell.find(d, c => c.echoMode !== undefined && c.selectByMouse !== undefined, []);
    }
    function status(d) {
        const s = shell.find(d, c => c.kind !== undefined && c.trailing !== undefined, [])[0];
        return s ? s.text : "<none>";
    }

    FloatingWindow {
        id: win
        implicitWidth: 560
        implicitHeight: 300
        color: Config.colors.base
        Popups.LoginDialog {
            id: dlg
            x: 20
            y: 20
            user: "ada"
            onAccepted: (u, p) => shell.got = shell.got.concat([u + "/" + p])
            onCancelled: shell.cancels++
        }
    }

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const f = shell.fields(dlg);
            const userF = f.find(x => x.echoMode !== TextInput.Password);
            const passF = f.find(x => x.echoMode === TextInput.Password);
            shell.check("two fields: user name and a masked password", f.length === 2 && userF !== undefined && passF !== undefined);

            // ---- lock mode ----
            shell.check("lock: the password field holds the focus by default (no focusInput call)", passF.focus === true && userF.focus === false);
            shell.check("lock: the user field shows the user and is read-only", userF.text === "ada" && userF.readOnly === true);
            dlg.focusInput();
            tc.wait(50);
            shell.check("lock: focus starts in the password field", passF.activeFocus === true);
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            shell.check("lock: Enter with an empty password submits nothing", shell.got.length === 0);
            tc.keyClick("s"); tc.keyClick("e"); tc.keyClick("c");
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            shell.check("lock: typing then Enter submits user and password", shell.got.join() === "ada/sec");
            tc.keyClick(Qt.Key_Escape);
            tc.wait(50);
            shell.check("lock: Escape clears the password, emits cancelled, the dialog stays", passF.text === "" && shell.cancels === 1 && dlg.visible === true);
            tc.keyClick("x");
            tc.mouseClick(shell.button(dlg, "OK"));
            tc.wait(50);
            shell.check("lock: a click on OK submits like Enter", shell.got.join() === "ada/sec,ada/x");
            shell.check("lock: there is no Cancel button (Escape does its job)", shell.button(dlg, "Cancel") === undefined);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(50);
            shell.check("lock: Escape again clears the password", passF.text === "" && shell.cancels === 2);
            dlg.focusInput();
            tc.keyClick("y");
            dlg.busy = true;
            tc.wait(50);
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            shell.check("busy: Enter submits nothing and the status says Checking...", shell.got.length === 2 && shell.status(dlg) === "Checking...");
            shell.check("busy: OK is disabled", shell.button(dlg, "OK").enabled === false);
            dlg.busy = false;
            dlg.status = "Wrong password (1)";
            dlg.statusIsError = true;
            tc.wait(50);
            shell.check("the status line shows the host's status", shell.status(dlg) === "Wrong password (1)");
            dlg.clear();
            tc.wait(50);
            shell.check("clear() empties the password and keeps the focus there", passF.text === "" && passF.activeFocus === true);

            // ---- greeter mode ----
            dlg.mode = "greeter";
            dlg.user = "";
            userF.text = "";
            tc.wait(50);
            shell.check("greeter: the user field is editable", userF.readOnly === false);
            dlg.focusInput();
            tc.wait(50);
            shell.check("greeter: with no user name the focus starts in the user field", userF.activeFocus === true);
            tc.keyClick("b"); tc.keyClick("o");
            tc.keyClick(Qt.Key_Tab);
            tc.wait(50);
            shell.check("greeter: Tab moves from the user field to the password", passF.activeFocus === true && userF.text === "bo");
            tc.keyClick("p");
            tc.keyClick(Qt.Key_Return);
            tc.wait(50);
            shell.check("greeter: Enter submits the typed user and password", shell.got[shell.got.length - 1] === "bo/p");
            userF.text = "";
            passF.text = "q";
            tc.mouseClick(shell.button(dlg, "OK"));
            tc.wait(50);
            shell.check("greeter: an empty user name submits nothing", shell.got.length === 3);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
