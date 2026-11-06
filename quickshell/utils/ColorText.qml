pragma Singleton
import Quickshell

// Launcher colour preview: "#c950bb", "#abc", "rgb(201, 80, 187)". Pure functions, no I/O.
// answer(text) returns { hex, rgb, hsl, sub } or null when the input is not a colour.
Singleton {
    id: root

    // [r, g, b] (0..255) or null
    function parse(input) {
        const s = String(input).trim().toLowerCase();
        let m = s.match(/^#([0-9a-f]{3})$/);
        if (m)
            return [0, 1, 2].map(i => parseInt(m[1][i] + m[1][i], 16));
        m = s.match(/^#([0-9a-f]{6})$/);
        if (m)
            return [0, 2, 4].map(i => parseInt(m[1].substr(i, 2), 16));
        m = s.match(/^rgb\(\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*\)$/);
        if (m) {
            const c = [Number(m[1]), Number(m[2]), Number(m[3])];
            return c.every(x => x <= 255) ? c : null;
        }
        return null;
    }

    function hex(c) {
        return "#" + c.map(x => (x < 16 ? "0" : "") + x.toString(16)).join("");
    }

    // [h 0..359, s 0..100, l 0..100], rounded
    function hsl(c) {
        const r = c[0] / 255, g = c[1] / 255, b = c[2] / 255;
        const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
        const l = (mx + mn) / 2;
        let h = 0, s = 0;
        if (d !== 0) {
            s = d / (1 - Math.abs(2 * l - 1));
            h = mx === r ? ((g - b) / d + 6) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
            h *= 60;
        }
        return [Math.round(h) % 360, Math.round(s * 100), Math.round(l * 100)];
    }

    function answer(input) {
        const c = root.parse(input);
        if (c === null)
            return null;
        const h = root.hsl(c);
        const rgb = "rgb(" + c.join(", ") + ")";
        const hs = "hsl(" + h[0] + ", " + h[1] + "%, " + h[2] + "%)";
        return { hex: root.hex(c), rgb: rgb, hsl: hs, sub: rgb + " \u00b7 " + hs };
    }
}
