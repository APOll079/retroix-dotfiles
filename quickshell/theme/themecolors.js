.pragma library

// Pure palette helpers for the theme editor (popups/ThemeEditor.qml): the same numbers and formulas as theme/apply.py
// (contrast, lift_highlight, darken_to, the select bar/text pair, check_palette), ported one to one so the editor says
// "refused" exactly when apply.py would. tests/interaction/themeeditor.qml compares them with values computed by
// apply.py's own functions. If apply.py's rules change, change them here in the same commit.

var ROLES = ["base", "shadow", "highlight", "urgent", "accent", "text", "outline", "outlineGradientFade"];
var MIN_EDGE = 1.35;
var MIN_TEXT = 4.5;
var MIN_URGENT = 3.0;
var MIN_SELECT = 4.5;

// Python's round(): halves go to the even number (JS Math.round goes up)
function pyRound(x) {
    var f = Math.floor(x);
    var d = x - f;
    if (d < 0.5) return f;
    if (d > 0.5) return f + 1;
    return f % 2 === 0 ? f : f + 1;
}

function isHex(s) {
    return typeof s === "string" && /^#[0-9a-fA-F]{6}$/.test(s);
}

// "#ABCDEF" / "abcdef" / " #abcdef " -> "#abcdef", or "" when it is not a colour
function normalise(s) {
    if (typeof s !== "string") return "";
    var t = s.trim();
    if (/^[0-9a-fA-F]{6}$/.test(t)) t = "#" + t;
    return isHex(t) ? t.toLowerCase() : "";
}

function rgb(h) {
    h = h.replace(/^#/, "");
    return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
}

function hexs(c) {
    var out = "#";
    for (var i = 0; i < 3; i++) {
        var v = Math.max(0, Math.min(255, pyRound(c[i])));
        out += (v < 16 ? "0" : "") + v.toString(16);
    }
    return out;
}

function luminance(h) {
    function ch(v) {
        v /= 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    }
    var c = rgb(h);
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2]);
}

function contrast(a, b) {
    var la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

function rgbToHsv(r, g, b) {
    var maxc = Math.max(r, g, b), minc = Math.min(r, g, b);
    var v = maxc;
    if (minc === maxc) return [0.0, 0.0, v];
    var s = (maxc - minc) / maxc;
    var rc = (maxc - r) / (maxc - minc);
    var gc = (maxc - g) / (maxc - minc);
    var bc = (maxc - b) / (maxc - minc);
    var h;
    if (r === maxc) h = bc - gc;
    else if (g === maxc) h = 2.0 + rc - bc;
    else h = 4.0 + gc - rc;
    h = (h / 6.0) % 1.0;
    if (h < 0) h += 1.0;
    return [h, s, v];
}

function hsvToRgb(h, s, v) {
    if (s === 0.0) return [v, v, v];
    var i = Math.floor(h * 6.0);
    var f = (h * 6.0) - i;
    var p = v * (1.0 - s);
    var q = v * (1.0 - s * f);
    var t = v * (1.0 - s * (1.0 - f));
    i = i % 6;
    if (i === 0) return [v, t, p];
    if (i === 1) return [q, v, p];
    if (i === 2) return [p, v, t];
    if (i === 3) return [p, q, v];
    if (i === 4) return [t, p, v];
    return [v, p, q];
}

// Qt.darker: HSV value divided by the factor
function darker(h, f) {
    var c = rgb(h);
    var hsv = rgbToHsv(c[0] / 255, c[1] / 255, c[2] / 255);
    var o = hsvToRgb(hsv[0], hsv[1], hsv[2] / f);
    return hexs([o[0] * 255, o[1] * 255, o[2] * 255]);
}

// highlight if its step from base is already enough, else base mixed towards white until the step reaches target
function liftHighlight(base, highlight, target) {
    if (target === undefined) target = 1.40;
    if (contrast(base, highlight) >= MIN_EDGE) return highlight;
    var b = rgb(base);
    for (var i = 0; i <= 100; i++) {
        var c = hexs([b[0] + (255 - b[0]) * i / 100, b[1] + (255 - b[1]) * i / 100, b[2] + (255 - b[2]) * i / 100]);
        if (contrast(base, c) >= target) return c;
    }
    return "#ffffff";
}

// colour, or colour darkened (HSV value, keeps the hue) until it reaches target:1 on bg
function darkenTo(colour, bg, target) {
    var f = 1.0;
    var c = colour;
    while (contrast(c, bg) < target && f < 4.0) {
        f += 0.02;
        c = darker(colour, f);
    }
    return c;
}

// apply.py derive(): the accent with the best of base / text / outline, else the accent darkened. { bar, text, ratio, darkened }
function selectPair(roles) {
    var acc = roles.accent;
    var best = null, bestC = -1;
    var keys = ["base", "text", "outline"];
    for (var i = 0; i < keys.length; i++) {
        var c = contrast(roles[keys[i]], acc);
        if (c > bestC) {
            bestC = c;
            best = roles[keys[i]];
        }
    }
    if (bestC >= MIN_SELECT) return { bar: acc, text: best, ratio: bestC, darkened: false };
    var f = 1.0;
    while (f < 2.0 && contrast(roles.base, darker(acc, f)) < MIN_SELECT) f += 0.05;
    var bar = darker(acc, f);
    return { bar: bar, text: roles.base, ratio: contrast(roles.base, bar), darkened: true };
}

function fixed(n) {
    return n.toFixed(2);
}

// The live contrast lines, in the order the editor shows them. Each: { key, label, value, min, ok, blocking, detail }.
// blocking = apply.py would refuse the palette (check_palette); the select-text line is advisory (apply.py darkens
// the accent itself). `roles` holds lower-case #rrggbb for every role that is a valid colour; a rule whose colours are
// missing is left out.
function checkRows(roles) {
    var rows = [];
    function has() {
        for (var i = 0; i < arguments.length; i++)
            if (!isHex(roles[arguments[i]])) return false;
        return true;
    }
    if (has("base", "highlight")) {
        var edge = contrast(roles.base, roles.highlight);
        rows.push({ key: "edge", label: "Bevel edge (highlight on base)", value: edge, min: MIN_EDGE, ok: edge >= MIN_EDGE, blocking: true,
            detail: "highlight is only " + fixed(edge) + ":1 lighter than base; the bevel's light edge needs " + MIN_EDGE + ":1 (try " + liftHighlight(roles.base, roles.highlight) + ")" });
    }
    var surfaces = [["base", "Text on base"], ["highlight", "Text on highlight"], ["shadow", "Text on shadow"]];
    for (var s = 0; s < surfaces.length; s++) {
        if (!has("text", surfaces[s][0])) continue;
        var tc = contrast(roles.text, roles[surfaces[s][0]]);
        rows.push({ key: "text-" + surfaces[s][0], label: surfaces[s][1], value: tc, min: MIN_TEXT, ok: tc >= MIN_TEXT, blocking: true,
            detail: "text on " + surfaces[s][0] + " is " + fixed(tc) + ":1, it needs " + MIN_TEXT + ":1" });
    }
    if (has("urgent", "base")) {
        var u = contrast(roles.urgent, roles.base);
        rows.push({ key: "urgent", label: "Urgent on base", value: u, min: MIN_URGENT, ok: u >= MIN_URGENT, blocking: true,
            detail: "urgent is only " + fixed(u) + ":1 on base, it needs " + MIN_URGENT + ":1 (try " + darkenTo(roles.urgent, roles.base, MIN_URGENT + 0.2) + ")" });
    }
    if (has("base", "text", "outline", "accent")) {
        var sp = selectPair(roles);
        var best = contrast(sp.text, roles.accent);
        rows.push({ key: "select", label: "Selected-row text on accent", value: sp.darkened ? best : sp.ratio, min: MIN_SELECT, ok: !sp.darkened, blocking: false,
            detail: sp.darkened ? "no text colour reads on the accent; the accent bar is darkened to " + sp.bar + " (" + fixed(sp.ratio) + ":1)" : "" });
    }
    return rows;
}

// Why Apply is off: the detail of every blocking row that fails (apply.py would refuse the palette); [] = fine
function blockers(roles) {
    return checkRows(roles).filter(function (r) { return r.blocking && !r.ok; }).map(function (r) { return r.detail; });
}

// Every role must be a #rrggbb colour
function missingRoles(roles) {
    return ROLES.filter(function (k) { return !isHex(roles[k]); });
}

// The palette as it is written to custom-theme.json: every role normalised, plus the empty wallpaper entry themes.json has
function toFile(roles) {
    var o = {};
    for (var i = 0; i < ROLES.length; i++) o[ROLES[i]] = normalise(roles[ROLES[i]]);
    o.defaultWallpaperPath = "";
    return o;
}

// Starting values: the theme's own colours; a role the theme lacks borrows a sensible one so the editor opens complete
function startingPalette(theme) {
    var o = {};
    for (var i = 0; i < ROLES.length; i++) {
        var v = normalise(theme ? theme[ROLES[i]] : "");
        o[ROLES[i]] = v;
    }
    if (o.urgent === "") o.urgent = o.accent;
    if (o.outlineGradientFade === "") o.outlineGradientFade = o.outline;
    return o;
}
