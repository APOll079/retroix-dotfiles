// The cascading Programs menu (popups/PopupCascade.qml): categories with apps only, hidden apps left out, hover or Right opens a
// category's apps, Up / Down move, Enter or a click launches (and closes everything), Left closes the apps list, Escape closes
// the cascade and not the Start menu, and the category set is the launcher's. PopupCascade is two PopupWindows, which can't be
// created offscreen: like updatespanel.qml this loads a scratch copy (in the runner's scratch tree) with PopupWindow turned
// into FloatingWindow and the anchor / grab lines dropped. The apps are fakes; nothing is launched.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    property int closed: 0
    property var launched: []
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function asVar(o: var): var {
        return o;
    }
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }
    function app(id, name, cats) {
        return { id: id, name: name, icon: "", categories: cats, execute: function () { shell.launched = shell.launched.concat([id]); } };
    }

    FileView {
        id: src
        path: Quickshell.shellPath("popups/PopupCascade.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/PopupCascadeTest.qml")
        blockWrites: true
    }
    FileView {
        id: launcher
        path: Quickshell.shellPath("popups/AppLauncher.qml")
        blockLoading: true
    }

    Component.onCompleted: {
        let t = src.text();
        t = t.split("PopupWindow {").join("FloatingWindow {");
        t = t.split("\n").filter(l => l.indexOf("anchor.") < 0 && l.indexOf("grabFocus") < 0).join("\n");
        // (a FloatingWindow is visible from the start and so already has the keyboard focus, which the real key presses below
        // need offscreen; open / close are tested through the cascade's own visible)
        dst.setText(t);
        loader.setSource("popups/PopupCascadeTest.qml", {});
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    // Opens the cascade the way a click on Programs would, with the pointer elsewhere. Offscreen the pointer sits at the
    // window's origin, right on the first row, which would count as a hover; so the hover's effect is undone.
    function fresh(cas) {
        cas.openAt(null, 0, 0);
        tc.wait(150);
        cas.catIndex = -1;
        cas.appIndex = -1;
        cas.subOpen = false;
        cas.inApps = false;
        tc.wait(50);
    }

    // While the apps window is up, offscreen key events go to it (the real grab keeps them on the category popup), so those
    // keys call handleKey, the function the category popup's Keys.onPressed calls; the keyClicks above prove that wiring.
    function key(cas, k) {
        const ev = { key: k, accepted: false };
        cas.handleKey(ev);
        tc.wait(50);
    }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const cas = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", cas !== null);
            cas.closeCallback = function () { shell.closed++; };

            // the same category set as the launcher's filter row
            const lt = launcher.text();
            shell.check("categories: the same keys and freedesktop categories as AppLauncher.categories", cas.categories.every(c => {
                const i = lt.indexOf('{ key: "' + c.key + '", glyph: "');
                if (i < 0)
                    return false;
                const line = lt.slice(i, lt.indexOf("}", i));
                return c.cats.every(x => line.indexOf('"' + x + '"') >= 0) && (line.match(/"[A-Z][A-Za-z]+"/g) || []).length === c.cats.length;
            }) && cas.categories.length === 8);

            // groups: empty categories are not listed, hidden apps are left out
            const apps = [
                shell.app("ff", "Firefox", ["Network", "WebBrowser"]),
                shell.app("vlc", "VLC", ["AudioVideo", "Player"]),
                shell.app("code", "Code", ["Development", "IDE"]),
                shell.app("hid", "Hidden Browser", ["Network"]),
                shell.app("term", "Terminal", ["System", "Utility"])
            ];
            LauncherState.hidden = ["hid"];
            cas.source = apps;
            tc.wait(100);
            const keysOf = () => cas.groups.map(g => g.key).join();
            shell.check("groups: only categories with apps, All first", keysOf() === "all,web,media,dev,system,utility");
            shell.check("groups: a hidden app is in no category", cas.groups.every(g => g.apps.every(a => a.id !== "hid")) && cas.groups[0].apps.length === 4);
            shell.check("groups: an app with two categories is in both", cas.groups.find(g => g.key === "system").apps[0].id === "term" && cas.groups.find(g => g.key === "utility").apps[0].id === "term");

            // keys
            shell.fresh(cas);
            shell.check("open: the category list shows, nothing selected, no apps list", cas.visible && cas.catIndex === -1 && !cas.subVisible);
            tc.keyClick(Qt.Key_Down);
            tc.wait(50);
            shell.check("Down: the first category", cas.catIndex === 0);
            tc.keyClick(Qt.Key_Down);
            tc.keyClick(Qt.Key_Down);
            tc.wait(50);
            shell.check("Down moves through the categories", cas.catIndex === 2 && !cas.subVisible);
            tc.keyClick(Qt.Key_Up);
            tc.keyClick(Qt.Key_Up);
            tc.keyClick(Qt.Key_Up);
            tc.wait(50);
            shell.check("Up wraps to the last category", cas.catIndex === cas.groups.length - 1);
            cas.catIndex = 1;
            tc.keyClick(Qt.Key_Right);
            tc.wait(100);
            shell.check("Right: the apps of the category open and take the keys", cas.subVisible && cas.inApps && cas.appIndex === 0 && cas.shownApps.length === 1 && cas.shownApps[0].id === "ff");
            cas.catIndex = 0;
            cas.inApps = false;
            shell.key(cas, Qt.Key_Right);
            tc.wait(100);
            shell.key(cas, Qt.Key_Down);
            tc.wait(50);
            shell.check("Down in the apps list moves between apps (wraps)", cas.inApps && cas.appIndex === 1 && cas.catIndex === 0);
            shell.key(cas, Qt.Key_Left);
            tc.wait(100);
            shell.check("Left closes the apps list and goes back to the categories", !cas.subVisible && !cas.inApps && cas.visible && cas.catIndex === 0);
            shell.key(cas, Qt.Key_Left);
            tc.wait(50);
            shell.check("Left again does nothing (the cascade stays)", cas.visible);

            // Enter launches and closes everything
            cas.catIndex = 3;
            shell.key(cas, Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter on a category opens its apps", cas.subVisible && cas.inApps && cas.shownApps[0].id === "code");
            const before = LauncherState.counts["code"] || 0;
            shell.key(cas, Qt.Key_Return);
            tc.wait(100);
            shell.check("Enter on an app launches it", shell.launched.join() === "code");
            shell.check("Enter on an app closes the cascade and the Start menu (closeCallback)", !cas.visible && shell.closed === 1);
            shell.check("a launch counts for the launcher's usage ranking", (LauncherState.counts["code"] || 0) === before + 1);

            // Escape closes the cascade only
            cas.openAt(null, 0, 0);
            tc.wait(100);
            cas.hoverCat(1);
            tc.wait(100);
            shell.check("hoverCat opens the apps list", cas.subVisible);
            shell.key(cas, Qt.Key_Escape);
            tc.wait(100);
            shell.check("Escape closes the whole cascade, not the Start menu", !cas.visible && !cas.subVisible && shell.closed === 1);

            shell.fresh(cas);
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("a real Escape key press on the category list closes the cascade (the key wiring)", !cas.visible && shell.closed === 1);

            // mouse: hover and click
            cas.openAt(null, 0, 0);
            tc.wait(200);
            const rows = shell.find(cas.contentItem, c => c.objectName.indexOf("cat-") === 0, []);
            shell.check("one row per category", rows.length === cas.groups.length);
            const media = rows.find(r => r.objectName === "cat-media");
            tc.mouseMove(media, 20, 5);
            tc.wait(200);
            shell.check("hover on a category opens its apps", cas.subVisible && cas.catIndex === 2 && cas.shownApps[0].id === "vlc");
            const subWindow = shell.asVar(cas.data.find(o => o.objectName === "sub"));
            const appRowOf = id => shell.find(subWindow.contentItem, c => c.objectName === "app-" + id, [])[0] || null;
            const subWin = shell.asVar(appRowOf("vlc"));
            shell.check("the app row is there", subWin !== null);
            tc.mouseMove(subWin, 20, 5);
            tc.wait(100);
            shell.check("hover on an app selects it and keeps the category", cas.inApps && cas.appIndex === 0 && cas.catIndex === 2);
            const web = rows.find(r => r.objectName === "cat-web");
            tc.mouseMove(web, 20, 5);
            tc.wait(200);
            shell.check("moving to another category switches the apps list", cas.catIndex === 1 && cas.shownApps[0].id === "ff");
            cas.subOpen = true;
            tc.mouseClick(cas.contentItem, 2, 2);
            tc.wait(100);
            shell.check("a click on the empty edge closes the apps list only", !cas.subVisible && cas.visible);
            tc.mouseClick(media, 20, 5);
            tc.wait(100);
            shell.check("a click on a category opens its apps", cas.subVisible && cas.catIndex === 2);
            tc.mouseClick(shell.asVar(appRowOf("vlc")), 20, 5);
            tc.wait(100);
            shell.check("a click on an app launches it and closes everything", shell.launched.join() === "code,vlc" && !cas.visible && shell.closed === 2);

            // nothing installed
            LauncherState.hidden = [];
            cas.source = [];
            tc.wait(50);
            shell.check("no apps: no categories, Down does nothing", cas.groups.length === 0 && (cas.move(1), cas.catIndex === -1));

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
