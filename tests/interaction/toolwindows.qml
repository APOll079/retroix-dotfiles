// The cheat sheet ("Keys") and Services windows (popups/CheatSheet.qml, popups/ServicesPanel.qml) as real windows owned by the
// ToolWindows singleton: open / toggle / close, Escape order, the refresh on open, showServiceDetails, titles and sizes.
// QS_NO_APPLY is set by the runner: no binds.py, dinitctl, terminal or log script runs; the argv lists are recorded in
// `launched` (Services) and `bindReads` counts the binds.py reads (Keys). The test hands the answers over.
import QtQuick
import QtTest
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
    function asVar(o: var): var {
        return o;
    }
    function js(v) { return JSON.stringify(v); }

    TestCase { id: tc; name: "sim"; when: false }

    readonly property string listText: "[{+}     ] pipewire (pid: 100)\n[{+}     ] wireplumber (pid: 101)\n[     {-}] cups\n"

    Timer {
        interval: 1000; running: true
        onTriggered: {
            const TW = ToolWindows;
            const keys = shell.asVar(TW.win("keys"));
            const svc = shell.asVar(TW.win("services"));

            // ---- titles and sizes (the Hyprland rules match the titles) ----
            shell.check("titles: Keys, Services", keys.title === "Keys" && svc.title === "Services");
            shell.check("all start closed", !TW.keysVisible && !TW.servicesVisible && !TW.isOpen("keys") && !TW.isOpen("nothing"));
            shell.check("sizes come from MenuStyle, a minimum size is set",
                keys.implicitWidth === MenuStyle.windowWidth && keys.implicitHeight === MenuStyle.windowHeight && keys.minimumSize.width === 600 && keys.minimumSize.height === 420
                && svc.implicitWidth === MenuStyle.windowWidth && svc.minimumSize.width === 600);

            // ---- cheat sheet ----
            const r0 = keys.bindReads;
            TW.open("keys");
            tc.wait(100);
            shell.check("Keys: open shows the window and re-reads the binds", keys.visible && TW.keysVisible && keys.bindReads === r0 + 1);
            keys.binds = [{ keys: "Super+Q", label: "Close window", group: "Windows" }, { keys: "Super+D", label: "Launcher", group: "Apps" }];
            tc.wait(50);
            shell.check("Keys: two groups give two headings and four rows", keys.rows.length === 4 && keys.rows[0].heading === "Windows");
            keys.searchItem.text = "launch";
            shell.check("Keys: typing filters", keys.shown.length === 1 && keys.rows.length === 2);
            TW.open("keys");
            shell.check("Keys: opening an open window only focuses it (no re-read, filter kept)", keys.bindReads === r0 + 1 && keys.searchItem.text === "launch");
            tc.keyClick(Qt.Key_Escape);
            shell.check("Keys: first Escape clears the search, window stays", keys.visible && keys.searchItem.text === "");
            tc.keyClick(Qt.Key_Escape);
            shell.check("Keys: second Escape closes the window", !keys.visible);
            TW.toggle("keys");
            shell.check("Keys: toggle opens (search reset, binds re-read)", keys.visible && keys.searchItem.text === "" && keys.bindReads === r0 + 2);
            TW.toggle("keys");
            shell.check("Keys: toggle closes", !keys.visible);

            // ---- services ----
            TW.open("services");
            tc.wait(100);
            shell.check("Services: open lists the user scope once", svc.visible && TW.servicesVisible && svc.launched.length === 1 && shell.js(svc.launched[0]) === shell.js(["dinitctl", "--user", "list"]));
            svc.gotList(shell.listText);
            tc.wait(50);
            shell.check("Services: the list is parsed", svc.services.length === 3 && svc.shown.length === 3 && svc.current.name === "cups");
            TW.open("services");
            shell.check("Services: opening an open window only focuses it", svc.launched.length === 1);

            // user action
            svc.act("restart");
            shell.check("Services: a user action runs dinitctl --user restart <name>", shell.js(svc.launched[svc.launched.length - 1]) === shell.js(["dinitctl", "--user", "restart", "cups"]));
            // system scope: terminal, the window stays open
            svc.scope = "system";
            svc.services = [{ name: "sshd", state: "running", failed: false, info: "" }];
            const n = svc.launched.length;
            svc.act("stop");
            shell.check("Services: a System action starts the terminal command and keeps the window open",
                svc.launched.length === n + 1 && svc.launched[n][svc.launched[n].length - 1] === "sshd" && svc.launched[n][svc.launched[n].length - 2] === "stop" && svc.visible);
            svc.scope = "user";

            // Escape order: log first, then the window
            svc.services = [{ name: "pipewire", state: "running", failed: false, info: "" }];
            svc.openLog();
            shell.check("Services: Log opens", svc.logOpen && svc.logName === "pipewire");
            tc.keyClick(Qt.Key_Escape);
            shell.check("Services: Escape backs out of the log first", !svc.logOpen && svc.visible);
            tc.keyClick(Qt.Key_Escape);
            shell.check("Services: the next Escape closes the window", !svc.visible);

            // Details of a toast
            TW.showServiceDetails("wireplumber");
            tc.wait(50);
            shell.check("Services: showServiceDetails opens the window on the user scope, waiting for the list", svc.visible && svc.scope === "user" && svc.pendingSelect === "wireplumber");
            svc.gotList(shell.listText);
            tc.wait(50);
            shell.check("Services: Details selects that service and opens its log", svc.logOpen && svc.logName === "wireplumber" && svc.current.name === "wireplumber");
            TW.showServiceDetails("cups");
            svc.gotList(shell.listText);
            shell.check("Services: Details on the open window re-points it (still one window)", svc.visible && svc.logName === "cups");
            TW.close("services");
            shell.check("Services: close hides it", !svc.visible && !TW.servicesVisible);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 100; onTriggered: Qt.quit() }
}
