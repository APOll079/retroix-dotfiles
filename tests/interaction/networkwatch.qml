// Decision-function tests for the network toasts (NetworkWatch.qml): debounce, parsing, validation, rate limit.
// Pure values only; the runner sets QS_NO_APPLY, so the singleton's timers and Processes stay off.
// Run by scripts/run-interaction-tests.py.
import QtQuick
import Quickshell

ShellRoot {
    id: shell
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }

    Component.onCompleted: {
        const NW = NetworkWatch;
        // feeds a list of observations (true / false / null); returns the fire list like "3:down,5:up"
        function run(obs, need) {
            let s = NW.newState();
            const out = [];
            obs.forEach((v, i) => {
                const r = NW.observe(s, v, need === undefined ? 2 : need);
                s = r.state;
                if (r.fire)
                    out.push(i + ":" + r.fire);
            });
            return out.join(",");
        }

        shell.check("startup: the first steady value sets the baseline, no toast", run([true, true, true]) === "");
        shell.check("startup down is a baseline too, no toast", run([false, false]) === "");
        shell.check("a drop holding 2 polls fires down once", run([true, true, false, false, false]) === "3:down");
        shell.check("a single bad poll does not fire", run([true, true, false, true, true]) === "");
        shell.check("coming back needs 2 polls too", run([true, true, false, false, true, true]) === "3:down,5:up");
        shell.check("one change gives one toast, not one per poll", run([true, true, false, false, false, false, false]) === "3:down");
        shell.check("alternating never fires", run([true, true, false, true, false, true, false, true]) === "");
        shell.check("a failed reading (null) neither counts nor resets", run([true, true, false, null, false]) === "4:down");
        shell.check("need=1 fires on the first changed poll", run([true, false], 1) === "1:down");
        shell.check("an unsteady start settles on the repeated value silently", run([true, false, false]) === "");
        shell.check("observe does not change the state it was given", (() => {
            const s = NW.newState();
            NW.observe(s, true, 2);
            return s.stable === null && s.n === 0;
        })());

        shell.check("rateOk: first toast is allowed", NW.rateOk(undefined, 1000, 60000) === true);
        shell.check("rateOk: inside the gap is refused", NW.rateOk(1000, 30000, 60000) === false);
        shell.check("rateOk: at the gap is allowed", NW.rateOk(1000, 61000, 60000) === true);

        shell.check("linkUp: connected variants are up", NW.linkUp("connected") === true);
        shell.check("linkUp: disconnected and asleep are down", NW.linkUp("disconnected") === false && NW.linkUp("asleep") === false);
        shell.check("linkUp: connecting / unknown / junk are ignored", NW.linkUp("connecting") === null && NW.linkUp("unknown") === null && NW.linkUp("") === null);
        shell.check("parseLink reads the script JSON", NW.parseLink('{"state":"connected"}') === true && NW.parseLink('{"state":"disconnected"}') === false);
        shell.check("parseLink survives junk", NW.parseLink("") === null && NW.parseLink("x") === null && NW.parseLink("{}") === null && NW.parseLink('{"state":3}') === null);

        shell.check("validHost accepts names, IPv4 and IPv6", NW.validHost("192.168.1.1") && NW.validHost("router.lan") && NW.validHost("fe80::1") && NW.validHost("a-b.c"));
        shell.check("validHost refuses spaces, shell characters, empty, a leading dash and non-strings",
            !NW.validHost("a b") && !NW.validHost("a;b") && !NW.validHost("$(id)") && !NW.validHost("") && !NW.validHost("-c1") && !NW.validHost(5) && !NW.validHost(null) && !NW.validHost("a/b"));

        const m = NW.parseHosts('[{"host":"192.168.1.1","up":true},{"host":"nas.lan","up":false},{"host":"a b","up":false,"invalid":true},{"host":"x","up":"yes"}]');
        shell.check("parseHosts keeps good entries and drops invalid ones", m !== null && m["192.168.1.1"] === true && m["nas.lan"] === false && !("a b" in m) && !("x" in m));
        shell.check("parseHosts on junk is null, on an empty list {}", NW.parseHosts("") === null && NW.parseHosts("{}") === null && Object.keys(NW.parseHosts("[]")).length === 0);
        shell.check("cleanHosts drops invalid and duplicate entries", NW.cleanHosts(["a", "a", "b c", "-x", "b"]).join(",") === "a,b" && NW.cleanHosts(undefined).length === 0);

        shell.check("titles", NW.title("link", "down") === "Network is down" && NW.title("link", "up") === "Network is back"
            && NW.title("192.168.1.1", "down") === "192.168.1.1 is down" && NW.title("nas.lan", "up") === "nas.lan is back");

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
