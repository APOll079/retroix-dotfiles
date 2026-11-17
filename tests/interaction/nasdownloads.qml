// Tests for NasWatch (NAS mount status) and DownloadWatch (download-finished toast): the pure functions with fixtures,
// no tool runs (the runner sets QS_NO_APPLY, so both singletons stay inactive).
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
        interval: 500; running: true
        onTriggered: shell.run()
    }

    function run() {
        const N = NasWatch;
        shell.check("both stay inactive under QS_NO_APPLY", N.active === false && DownloadWatch.active === false);
        shell.check("NasWatch reads its settings group (two mounts) and starts with nothing mounted", N.mounts.join() === "/mnt/disk1,/mnt/disk2" && N.anyMounted === false && N.anyStale === false && N.summary === "none mounted");

        // ---- NasWatch ----
        shell.check("cleanMounts keeps safe absolute paths once", shell.js(N.cleanMounts(["/mnt/disk1", "/mnt/disk2", "/mnt/disk1"])) === shell.js(["/mnt/disk1", "/mnt/disk2"]));
        shell.check("cleanMounts drops unsafe ones", shell.js(N.cleanMounts(["relative", "/mnt/a b", "/mnt/../etc", "/", "/mnt/x;rm", 5, null, "/mnt/$(x)", "", "/mnt/ok-1_2.x"])) === shell.js(["/mnt/ok-1_2.x"]));
        shell.check("cleanMounts of a non-list is []", shell.js(N.cleanMounts(undefined)) === "[]" && shell.js(N.cleanMounts("x")) === "[]");
        const conf = ["/mnt/disk1", "/mnt/disk2"];
        const out = '[{"path":"/mnt/disk1","state":"mounted"},{"path":"/mnt/disk2","state":"stale"},{"path":"/mnt/evil","state":"mounted"},{"path":"/mnt/disk1","state":"bogus"}]';
        const s = N.parseStatus(out, conf);
        shell.check("parseStatus keeps configured paths with a known state", s["/mnt/disk1"] === "mounted" && s["/mnt/disk2"] === "stale" && s["/mnt/evil"] === undefined);
        shell.check("parseStatus of junk is {}", shell.js(N.parseStatus("oops", conf)) === "{}" && shell.js(N.parseStatus("{}", conf)) === "{}" && shell.js(N.parseStatus("", conf)) === "{}");
        shell.check("count / summaryText", N.count(s, "stale") === 1 && N.summaryText(s) === "1 mounted, 1 stale"
            && N.summaryText({ a: "mounted", b: "mounted" }) === "2 mounted" && N.summaryText({ a: "unmounted" }) === "none mounted" && N.summaryText({ a: "stale" }) === "1 stale");
        shell.check("stalePaths lists the stale ones", shell.js(N.stalePaths(s)) === shell.js(["/mnt/disk2"]));
        shell.check("canRemount only for configured paths", N.canRemount("/mnt/disk1", conf) && !N.canRemount("/mnt/other", conf) && !N.canRemount("/mnt/disk1; rm -rf /", conf) && !N.canRemount(null, conf) && !N.canRemount("/mnt/disk", conf));
        N.remount("/mnt/other");
        shell.check("remount refuses a path that is not configured (and records nothing)", shell.js(N.remountLog) === "[]");

        // toast: once per crossing, re-armed after recovery AND the cooldown
        const CD = 10 * 60000, MIN = 60000;
        function toasts(series) {   // [[stale, minutes]] -> indexes that fired
            let st = N.newState();
            const fired = [];
            series.forEach((p, i) => {
                const r = N.step(st, p[0], CD, p[1] * MIN);
                st = r.state;
                if (r.fire)
                    fired.push(i);
            });
            return fired.join(",");
        }
        shell.check("going stale toasts once", toasts([[false, 0], [true, 1], [true, 2], [true, 3]]) === "1");
        shell.check("recovering and going stale again before the cooldown stays quiet", toasts([[true, 0], [false, 2], [true, 4]]) === "0");
        shell.check("recovering, then going stale after the cooldown toasts again", toasts([[true, 0], [false, 2], [true, 15]]) === "0,2");
        shell.check("never stale never toasts", toasts([[false, 0], [false, 1], [false, 2]]) === "");
        const pl = N.plan({}, { "/mnt/a": "stale", "/mnt/b": "mounted" }, CD, 0);
        shell.check("plan toasts only the stale mount, and remembers it", shell.js(pl.fire) === shell.js(["/mnt/a"]) && pl.armed["/mnt/a"].armed === false && pl.armed["/mnt/b"].armed === true);
        const pl2 = N.plan(pl.armed, { "/mnt/a": "stale", "/mnt/b": "stale" }, CD, MIN);
        shell.check("plan: the still-stale mount does not toast again, a newly stale one does", shell.js(pl2.fire) === shell.js(["/mnt/b"]));

        // ---- DownloadWatch ----
        const D = DownloadWatch;
        // polls: [[{name,size}...]...]; parts: the partial file names per poll (missing = none) -> per poll the toasted names, joined
        function drive(polls, parts) {
            let st = D.newState();
            return polls.map((files, i) => {
                const r = D.step(st, files, 2, (parts || [])[i] || []);
                st = r.state;
                return r.fire.join("+");
            }).join("|");
        }
        const f = (n, s) => ({ name: n, size: s });
        shell.check("files already there at start never toast", drive([[f("old.zip", 100)], [f("old.zip", 100)], [f("old.zip", 100)], [f("old.zip", 100)]]) === "|||");
        shell.check("steady for two polls exactly: toast on the third sighting", drive([[], [f("a.iso", 10)], [f("a.iso", 10)], [f("a.iso", 10)], [f("a.iso", 10)]], [[], ["x.part"]]) === "|||a.iso|");
        shell.check("a growing file toasts once it has stopped", drive([[], [f("a", 1)], [f("a", 2)], [f("a", 3)], [f("a", 3)], [f("a", 3)], [f("a", 3)]], [[], ["x.part"]]) === "|||||a|");
        shell.check("an empty file does not toast", drive([[], [f("z", 0)], [f("z", 0)], [f("z", 0)], [f("z", 0)]], [[], ["x.part"]]) === "||||");
        shell.check("a file that vanishes and comes back toasts again", drive([[], [f("a", 5)], [f("a", 5)], [f("a", 5)], [], [f("a", 5)], [f("a", 5)], [f("a", 5)]], [[], ["x.part"], [], [], ["y.part"]]) === "|||a||||a");
        shell.check("two files finishing together toast both", drive([[], [f("a", 5), f("b", 6)], [f("a", 5), f("b", 6)], [f("a", 5), f("b", 6)]], [[], ["x.part"]]) === "|||a+b");
        shell.check("a base file that changes later never toasts", drive([[f("old", 5)], [f("old", 6)], [f("old", 6)], [f("old", 6)], [f("old", 6)]], [[], ["x.part"]]) === "||||");
        shell.check("rewriting a toasted file toasts again only after a new partial", drive([[], [f("a", 5)], [f("a", 5)], [f("a", 5)], [f("a", 9)], [f("a", 9)], [f("a", 9)]], [[], ["x.part"], [], ["y.part"]]) === "|||a|||a");
        shell.check("rewriting a toasted file with no partial does not toast again", drive([[], [f("a", 5)], [f("a", 5)], [f("a", 5)], [f("a", 5)], [f("a", 5)], [f("a", 9)], [f("a", 9)], [f("a", 9)]], [[], ["x.part"]]) === "|||a|||||");
        shell.check("junk entries are ignored", drive([[], [f("a", 5), null, { name: 3 }, { name: "", size: 1 }, { name: "x" }]]) === "|");
        shell.check("no partial seen: a new file never toasts (upload, unzip, copy)", drive([[], [f("up.png", 5)], [f("up.png", 5)], [f("up.png", 5)], [f("up.png", 5)]]) === "||||");
        shell.check("Zen: placeholder + .part, then the .part goes and the file fills: one toast", drive([[], [f("m.mkv", 0)], [f("m.mkv", 0)], [f("m.mkv", 500)], [f("m.mkv", 500)], [f("m.mkv", 500)], [f("m.mkv", 500)]], [[], ["m.mkv.part"], ["m.mkv.part"]]) === "|||||m.mkv|");
        shell.check("Chromium: Unconfirmed .crdownload renamed to the real name: one toast", drive([[], [], [f("movie.mkv", 9)], [f("movie.mkv", 9)], [f("movie.mkv", 9)]], [[], ["Unconfirmed 1.crdownload"]]) === "||||movie.mkv");
        shell.check("a file next to a partial that is still downloading does not toast", drive([[], [f("a", 5)], [f("a", 5)], [f("a", 5)]], [[], ["x.part"], ["x.part"], ["x.part"]]) === "|||");
        shell.check("an old partial past the window arms nothing", drive([[], [], [], [], [], [f("late", 5)], [f("late", 5)], [f("late", 5)]], [[], ["x.part"]]) === "|||||||");
        shell.check("parseFiles: the files of the new object", shell.js(D.parseFiles('{"files":[{"name":"a","size":1},{"name":2}],"partials":["a.part"]}')) === shell.js([{ name: "a", size: 1 }]));
        shell.check("parsePartials: names from the object, [] for the old list and junk", shell.js(D.parsePartials('{"files":[],"partials":["a.part",3]}')) === shell.js(["a.part"]) && shell.js(D.parsePartials('[{"name":"a","size":1}]')) === "[]" && shell.js(D.parsePartials("oops")) === "[]");
        shell.check("parseFiles: a list, junk filtered", shell.js(D.parseFiles('[{"name":"a","size":1},{"name":2,"size":1},5]')) === shell.js([{ name: "a", size: 1 }]));
        shell.check("parseFiles: not a list is null (the poll failed)", D.parseFiles("") === null && D.parseFiles("oops") === null && D.parseFiles("{}") === null && shell.js(D.parseFiles("[]")) === "[]");
        const cmd = D.toastCommand("evil'; touch x; '.iso", "/home/u/Downloads");
        shell.check("toastCommand: name and folder are positional parameters, not script text", cmd[0] === "sh" && cmd[1] === "-c" && cmd[2].indexOf("evil") < 0 && cmd[4] === "Download finished" && cmd[5] === "evil'; touch x; '.iso" && cmd[6] === "/home/u/Downloads");
        shell.check("toastCommand: Open and Show in folder actions, -a Downloads, options end before the title", cmd[2].indexOf("-a Downloads") >= 0 && cmd[2].indexOf("-A default=Open") >= 0 && cmd[2].indexOf('-A folder="Show in folder"') >= 0 && cmd[2].indexOf('-- "$1" "$2"') >= 0);
        shell.check("toastCommand: Open opens the file, the folder action opens the folder", cmd[2].indexOf('default) xdg-open "$3/$2"') >= 0 && cmd[2].indexOf('folder) xdg-open "$3"') >= 0);
        shell.check("folder is ~/Downloads", D.folder === Quickshell.env("HOME") + "/Downloads");

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
