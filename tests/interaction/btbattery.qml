// The bar's Bluetooth battery choice (LaptopControls.btBatteryText / btBatteryTooltip / btText) on fixture
// devices. Real BlueZ is not used: btDevices is
// replaced with plain objects shaped like Quickshell.Bluetooth devices (connected, batteryAvailable, battery 0..1).
import QtQuick
import Quickshell

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function dev(name, connected, bat) {
        return { name: name, address: "AA:BB", connected: connected, batteryAvailable: bat !== null, battery: bat === null ? 0 : bat };
    }

    // loaded by file name: the type lives in the shell's root folder, which qmllint can't see from tests/
    FloatingWindow {
        implicitWidth: loader.implicitWidth
        implicitHeight: loader.implicitHeight
        Loader {
            id: loader
            source: "LaptopControls.qml"
        }
    }
    readonly property var lc: loader.item

    Timer {
        interval: 300
        running: true
        onTriggered: {
            const none = [];
            const noBat = [shell.dev("Mouse", true, null)];
            const one = [shell.dev("Headset", true, 0.82)];
            const two = [shell.dev("Headset", true, 0.82), shell.dev("Mouse", true, 0.4)];
            const full = [shell.dev("Pad", true, 1.0)];
            const off = [shell.dev("Old", false, 0.1)];
            const zero = [shell.dev("Dead", true, 0.0)];
            shell.check("no devices: empty text", shell.lc.btBatteryText(none) === "");
            shell.check("no devices: empty tooltip", shell.lc.btBatteryTooltip(none) === "");
            shell.check("connected without battery: empty text", shell.lc.btBatteryText(noBat) === "");
            shell.check("connected without battery: empty tooltip", shell.lc.btBatteryTooltip(noBat) === "");
            shell.check("one at 82 %: text", shell.lc.btBatteryText(one) === "82%");
            shell.check("one at 82 %: tooltip", shell.lc.btBatteryTooltip(one) === "Headset 82%");
            shell.check("two: lowest wins", shell.lc.btBatteryText(two) === "40%");
            shell.check("two: one line each", shell.lc.btBatteryTooltip(two) === "Headset 82%\nMouse 40%");
            shell.check("100 %", shell.lc.btBatteryText(full) === "100%");
            shell.check("disconnected with battery ignored", shell.lc.btBatteryText(off) === "" && shell.lc.btBatteryTooltip(off) === "");
            shell.check("disconnected ignored next to a connected one", shell.lc.btBatteryText(one.concat(off)) === "82%");
            shell.check("0 % is shown, not hidden", shell.lc.btBatteryText(zero) === "0%" && shell.lc.btBatteryTooltip(zero) === "Dead 0%");
            shell.check("name falls back to address", shell.lc.btBatteryTooltip([{ name: "", deviceName: "", address: "AA:BB", connected: true, batteryAvailable: true, battery: 0.5 }]) === "AA:BB 50%");
            // the real property chain; whether an adapter is present depends on the machine (the system bus may be
            // reachable offscreen), so the fallback is compared with btOn, not with a fixed word
            const idle = shell.lc.btOn ? "ON" : "OFF";
            shell.lc.btDevices = none;
            shell.check("btText with no devices is ON / OFF", shell.lc.btText === idle);
            shell.lc.btDevices = two;
            shell.check("btText follows btDevices", shell.lc.btText === "40%");
            shell.lc.btDevices = noBat;
            shell.check("btText falls back when the battery is unknown", shell.lc.btText === idle);
            console.log("TEST done failures=" + shell.failures);
            Qt.quit();
        }
    }
}
