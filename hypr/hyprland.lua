---@module 'hl'

--## VARIABLES ###

mainMod = "SUPER"
menu = [[bash -c 'qs ipc call appLauncher_$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .name") toggleAppLauncher']]
terminal = "kitty"
fileManager = "nemo"

require("autostart")
require("monitors")
-- optional and gitignored: hypr/monitors_local.lua (copy monitors_local.lua.example) adds this machine's own monitors, e.g. a laptop
pcall(require, "monitors_local")
require("env")
require("look_and_feel")
require("inputs")
require("binds")
require("windowrules")
-- Win95 window frames (hyprbars + imgborders plugins); never allowed to break the rest of the config
pcall(require, "plugins")
