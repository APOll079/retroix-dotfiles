---@module 'hl'
-- =========================
-- KEYBINDINGS / WORKSPACES
-- (keyboard layout and mouse buttons live in inputs.lua)
-- =========================

hl.bind(mainMod .. " + " .. "D", hl.dsp.exec_cmd(menu))  -- help: Apps | Launcher
-- Super+Q closes an open quickshell menu first (any monitor); only with no menu open does it close the window
local closeMenuOrWindow = [[bash -c 'for m in $(hyprctl monitors -j | jq -r ".[].name"); do qs ipc call menus_$m closeAny; done | grep -q true || sh "$HOME/.config/hypr/scripts/closewin"']]
hl.bind(mainMod .. " + " .. "q", hl.dsp.exec_cmd(closeMenuOrWindow))  -- help: Windows | Close menu, else close window
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))  -- help: Windows | Maximise
hl.bind(mainMod .. " + SHIFT" .. " + " .. "F", hl.dsp.window.fullscreen())  -- help: Windows | Fullscreen
hl.bind(mainMod .. " + " .. "return", hl.dsp.exec_cmd(terminal))  -- help: Apps | Terminal
hl.bind(mainMod .. " + " .. "E", hl.dsp.exec_cmd(fileManager))  -- help: Apps | File manager
hl.bind(mainMod .. " + " .. "B", hl.dsp.exec_cmd("zen-browser"))  -- help: Apps | Browser
hl.bind(mainMod .. " + " .. "space", hl.dsp.window.float({ action = "toggle" }))  -- help: Windows | Toggle floating
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("hypremoji"))  -- help: Apps | Emoji picker

-- Snipping overlay on the focused monitor (quickshell ScreenshotOverlay.qml)
local screenshotOverlay = [[bash -c 'qs ipc call screenshot_$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .name") toggle']]
hl.bind(mainMod .. " + SHIFT" .. " + " .. "S", hl.dsp.exec_cmd(screenshotOverlay))  -- help: Screen | Screenshot overlay
local screenshotHistory = [[bash -c 'qs ipc call screenshot_$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .name") history']]
hl.bind(mainMod .. " + SHIFT" .. " + " .. "H", hl.dsp.exec_cmd(screenshotHistory))  -- help: Screen | Screenshot history
-- Games menu (quickshell GamesMenu.qml) on the focused monitor
local function recordCmd(fn) return "bash -c 'qs ipc call record_$(hyprctl monitors -j | jq -r \".[] | select(.focused) | .name\") " .. fn .. "'" end
hl.bind(mainMod .. " + SHIFT" .. " + " .. "R", hl.dsp.exec_cmd(recordCmd("toggle")))  -- help: Screen | Record the screen (stops a running recording)
hl.bind(mainMod .. " + CTRL" .. " + " .. "R", hl.dsp.exec_cmd(recordCmd("replayToggle")))  -- help: Screen | Replay buffer on / off
hl.bind(mainMod .. " + CTRL" .. " + " .. "S", hl.dsp.exec_cmd(recordCmd("replaySave")))  -- help: Screen | Save the replay clip
hl.bind(mainMod .. " + CTRL" .. " + " .. "P", hl.dsp.exec_cmd(recordCmd("pauseToggle")))  -- help: Screen | Pause / resume the recording
local gamesMenu = [[bash -c 'qs ipc call games_$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .name") toggle']]
hl.bind(mainMod .. " + SHIFT" .. " + " .. "G", hl.dsp.exec_cmd(gamesMenu))  -- help: Apps | Games menu
hl.bind(mainMod .. " + SHIFT" .. " + " .. "c", hl.dsp.exec_cmd([[bash -c 'c=$(sh ~/.config/quickshell/scripts/colorpick.sh) && [ -n "$c" ] && qs ipc call colors add "$c"']]))  -- help: Screen | Pick a colour
hl.bind(mainMod .. " + CTRL" .. " + " .. "M", hl.dsp.exec_cmd([[bash -c 'qs ipc call mic_$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .name") toggle']]))  -- help: Audio | Mute / unmute the microphone
-- Task Manager (quickshell TaskManager.qml): one real window; opens it, or focuses it when it is
-- already open. Over a fullscreen game or video it leaves fullscreen first, so the window can't
-- open hidden behind it (misc.on_focus_under_fullscreen only covers tiled windows).
-- fullscreen == 2 is real fullscreen (1 = maximised, kept); the no-argument
-- hl.dsp.window.fullscreen() toggles it off, like SUPER + SHIFT + F above (GUESS: not seen running)
hl.bind("CTRL + SHIFT" .. " + " .. "ESCAPE", function()  -- help: Apps | Task Manager
    local w = hl.get_active_window()
    if w and w.fullscreen == 2 then
        hl.dispatch(hl.dsp.window.fullscreen())
    end
    hl.dispatch(hl.dsp.exec_cmd("qs ipc call taskmanager open"))
end)
-- Spotify panel (quickshell SpotifyPanel.qml) on the focused monitor
local spotifyPanel = [[bash -c 'qs ipc call spotify_$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .name") toggle']]
hl.bind(mainMod .. " + " .. "S", hl.dsp.exec_cmd(spotifyPanel))  -- help: Apps | Spotify panel
-- Keybind cheat sheet (quickshell CheatSheet.qml)
local cheatSheet = [[bash -c 'qs ipc call cheatsheet_$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .name") toggle']]
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd(cheatSheet))  -- help: Desktop | This cheat sheet
-- Clipboard history lives in the quickshell launcher (themed, keyboard-driven)
hl.bind(mainMod .. " + " .. "V", hl.dsp.exec_cmd([[bash -c 'qs ipc call appLauncher_$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .name") clipboard']]))  -- help: Apps | Clipboard history
hl.bind(mainMod .. " + SHIFT" .. " + " .. "comma", hl.dsp.exec_cmd([[bash -c 'qs ipc call appLauncher_$(hyprctl monitors -j | jq -r ".[] | select(.focused) | .name") settings']]))  -- help: Apps | Settings
hl.bind(mainMod .. " + " .. "L", hl.dsp.exec_cmd("hyprlock"))  -- help: Desktop | Lock screen
hl.bind(mainMod .. " + CTRL" .. " + " .. "L", hl.dsp.exec_cmd("qs ipc call lyrics toggle"))  -- help: Media | Lyrics window (toggle)

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + " .. "left", hl.dsp.focus({ direction = "left" }))  -- help: Windows | Focus left
hl.bind(mainMod .. " + " .. "right", hl.dsp.focus({ direction = "right" }))  -- help: Windows | Focus right
hl.bind(mainMod .. " + " .. "up", hl.dsp.focus({ direction = "up" }))  -- help: Windows | Focus up
hl.bind(mainMod .. " + " .. "down", hl.dsp.focus({ direction = "down" }))  -- help: Windows | Focus down

-- Workspaces 1-4 live on the main monitor: mainMod + N switches, mainMod + SHIFT + N moves the active window
for i = 1, 4 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))  -- help: Workspaces | Go to workspace
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))  -- help: Workspaces | Move window to workspace
    hl.workspace_rule({
        workspace = tostring(i),
        monitor = "DP-2",
        default = (i == 1)
    })
end

-- Top monitor: one fixed workspace that none of the number binds ever switch
hl.workspace_rule({
    workspace = "11",
    monitor = "DP-1",
    default = true,
    persistent = true
})

hl.bind(mainMod .. " + " .. "mouse_down", hl.dsp.focus({ workspace = "e+1" }))  -- help: Workspaces | Next workspace
hl.bind(mainMod .. " + " .. "mouse_up", hl.dsp.focus({ workspace = "e-1" }))  -- help: Workspaces | Previous workspace

-- SUPER + C: scratchpad for Vesktop. The window rule in windowrules.lua sends it to
-- special:spotifyspace (the name is kept from when Spotify lived there too; a Spotify started by
-- hand still lands there hidden); this launches it if it isn't running, then toggles the workspace.
-- Spotify itself is a Quickshell menu (Super+S) and is no longer started from here.
local scratchApps = {
    { class = "vesktop", cmd = "vesktop" }
}
hl.bind(mainMod .. " + " .. "C", function()  -- help: Desktop | Vesktop scratchpad
    local running = {}
    for _, w in ipairs(hl.get_windows()) do
        running[w.class] = true
    end
    for _, app in ipairs(scratchApps) do
        if not running[app.class] then
            hl.dispatch(hl.dsp.exec_cmd(app.cmd))
        end
    end
    hl.dispatch(hl.dsp.workspace.toggle_special("spotifyspace"))
end)

hl.bind(mainMod .. " + CTRL" .. " + " .. "W", function() require("restore").run() end)  -- help: Desktop | Restore workspaces
hl.bind(mainMod .. " + CTRL" .. " + " .. "O", hl.dsp.exec_cmd("qs ipc call miniplayer toggle"))  -- help: Media | Mini player (toggle)
hl.bind(mainMod .. " + SHIFT" .. " + " .. "O", hl.dsp.exec_cmd("pkill -SIGUSR1 hyprexpose"))  -- help: Windows | Workspace overview
hl.bind(mainMod .. " + CTRL" .. " + " .. "K", hl.dsp.exec_cmd("qs ipc call screensaver start"))  -- help: Desktop | Start the screensaver
-- SUPER + CTRL + T: a drop-down terminal (kitty --class dropterm) in its own special workspace, like the Vesktop scratchpad
-- above; started the first time, then toggled. The "dropdown-terminal" rule in windowrules.lua floats and places it
hl.bind(mainMod .. " + CTRL" .. " + " .. "T", function()  -- help: Desktop | Drop-down terminal
    local running = false
    for _, w in ipairs(hl.get_windows()) do
        if w.class == "dropterm" then running = true end
    end
    if not running then
        hl.dispatch(hl.dsp.exec_cmd("kitty --class dropterm"))
    end
    hl.dispatch(hl.dsp.workspace.toggle_special("dropterm"))
end)

-- SUPER + CTRL + Z: magnify around the cursor (Hyprland's cursor zoom), again to go back. Option name from the
-- reference stubs (cursor.zoom_factor); the Lua call shape is a guess, not seen running here
local zoomed = false
hl.bind(mainMod .. " + CTRL" .. " + " .. "Z", function()  -- help: Desktop | Zoom around the cursor (toggle)
    zoomed = not zoomed
    hl.config({ cursor = { zoom_factor = zoomed and 2.5 or 1.0 } })
end)

-- Named <focused window class>_YYYY-MM-DD_HH-MM by quickshell/scripts/shot-name.sh (screenshot_... if
-- that script is missing); a taken name gets -2, -3
local screenshotCmd = [[bash -c 'dir=$HOME/screenshots; mkdir -p "$dir"; n=$(sh "$HOME/.config/quickshell/scripts/shot-name.sh" 2>/dev/null); [ -n "$n" ] || n=screenshot_$(date +%Y-%m-%d_%H-%M); b="$dir/$n"; f="$b.png"; i=2; while [ -e "$f" ]; do f="$b-$i.png"; i=$((i+1)); done; grim "$f" && wl-copy < "$f"']]
-- Print (and SUPER + SHIFT + S, above) open the quickshell snipping overlay on the focused
-- monitor: region drag, window, screen, all, history. Shift+Print stays instant
hl.bind("Print", hl.dsp.exec_cmd(screenshotOverlay))  -- help: Screen | Screenshot overlay
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(screenshotCmd))  -- help: Screen | Instant full screenshot
-- Autoclicker toggle (hypr/scripts/autoclick: ydotool, left button about 20 clicks/s); setup once with scripts/autoclick-setup.sh
hl.bind("F8", hl.dsp.exec_cmd("fish ~/.config/hypr/scripts/autoclick"))  -- help: Desktop | Autoclicker (toggle)

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl -p spotify play-pause"), { locked = true })  -- help: hidden
