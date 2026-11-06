// Tests for CalcHistory (the launcher's last calculator results) and Emoji (the ":" search): pure functions with
// fixtures, then CalcHistory.add against the scratch state file the runner gives every test.
// Run by scripts/run-interaction-tests.py.
import QtQuick
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
    function js(v) { return JSON.stringify(v); }

    Timer {
        interval: 600; running: true
        onTriggered: shell.run()
    }

    function run() {
        const H = CalcHistory;
        const e = (v, q) => ({ value: v, query: q });

        // ---- history ----
        shell.check("added puts the newest on top", shell.js(H.added([e("4", "2+2")], "9", "3*3", 10)) === shell.js([e("9", "3*3"), e("4", "2+2")]));
        shell.check("added moves an older identical pair up instead of repeating it", shell.js(H.added([e("9", "3*3"), e("4", "2+2")], "4", "2+2", 10)) === shell.js([e("4", "2+2"), e("9", "3*3")]));
        shell.check("the same value from another query is a separate entry", H.added([e("4", "2+2")], "4", "2*2", 10).length === 2);
        const many = [];
        for (let i = 0; i < 10; i++)
            many.push(e(String(i), "q" + i));
        const more = H.added(many, "x", "qx", 10);
        shell.check("added trims to 10, dropping the oldest", more.length === 10 && more[0].value === "x" && more[9].value === "8");
        shell.check("added ignores an empty value", shell.js(H.added([e("4", "2+2")], "   ", "q", 10)) === shell.js([e("4", "2+2")]) && H.added([], "", "", 10).length === 0);
        shell.check("added trims the value and the query", shell.js(H.added([], " 12 ", " 3*4 ", 10)) === shell.js([e("12", "3*4")]));
        shell.check("clean drops junk and repeats", shell.js(H.clean([e("1", "a"), null, { value: 5 }, { value: "" }, e("1", "a"), { value: "2" }, "x"], 10)) === shell.js([e("1", "a"), e("2", "")]));
        shell.check("clean of a non-list is []", shell.js(H.clean({}, 10)) === "[]" && shell.js(H.clean(undefined, 10)) === "[]" && shell.js(H.clean("x", 10)) === "[]");
        shell.check("clean trims a longer file to the maximum", H.clean(many.concat(many.map(x => e(x.value + "b", x.query))), 10).length === 10);
        shell.check("the maximum is 10", H.max === 10);
        // the real singleton, one add at a time with the file settling in between (checked at the end)
        addStep.start();

        // ---- emoji ----
        const E = Emoji;
        const names = (q, n) => E.search(q, n).map(r => r.name);
        shell.check("the table has a few hundred entries, every one with a character, a name and keywords",
            E.table.length >= 250 && E.table.every(r => r.length === 3 && r[0].length > 0 && r[1] !== "" && r[2] !== ""));
        shell.check("exact name ranks first", names("fire", 5)[0] === "fire");
        shell.check("exact name beats a prefix", names("rocket", 3)[0] === "rocket");
        shell.check("a name prefix comes before a keyword match", (() => {
            const r = names("heart", 40);
            // "heart exclamation" starts with heart; "smiling face with heart-eyes" only contains it
            return r.indexOf("heart exclamation") >= 0 && r.indexOf("heart exclamation") < r.indexOf("smiling face with heart-eyes");
        })());
        shell.check("keyword search finds by a keyword that is not in the name", names("lol", 5).indexOf("face with tears of joy") >= 0);
        shell.check("keyword prefix", names("celeb", 10).indexOf("party popper") >= 0);
        shell.check("a word of the name", names("monkey", 20).indexOf("see-no-evil monkey") >= 0);
        shell.check("case and spaces around the query do not matter", shell.js(names("  FIRE ", 5)) === shell.js(names("fire", 5)));
        shell.check("a multi-word query needs every word", names("face tears", 10).indexOf("face with tears of joy") >= 0 && names("rocket zzzz", 10).length === 0);
        shell.check("no match gives []", E.search("qzxwv", 10).length === 0);
        shell.check("the limit is respected", E.search("face", 7).length === 7 && E.search("", 12).length === 12);
        shell.check("an empty query lists the first entries", E.search("", 3)[0].char === E.table[0][0]);
        shell.check("rank: exact 0, name prefix 1, exact keyword 2, keyword prefix 3", (() => {
            const t = ["x", "heart", "kw"];
            return E.rank(["x", "heart", "kw"], "heart") === 0 && E.rank(["x", "heart eyes", "kw"], "heart") === 1
                && E.rank(["x", "face", "heart love"], "heart") === 2 && E.rank(["x", "face", "hearty love"], "heart") === 3
                && E.rank(["x", "red heart", "love"], "heart") === 4 && E.rank(["x", "face", "love"], "heart") === -1;
        })());
        shell.check("results carry the character as a two-code-unit escape for a non-BMP emoji", (() => {
            const r = E.search("rocket", 1)[0];
            return r.char.length === 2 && r.char.charCodeAt(0) >= 0xd800 && r.char.charCodeAt(0) <= 0xdbff;
        })());
    }
    property int addN: 0
    Timer {
        id: addStep
        interval: 300; repeat: true
        onTriggered: {
            if (shell.addN === 0) CalcHistory.add("42", "6*7");
            else if (shell.addN === 1) CalcHistory.add("7", "3+4");
            else if (shell.addN === 2) CalcHistory.add("42", "6*7");
            else {
                addStep.stop();
                shell.check("add keeps the real list: newest first, no repeat", shell.js(CalcHistory.entries) === shell.js([{ value: "42", query: "6*7" }, { value: "7", query: "3+4" }]));
                console.log("TEST done failures=" + shell.failures);
                quitTimer.start();
            }
            shell.addN++;
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
