// Failed-service toast (ServiceWatch.qml): pure parser / diff / re-arm logic on fixtures, no dinitctl runs (the runner
// sets QS_NO_APPLY, so the singleton's timer and Processes stay off). The OLD ServicesPanel parser is copied below to
// prove ServiceWatch.parseList gives the same results. Run by scripts/run-interaction-tests.py.
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

    // verbatim copy of ServicesPanel.parse before the move
    function oldParse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            if (line.length < 11 || line[0] !== "[")
                continue;
            const flags = line.slice(1, 9);
            const rest = line.slice(10).trim();
            const sp = rest.search(/\s/);
            const name = sp < 0 ? rest : rest.slice(0, sp);
            const info = sp < 0 ? "" : rest.slice(sp).trim().replace(/^\(|\)$/g, "");
            if (name === "")
                continue;
            out.push({
                name: name,
                state: flags.includes("+") ? "running" : flags.includes("-") ? "stopped" : "other",
                failed: /fail|exit status/i.test(info),
                info: info
            });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }

    function svc(name, state, failed) {
        return { name: name, state: state, failed: failed === true, info: "" };
    }

    Component.onCompleted: {
        const SW = ServiceWatch;
        const J = JSON.stringify;
        const MIN = 60000;

        const fixture = "[{+}     ] boot\n"
            + "[{+}     ] pipewire (pid: 812)\n"
            + "[{+}     ] wireplumber (pid: 840)\n"
            + "[     {-}] mpd\n"
            + "[     {-}] syncthing (has failed to start: exit status 1)\n"
            + "[{+}     ] zeta (pid: 9)\n"
            + "[{ }     ] weird\n"
            + "garbage line\n"
            + "[short\n"
            + "[{+}     ] \n"
            + "\n";
        const parsed = SW.parseList(fixture, "user");
        shell.check("parseList: same results as the old ServicesPanel parser", J(parsed) === J(shell.oldParse(fixture)));
        shell.check("parseList: also for empty and junk", J(SW.parseList("", "user")) === J(shell.oldParse("")) && J(SW.parseList("nope\n[", "user")) === "[]");
        shell.check("parseList: 7 services, sorted", parsed.length === 7 && parsed[0].name === "boot" && parsed[6].name === "zeta");
        const sync = parsed.find(s => s.name === "syncthing");
        shell.check("parseList: failed service is stopped and failed", sync.state === "stopped" && sync.failed === true);
        shell.check("parseList: info loses its parentheses", parsed.find(s => s.name === "pipewire").info === "pid: 812");
        shell.check("parseList: unknown flags are 'other'", parsed.find(s => s.name === "weird").state === "other");
        shell.check("parseList: system scope parses the same", J(SW.parseList(fixture, "system")) === J(parsed));

        // diff
        const a = [svc("a", "running"), svc("b", "running"), svc("c", "stopped"), svc("d", "running")];
        shell.check("diff: running -> stopped is reported", J(SW.diff(a, [svc("a", "running"), svc("b", "stopped"), svc("c", "stopped"), svc("d", "running")])) === J([{ name: "b", failed: false }]));
        shell.check("diff: running -> failed is reported with failed", J(SW.diff(a, [svc("a", "running"), svc("b", "running"), svc("c", "stopped"), svc("d", "stopped", true)])) === J([{ name: "d", failed: true }]));
        shell.check("diff: stopped -> stopped, stopped -> running are not", SW.diff(a, [svc("a", "running"), svc("b", "running"), svc("c", "running"), svc("d", "running")]).length === 0);
        shell.check("diff: a newly seen service that is already stopped is not", SW.diff(a, a.concat([svc("e", "stopped", true)])).length === 0);
        shell.check("diff: a service that disappeared is not", SW.diff(a, [svc("a", "running")]).length === 0);
        shell.check("diff: first snapshot (no prev) reports nothing", SW.diff(null, a).length === 0);
        shell.check("diff: already failed -> still failed is not", SW.diff([svc("x", "stopped", true)], [svc("x", "stopped", true)]).length === 0);

        // expect() suppression
        const down = [{ name: "b", failed: false }, { name: "d", failed: true }];
        shell.check("dropExpected: an expected service is dropped inside the window", J(SW.dropExpected(down, { b: 1000 }, 1000 + 30000, SW.expectMs)) === J([down[1]]));
        shell.check("dropExpected: expired expectation no longer hides it", SW.dropExpected(down, { b: 1000 }, 1000 + 61000, SW.expectMs).length === 2);

        // evaluate: a series of snapshots
        function run(frames) {
            let prev = null, gates = {}, expected = {};
            const fired = [];
            frames.forEach(f => {
                if (f.expect)
                    expected[f.expect] = f.t * MIN;
                const r = SW.evaluate(prev, f.list, gates, expected, f.t * MIN);
                prev = f.list;
                gates = r.gates;
                expected = r.expected;
                for (const d of r.fired)
                    fired.push(d.name + "@" + f.t);
            });
            return fired.join(",");
        }
        const up = [svc("a", "running"), svc("b", "running")];
        const bDown = [svc("a", "running"), svc("b", "stopped")];
        shell.check("evaluate: a service going down fires once", run([{ t: 0, list: up }, { t: 1, list: bDown }, { t: 2, list: bDown }, { t: 3, list: bDown }]) === "b@1");
        shell.check("evaluate: the very first snapshot never fires", run([{ t: 0, list: bDown }]) === "");
        shell.check("evaluate: expect() before the stop suppresses the toast", run([{ t: 0, list: up }, { t: 0.5, list: up, expect: "b" }, { t: 1, list: bDown }]) === "");
        shell.check("evaluate: an old expectation does not suppress a later crash", run([{ t: 0, list: up, expect: "b" }, { t: 5, list: up }, { t: 6, list: bDown }]) === "b@6");
        shell.check("evaluate: running again re-arms, a second crash fires again", run([{ t: 0, list: up }, { t: 1, list: bDown }, { t: 2, list: up }, { t: 3, list: bDown }]) === "b@1,b@3");
        shell.check("evaluate: flapping inside one incident (down, down again without running) fires once", run([{ t: 0, list: up }, { t: 1, list: bDown }, { t: 2, list: [svc("a", "running"), svc("b", "stopped", true)] }]) === "b@1");
        shell.check("evaluate: two services get one toast each", run([{ t: 0, list: up }, { t: 1, list: [svc("a", "stopped"), svc("b", "stopped")] }]) === "a@1,b@1");

        // step: rate limit
        let g = { armed: true, last: 0 };
        let r = SW.step(g, true, false, 30 * MIN, 0);
        shell.check("step: first down fires and disarms", r.fire && !r.state.armed);
        r = SW.step(r.state, true, false, 30 * MIN, 10 * MIN);
        shell.check("step: down again within 30 min does not fire", !r.fire && !r.state.armed);
        const after = SW.step(r.state, false, false, 30 * MIN, 31 * MIN);
        shell.check("step: re-arms after 30 minutes", after.state.armed && !after.fire);
        shell.check("step: down after 30 minutes fires again", SW.step(r.state, true, false, 30 * MIN, 31 * MIN).fire);
        shell.check("step: running re-arms at once", SW.step(r.state, false, true, 30 * MIN, 1 * MIN).state.armed);
        shell.check("step: pure (input untouched)", g.armed === true && g.last === 0);

        // toast text
        shell.check("toast: body says what happened, title matches it", SW.toastBody(false) === "It is not running any more." && SW.toastBody(true) === "It failed. Details shows its log.");
        const cmd = SW.toastCommand("pipe wire; rm -rf ~", true);
        shell.check("toast: argument array with both actions, name only in the title", J(cmd) === J(["notify-send", "-a", "Services", "-A", "restart=Restart", "-A", "details=Details", "pipe wire; rm -rf ~ failed", "It failed. Details shows its log."]));
        shell.check("safeName: accepts real names, refuses odd ones", SW.safeName("pipewire-pulse") && SW.safeName("a@b.c_d") && !SW.safeName("-x") && !SW.safeName("a b") && !SW.safeName("a;b") && !SW.safeName(""));

        shell.check("harness: inactive under QS_NO_APPLY", SW.active === false);

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
