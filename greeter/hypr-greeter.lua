---@module 'hl'
-- Minimal Hyprland config for the login screen (greetd runs `start-hyprland -- --config <this file>` as the `greeter`
-- user, see install.sh "Login screen"). No binds, no animations, no wallpaper; it starts the Quickshell greeter and
-- leaves Hyprland when the greeter quits (after a successful login or a crash, so greetd can start your session or
-- fall back to agreety). Monitors come from hypr/monitors.lua (and monitors_local.lua when it exists), which install.sh copies
-- next to this file; if they can't be loaded, every screen is configured by its preferred mode. The keyboard is as in inputs.lua.

local dir = "/etc/greetd/qs-greeter/"
local ok = pcall(dofile, dir .. "monitors.lua")
if ok then
    pcall(dofile, dir .. "monitors_local.lua")
else
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
end

hl.config({
    input = { kb_layout = "se", follow_mouse = 1 },
    animations = { enabled = false },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0 }
})

hl.on("hyprland.start", function()
    hl.exec_cmd([[sh -c 'QS_NO_APPLY=1 quickshell -p /etc/greetd/qs-greeter/shell.qml; hyprctl dispatch "hl.dsp.exit()"']])
end)
