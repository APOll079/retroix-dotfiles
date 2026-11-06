// Logic test for the launcher's time zones (utils/TimeZones.qml): pure functions with a fixed "now".
import QtQuick
import Quickshell
import "utils" as Utils

ShellRoot {
    id: shell
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function at(q, y, mo, d, h, mi) {
        const a = Utils.TimeZones.answer(q, Date.UTC(y, mo - 1, d, h, mi));
        return a === null ? "null" : a.title;
    }

    Component.onCompleted: {
        // 2026-11-07 12:05 UTC is a Saturday
        shell.check("TimeZones: tokyo", shell.at("time tokyo", 2026, 11, 7, 12, 5) === "Tokyo 21:05 (Sat 7 Nov)");
        shell.check("TimeZones: utc", shell.at("time utc", 2026, 11, 7, 12, 5) === "UTC 12:05 (Sat 7 Nov)");
        shell.check("TimeZones: new york in November is standard time", shell.at("time new york", 2026, 11, 7, 12, 5) === "New York 07:05 (Sat 7 Nov)");
        shell.check("TimeZones: new york in July is daylight time", shell.at("time new york", 2026, 7, 7, 12, 5) === "New York 08:05 (Tue 7 Jul)");
        shell.check("TimeZones: berlin in July", shell.at("time berlin", 2026, 7, 7, 12, 5) === "Berlin 14:05 (Tue 7 Jul)");
        shell.check("TimeZones: berlin in November", shell.at("time Berlin", 2026, 11, 7, 12, 5) === "Berlin 13:05 (Sat 7 Nov)");
        shell.check("TimeZones: sydney in November is daylight time", shell.at("time sydney", 2026, 11, 7, 12, 5) === "Sydney 23:05 (Sat 7 Nov)");
        shell.check("TimeZones: sydney in July is standard time", shell.at("time sydney", 2026, 7, 7, 12, 5) === "Sydney 22:05 (Tue 7 Jul)");
        shell.check("TimeZones: the date rolls over", shell.at("time tokyo", 2026, 11, 7, 20, 0) === "Tokyo 05:00 (Sun 8 Nov)");
        shell.check("TimeZones: auckland in January", shell.at("time auckland", 2026, 1, 15, 12, 0) === "Auckland 01:00 (Fri 16 Jan)");
        shell.check("TimeZones: half hour zone", shell.at("time delhi", 2026, 11, 7, 12, 5) === "Delhi 17:35 (Sat 7 Nov)");
        // EU switch 2026-03-29 01:00 UTC, US switch 2026-03-08 07:00 UTC (02:00 EST)
        shell.check("TimeZones: berlin just before the EU switch", shell.at("time berlin", 2026, 3, 29, 0, 59) === "Berlin 01:59 (Sun 29 Mar)");
        shell.check("TimeZones: berlin just after the EU switch", shell.at("time berlin", 2026, 3, 29, 1, 0) === "Berlin 03:00 (Sun 29 Mar)");
        shell.check("TimeZones: new york just before the US switch", shell.at("time new york", 2026, 3, 8, 6, 59) === "New York 01:59 (Sun 8 Mar)");
        shell.check("TimeZones: new york just after the US switch", shell.at("time new york", 2026, 3, 8, 7, 0) === "New York 03:00 (Sun 8 Mar)");
        shell.check("TimeZones: a prefix finds the city", shell.at("time toky", 2026, 11, 7, 12, 5) === "Tokyo 21:05 (Sat 7 Nov)");
        shell.check("TimeZones: unknown city gives no row", shell.at("time atlantis", 2026, 11, 7, 12, 5) === "null");
        shell.check("TimeZones: no keyword gives no row", shell.at("tokyo", 2026, 11, 7, 12, 5) === "null");
        shell.check("TimeZones: bare time gives no row", shell.at("time", 2026, 11, 7, 12, 5) === "null");
        const a = Utils.TimeZones.answer("time tokyo", Date.UTC(2026, 10, 7, 12, 5));
        shell.check("TimeZones: the copied time and the sub line", a.time === "21:05" && a.sub === "Asia/Tokyo · UTC+9");
        shell.check("TimeZones: at least 40 zones", Utils.TimeZones.zones.length >= 40);
        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
