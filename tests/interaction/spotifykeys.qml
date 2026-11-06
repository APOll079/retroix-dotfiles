// Keys on the Spotify drawer's "..." menu and its two confirms (log out, change client ID), with real simulated keys:
// the menu takes the keyboard (Down / Up move, Enter picks, Escape closes only the menu, not the drawer); a confirm
// answers Enter with its verb and Escape with Cancel; goBack() steps out of the menu / a confirm first.
// SpotifyPanel is a layer-shell PanelWindow and can't be created offscreen, so a scratch copy (in the runner's own
// scratch tree) turns it into a FloatingWindow; everything else is the real file. QS_NO_APPLY is set and
// no account exists: SpotifyState.logout() only runs spotify.py against the scratch state dir.
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
    FileView {
        id: src
        path: Quickshell.shellPath("popups/SpotifyPanel.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/SpotifyPanelTest.qml")
        blockWrites: true
    }
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }
    Component.onCompleted: {
        let t = src.text();
        t = t.replace("PanelWindow {", "FloatingWindow {");
        t = t.replace(/\n    anchors \{[\s\S]*?\n    \}/, "");
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0 && l.indexOf("margins.top") < 0).join("\n");
        t = t.replace("implicitWidth: MenuStyle.spotifyWidth", "implicitWidth: MenuStyle.spotifyWidth\n    implicitHeight: 2 * MenuStyle.spotifyWidth");
        dst.setText(t);
        loader.setSource("popups/SpotifyPanelTest.qml", {});
    }
    Loader { id: loader }
    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1500; running: true
        onTriggered: {
            const p = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", p !== null && p.confirming !== undefined);
            p.closeCallback = function () { shell.closed++; };
            p.openMenu();
            tc.wait(200);
            const bodies = shell.find(p.contentItem, c => c.escaped !== undefined && c.currentIndex !== undefined && c.title === "" && c.model.length === 4, []);
            shell.check("the ... menu body exists", bodies.length === 1);
            const body = bodies[0];

            // the menu
            p.menuOpen = true;
            tc.wait(100);
            shell.check("the menu takes the keyboard when it opens", body.activeFocus === true);
            shell.check("it starts on the first entry", body.currentIndex === 0);
            tc.keyClick(Qt.Key_Down);
            shell.check("Down moves", body.currentIndex === 1);
            tc.keyClick(Qt.Key_Up);
            shell.check("Up moves back", body.currentIndex === 0);
            tc.keyClick(Qt.Key_Escape);
            shell.check("Escape closes only the menu", p.menuOpen === false && shell.closed === 0);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(50);
            shell.check("the next Escape closes the drawer", shell.closed === 1);

            // Enter on "Change client ID" asks first; Escape cancels it
            p.menuOpen = true;
            tc.wait(100);
            tc.keyClick(Qt.Key_Down);
            tc.keyClick(Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter on Change client ID opens the confirm and closes the menu", p.confirmClient === true && p.menuOpen === false);
            tc.keyClick(Qt.Key_Escape);
            shell.check("Escape on the confirm is Cancel: nothing changed, the drawer stays", p.confirmClient === false && p.editClient === false && shell.closed === 1);

            // Enter on the log-out confirm is its verb
            p.confirmLogout = true;
            tc.wait(100);
            tc.keyClick(Qt.Key_Return);
            shell.check("Enter on the log-out confirm is Log out", p.confirmLogout === false && shell.closed === 1);

            // Enter on the client-ID confirm: log out and edit the ID
            p.confirmClient = true;
            tc.wait(100);
            tc.keyClick(Qt.Key_Enter);
            shell.check("Enter on the client-ID confirm is the verb: asks for a new ID", p.confirmClient === false && p.editClient === true);
            p.editClient = false;

            // goBack steps out of the menu / confirm first
            p.menuOpen = true;
            shell.check("goBack closes the menu first", p.goBack() === true && p.menuOpen === false);
            p.confirmLogout = true;
            shell.check("goBack cancels a confirm first", p.goBack() === true && p.confirmLogout === false);
            console.log("TEST done failures=" + shell.failures);
            Qt.quit();
        }
    }
}
