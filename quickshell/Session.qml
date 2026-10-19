pragma Singleton
import QtQuick
import Quickshell

// Session actions, shared by the side panel power row, the Start menu's session panel and the launcher.
// One policy everywhere: Lock runs on one click; Log out, Suspend, Reboot and Shutdown ask first
// (prompt + a button with the verb, then Cancel) and then run at once. The session panel adds a
// countdown for `countdown` actions only when settings.json "session.countdownSeconds" is above 0.
// Custom actions: settings.json "session": customActions.
Singleton {
    id: root

    // confirm: asks first; verb: the confirm button; prompt: the question
    readonly property var builtins: [
        { name: "Suspend", icon: "", cmd: "loginctl suspend", confirm: true, countdown: false, verb: "Suspend", prompt: "Suspend now?" },
        { name: "Lock", icon: "", cmd: "pidof hyprlock || hyprlock", confirm: false, countdown: false, verb: "Lock", prompt: "" },
        { name: "Log out", icon: "", cmd: "hyprctl dispatch 'hl.dsp.exit()'", confirm: true, countdown: false, verb: "Log out", prompt: "Log out of Hyprland?" },
        { name: "Reboot", icon: "", cmd: "loginctl reboot", confirm: true, countdown: true, verb: "Reboot", prompt: "Reboot now?" },
        { name: "Shutdown", icon: "", cmd: "loginctl poweroff", confirm: true, countdown: true, verb: "Shut down", prompt: "Shut down the computer?" }
    ]

    // Your own actions from settings.json: [{ "name", "icon" (glyph, optional), "cmd" }]
    readonly property var custom: (Config.settings.session.customActions || []).map(a => ({
        name: a.name, icon: a.icon || "", cmd: a.cmd, confirm: false, countdown: false, verb: a.name, prompt: ""
    }))

    readonly property var all: builtins.concat(custom)

    function run(action) {
        Quickshell.execDetached(["sh", "-c", action.cmd]);
    }
}
