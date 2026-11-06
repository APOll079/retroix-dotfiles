pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Currency answers for the launcher: "100 eur in sek", "50 usd to eur", "usd to eur" (an amount of 1). The 31 codes of the
// European Central Bank's reference rates (EUR and the 30 it quotes), any letter case. Rates come from scripts/rates.sh
// (frankfurter.app, EUR = 1) and are cached in rates.json in Quickshell's state dir with the time they were fetched.
// Nothing is fetched while typing: the launcher calls refreshIfStale() once when it opens, and that fetches only when the
// cache is older than 12 hours (and not when a fetch is already running or QS_NO_APPLY is set). No cache and no network
// is not an error: answer() then returns a row that says "No exchange rates yet".
// parse / convert / format / answerWith are pure functions of (text, rates), so tests drive them with a fixture.
Singleton {
    id: root

    readonly property bool active: !Quickshell.env("QS_NO_APPLY")
    readonly property int maxAgeMs: 12 * 3600 * 1000
    readonly property string script: Quickshell.shellDir + "/scripts/rates.sh"
    readonly property var codes: ["AUD", "BGN", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK", "EUR", "GBP", "HKD", "HUF", "IDR", "ILS", "INR", "ISK", "JPY", "KRW", "MXN", "MYR", "NOK", "NZD", "PHP", "PLN", "RON", "SEK", "SGD", "THB", "TRY", "USD", "ZAR"]

    property alias rates: adapter.rates          // { "EUR": 1, "SEK": 11.2, ... }, {} before the first fetch
    property alias date: adapter.date            // the ECB's date, "2026-11-06"
    property alias fetched: adapter.fetched      // ms since the epoch of the last good fetch, 0 = never
    property int fetches: 0                      // how many rates.sh runs were started (tests read this)

    // ---- pure helpers ----

    // "1,234.5" / "1.234,5" / "1234,5" / "12 000" -> 1234.5 (NaN when it is not a number)
    function parseAmount(s) {
        let t = String(s).replace(/\s+/g, "");
        if (!/^[0-9][0-9.,]*$/.test(t))
            return NaN;
        const lastComma = t.lastIndexOf(","), lastDot = t.lastIndexOf(".");
        if (lastComma >= 0 && lastDot >= 0) {
            // the later one is the decimal mark
            t = lastComma > lastDot ? t.replace(/\./g, "").replace(",", ".") : t.replace(/,/g, "");
        } else if (lastComma >= 0) {
            t = (t.split(",").length === 2 && t.length - lastComma - 1 <= 2) ? t.replace(",", ".") : t.replace(/,/g, "");
        } else if (lastDot >= 0 && t.split(".").length > 2) {
            t = t.replace(/\./g, "");
        }
        const n = Number(t);
        return isFinite(n) ? n : NaN;
    }

    // "100 eur in sek" -> { amount: 100, from: "EUR", to: "SEK" }; null for anything else (including an unknown code)
    function parse(q) {
        const m = /^\s*(?:([0-9][0-9.,\s]*?)\s*)?([a-z]{3})\s+(?:in|to|as|into)\s+([a-z]{3})\s*$/i.exec(String(q));
        if (!m)
            return null;
        const from = m[2].toUpperCase(), to = m[3].toUpperCase();
        if (root.codes.indexOf(from) < 0 || root.codes.indexOf(to) < 0)
            return null;
        const amount = m[1] === undefined ? 1 : root.parseAmount(m[1]);
        if (!isFinite(amount) || amount < 0)
            return null;
        return { amount: amount, from: from, to: to };
    }

    // amount in `from` -> amount in `to` through EUR; null when a rate is missing
    function convert(amount, from, to, rates) {
        if (!rates || !(rates[from] > 0) || !(rates[to] > 0))
            return null;
        return amount / rates[from] * rates[to];
    }

    // 1123.4 -> "1,123.40"; below 1 more decimals so a small value is not shown as 0.00
    function format(n) {
        const abs = Math.abs(n);
        const dec = abs >= 1 || abs === 0 ? 2 : abs >= 0.01 ? 4 : 6;
        const parts = n.toFixed(dec).split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        return parts.join(".");
    }

    // The same value without grouping, for the clipboard: "1123.40"
    function plain(n) {
        const abs = Math.abs(n);
        return n.toFixed(abs >= 1 || abs === 0 ? 2 : abs >= 0.01 ? 4 : 6);
    }

    // The launcher row for query q with these rates: null (not a currency query), { title, sub, number: "" } (no rates yet),
    // or { title: "100 EUR = 1,123.40 SEK", sub: "rates of 2026-11-06 - Enter copies 1123.40", number: "1123.40" }
    function answerWith(q, rates, date) {
        const p = root.parse(q);
        if (!p)
            return null;
        const r = root.convert(p.amount, p.from, p.to, rates);
        if (r === null)
            return { title: "No exchange rates yet", sub: "They are fetched when the launcher opens and the network is up", number: "" };
        const from = root.format(p.amount);
        return {
            title: from + " " + p.from + " = " + root.format(r) + " " + p.to,
            sub: (date ? "rates of " + date + " - " : "") + "Enter copies " + root.plain(r),
            number: root.plain(r)
        };
    }

    // True when the cache is missing or older than maxAgeMs
    function isStale(fetched, now, maxAge) {
        return !(fetched > 0) || now - fetched >= maxAge || fetched > now + 60000;
    }

    // ---- state ----

    function answer(q) {
        return root.answerWith(q, root.rates, root.date);
    }

    // Called by the launcher when it opens. At most one fetch at a time, none while the cache is fresh.
    function refreshIfStale() {
        if (!root.active || proc.running || !root.isStale(root.fetched, Date.now(), root.maxAgeMs))
            return;
        root.fetches++;
        proc.running = true;
    }

    // A rates.sh answer (JSON text) -> true and stored when it is a good one; a bad one keeps the old cache
    function take(text, now) {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return false;
        }
        if (!d || d.ok !== true || !d.rates || typeof d.date !== "string" || !(d.rates.EUR > 0) || Object.keys(d.rates).length < 2)
            return false;
        adapter.rates = d.rates;
        adapter.date = d.date;
        adapter.fetched = now;
        return true;
    }

    Process {
        id: proc
        command: ["sh", root.script]
        stdout: StdioCollector {
            onStreamFinished: root.take(text, Date.now())
        }
    }

    // First run has no file yet; GuardedFileView creates it
    GuardedFileView {
        path: Quickshell.statePath("rates.json")
        printErrors: false
        JsonAdapter {
            id: adapter
            property var rates: ({})
            property string date: ""
            property var fetched: 0
        }
    }
}
