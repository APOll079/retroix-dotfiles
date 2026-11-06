pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Security toasts from arch-audit. Every settings.securityAudit.intervalHours (and once at start) scripts/secaudit.sh prints
// arch-audit's text; the (package, CVE) pairs in it are compared with the ones already seen (security-seen.json in Quickshell's
// state dir, a GuardedFileView). The first run only records them (no toast storm); after that each new pair raises
//   notify-send -a Security -u critical|normal -- "<package> is affected by <cve>" "<severity> risk[, fixed in <version>]"
// at most `maxToasts` per run (worst first), then one "and N more" toast. critical = High / Critical risk, normal = the rest.
// arch-audit missing = status "not-installed", nothing shown. Not started when QS_NO_APPLY is set (the test harness).
// parse() and decide() are pure so tests can drive them with fixture text.
Singleton {
    id: root

    readonly property var cfg: Config.settings.securityAudit
    readonly property bool active: Config.settingsLoaded && cfg.enabled && !Quickshell.env("QS_NO_APPLY")
    readonly property int maxToasts: 3
    readonly property string script: Quickshell.shellDir + "/scripts/secaudit.sh"

    property string status: "idle"          // idle | ok | not-installed | error
    property string error: ""
    property var items: []                  // [{ package, cve, severity, fixed }] from the last run
    property bool stateReady: false

    // ---- pure helpers ----
    readonly property var rank: ({ critical: 4, high: 3, medium: 2, low: 1 })

    // Text of secaudit.sh -> { status: ok|not-installed|error, error, items }. One item per (package, CVE / AVG id);
    // severity is "High", "Medium", ... (arch-audit's "<word> risk!"), fixed is the version of "Update to <v>!" or "".
    function parse(text) {
        const t = String(text === null || text === undefined ? "" : text);
        if (t.indexOf("##not-installed") >= 0)
            return { status: "not-installed", error: "", items: [] };
        const err = t.match(/^##error (.*)$/m);
        if (err)
            return { status: "error", error: err[1], items: [] };
        const up = t.indexOf("##upgradable");
        const plain = t.slice(0, up >= 0 ? up : t.length);
        const fixedBy = {};
        if (up >= 0) {
            for (const line of t.slice(up).split("\n")) {
                const p = root.parseLine(line);
                if (p && p.fixed !== "")
                    fixedBy[p.package] = p.fixed;
            }
        }
        const out = [], seen = {};
        for (const line of plain.split("\n")) {
            const p = root.parseLine(line);
            if (!p)
                continue;
            for (const cve of p.cves) {
                const key = p.package + "|" + cve;
                if (seen[key])
                    continue;
                seen[key] = true;
                out.push({ package: p.package, cve: cve, severity: p.severity, fixed: p.fixed !== "" ? p.fixed : (fixedBy[p.package] || "") });
            }
        }
        return { status: "ok", error: "", items: out };
    }

    // "Package gnutls is affected by CVE-2024-0553, CVE-2024-0567. High risk! Update to 3.8-1!" -> { package, cves, severity, fixed }
    function parseLine(line) {
        const m = String(line).match(/^\s*Package (\S+) is affected by (.+?)\.?\s+(\w+) risk!(?:\s+Update to (\S+?)!)?/);
        if (!m || !/^[A-Za-z0-9@._+-]+$/.test(m[1]))
            return null;
        const cves = m[2].match(/(?:CVE-\d{4}-\d+|AVG-\d+)/g);
        if (!cves)
            return null;
        const sev = m[3].charAt(0).toUpperCase() + m[3].slice(1).toLowerCase();
        return { package: m[1], cves: cves, severity: sev, fixed: m[4] || "" };
    }

    function key(item) { return item.package + "|" + item.cve; }

    function rankOf(sev) { return root.rank[String(sev).toLowerCase()] || 0; }

    // Items not in `seen` (a list of keys), worst first, then by package name
    function newItems(seen, items) {
        const known = {};
        for (const k of seen)
            known[k] = true;
        return items.filter(i => !known[root.key(i)]).sort((a, b) => root.rankOf(b.severity) - root.rankOf(a.severity) || a.package.localeCompare(b.package) || a.cve.localeCompare(b.cve));
    }

    function toastArgs(item) {
        const urgent = root.rankOf(item.severity) >= 3;
        return ["notify-send", "-a", "Security", "-u", urgent ? "critical" : "normal", "--",
            item.package + " is affected by " + item.cve,
            item.severity + " risk" + (item.fixed !== "" ? ", fixed in " + item.fixed : "")];
    }

    function moreArgs(n) {
        return ["notify-send", "-a", "Security", "-u", "normal", "--", "and " + n + " more", "Run arch-audit to see all affected packages"];
    }

    // state { seeded, seen: [keys] } + the items of this run -> { toasts: [argv], state }. The first run (not seeded)
    // records everything and toasts nothing. The new state's `seen` is exactly the current set, so a fixed pair
    // is forgotten (and would toast again if it came back).
    function decide(state, items, maxToasts) {
        const next = { seeded: true, seen: items.map(i => root.key(i)) };
        if (!state.seeded)
            return { toasts: [], state: next };
        const fresh = root.newItems(state.seen, items);
        const toasts = fresh.slice(0, maxToasts).map(i => root.toastArgs(i));
        if (fresh.length > maxToasts)
            toasts.push(root.moreArgs(fresh.length - maxToasts));
        return { toasts: toasts, state: next };
    }

    // ---- live part ----
    function run() {
        if (root.active && root.stateReady && !poll.running)
            poll.running = true;
    }

    function handle(text) {
        const r = root.parse(text);
        root.status = r.status;
        root.error = r.error;
        if (r.status !== "ok")
            return;
        root.items = r.items;
        const d = root.decide({ seeded: adapter.seeded, seen: Array.from(adapter.seen) }, r.items, root.maxToasts);
        for (const t of d.toasts)
            Quickshell.execDetached(t);
        adapter.seen = d.state.seen;
        adapter.seeded = true;
    }

    onActiveChanged: root.run()
    onStateReadyChanged: root.run()

    Process {
        id: poll
        command: ["sh", root.script]
        stdout: StdioCollector {
            onStreamFinished: root.handle(text)
        }
    }

    Timer {
        interval: Math.max(1, root.cfg.intervalHours) * 3600000
        running: root.active && root.stateReady
        repeat: true
        onTriggered: root.run()
    }

    // GuardedFileView: a security-seen.json that doesn't parse is kept as .bad-<time> and never overwritten
    GuardedFileView {
        path: Quickshell.statePath("security-seen.json")
        printErrors: false
        onLoaded: root.stateReady = true
        onLoadFailed: root.stateReady = true
        JsonAdapter {
            id: adapter
            property bool seeded: false
            property var seen: []
        }
    }
}
