pragma Singleton
import Quickshell

// Launcher time zones: "time tokyo", "time new york", "time utc". Pure functions, no I/O.
// Quickshell's QML engine has no Intl and toLocaleString ignores timeZone, so this is a fixed table of
// standard UTC offsets plus daylight-saving rules for the US, EU, Australia (south-east) and New Zealand
// worked out by hand. Zones whose rules differ (Chile, Egypt, Iran, Brazil history ...) are not in the table.
// answer(text, nowMs) returns { name, iana, time, day, title, sub } or null.
Singleton {
    id: root

    // [aliases, display name, IANA name, standard offset in minutes, DST rule]
    readonly property var zones: [
        [["utc", "gmt", "z"], "UTC", "Etc/UTC", 0, ""],
        [["london", "uk"], "London", "Europe/London", 0, "eu"],
        [["dublin"], "Dublin", "Europe/Dublin", 0, "eu"],
        [["lisbon"], "Lisbon", "Europe/Lisbon", 0, "eu"],
        [["paris"], "Paris", "Europe/Paris", 60, "eu"],
        [["berlin"], "Berlin", "Europe/Berlin", 60, "eu"],
        [["madrid"], "Madrid", "Europe/Madrid", 60, "eu"],
        [["rome"], "Rome", "Europe/Rome", 60, "eu"],
        [["amsterdam"], "Amsterdam", "Europe/Amsterdam", 60, "eu"],
        [["stockholm", "sweden"], "Stockholm", "Europe/Stockholm", 60, "eu"],
        [["oslo"], "Oslo", "Europe/Oslo", 60, "eu"],
        [["vienna"], "Vienna", "Europe/Vienna", 60, "eu"],
        [["zurich"], "Zurich", "Europe/Zurich", 60, "eu"],
        [["warsaw"], "Warsaw", "Europe/Warsaw", 60, "eu"],
        [["athens"], "Athens", "Europe/Athens", 120, "eu"],
        [["helsinki"], "Helsinki", "Europe/Helsinki", 120, "eu"],
        [["kyiv", "kiev"], "Kyiv", "Europe/Kyiv", 120, "eu"],
        [["istanbul"], "Istanbul", "Europe/Istanbul", 180, ""],
        [["moscow"], "Moscow", "Europe/Moscow", 180, ""],
        [["cairo"], "Cairo", "Africa/Cairo", 120, ""],
        [["johannesburg", "south africa"], "Johannesburg", "Africa/Johannesburg", 120, ""],
        [["lagos"], "Lagos", "Africa/Lagos", 60, ""],
        [["nairobi"], "Nairobi", "Africa/Nairobi", 180, ""],
        [["dubai"], "Dubai", "Asia/Dubai", 240, ""],
        [["karachi"], "Karachi", "Asia/Karachi", 300, ""],
        [["delhi", "mumbai", "india", "kolkata"], "Delhi", "Asia/Kolkata", 330, ""],
        [["dhaka"], "Dhaka", "Asia/Dhaka", 360, ""],
        [["bangkok"], "Bangkok", "Asia/Bangkok", 420, ""],
        [["jakarta"], "Jakarta", "Asia/Jakarta", 420, ""],
        [["singapore"], "Singapore", "Asia/Singapore", 480, ""],
        [["hong kong", "hongkong"], "Hong Kong", "Asia/Hong_Kong", 480, ""],
        [["shanghai", "beijing", "china"], "Shanghai", "Asia/Shanghai", 480, ""],
        [["manila"], "Manila", "Asia/Manila", 480, ""],
        [["perth"], "Perth", "Australia/Perth", 480, ""],
        [["seoul"], "Seoul", "Asia/Seoul", 540, ""],
        [["tokyo", "japan"], "Tokyo", "Asia/Tokyo", 540, ""],
        [["sydney", "melbourne", "canberra"], "Sydney", "Australia/Sydney", 600, "au"],
        [["brisbane"], "Brisbane", "Australia/Brisbane", 600, ""],
        [["auckland", "new zealand", "wellington"], "Auckland", "Pacific/Auckland", 720, "nz"],
        [["honolulu", "hawaii"], "Honolulu", "Pacific/Honolulu", -600, ""],
        [["anchorage", "alaska"], "Anchorage", "America/Anchorage", -540, "us"],
        [["los angeles", "la", "san francisco", "seattle", "pacific"], "Los Angeles", "America/Los_Angeles", -480, "us"],
        [["vancouver"], "Vancouver", "America/Vancouver", -480, "us"],
        [["denver", "mountain"], "Denver", "America/Denver", -420, "us"],
        [["phoenix"], "Phoenix", "America/Phoenix", -420, ""],
        [["chicago", "central"], "Chicago", "America/Chicago", -360, "us"],
        [["mexico city", "mexico"], "Mexico City", "America/Mexico_City", -360, ""],
        [["new york", "nyc", "toronto", "boston", "eastern"], "New York", "America/New_York", -300, "us"],
        [["bogota"], "Bogota", "America/Bogota", -300, ""],
        [["halifax"], "Halifax", "America/Halifax", -240, "us"],
        [["sao paulo", "brazil"], "Sao Paulo", "America/Sao_Paulo", -180, ""],
        [["buenos aires", "argentina"], "Buenos Aires", "America/Argentina/Buenos_Aires", -180, ""]
    ]

    readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    // Day of month of the nth (1-based) Sunday of a month (month 0-11), or the last one with n = -1
    function sunday(year, month, n) {
        if (n > 0) {
            const first = new Date(Date.UTC(year, month, 1)).getUTCDay();
            return 1 + (7 - first) % 7 + (n - 1) * 7;
        }
        const last = new Date(Date.UTC(year, month + 1, 0));
        return last.getUTCDate() - last.getUTCDay();
    }

    // Is daylight saving in force at this instant? rule: "us" | "eu" | "au" | "nz" | ""
    function dst(rule, stdMin, ms) {
        if (rule === "")
            return false;
        const y = new Date(ms + stdMin * 60000).getUTCFullYear();
        const at = (yy, mo, n, localMin, offMin) => Date.UTC(yy, mo, root.sunday(yy, mo, n)) + (localMin - offMin) * 60000;
        if (rule === "us")
            return ms >= at(y, 2, 2, 120, stdMin) && ms < at(y, 10, 1, 120, stdMin + 60);
        if (rule === "eu")
            return ms >= at(y, 2, -1, 60, 0) && ms < at(y, 9, -1, 60, 0);
        // southern: DST spans New Year; ends first Sunday of April at 03:00 DST (= 02:00 standard)
        const start = rule === "au" ? at(y, 9, 1, 120, stdMin) : at(y, 8, -1, 120, stdMin);
        return ms >= start || ms < at(y, 3, 1, 120, stdMin);
    }

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }

    // The zone row for a table entry at an instant
    function describe(z, ms) {
        const off = z[3] + (root.dst(z[4], z[3], ms) ? 60 : 0);
        const d = new Date(ms + off * 60000);
        const time = root.pad(d.getUTCHours()) + ":" + root.pad(d.getUTCMinutes());
        const day = root.dayNames[d.getUTCDay()] + " " + d.getUTCDate() + " " + root.monthNames[d.getUTCMonth()];
        const sign = off < 0 ? "-" : "+";
        const a = Math.abs(off);
        const utc = "UTC" + sign + Math.floor(a / 60) + (a % 60 ? ":" + root.pad(a % 60) : "");
        return { name: z[1], iana: z[2], time: time, day: day, title: z[1] + " " + time + " (" + day + ")", sub: z[2] + " \u00b7 " + utc };
    }

    // The table entry for a typed name: exact alias, else the first name or alias starting with it
    function find(name) {
        const q = name.trim().toLowerCase().replace(/\s+/g, " ");
        if (q === "")
            return null;
        for (const z of root.zones)
            if (z[0].indexOf(q) !== -1 || z[1].toLowerCase() === q)
                return z;
        if (q.length < 3)
            return null;
        for (const z of root.zones)
            if (z[0].some(a => a.startsWith(q)) || z[1].toLowerCase().startsWith(q))
                return z;
        return null;
    }

    function answer(input, nowMs) {
        const m = String(input).trim().match(/^(?:time|clock)\s+(?:in\s+)?(.+)$/i);
        if (!m)
            return null;
        const z = root.find(m[1]);
        return z === null ? null : root.describe(z, nowMs === undefined ? Date.now() : nowMs);
    }
}
