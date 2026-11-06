// Muted apps and priority apps (NotificationStore.qml, popups/NotificationList.qml): the pure add / remove / has
// functions, showsToast with the new priority / muted arguments (the old four-argument calls keep their meaning),
// add() with a fake notification (a muted app is stored in the history but not toasted; a priority app passes Do Not
// Disturb), the settings round trip, and the "Muted apps (n)" button + menu in the history header.
// The toast right-click menu lives in the layer-shell NotificationDaemon window and is a live test.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Services.Notifications

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    readonly property int winW: 480
    readonly property int winH: 400
    function asVar(o: var): var {
        return o;
    }
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function find(it: var, pred: var): var {
        if (pred(it))
            return it;
        for (const c of it.children) {
            const r = shell.find(c, pred);
            if (r)
                return r;
        }
        return null;
    }
    function fake(app, urgency) {
        return { appName: app, summary: "s", body: "b", urgency: urgency === undefined ? NotificationUrgency.Normal : urgency, appIcon: "", image: "", desktopEntry: "", closed: { connect: () => {} }, dismiss: () => {} };
    }

    FloatingWindow {
        implicitWidth: shell.winW; implicitHeight: shell.winH
        Rectangle {
            anchors.fill: parent
            color: Config.colors.base
            Loader {
                id: listLoad
                x: 10; y: 10
                width: shell.winW - 20
                height: shell.winH - 20
                Component.onCompleted: setSource("popups/NotificationList.qml", { active: true })
            }
            TestCase { id: tc; name: "sim"; when: false }
            Timer {
                interval: 900; running: true
                onTriggered: {
                    const S = NotificationStore;
                    const list = shell.asVar(listLoad.item);
                    S.restored = true;

                    // ---- pure list helpers ----
                    shell.check("listAdd appends a new name", JSON.stringify(S.listAdd(["a"], "b")) === '["a","b"]');
                    shell.check("listAdd does not duplicate", JSON.stringify(S.listAdd(["a"], "a")) === '["a"]');
                    shell.check("listAdd ignores an empty name", JSON.stringify(S.listAdd(["a"], "")) === '["a"]');
                    shell.check("listAdd on nothing starts a list", JSON.stringify(S.listAdd(undefined, "a")) === '["a"]');
                    shell.check("listRemove drops the name", JSON.stringify(S.listRemove(["a", "b"], "a")) === '["b"]');
                    shell.check("listRemove of an absent name changes nothing", JSON.stringify(S.listRemove(["a"], "z")) === '["a"]');
                    shell.check("listHas", S.listHas(["a"], "a") === true && S.listHas(["a"], "b") === false && S.listHas([], "") === false && S.listHas(undefined, "a") === false);
                    const orig = ["a"];
                    S.listAdd(orig, "b");
                    S.listRemove(orig, "a");
                    shell.check("the helpers never change their input", JSON.stringify(orig) === '["a"]');
                    shell.check("names are matched exactly", S.listHas(["Discord"], "discord") === false);

                    // ---- showsToast ----
                    shell.check("showsToast: plain notification shows", S.showsToast(false, true, false, false) === true);
                    shell.check("showsToast: DND holds (old four-argument call)", S.showsToast(true, true, false, false) === false);
                    shell.check("showsToast: sharing holds", S.showsToast(false, true, true, false) === false);
                    shell.check("showsToast: critical passes DND", S.showsToast(true, true, true, true) === true);
                    shell.check("showsToast: priority passes DND", S.showsToast(true, true, false, false, true, false) === true);
                    shell.check("showsToast: priority passes the screen-share hold", S.showsToast(false, true, true, false, true, false) === true);
                    shell.check("showsToast: not priority is still held", S.showsToast(true, true, true, false, false, false) === false);
                    shell.check("showsToast: muted never shows", S.showsToast(false, false, false, false, false, true) === false);
                    shell.check("showsToast: muted beats priority and critical", S.showsToast(false, false, false, true, true, true) === false);

                    // ---- add() with a fake notification ----
                    Config.settings.notifications.dnd = false;
                    Config.settings.notifications.mutedApps = ["Noisy"];
                    Config.settings.notifications.priorityApps = ["Chat"];
                    tc.wait(50);
                    shell.check("the settings read back as plain lists", JSON.stringify(S.mutedApps) === '["Noisy"]' && JSON.stringify(S.priorityApps) === '["Chat"]');
                    S.items = [];
                    S.dropToasts();
                    S.add(shell.fake("Noisy"));
                    shell.check("a muted app: stored in the history, no toast", S.items.length === 1 && S.toasts.length === 0);
                    S.add(shell.fake("Other"));
                    shell.check("another app still toasts", S.items.length === 2 && S.toasts.length === 1);
                    Config.settings.notifications.dnd = true;
                    S.add(shell.fake("Other2"));
                    shell.check("DND holds a normal app's toast", S.items.length === 3 && S.toasts.length === 1);
                    S.add(shell.fake("Chat"));
                    shell.check("a priority app gets through DND", S.items.length === 4 && S.toasts.length === 2);
                    S.add(shell.fake("Noisy", NotificationUrgency.Critical));
                    shell.check("a muted app stays muted when critical, still in the history", S.items.length === 5 && S.toasts.length === 2);
                    Config.settings.notifications.dnd = false;
                    tc.wait(100);

                    // ---- store actions ----
                    S.dropToasts();
                    S.add(shell.fake("Fresh"));
                    shell.check("a fresh app toasts", S.toasts.length === 1);
                    S.muteApp("Fresh");
                    tc.wait(50);
                    shell.check("muteApp appends to the setting and drops the app's live toast", JSON.stringify(Config.settings.notifications.mutedApps) === '["Noisy","Fresh"]' && S.toasts.length === 0);
                    S.muteApp("Fresh");
                    shell.check("muting twice does not duplicate", Config.settings.notifications.mutedApps.length === 2);
                    S.unmuteApp("Noisy");
                    tc.wait(50);
                    shell.check("unmuteApp removes it", JSON.stringify(Config.settings.notifications.mutedApps) === '["Fresh"]');
                    S.setPriority("Mail", true);
                    tc.wait(50);
                    shell.check("setPriority on adds", JSON.stringify(Config.settings.notifications.priorityApps) === '["Chat","Mail"]');
                    S.setPriority("Chat", false);
                    tc.wait(50);
                    shell.check("setPriority off removes", JSON.stringify(Config.settings.notifications.priorityApps) === '["Mail"]');

                    // ---- history header ----
                    S.items = [];
                    S.items = [{ key: 1, appName: "A", summary: "s", body: "b", urgency: 1, appIcon: "", image: "", time: new Date(), notif: null }];
                    Config.settings.notifications.mutedApps = [];
                    tc.wait(100);
                    const btn = () => shell.find(list, it => it.objectName === "mutedButton");
                    shell.check("no Muted apps button while nothing is muted", btn() !== null && btn().visible === false);
                    Config.settings.notifications.mutedApps = ["Noisy", "Fresh"];
                    tc.wait(100);
                    shell.check("the button shows 'Muted apps (2)'", btn().visible === true && btn().text === "Muted apps (2)");
                    tc.mouseClick(btn());
                    tc.wait(100);
                    const m = list.mutedMenuItem;
                    shell.check("clicking it opens the menu with one entry per muted app", m.visible === true && m.model.length === 2 && m.model[0].text === "Unmute Noisy" && m.model[1].text === "Unmute Fresh");
                    m.model[0].action();
                    shell.check("picking an entry unmutes that app", JSON.stringify(Config.settings.notifications.mutedApps) === '["Fresh"]');
                    tc.wait(50);
                    shell.check("the count follows", btn().text === "Muted apps (1)");
                    m.close();
                    shell.check("the history keeps muted apps' notifications", S.items.length === 1);
                    console.log("TEST done failures=" + shell.failures);
                    Qt.quit();
                }
            }
        }
    }
}
