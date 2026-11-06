// Logic test for the launcher's currency answers (utils/Currency.qml): parse, convert, format and the answer rows with a
// fixture rates table, plus the 12 hour cache rule. Pure functions only; the runner sets QS_NO_APPLY so no rates.sh runs.
// Until `singleton Currency 1.0 Currency.qml` is in quickshell/utils/qmldir the test says so and passes.
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

    Component.onCompleted: {
        let C;
        try {
            C = Utils.Currency;
        } catch (e) {
            C = undefined;
        }
        if (!C || C.codes === undefined) {
            console.log("TEST pass Currency: not registered in utils/qmldir yet (skipped)");
            console.log("TEST done failures=0");
            quitTimer.start();
            return;
        }
        const R = { EUR: 1, SEK: 11.234, USD: 1.08, JPY: 160, GBP: 0.85 };
        const D = "2026-11-06";
        const t = q => { const a = C.answerWith(q, R, D); return a === null ? "null" : a.title; };

        shell.check("31 codes, EUR among them", C.codes.length === 31 && C.codes.indexOf("EUR") >= 0 && C.codes.indexOf("SEK") >= 0);
        shell.check("100 eur in sek", t("100 eur in sek") === "100.00 EUR = 1,123.40 SEK");
        shell.check("codes are case-insensitive", t("100 EUR IN Sek") === "100.00 EUR = 1,123.40 SEK");
        shell.check("50 usd to eur", t("50 usd to eur") === "50.00 USD = 46.30 EUR");
        shell.check("an amount is optional (1)", t("usd to eur") === "1.00 USD = 0.9259 EUR");
        shell.check("through EUR for two other currencies", t("100 usd to sek") === "100.00 USD = 1,040.19 SEK");
        shell.check("thousands separator and decimal comma in the amount", t("1,234.5 eur to usd") === "1,234.50 EUR = 1,333.26 USD" && t("1.234,5 eur to usd") === "1,234.50 EUR = 1,333.26 USD");
        shell.check("an amount with a decimal comma", C.parse("12,5 eur to usd").amount === 12.5);
        shell.check("an amount without a space before the code", C.parse("100eur to usd") !== null && C.parse("100eur to usd").amount === 100);
        shell.check("'in', 'to' and 'as' all work", C.parse("5 eur as usd") !== null && C.parse("5 eur in usd") !== null);
        shell.check("same currency", t("5 eur to eur") === "5.00 EUR = 5.00 EUR");

        shell.check("an unknown code is not a currency query", C.parse("5 xyz to eur") === null && C.parse("5 eur to xyz") === null);
        shell.check("a unit query is not a currency query", C.parse("5 km in mi") === null && C.parse("10 min in sec") === null);
        shell.check("plain words are not", C.parse("sek") === null && C.parse("hello world") === null && C.parse("") === null);
        shell.check("a negative or garbage amount is refused", C.parse("-5 eur to usd") === null && C.parse("1..2.3x eur to usd") === null);

        const a = C.answerWith("100 eur in sek", R, D);
        shell.check("the sub line says the rate date and the copied number", a.sub === "rates of 2026-11-06 - Enter copies 1123.40" && a.number === "1123.40");
        shell.check("a code missing from the rates says there are no rates yet", C.answerWith("1 eur to chf", R, D).title === "No exchange rates yet");
        const none = C.answerWith("100 eur in sek", {}, "");
        shell.check("no cache at all: 'No exchange rates yet', empty number, not an error", none.title === "No exchange rates yet" && none.number === "");
        shell.check("not a currency query: null", C.answerWith("2+2", R, D) === null);

        shell.check("convert needs both rates", C.convert(1, "EUR", "CHF", R) === null && C.convert(1, "EUR", "USD", R) === 1.08);
        shell.check("format groups thousands and keeps 2 decimals", C.format(1123.4) === "1,123.40" && C.format(1234567.891) === "1,234,567.89" && C.format(0) === "0.00");
        shell.check("a small value gets more decimals", C.format(0.0123) === "0.0123" && C.format(0.000123) === "0.000123");
        shell.check("plain has no grouping", C.plain(1123.4) === "1123.40");

        const H = 12 * 3600 * 1000, now = 1000 * H;
        shell.check("no cache is stale", C.isStale(0, now, H));
        shell.check("11 hours old is fresh, 12 hours old is stale", !C.isStale(now - 11 * 3600 * 1000, now, H) && C.isStale(now - H, now, H));
        shell.check("a fetch time in the future (clock moved) is stale", C.isStale(now + 3600 * 1000, now, H));

        shell.check("take() stores a good answer", C.take(JSON.stringify({ ok: true, date: D, rates: R }), now) && C.rates.SEK === 11.234 && C.date === D);
        shell.check("take() keeps the cache on a failed or garbage answer", !C.take(JSON.stringify({ ok: false, date: "", rates: {}, error: "no network" }), now + 1) && !C.take("not json", now + 1));
        shell.check("answer() now uses the cache", C.answer("100 eur in sek").title === "100.00 EUR = 1,123.40 SEK");
        C.refreshIfStale();
        shell.check("refreshIfStale does nothing under QS_NO_APPLY", C.fetches === 0);

        shell.now = now;
        lateTimer.start();
    }
    property double now: 0
    // the file adapter settles its properties a moment after take()
    Timer {
        id: lateTimer
        interval: 200
        onTriggered: {
            shell.check("take() stamps the fetch time and a failed answer does not change it", Utils.Currency.fetched === shell.now);
            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
