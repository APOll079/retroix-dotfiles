// The Text (OCR) choice of the snipping overlay (popups/ScreenshotOverlay.qml): Shot / Record / Text act as one switch,
// Text is region only (Window / Screen / All are disabled and ignored by keys 2-4), the hint says to drag over the text,
// and the old Shot / Record behaviour is unchanged. ScreenshotOverlay is a layer-shell PanelWindow, so this test writes a
// scratch copy (inside the runner's own scratch tree) with PanelWindow turned into FloatingWindow and the layer-shell
// lines dropped; everything else is the real file. QS_NO_APPLY is set: RecordState.ocr() starts nothing.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function asVar(o: var): var {
        return o;
    }
    FileView {
        id: src
        path: Quickshell.shellPath("popups/ScreenshotOverlay.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/ScreenshotOverlayTest.qml")
        blockWrites: true
    }
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }
    Component.onCompleted: {
        let t = src.text();
        t = t.replace("PanelWindow {", "FloatingWindow {");
        t = t.replace(/\n    anchors \{[\s\S]*?\n    \}/, "");
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0).join("\n");
        dst.setText(t);
        loader.setSource("popups/ScreenshotOverlayTest.qml", {});
    }
    Loader { id: loader }
    TestCase { id: tc; name: "sim"; when: false }

    Timer {
        interval: 1500; running: true
        onTriggered: {
            const o = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", o !== null && o.ocr !== undefined);
            const btn = text => shell.find(o.contentItem, c => c.text === text && c.clicked !== undefined, [])[0];
            o.open();
            tc.wait(100);
            shell.check("open: a plain shot, Text off", o.ocr === false && o.record === false && o.mode === "region");
            shell.check("the Text button exists next to Shot and Record", btn("Text") !== undefined && btn("Shot") !== undefined && btn("Record") !== undefined);
            shell.check("the old Window / Screen / All buttons are enabled for a shot", btn("Window").enabled && btn("Screen").enabled && btn("All").enabled);

            btn("Text").clicked();
            shell.check("Text on: region mode, Record off", o.ocr === true && o.record === false && o.mode === "region");
            shell.check("Text on: Window, Screen and All are disabled, Region stays", !btn("Window").enabled && !btn("Screen").enabled && !btn("All").enabled && btn("Region").enabled);
            shell.check("Text on: Text is the checked one, Shot is not", btn("Text").checked === true && btn("Shot").checked === false);
            o.pick("window");
            shell.check("Text on: picking Window (key 2) does nothing", o.mode === "region");
            o.pick("screen");
            shell.check("Text on: picking Screen (key 3) does not shoot", o.mode === "region" && o.capturing === false);
            shell.check("Text on: the hint says to drag over the text", RecordState.hintText(o.mode, o.recordArmed, RecordState.preflight, o.ocr) === "Drag to select the text. Esc cancels.");

            btn("Record").clicked();
            shell.check("Record turns Text off and arms recording", o.ocr === false && o.record === true && btn("Window").enabled);
            btn("Text").clicked();
            shell.check("Text turns Record off", o.ocr === true && o.record === false);
            btn("Shot").clicked();
            shell.check("Shot turns Text off", o.ocr === false);
            o.pick("window");
            shell.check("Shot: Window mode works again", o.mode === "window");
            btn("Text").clicked();
            shell.check("Text from Window mode goes back to region", o.mode === "region" && o.ocr === true);

            o.close();
            o.open();
            shell.check("every open starts as a plain shot", o.ocr === false && o.record === false);
            console.log("TEST done failures=" + shell.failures);
            Qt.quit();
        }
    }
}
