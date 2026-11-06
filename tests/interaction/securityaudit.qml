// Security audit (SecurityAudit.qml): parse of fixture arch-audit text (plain and --upgradable lines), the first run that only
// records, the new-pair diff, the 3-toast cap with the "and N more" summary and the exact notify-send arguments. Pure functions;
// QS_NO_APPLY keeps the singleton's timer and Process off. scripts/secaudit.sh is tested in tests/scripts-r4b.py.
import QtQuick
import Quickshell

ShellRoot {
    id: shell
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function js(v) { return JSON.stringify(v); }

    readonly property string fixture: "##plain\n"
        + "Package gnutls is affected by CVE-2024-0553, CVE-2024-0567. High risk!\n"
        + "Package openssl is affected by CVE-2023-5678. Medium risk!\n"
        + "Package linux is affected by CVE-2024-1111, CVE-2024-2222. Critical risk!\n"
        + "Package libfoo is affected by AVG-1234. Low risk!\n"
        + "Package bad name; rm is affected by CVE-2024-9. High risk!\n"
        + "some other line\n"
        + "##upgradable\n"
        + "Package gnutls is affected by CVE-2024-0553, CVE-2024-0567. High risk! Update to 3.8.3-1!\n"
        + "Package linux is affected by CVE-2024-1111, CVE-2024-2222. Critical risk! Update to 6.7.1-1!\n"

    Component.onCompleted: {
        const S = SecurityAudit;
        const r = S.parse(shell.fixture);
        shell.check("parse: ok with one item per (package, CVE), the junk package name skipped", r.status === "ok" && r.items.length === 6);
        shell.check("parse: severity words are capitalised", r.items.find(i => i.package === "openssl").severity === "Medium" && r.items.find(i => i.package === "linux").severity === "Critical");
        shell.check("parse: AVG ids count as ids", r.items.some(i => i.package === "libfoo" && i.cve === "AVG-1234" && i.severity === "Low"));
        shell.check("parse: the fixed version comes from the --upgradable section", r.items.find(i => i.cve === "CVE-2024-0567").fixed === "3.8.3-1" && r.items.find(i => i.package === "openssl").fixed === "");
        const inline = S.parse("##plain\nPackage a is affected by CVE-2020-1. High risk! Update to 1.2-3!\n##upgradable\n");
        shell.check("parse: an 'Update to' on a plain line is read too", inline.items.length === 1 && inline.items[0].fixed === "1.2-3");
        shell.check("parse: not installed and errors and junk", S.parse("##not-installed\n").status === "not-installed"
            && S.parse("##error could not reach security.archlinux.org").status === "error" && S.parse("##error x").error === "x"
            && S.parse("").items.length === 0 && S.parse(null).status === "ok" && S.parse("##plain\n\n##upgradable\n").items.length === 0);

        // first run records, never toasts
        const first = S.decide({ seeded: false, seen: [] }, r.items, 3);
        shell.check("first run: no toasts, but everything is recorded and seeded", first.toasts.length === 0 && first.state.seeded && first.state.seen.length === 6);
        // same set again: nothing new
        const again = S.decide(first.state, r.items, 3);
        shell.check("second run with the same set: no toasts", again.toasts.length === 0);
        // one new pair and one fixed pair
        const items2 = r.items.filter(i => i.cve !== "CVE-2023-5678").concat([{ package: "curl", cve: "CVE-2024-7", severity: "High", fixed: "8.6-1" }]);
        const one = S.decide(first.state, items2, 3);
        shell.check("one new pair: exactly one toast with the exact notify-send arguments", one.toasts.length === 1 && shell.js(one.toasts[0]) === shell.js(["notify-send", "-a", "Security", "-u", "critical", "--", "curl is affected by CVE-2024-7", "High risk, fixed in 8.6-1"]));
        shell.check("a fixed pair is forgotten from the seen set", one.state.seen.indexOf("openssl|CVE-2023-5678") < 0 && one.state.seen.indexOf("curl|CVE-2024-7") >= 0);
        const normal = S.decide(first.state, r.items.concat([{ package: "zlib", cve: "CVE-2024-8", severity: "Medium", fixed: "" }]), 3);
        shell.check("Medium is urgency normal and has no 'fixed in' when unknown", shell.js(normal.toasts[0]) === shell.js(["notify-send", "-a", "Security", "-u", "normal", "--", "zlib is affected by CVE-2024-8", "Medium risk"]));
        // five new pairs: 3 toasts, worst first, and a summary
        const many = [1, 2, 3, 4, 5].map(n => ({ package: "p" + n, cve: "CVE-2024-" + n, severity: n === 5 ? "Critical" : (n === 4 ? "Low" : "High"), fixed: "" }));
        const storm = S.decide({ seeded: true, seen: [] }, many, 3);
        shell.check("five new pairs: three toasts then 'and 2 more'", storm.toasts.length === 4 && storm.toasts[3].join("|") === ["notify-send", "-a", "Security", "-u", "normal", "--", "and 2 more", "Run arch-audit to see all affected packages"].join("|"));
        shell.check("the toasts are the worst first (Critical, then High, High)", storm.toasts[0][6] === "p5 is affected by CVE-2024-5" && storm.toasts[1][6] === "p1 is affected by CVE-2024-1" && storm.toasts[2][6] === "p2 is affected by CVE-2024-2");
        shell.check("exactly three new pairs: no summary", S.decide({ seeded: true, seen: [] }, many.slice(0, 3), 3).toasts.length === 3);
        shell.check("settings.securityAudit is read and the harness is inactive", Config.settings.securityAudit.enabled === true && Config.settings.securityAudit.intervalHours === 12 && S.active === false);

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
