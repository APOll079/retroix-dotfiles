pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Weather from wttr.in (no key). settings.json "weather": location ("" = guessed from your IP),
// metric. Refreshes every 30 minutes; shown in the side panel's Calendar tab and on the bar clock.
Singleton {
    id: root

    readonly property var cfg: Config.settings.weather
    property bool ok: false
    property bool failed: false   // the last fetch gave nothing usable (retried after weatherRetry, doubling up to weatherRefresh)
    property int failures: 0      // consecutive failed fetches (retry backoff)
    property string place: ""
    property int temp: 0
    property int feels: 0
    property string desc: ""
    property string icon: ""
    property var days: []         // [{ name: "Sat", lo, hi, icon, desc }]
    // The API's 3-hourly slots of every forecast day, in order: [{ ms, temp, icon, desc }]. `ms` is the slot's
    // start as a local Date's epoch, whatever the place's time zone (wttr.in times are the place's own), so it
    // compares with `hoursNow` (the place's own clock at fetch time, same frame), not with the PC's clock.
    property var hours: []
    property real hoursNow: 0
    property real hoursAt: 0      // Date.now() when `hoursNow` was read (the place's clock advances with it)

    // wttr.in weather codes -> Material Symbols glyphs
    function glyph(code) {
        const c = Number(code);
        if (c === 113) return "";                                  // wb_sunny
        if (c === 116) return "";                                  // partly_cloudy_day
        if (c === 119 || c === 122) return "";                     // cloud
        if ([143, 248, 260].includes(c)) return "";                // foggy
        if ([200, 386, 389, 392, 395].includes(c)) return "";      // thunderstorm
        if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].includes(c))
            return "";                                             // weather_snowy
        return "";                                                 // rainy (drizzle, rain, showers)
    }

    // ---- hourly forecast (pure; the fixture test is tests/interaction/hourly.qml) ----

    // wttr.in gives each day 8 slots at 0, 300, ... 2100 (three hours apart). Every slot: its start, the
    // temperature in the wanted unit, a glyph and the description. Anything malformed is skipped.
    function parseHours(d, metric) {
        const out = [];
        for (const w of (d && d.weather) || []) {
            const day = /^(\d{4})-(\d\d)-(\d\d)$/.exec(String(w.date));
            if (!day)
                continue;
            for (const h of w.hourly || []) {
                const t = Number(h.time);
                const temp = Number(metric ? h.tempC : h.tempF);
                if (isNaN(t) || isNaN(temp))
                    continue;
                out.push({
                    ms: new Date(Number(day[1]), Number(day[2]) - 1, Number(day[3]), Math.floor(t / 100), t % 100).getTime(),
                    temp: temp,
                    icon: root.glyph(h.weatherCode),
                    desc: h.weatherDesc && h.weatherDesc[0] ? h.weatherDesc[0].value : ""
                });
            }
        }
        return out;
    }

    // The place's own "now" ("2026-11-06 02:30 PM" in current_condition.localObsDateTime) as a local Date's
    // epoch, or `fallback` when it isn't there
    function placeNow(d, fallback) {
        const c = d && d.current_condition && d.current_condition[0];
        const m = c ? /^(\d{4})-(\d\d)-(\d\d) (\d\d?):(\d\d) ?(AM|PM)$/i.exec(String(c.localObsDateTime)) : null;
        if (!m)
            return fallback;
        let hh = Number(m[4]) % 12;
        if (m[6].toUpperCase() === "PM")
            hh += 12;
        return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), hh, Number(m[5])).getTime();
    }

    // The slot that is running now, then the following ones, `count` in all (fewer if the data ends)
    function nextHours(slots, nowMs, count) {
        const span = 3 * 3600000;
        return slots.filter(s => s.ms + span > nowMs).slice(0, count);
    }

    // "15:00"
    function hourLabel(ms) {
        return Qt.formatDateTime(new Date(ms), "hh:mm");
    }

    // Not fetched when QS_NO_APPLY is set (the test harness): tests never reach the network
    function refresh() {
        if (Quickshell.env("QS_NO_APPLY"))
            return;
        const loc = encodeURIComponent(root.cfg.location);
        fetch.command = ["curl", "-s", "--max-time", "10", "-A", "curl", "https://wttr.in/" + loc + "?format=j1"];
        fetch.running = true;
    }

    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                // Parse into locals first, so a partial answer never leaves half-updated properties
                let r = null;
                try {
                    const d = JSON.parse(text);
                    const metric = root.cfg.metric;
                    const c = d.current_condition[0];
                    const a = d.nearest_area ? d.nearest_area[0] : null;
                    r = {
                        place: root.cfg.location !== "" ? root.cfg.location : (a ? a.areaName[0].value : ""),
                        temp: Number(metric ? c.temp_C : c.temp_F),
                        feels: Number(metric ? c.FeelsLikeC : c.FeelsLikeF),
                        desc: c.weatherDesc[0].value,
                        icon: root.glyph(c.weatherCode),
                        hours: root.parseHours(d, metric),
                        hoursNow: root.placeNow(d, Date.now()),
                        days: d.weather.map(w => ({
                            name: Qt.formatDate(new Date(w.date + "T12:00:00"), "ddd"),
                            lo: Number(metric ? w.mintempC : w.mintempF),
                            hi: Number(metric ? w.maxtempC : w.maxtempF),
                            icon: root.glyph(w.hourly[4].weatherCode),
                            desc: w.hourly[4].weatherDesc[0].value
                        }))
                    };
                } catch (e) {
                    r = null;
                }
                if (!r) {
                    root.ok = false;
                    root.failed = true;
                    // 60 s, doubling per failure in a row, up to the normal refresh interval
                    retry.interval = Math.min(MenuStyle.weatherRefresh, MenuStyle.weatherRetry * Math.pow(2, root.failures));
                    root.failures += 1;
                    retry.restart();
                    return;
                }
                root.place = r.place;
                root.temp = r.temp;
                root.feels = r.feels;
                root.desc = r.desc;
                root.icon = r.icon;
                root.days = r.days;
                root.hours = r.hours;
                root.hoursNow = r.hoursNow;
                root.hoursAt = Date.now();
                root.ok = true;
                root.failed = false;
                root.failures = 0;
                retry.stop();
            }
        }
    }

    // A failed fetch (offline at login, wttr.in down) tries again soon instead of in 30 minutes, backing off
    Timer {
        id: retry
        interval: MenuStyle.weatherRetry
        onTriggered: root.refresh()
    }

    Timer {
        interval: MenuStyle.weatherRefresh
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: root.cfg
        function onLocationChanged() { root.refresh() }
        function onMetricChanged() { root.refresh() }
    }

    readonly property string unit: cfg.metric ? "°C" : "°F"
}
