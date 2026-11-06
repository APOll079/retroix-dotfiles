// Settings tab of the launcher (popups/SettingsView.qml, SettingRow.qml, SettingsSchema.js):
//  (a) pure helpers on fixtures, (b) schema coverage against quickshell/settings.json, (c) each control type on a
//  scratch settings object (QtObjects, never Config.settings), (d) the view with real clicks and keys.
// Nothing here touches the real settings: every value lives in the fixtures below.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "popups/SettingsSchema.js" as Schema

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
    function leaves(o, prefix, out) {
        for (const k of Object.keys(o)) {
            const v = o[k], p = prefix === "" ? k : prefix + "." + k;
            if (v !== null && typeof v === "object" && !Array.isArray(v))
                shell.leaves(v, p, out);
            else
                out.push(p);
        }
        return out;
    }

    FileView {
        id: barFile
        path: Quickshell.shellPath("taskbar/Bar.qml")
        blockLoading: true
    }

    FileView {
        id: realSettings
        path: Quickshell.shellPath("settings.json")
        blockLoading: true
    }

    // scratch values for the control tests
    QtObject {
        id: fx
        property var g: QtObject {
            property bool b: false
            property int n: 5
            property int neg: 0
            property string s: "a"
            property var l: ["x"]
            property string c: "one"
            property bool r: false
        }
    }
    // scratch values for the view
    QtObject {
        id: fx2
        property bool militaryTimeClockFormat: true
        property string currentTheme: "cherry"
        property var bar: QtObject {
            property int fontSize: 12
            property int trayIconSize: 20
            property bool monochromeTrayIcons: true
        }
        property var idle: QtObject {
            property bool enabled: true
            property int dimMinutes: 5
            property int lockMinutes: 10
            property int screenOffMinutes: 15
            property bool stayAwakeInFullscreen: true
        }
        property var memoryWatch: QtObject {
            property bool enabled: true
            property int ramPercent: 90
            property int tmpGb: 4
            property int cooldownMinutes: 30
        }
    }

    property int escapes: 0
    property int focusSearches: 0
    property int openedCount: 0
    property string lastAction: ""

    FloatingWindow {
        implicitWidth: 900; implicitHeight: 700
        Rectangle {
            anchors.fill: parent
            color: Config.colors.base
            Column {
                id: rows
                x: 10; y: 10
                spacing: 4
                Loader { id: lBool; Component.onCompleted: setSource("popups/SettingRow.qml", { width: 500, settings: fx, entry: { category: "t", path: "g.b", type: "bool", label: "Flag", hint: "A flag", restart: false } }) }
                Loader { id: lRestart; Component.onCompleted: setSource("popups/SettingRow.qml", { width: 500, settings: fx, entry: { category: "t", path: "g.r", type: "bool", label: "Needs restart", hint: "", restart: true } }) }
                Loader { id: lInt; Component.onCompleted: setSource("popups/SettingRow.qml", { width: 500, settings: fx, entry: { category: "t", path: "g.n", type: "int", label: "Count", hint: "1 to 10", min: 1, max: 10, restart: false } }) }
                Loader { id: lNeg; Component.onCompleted: setSource("popups/SettingRow.qml", { width: 500, settings: fx, entry: { category: "t", path: "g.neg", type: "int", label: "Offset", hint: "", min: -5, max: 5, restart: false } }) }
                Loader { id: lStr; Component.onCompleted: setSource("popups/SettingRow.qml", { width: 500, settings: fx, entry: { category: "t", path: "g.s", type: "string", label: "Name", hint: "text", restart: false } }) }
                Loader { id: lList; Component.onCompleted: setSource("popups/SettingRow.qml", { width: 500, settings: fx, entry: { category: "t", path: "g.l", type: "list", label: "Items", hint: "", restart: false } }) }
                Loader { id: lChoice; Component.onCompleted: setSource("popups/SettingRow.qml", { width: 500, settings: fx, entry: { category: "t", path: "g.c", type: "choice", label: "Pick", hint: "", choices: ["one", "two", "three"], restart: false } }) }
            }
            Loader {
                id: lView
                x: 520; y: 10
                width: 370; height: 600
            }
            TestCase { id: tc; name: "sim"; when: false }
            Timer {
                interval: 1500; running: true
                onTriggered: shell.run()
            }
        }
    }

    function inputOf(loader) {
        return shell.find(loader.item, c => c.visible && c.selectByMouse !== undefined, [])[0];
    }
    function buttonsOf(item, label) {
        return shell.find(item, c => c.visible && c.clicked !== undefined && c.text === label, []);
    }

    function run() {
        // ---- (a) pure helpers
        const S = Schema.SCHEMA;
        shell.check("categories keep the fixed order", js(Schema.categories(S).slice(0, 3)) === js(["General", "Bar", "Appearance"]));
        shell.check("categories include a later-added one at the end", js(Schema.categories(S.concat([{ category: "Zed", path: "z.a", type: "bool", label: "", hint: "" }])).slice(-1)) === js(["Zed"]));
        shell.check("entriesFor Bar has the 3 bar keys", Schema.entriesFor(S, "Bar").length === 3);
        shell.check("entriesFor an unknown category is empty", Schema.entriesFor(S, "Nope").length === 0);
        shell.check("search is case-insensitive over label", Schema.search(S, "TRAY").length >= 2);
        shell.check("search matches the path", Schema.search(S, "idle.dim").length === 1);
        shell.check("search matches the hint", Schema.search(S, "fullscreen").some(s => s.path === "idle.stayAwakeInFullscreen"));
        shell.check("search spans categories", new Set(Schema.search(S, "minutes").map(s => s.category)).size > 1);
        shell.check("empty search matches nothing", Schema.search(S, "  ").length === 0);
        shell.check("parseList trims and drops empties", js(Schema.parseList(" a, b ,, c ,")) === js(["a", "b", "c"]));
        shell.check("parseList of empty text is []", js(Schema.parseList("")) === "[]");
        shell.check("listText joins", Schema.listText(["a", "b"]) === "a, b" && Schema.listText(undefined) === "");
        shell.check("list round trip", js(Schema.parseList(Schema.listText(["x", "y z"]))) === js(["x", "y z"]));
        shell.check("parseIntRange accepts in range", js(Schema.parseIntRange("7", 1, 10)) === js({ ok: true, value: 7, message: "" }));
        shell.check("parseIntRange refuses above max", !Schema.parseIntRange("11", 1, 10).ok && Schema.parseIntRange("11", 1, 10).message === "Must be 1 to 10");
        shell.check("parseIntRange refuses below min", !Schema.parseIntRange("0", 1, 10).ok);
        shell.check("parseIntRange refuses text and a minus when min >= 0", !Schema.parseIntRange("-1", 0, 10).ok && !Schema.parseIntRange("1a", 0, 10).ok && !Schema.parseIntRange("", 0, 10).ok);
        shell.check("parseIntRange accepts a minus when min < 0", Schema.parseIntRange("-3", -5, 5).value === -3);
        const plain = { a: { b: 1, l: [] }, top: true };
        shell.check("valueOf reads nested and top-level", Schema.valueOf(plain, "a.b") === 1 && Schema.valueOf(plain, "top") === true && Schema.valueOf(plain, "a.x.y") === undefined);
        const arr = ["q"];
        shell.check("setValue assigns and copies arrays", Schema.setValue(plain, "a.b", 2) && plain.a.b === 2 && Schema.setValue(plain, "a.l", arr) && plain.a.l !== arr && js(plain.a.l) === '["q"]');
        shell.check("setValue on a missing group is false", Schema.setValue(plain, "nope.x", 1) === false);
        shell.check("setValue top-level", Schema.setValue(plain, "top", false) && plain.top === false);

        // ---- (b) coverage
        const real = JSON.parse(realSettings.text()).settings;
        const leafPaths = shell.leaves(real, "", []);
        const schemaPaths = S.filter(s => s.type !== "action").map(s => s.path);
        const notes = S.filter(s => s.type === "json-note").map(s => s.path);
        shell.check("json-note exceptions are exactly session.customActions", js(notes) === js(["session.customActions"]));
        const missing = leafPaths.filter(p => schemaPaths.indexOf(p) < 0);
        shell.check("every settings.json key is in the schema (missing: " + missing.join(" ") + ")", missing.length === 0);
        const extra = schemaPaths.filter(p => leafPaths.indexOf(p) < 0);
        shell.check("every schema path exists in settings.json (extra: " + extra.join(" ") + ")", extra.length === 0);
        // System tools rows: every action id is unique and has a handler in Bar.qml's toolActions
        const acts = S.filter(s => s.type === "action");
        const barText = barFile.text();
        shell.check("System tools: eight action rows with unique ids", acts.length === 8 && new Set(acts.map(a => a.action)).size === 8);
        const noHandler = acts.filter(a => barText.indexOf("\n" + a.action + ": function()") < 0).map(a => a.action);
        shell.check("every System tools action has a handler in Bar.qml toolActions (missing: " + noHandler.join(" ") + ")", noHandler.length === 0);
        shell.check("action rows come last, in their own category", acts.every(a => a.category === "System tools") && Schema.categories(S).slice(-1)[0] === "System tools");
        shell.check("search finds a tool by name", Schema.search(S, "network").some(s => s.action === "network") && Schema.search(S, "services").some(s => s.action === "services"));
        shell.check("schema paths are unique", new Set(schemaPaths).size === schemaPaths.length);
        shell.check("every entry has a category, label and hint", S.every(s => s.category && s.label && s.hint));
        shell.check("every int has a range", S.filter(s => s.type === "int").every(s => s.min !== undefined && s.max !== undefined && s.min <= s.max));
        shell.check("every choice has choices or a source", S.filter(s => s.type === "choice").every(s => s.choices || s.choicesFrom === "themes"));
        shell.check("every category is in the fixed list", Schema.categories(S).every(c => Schema.CATEGORIES.indexOf(c) >= 0));

        // ---- (c) controls
        const rBool = shell.asVar(lBool.item);
        tc.mouseClick(shell.buttonsOf(rBool, "Off")[0]); tc.wait(50);
        shell.check("bool: click turns it on", fx.g.b === true);
        shell.check("bool: the button reads On", shell.buttonsOf(rBool, "On").length === 1);
        tc.mouseClick(shell.buttonsOf(rBool, "On")[0]); tc.wait(50);
        shell.check("bool: click turns it off again", fx.g.b === false);
        shell.check("bool without restart: no restart note", rBool.message === "Saved Flag" && !rBool.messageIsError);
        const rRe = shell.asVar(lRestart.item);
        tc.mouseClick(shell.buttonsOf(rRe, "Off")[0]); tc.wait(50);
        shell.check("restart: the message says it applies after a restart", fx.g.r === true && rRe.message.indexOf("applies after a Quickshell restart") >= 0);

        const rInt = shell.asVar(lInt.item), inInt = shell.inputOf(lInt);
        inInt.forceActiveFocus();
        inInt.text = "99"; tc.keyClick(Qt.Key_Return); tc.wait(50);
        shell.check("int: out of range is not written", fx.g.n === 5);
        shell.check("int: out of range gives an error message", rInt.messageIsError && rInt.message.indexOf("Must be 1 to 10") >= 0);
        inInt.text = "7"; tc.keyClick(Qt.Key_Return); tc.wait(50);
        shell.check("int: Enter saves an in-range value", fx.g.n === 7 && !rInt.messageIsError);
        inInt.text = "3"; tc.keyClick(Qt.Key_Escape); tc.wait(50);
        shell.check("int: Escape reverts the field and writes nothing", inInt.text === "7" && fx.g.n === 7);
        inInt.text = ""; tc.keyClick("a"); tc.keyClick("4");
        shell.check("int: letters are not typed, digits are", inInt.text === "4");
        inInt.text = "8";
        shell.asVar(lStr.item).focusFirstControl(); tc.wait(50);
        shell.check("int: losing focus saves the changed text", fx.g.n === 8);
        inInt.forceActiveFocus(); inInt.text = "0";
        shell.asVar(lStr.item).focusFirstControl(); tc.wait(50);
        shell.check("int: losing focus with a bad value refuses, reverts the text", fx.g.n === 8 && inInt.text === "8" && rInt.messageIsError);
        const inNeg = shell.inputOf(lNeg);
        inNeg.forceActiveFocus(); inNeg.text = ""; tc.keyClick("-"); tc.keyClick("3");
        shell.check("int: a minus is typed when min < 0", inNeg.text === "-3");
        tc.keyClick(Qt.Key_Return); tc.wait(50);
        shell.check("int: negative value saved", fx.g.neg === -3);

        const inStr = shell.inputOf(lStr);
        inStr.forceActiveFocus(); inStr.text = "hello"; tc.keyClick(Qt.Key_Return); tc.wait(50);
        shell.check("string: Enter saves", fx.g.s === "hello");
        const rStr = shell.asVar(lStr.item);
        rStr.escaped.connect(() => { shell.escapes++; });
        inStr.text = "oops"; tc.keyClick(Qt.Key_Escape); tc.wait(50);
        shell.check("string: Escape reverts", inStr.text === "hello" && fx.g.s === "hello" && shell.escapes === 0);
        tc.keyClick(Qt.Key_Escape); tc.wait(50);
        shell.check("string: Escape with nothing to revert emits escaped", shell.escapes === 1);
        const before = rStr.message;
        inStr.forceActiveFocus(); tc.keyClick(Qt.Key_Return); tc.wait(50);
        shell.check("string: unchanged text writes nothing", rStr.message === before);

        const inList = shell.inputOf(lList);
        inList.forceActiveFocus(); inList.text = "a, b,, c ,"; tc.keyClick(Qt.Key_Return); tc.wait(50);
        shell.check("list: saves a trimmed array", js(fx.g.l) === js(["a", "b", "c"]));
        shell.check("list: the field shows the joined text", inList.text === "a, b, c");
        inList.text = ""; tc.keyClick(Qt.Key_Return); tc.wait(50);
        shell.check("list: empty text saves []", js(fx.g.l) === "[]");

        const rCh = shell.asVar(lChoice.item);
        shell.check("choice: one button per value, current is checked", shell.buttonsOf(rCh, "one")[0].checked === true && shell.buttonsOf(rCh, "two")[0].checked === false && shell.buttonsOf(rCh, "three").length === 1);
        tc.mouseClick(shell.buttonsOf(rCh, "two")[0]); tc.wait(50);
        shell.check("choice: click picks it", fx.g.c === "two" && shell.buttonsOf(rCh, "two")[0].checked === true && shell.buttonsOf(rCh, "one")[0].checked === false);

        // ---- (d) the view
        lView.setSource("popups/SettingsView.qml", { settingsObject: fx2, dryRun: true });
        tc.wait(300);
        const view = shell.asVar(lView.item);
        view.focusSearch.connect(() => { shell.focusSearches++; });
        view.opened.connect(() => { shell.openedCount++; });
        shell.check("view: starts on the first category", view.category === "General" && view.shown.length === 10);
        tc.mouseClick(shell.buttonsOf(view, "Bar")[0]); tc.wait(200);
        shell.check("view: clicking a category switches the rows", view.category === "Bar" && view.shown.length === 3);
        shell.check("view: the Bar rows are built", shell.find(view, c => c.visible && c.entry !== undefined && c.entry.path === "bar.fontSize", []).length === 1);
        tc.keyClick(Qt.Key_Down); tc.wait(50);
        shell.check("view: Down on the category list moves to the next category", view.category === "Appearance");
        tc.keyClick(Qt.Key_Up); tc.keyClick(Qt.Key_Up); tc.wait(50);
        shell.check("view: Up moves back, and stops at the first", view.category === "General");
        tc.mouseClick(shell.buttonsOf(view, "Appearance")[0]); tc.wait(200);
        const themeCount = Object.keys(Config.themes).length;
        shell.check("view: the Theme choice lists every theme", shell.find(view, c => c.visible && c.entry !== undefined && c.entry.path === "currentTheme", []).length === 1
            && shell.find(view, c => c.visible && c.clicked !== undefined && Object.keys(Config.themes).indexOf(c.text) >= 0, []).length === themeCount);
        tc.keyClick(Qt.Key_Escape); tc.wait(50);
        shell.check("view: Escape on the category list emits focusSearch", shell.focusSearches === 1);

        view.query = "minutes"; tc.wait(200);
        const hits = Schema.search(S, "minutes");
        shell.check("view: a query lists matches from all categories", view.shown.length === hits.length && new Set(view.shown.map(s => s.category)).size > 1);
        shell.check("view: a query disables the category rows", shell.buttonsOf(view, "Bar").length === 1 && shell.buttonsOf(view, "Bar")[0].enabled === false);
        shell.check("view: category rows show counts while searching", view.countIn("Idle and power") === hits.filter(s => s.category === "Idle and power").length);
        view.query = "zzzzzz"; tc.wait(100);
        shell.check("view: a query without a match shows nothing", view.shown.length === 0);
        view.query = ""; tc.wait(100);

        shell.check("view: handleKey consumes Down only", view.handleKey({ key: Qt.Key_Down }) === true && view.handleKey({ key: Qt.Key_A }) === false);
        view.category = "Bar"; tc.wait(200);
        view.focusFirst(); tc.wait(100);
        const fsInput = shell.find(view, c => c.visible && c.selectByMouse !== undefined, [])[0];
        shell.check("view: focusFirst focuses the first control", fsInput && fsInput.activeFocus);
        fsInput.text = "99"; tc.keyClick(Qt.Key_Return); tc.wait(100);
        shell.check("view: a refused value shows an error in the status line and is not written", fx2.bar.fontSize === 12
            && shell.find(view, c => c.visible && c.text !== undefined && c.text.indexOf("Must be 8 to 32") >= 0, []).length > 0);
        fsInput.text = "14"; tc.keyClick(Qt.Key_Return); tc.wait(100);
        shell.check("view: a saved value reaches the settings object and the status line", fx2.bar.fontSize === 14
            && shell.find(view, c => c.visible && c.text === "Saved Bar font size", []).length > 0);
        tc.keyClick(Qt.Key_Escape); tc.wait(50);
        shell.check("view: Escape in a field with nothing to revert emits focusSearch", shell.focusSearches === 2);

        const open = shell.buttonsOf(view, "Open settings.json");
        shell.check("view: there is an Open settings.json button", open.length === 1);
        tc.mouseClick(open[0]); tc.wait(50);
        shell.check("view: the button asks to open the file", shell.openedCount === 1);

        // System tools: an Open row emits its action id (the launcher then closes and Bar.qml opens the tool)
        view.actionRequested.connect(id => { shell.lastAction = id; });
        view.query = "network"; tc.wait(200);
        const opens = shell.buttonsOf(view, "Open");
        shell.check("view: searching 'network' shows the Network tool row with an Open button", opens.length >= 1);
        tc.mouseClick(opens[0]); tc.wait(50);
        shell.check("view: clicking Open emits the tool's action id", shell.lastAction === "network");
        view.query = "";

        console.log("TEST done failures=" + shell.failures);
        Qt.quit();
    }
}
