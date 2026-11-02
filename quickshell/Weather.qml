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

    function refresh() {
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
