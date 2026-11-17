---@module 'hl'
-- Minimal Hyprland config for the login screen (greetd runs `start-hyprland -- --config <this file>` as the `greeter`
-- user, see install.sh "Login screen"). No binds, no animations, no wallpaper; it starts the Quickshell greeter and
-- leaves Hyprland when the greeter quits (after a successful login or a crash, so greetd can start your session or
-- fall back to agreety). Monitors and keyboard as in hypr/monitors.lua / inputs.lua; edit them here if they change.

hl.monitor({ output = "DP-1", mode = "1920x1080@60", position = "0x-1080", scale = 1 })
hl.monitor({ output = "DP-2", mode = "1920x1080@165", position = "0x0", scale = 1 })

hl.config({
    input = { kb_layout = "se", follow_mouse = 1 },
    animations = { enabled = false },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0 }
})

hl.on("hyprland.start", function()
    hl.exec_cmd([[sh -c 'QS_NO_APPLY=1 quickshell -p /etc/greetd/qs-greeter/shell.qml; hyprctl dispatch "hl.dsp.exit()"']])
end)
