// MangoHud toggle and Flatpak entries in the Games view: GamesState.launchCommand for every launch kind (pure), the MangoHud button
// in the chip row (same height as Add game, clicking flips settings.games.mangohud), a Flatpak entry counts under Other and not
// under Steam, and shows the source name Flatpak. Hide / unhide is by id like every entry (not driven here: saving games.json
// would start the real games.py scan). scripts/games.py's own Flatpak scan is tested in tests/scripts-r4b.py.
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
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }

    FloatingWindow {
        id: win
        visible: true
        implicitWidth: MenuStyle.windowWidth
        implicitHeight: MenuStyle.windowHeight
        color: Config.colors.base
        Loader {
            id: loader
            anchors.fill: parent
        }
    }

    Component.onCompleted: loader.setSource("popups/GamesView.qml", {})

    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            const G = GamesState;
            const steam = { id: "steam:1", source: "steam", launch: ["steam", "steam://rungameid/1"] };
            const sc = { id: "shortcut:2", source: "shortcut", launch: ["steam", "steam://rungameid/2"] };
            const fp = { id: "flatpak:com.vinegarhq.Sober", source: "flatpak", kind: "flatpak", launch: ["flatpak", "run", "com.vinegarhq.Sober"] };
            const own = { id: "custom:x", source: "custom", launch: ["sh", "-c", "wine ~/g.exe"] };

            shell.check("off: every kind keeps its command and has no environment", [steam, sc, fp, own].every(g => shell.js(G.launchCommand(g, false).command) === shell.js(g.launch) && Object.keys(G.launchCommand(g, false).environment).length === 0));
            shell.check("on, Steam and shortcut: same command, MANGOHUD=1 in the environment", shell.js(G.launchCommand(steam, true)) === shell.js({ command: steam.launch, environment: { MANGOHUD: "1" } })
                && G.launchCommand(sc, true).environment.MANGOHUD === "1");
            shell.check("on, Flatpak: flatpak run --env=MANGOHUD=1 <id>", shell.js(G.launchCommand(fp, true).command) === shell.js(["flatpak", "run", "--env=MANGOHUD=1", "com.vinegarhq.Sober"]));
            shell.check("on, own entry: mangohud in front", shell.js(G.launchCommand(own, true).command) === shell.js(["mangohud", "sh", "-c", "wine ~/g.exe"]));
            shell.check("on, an entry that already starts with mangohud is left alone", shell.js(G.launchCommand({ source: "custom", launch: ["mangohud", "x"] }, true).command) === shell.js(["mangohud", "x"]));
            shell.check("launchCommand does not change the game's own list", shell.js(own.launch) === shell.js(["sh", "-c", "wine ~/g.exe"]));

            const v = shell.asVar(loader.item);
            shell.check("the view loaded", v !== null && v.chips !== undefined);
            GamesState.games = [
                { id: "steam:1", title: "Steam One", source: "steam", launch: steam.launch, cwd: "", dir: "", art: "", lastPlayed: 0 },
                { id: "flatpak:com.vinegarhq.Sober", title: "Sober", source: "flatpak", kind: "flatpak", launch: fp.launch, cwd: "", dir: "", art: "", lastPlayed: 0 }
            ];
            GamesState.loaded = true;
            tc.wait(200);
            v.setFilter("other");
            shell.check("a Flatpak game is under Other", v.results.length === 1 && v.results[0].title === "Sober");
            v.setFilter("steam");
            shell.check("a Flatpak game is not under Steam", v.results.length === 1 && v.results[0].title === "Steam One");
            v.setFilter("all");
            shell.check("both show under All and the source reads Flatpak", v.results.length === 2 && v.sourceName(GamesState.games[1]) === "Flatpak");
            const mango = shell.find(v, c => c.visible && c.text === "MangoHud" && c.clicked !== undefined, []);
            const add = shell.find(v, c => c.visible && c.text === "Add game" && c.clicked !== undefined, []);
            shell.check("one MangoHud button next to Add game, the same height", mango.length === 1 && add.length === 1 && mango[0].height === add[0].height);
            const before = Config.settings.games.mangohud === true;
            shell.check("it starts unchecked (default off)", before === false && mango[0].checked === false);
            tc.mouseClick(mango[0]);
            tc.wait(100);
            shell.check("clicking turns it on: the setting flips and the button is checked", Config.settings.games.mangohud === true && mango[0].checked === true);
            tc.mouseClick(mango[0]);
            tc.wait(100);
            shell.check("clicking again turns it off", Config.settings.games.mangohud === false && mango[0].checked === false);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
