// Test for the hourly forecast: the pure parse / pick / format functions in Weather.qml on a fixture in wttr.in's
// ?format=j1 shape (never fetched), and the row in the Calendar tab (fixed cell count, unit, hidden without
// weather). Run by scripts/run-interaction-tests.py (see components.qml for how these files work). The tab is
// loaded by path because a test file sits outside quickshell/, where qmllint can't resolve `import "popups"`.
import QtQuick
import QtTest
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property int winW: 480
    readonly property int winH: 760
    function asVar(o: var): var {
        return o;
    }
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function find(it: var, pred: var): var {
        if (pred(it))
            return it;
        for (const c of it.children) {
            const r = shell.find(c, pred);
            if (r)
                return r;
        }
        return null;
    }

    // wttr.in gives eight 3-hourly slots a day, "time" as "0" ... "2100"
    function day(date, base) {
        const hourly = [];
        for (let i = 0; i < 8; i++)
            hourly.push({ time: String(i * 300), tempC: String(base + i), tempF: String((base + i) * 2 + 30), weatherCode: i === 3 ? "113" : "122", weatherDesc: [{ value: i === 3 ? "Sunny" : "Overcast" }] });
        return { date: date, mintempC: String(base), maxtempC: String(base + 7), mintempF: "40", maxtempF: "60", hourly: hourly };
    }
    readonly property var fixture: ({
        current_condition: [{ localObsDateTime: "2026-11-06 02:30 PM", temp_C: "10", temp_F: "50", FeelsLikeC: "9", FeelsLikeF: "48", weatherCode: "122", weatherDesc: [{ value: "Overcast" }] }],
        nearest_area: [{ areaName: [{ value: "Nowhere" }] }],
        weather: [day("2026-11-06", 1), day("2026-11-07", 20)]
    })

    FloatingWindow {
        implicitWidth: shell.winW; implicitHeight: shell.winH
        Rectangle {
            anchors.fill: parent
            color: Config.colors.base
            Loader {
                id: tabLoad
                x: 10; y: 10
                width: shell.winW - 20
                Component.onCompleted: setSource("popups/CalendarTab.qml", { active: true })
            }
            TestCase { id: tc; name: "sim"; when: false }
            Timer {
                interval: 900; running: true
                onTriggered: shell.run()
            }
        }
    }

    function run() {
        const d = shell.fixture;

        // parseHours
        const all = Weather.parseHours(d, true);
        shell.check("parse: two days of eight slots", all.length === 16);
        shell.check("parse: the first slot is midnight of the first day, metric temperature", new Date(all[0].ms).getHours() === 0 && new Date(all[0].ms).getDate() === 6 && all[0].temp === 1);
        shell.check("parse: slots are three hours apart and in order", all[1].ms - all[0].ms === 3 * 3600000 && all[8].ms - all[7].ms === 3 * 3600000);
        shell.check("parse: the glyph follows the weather code", all[3].icon === Weather.glyph(113) && all[3].icon !== all[2].icon && all[3].desc === "Sunny");
        shell.check("parse: Fahrenheit when not metric", Weather.parseHours(d, false)[2].temp === 3 * 2 + 30);
        shell.check("parse: garbage gives an empty list, not an error", Weather.parseHours(null, true).length === 0 && Weather.parseHours({ weather: [{ date: "nope", hourly: [] }] }, true).length === 0 && Weather.parseHours({ weather: [{ date: "2026-11-06", hourly: [{ time: "x", tempC: "1" }] }] }, true).length === 0);

        // placeNow
        const now = Weather.placeNow(d, -1);
        shell.check("placeNow: reads the place's clock (2:30 PM is 14:30)", new Date(now).getHours() === 14 && new Date(now).getMinutes() === 30 && new Date(now).getDate() === 6);
        shell.check("placeNow: 12:05 AM is 00:05, 12:05 PM is 12:05", new Date(Weather.placeNow({ current_condition: [{ localObsDateTime: "2026-11-06 12:05 AM" }] }, -1)).getHours() === 0 && new Date(Weather.placeNow({ current_condition: [{ localObsDateTime: "2026-11-06 12:05 PM" }] }, -1)).getHours() === 12);
        shell.check("placeNow: falls back when it is missing", Weather.placeNow({}, 123) === 123 && Weather.placeNow({ current_condition: [{}] }, 123) === 123);

        // nextHours: the slot running now (12:00 covers 14:30), then the next ones
        const hrs = ms => Weather.nextHours(all, ms, 4).map(s => new Date(s.ms).getHours()).join(",");
        shell.check("next: from 14:30 the 12:00 slot (still running) then 15, 18, 21", hrs(now) === "12,15,18,21");
        shell.check("next: exactly on a slot start (15:00) begins with that slot", hrs(new Date(2026, 10, 6, 15, 0).getTime()) === "15,18,21,0");
        shell.check("next: runs over midnight into the next day", hrs(new Date(2026, 10, 6, 22, 30).getTime()) === "21,0,3,6");
        shell.check("next: fewer when the data ends", Weather.nextHours(all, new Date(2026, 10, 7, 20, 0).getTime(), 4).length === 2);
        shell.check("next: nothing when all is in the past", Weather.nextHours(all, new Date(2027, 0, 1).getTime(), 4).length === 0);
        shell.check("next: does not change the input", all.length === 16);

        // hourLabel
        shell.check("label: 24-hour hh:mm", Weather.hourLabel(new Date(2026, 10, 6, 9, 0).getTime()) === "09:00" && Weather.hourLabel(new Date(2026, 10, 6, 15, 0).getTime()) === "15:00");

        // the row in the tab
        const tab = asVar(tabLoad.item);
        const row = shell.find(tab, it => it.objectName === "hourlyRow");
        shell.check("tab: no weather, no hourly row", row !== null && row.visible === false);

        Weather.ok = true;
        Weather.hours = all;
        Weather.hoursNow = now;
        Weather.hoursAt = Date.now();
        tc.wait(300);
        const texts = () => {
            const out = [];
            const walk = it => {
                if (it.text !== undefined && it.font && it.font.family !== MenuStyle.iconFont && /^\d\d:\d\d /.test(it.text))
                    out.push(it.text);
                for (const c of it.children)
                    walk(c);
            };
            walk(row);
            return out;
        };
        shell.check("tab: weather and hours show the row", row.visible === true);
        shell.check("tab: four cells, hour then temperature with the unit", texts().join("|") === "12:00 5" + Weather.unit + "|15:00 6" + Weather.unit + "|18:00 7" + Weather.unit + "|21:00 8" + Weather.unit);
        shell.check("tab: the unit follows settings.weather.metric", Weather.unit === (Config.settings.weather.metric ? "\u00b0C" : "\u00b0F"));

        // fewer slots: the row keeps its size
        const h1 = row.height, w1 = row.implicitWidth;
        Weather.hours = all.slice(14);
        tc.wait(200);
        shell.check("tab: with less data the row keeps its height and cell count", Math.abs(row.height - h1) < 1);
        shell.check("tab: ... and only the cells with data show text", texts().length === 2);

        // no hours at all hides the row; no weather hides all of it
        Weather.hours = [];
        tc.wait(200);
        shell.check("tab: no hours, no row", row.visible === false);
        Weather.hours = all;
        Weather.ok = false;
        tc.wait(200);
        shell.check("tab: weather gone, the row is not shown", row.visible === false);

        console.log("TEST done failures=" + shell.failures);
        Qt.quit();
    }
}
