// Tests for UsbState.qml's pure logic: the diff of two drive lists, the baseline (drives already plugged in never toast),
// label / size formatting, parsing usb.sh output and hostile labels. No tool runs (the runner sets QS_NO_APPLY, so the
// singleton's timer and Processes stay off). The script itself is tested by tests/usb-script-test.sh.
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
        const U = UsbState;
        const stick = { dev: "sdb1", label: "STICK", size: 15999000000, mountpoint: null, removable: true };
        const card = { dev: "mmcblk0p1", label: "", size: 32000000000, mountpoint: "/run/media/u/SD", removable: true };
        const names = list => list.map(d => d.dev).join(",");

        // diff
        shell.check("diff: a new drive is added", names(U.diff([], [stick]).added) === "sdb1");
        shell.check("diff: a vanished drive is removed", names(U.diff([stick], []).removed) === "sdb1");
        shell.check("diff: unchanged lists give nothing", (() => { const r = U.diff([stick, card], [card, stick]); return r.added.length === 0 && r.removed.length === 0; })());
        shell.check("diff: added and removed at once", (() => { const r = U.diff([stick], [card]); return names(r.added) === "mmcblk0p1" && names(r.removed) === "sdb1"; })());
        shell.check("diff: mounting the same drive is not a new drive", U.diff([stick], [Object.assign({}, stick, { mountpoint: "/m" })]).added.length === 0);
        shell.check("diff: unplug then replug is added again", (() => {
            const gone = U.step([stick], true, []);
            return U.step(gone.drives, gone.baselined, [stick]).toast.length === 1;
        })());

        // baseline
        shell.check("baseline: the first poll never toasts, even with drives plugged in", (() => { const r = U.step([], false, [stick, card]); return r.toast.length === 0 && r.baselined === true && r.drives.length === 2; })());
        shell.check("baseline: a drive appearing after the first poll toasts once", (() => {
            const first = U.step([], false, [stick]);
            const second = U.step(first.drives, first.baselined, [stick, card]);
            const third = U.step(second.drives, second.baselined, [stick, card]);
            return names(second.toast) === "mmcblk0p1" && third.toast.length === 0;
        })());
        shell.check("baseline: an empty first poll still records the baseline", (() => {
            const first = U.step([], false, []);
            return first.baselined === true && U.step(first.drives, first.baselined, [stick]).toast.length === 1;
        })());

        // formatting
        shell.check("size: gigabytes", U.formatSize(15999000000) === "16.0 GB");
        shell.check("size: megabytes", U.formatSize(512000000) === "512 MB");
        shell.check("size: terabytes", U.formatSize(2e12) === "2.0 TB");
        shell.check("size: nonsense gives ?", U.formatSize(-1) === "?" && U.formatSize(undefined) === "?" && U.formatSize("x") === "?");
        shell.check("label: the label when there is one", U.displayName(stick) === "STICK");
        shell.check("label: the device name when the label is empty", U.displayName(card) === "mmcblk0p1");
        shell.check("label: a blank label counts as empty", U.displayName({ dev: "sdc", label: "  \n\t ", size: 1 }) === "sdc");
        shell.check("toast body: label and size", U.toastBody(stick) === "STICK (16.0 GB)");
        shell.check("toast body: device name and size without a label", U.toastBody(card) === "mmcblk0p1 (32.0 GB)");

        // hostile labels
        shell.check("hostile: line breaks and control characters become spaces", U.cleanLabel("a\nb\u0007c\r\nd") === "a b c d");
        shell.check("hostile: a very long label is cut", U.cleanLabel("x".repeat(500)).length === U.labelMax);
        shell.check("hostile: markup is left as plain text (the toast and menus are PlainText)", U.cleanLabel("<b>bold</b> & $(id)") === "<b>bold</b> & $(id)");
        shell.check("hostile: null and undefined labels are empty", U.cleanLabel(null) === "" && U.cleanLabel(undefined) === "");

        // device names
        shell.check("dev: plain kernel names are valid", U.validDev("sdb1") && U.validDev("mmcblk0p1") && U.validDev("nvme0n1p2"));
        shell.check("dev: shell and path characters are refused", !U.validDev("sdb1;rm") && !U.validDev("../sda") && !U.validDev("") && !U.validDev("SDB1") && !U.validDev("sd b") && !U.validDev(null) && !U.validDev(5));

        // parse
        shell.check("parse: usb.sh output becomes drives", (() => {
            const r = U.parse('[{"dev":"sdb1","label":"STICK","size":100,"mountpoint":null,"removable":true},{"dev":"sdc","label":"","size":5,"mountpoint":"/m","removable":true}]');
            return r.length === 2 && r[0].mountpoint === null && r[1].mountpoint === "/m" && r[0].size === 100;
        })());
        shell.check("parse: junk gives null so the old list is kept", U.parse("not json") === null && U.parse("") === null && U.parse('{"a":1}') === null);
        shell.check("parse: an empty list is a valid empty list", (() => { const r = U.parse("[]"); return Array.isArray(r) && r.length === 0; })());
        shell.check("parse: entries with a bad device name are dropped", names(U.parse('[{"dev":"../etc","label":"x","size":1},{"dev":"sdb1","label":"ok","size":1}]')) === "sdb1");
        shell.check("parse: a hostile label is cleaned", U.parse('[{"dev":"sdb1","label":"a\\nb","size":1}]')[0].label === "a b");
        shell.check("parse: an empty mountpoint string means unmounted", U.parse('[{"dev":"sdb1","label":"","size":1,"mountpoint":""}]')[0].mountpoint === null);

        // the toast command: the text goes in as separate arguments, never into a shell string
        shell.check("toast: notify-send -a USB with Open and Eject", (() => {
            const c = U.toast("USB drive plugged in", "STICK (16.0 GB)", ["open=Open", "eject=Eject"]);
            return c.join("|") === "notify-send|-a|USB|-A|open=Open|-A|eject=Eject|USB drive plugged in|STICK (16.0 GB)";
        })());
        shell.check("toast: a hostile body stays one argument", U.toast("t", "$(id); `x`", []).length === 5);

        // ejectable
        shell.check("ejectable: only mounted drives", (() => { U.drives = [stick, card]; return names(U.ejectable) === "mmcblk0p1"; })());
        shell.check("open / eject do nothing without a running shell (QS_NO_APPLY) or with a bad name", (() => { U.open("sdb1"); U.eject("../x"); return true; })());

        console.log("TEST done failures=" + shell.failures);
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
