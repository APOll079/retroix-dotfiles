pragma Singleton
import Quickshell

// Launcher unit conversions: "5 km in mi", "72 f in c", "3 kg to lb". Pure functions, no I/O.
// answer(text) returns { number, unit, text } ("5 km = 3.1069 mi"), or null when the input is not a
// conversion, a unit is unknown or the two units measure different things (never an error row).
Singleton {
    id: root

    // name -> list of [dimension, factor to the dimension's base unit]. A name with two entries
    // (ms: milliseconds or metres per second) is settled by the other unit of the pair.
    // length m, mass kg, volume l, speed m/s, data byte, time s; temperature is handled apart.
    readonly property var table: ({
        mm: [["len", 0.001]], cm: [["len", 0.01]], m: [["len", 1]], km: [["len", 1000]],
        in: [["len", 0.0254]], inch: [["len", 0.0254]], ft: [["len", 0.3048]], yd: [["len", 0.9144]], mi: [["len", 1609.344]],
        g: [["mass", 0.001]], kg: [["mass", 1]], oz: [["mass", 0.028349523125]], lb: [["mass", 0.45359237]],
        ml: [["vol", 0.001]], l: [["vol", 1]], tsp: [["vol", 0.00492892159375]], tbsp: [["vol", 0.01478676478125]],
        cup: [["vol", 0.2365882365]], gal: [["vol", 3.785411784]],
        c: [["temp", 0]], f: [["temp", 0]], k: [["temp", 0]],
        kmh: [["speed", 1 / 3.6]], "km/h": [["speed", 1 / 3.6]], mph: [["speed", 0.44704]], "m/s": [["speed", 1]], kn: [["speed", 1852 / 3600]],
        b: [["data", 1]], kb: [["data", 1e3]], mb: [["data", 1e6]], gb: [["data", 1e9]], tb: [["data", 1e12]],
        s: [["time", 1]], min: [["time", 60]], h: [["time", 3600]], d: [["time", 86400]],
        ms: [["time", 0.001], ["speed", 1]]
    })

    // The factor pair [a, b, dimension] for two unit names, or null (unknown or mixed dimensions)
    function pair(from, to) {
        if (!root.table.hasOwnProperty(from) || !root.table.hasOwnProperty(to))
            return null;
        for (const x of root.table[from])
            for (const y of root.table[to])
                if (x[0] === y[0])
                    return [x[1], y[1], x[0]];
        return null;
    }

    // Value conversion, or null
    function convert(n, from, to) {
        const p = root.pair(from, to);
        if (p === null)
            return null;
        if (p[2] !== "temp")
            return n * p[0] / p[1];
        const k = from === "c" ? n + 273.15 : from === "f" ? (n - 32) * 5 / 9 + 273.15 : n;
        return to === "c" ? k - 273.15 : to === "f" ? (k - 273.15) * 9 / 5 + 32 : k;
    }

    // Up to 6 significant digits, trailing zeros trimmed, no exponent for sensible sizes
    function fmt(v) {
        if (!isFinite(v))
            return "";
        if (v === 0)
            return "0";
        const a = Math.abs(v);
        if (a >= 1e15 || a < 1e-6)
            return String(Number(v.toExponential(5)));
        if (a >= 1e6)
            return String(Math.round(v));
        const s = Number(v.toPrecision(6));
        return a < 1e-4 ? s.toFixed(10).replace(/0+$/, "").replace(/\.$/, "") : String(s);
    }

    function answer(input) {
        const s = String(input).trim().toLowerCase();
        const m = s.match(/^(-?(?:\d+(?:[.,]\d+)?|[.,]\d+))\s*([a-z/]+)\s+(?:to|in)\s+([a-z/]+)$/);
        if (!m)
            return null;
        const n = Number(m[1].replace(",", "."));
        const r = root.convert(n, m[2], m[3]);
        if (r === null || !isFinite(r))
            return null;
        const num = root.fmt(r);
        return { number: num, unit: m[3], text: root.fmt(n) + " " + m[2] + " = " + num + " " + m[3] };
    }
}
