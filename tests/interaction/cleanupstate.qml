// Pure-helper tests for CleanupState.qml (decimal sizes, row texts, totals, JSON parsing, terminal command, run guard).
// QS_NO_APPLY is set by the runner: no tool runs, run(id) only records the id. Run by scripts/run-interaction-tests.py.
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

    Component.onCompleted: {
        const S = CleanupState;
        const J = JSON.stringify;
        shell.check("formatBytes: 0 B", S.formatBytes(0) === "0 B");
        shell.check("formatBytes: 512 B", S.formatBytes(512) === "512 B");
        shell.check("formatBytes: 1.5 KB", S.formatBytes(1500) === "1.5 KB");
        shell.check("formatBytes: 1.2 GB (decimal)", S.formatBytes(1.2e9) === "1.2 GB");
        shell.check("formatBytes: 999999 rolls over to 1.0 MB", S.formatBytes(999999) === "1.0 MB");
        shell.check("formatBytes: null and negative are ?", S.formatBytes(null) === "?" && S.formatBytes(-1) === "?" && S.formatBytes(NaN) === "?");

        const rows = [
            { id: "pacman-cache", label: "Old package cache", bytes: 1.5e6, count: 7, needsRoot: true, note: "" },
            { id: "orphans", label: "Orphaned packages", bytes: 0, count: 0, needsRoot: true, note: "" },
            { id: "flatpak-unused", label: "Unused Flatpak runtimes", bytes: null, count: 2, needsRoot: false, note: "size unknown" },
            { id: "shots", label: "Screenshots older than 30 days", bytes: 3000, count: 30, needsRoot: false, note: "" },
            { id: "trash", label: "Trash", bytes: 1.2e9, count: null, needsRoot: false, note: "" },
            { id: "x", label: "Missing", bytes: null, count: null, needsRoot: false, note: "not installed" }
        ];
        shell.check("total sums known sizes, null counts as 0", S.total(rows) === 1.5e6 + 3000 + 1.2e9);
        shell.check("visibleRows drops empty and not-installed rows, keeps unknown-size ones", S.visibleRows(rows).map(r => r.id).join() === "pacman-cache,flatpak-unused,shots,trash");
        shell.check("sizeText: bytes", S.sizeText(rows[0]) === "1.5 MB" && S.sizeText(rows[4]) === "1.2 GB");
        shell.check("sizeText: unknown size shows the count", S.sizeText(rows[2]) === "2 items (size unknown)");
        shell.check("sizeText: not installed", S.sizeText(rows[5]) === "not installed");
        shell.check("detailText: root item says it asks for doas in a terminal", S.detailText(rows[0]) === "7 items (asks for doas in a terminal)");
        shell.check("detailText: a plain item has just the count", S.detailText(rows[3]) === "30 items");
        shell.check("detailText: the trash has none", S.detailText(rows[4]) === "");
        shell.check("confirmVerb: Empty Trash for the trash, Clean up otherwise", S.confirmVerb(rows[4]) === "Empty Trash" && S.confirmVerb(rows[0]) === "Clean up" && S.confirmVerb(rows[3]) === "Clean up");
        shell.check("confirmText names the size", S.confirmText(rows[4]).indexOf("1.2 GB") >= 0 && S.confirmText(rows[3]).indexOf("3.0 KB") >= 0 && S.confirmText(rows[0]).indexOf("1.5 MB") >= 0);
        shell.check("confirmText: root item mentions doas", S.confirmText(rows[0]).indexOf("doas") >= 0 && S.confirmText(rows[3]).indexOf("doas") < 0);

        const parsed = S.parseSizes(J(rows.concat([{ id: "evil", label: "x" }, { id: "trash" }, 7, null])));
        shell.check("parseSizes keeps only known ids with a label", parsed.map(r => r.id).join() === "pacman-cache,orphans,flatpak-unused,shots,trash");
        shell.check("parseSizes keeps null bytes as null", parsed[2].bytes === null && parsed[4].count === null);
        shell.check("parseSizes of garbage is []", S.parseSizes("oops").length === 0 && S.parseSizes('{"a":1}').length === 0);
        shell.check("parseRun: terminal", J(S.parseRun('{"terminal": "doas paccache -r -k2"}')) === J({ terminal: "doas paccache -r -k2" }));
        shell.check("parseRun: ok message", J(S.parseRun('{"ok": false, "message": "gio trash failed"}')) === J({ ok: false, message: "gio trash failed" }));
        shell.check("parseRun: garbage is null", S.parseRun("") === null && S.parseRun("[]") === null);

        const script = "doas paccache -r -k2; echo; read -P 'Press Enter to close'";
        shell.check("terminalCommand: kitty default", J(S.terminalCommand("kitty", "--class", "doas paccache -r -k2")) === J(["kitty", "--class", "qs-dialog", "fish", "-c", script]));
        shell.check("terminalCommand: empty flag leaves the window unnamed", J(S.terminalCommand("foot", "", "x")) === J(["foot", "fish", "-c", "x; echo; read -P 'Press Enter to close'"]));

        S.rows = rows;
        shell.check("trashBytes and trashLabel come from the trash row", S.trashBytes === 1.2e9 && S.trashLabel === "Empty Trash (1.2 GB)");
        S.rows = [];
        shell.check("no rows: trashBytes 0 and a plain label", S.trashBytes === 0 && S.trashLabel === "Empty Trash");
        S.run("bogus");
        shell.check("run ignores an unknown id", S.runLog.length === 0);
        S.run("trash");
        shell.check("run under QS_NO_APPLY only records the id", J(S.runLog) === J(["trash"]) && !S.loading);
        S.load();
        shell.check("load starts nothing under QS_NO_APPLY", !S.loading);
        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
