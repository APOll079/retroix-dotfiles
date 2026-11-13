---@module 'hl'

-- =========================
-- WINDOW RULES
-- =========================

hl.window_rule({
    name  = "windowrule-1",
    match = {
        class = ".*"
    },
    suppress_event = "maximize"
})

hl.window_rule({
    name  = "windowrule-2",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false
    },
    no_focus = true
})

-- Float Nemo dialogs
hl.window_rule({
    name  = "windowrule-3",
    match = {
        class = "^nemo$",
        title = "^(.*Properties.*)$"
    },
    float = true
})

-- Make portal dialogs float (file pickers, screen-share picker). Classes are e.g.
-- xdg-desktop-portal-gtk / xdg-desktop-portal-hyprland, so match the prefix
hl.window_rule({
    name  = "windowrule-4",
    match = {
        class = "^(xdg-desktop-portal.*)$"
    },
    float = true
})

hl.window_rule({
    name  = "windowrule-imageviewer",
    match = {
        class = "^(ImageViewer)$"
    },
    float = true
})

-- Make GNOME Image Viewer (Loupe) float: matched on the class only (the title changes with the open file)
hl.window_rule({
    name = "windowrule-loupe",
    match = {
        initial_class = [[^(org\.gnome\.Loupe)$]]
    },
    float = true
})

-- Zen's Picture-in-Picture: floats, pinned (follows you across workspaces), small, in the bottom-right corner.
-- Field names as in the lyrics-window rule below; the title "Picture-in-Picture" is Firefox's, not seen running here
hl.window_rule({
    name  = "zen-picture-in-picture",
    match = {
        class = "^(zen|zen-browser)$",
        title = "^Picture-in-Picture$"
    },
    float = true,
    pin   = true,
    size  = { 480, 270 },
    move  = { "monitor_w-window_w-16", "monitor_h-window_h-48" }
})

-- Dialogs (file pickers, save / open, properties) float and centre instead of tiling over your layout.
-- Matched by title because Hyprland has no "modal" match; not seen running here
hl.window_rule({
    name  = "dialogs-float",
    match = {
        title = "^(Open File|Open Files|Open Folder|Save File|Save As|Select .*|Choose .*|File Upload|Properties)$"
    },
    float  = true,
    center = true
})

hl.window_rule({
    name  = "windowrule-zen-download",
    match = {
        class = "^(zen|zen-browser)$",
        title = "^(.*Downloads.*)$"
    },
    float = true
})

-- Spotify + Vesktop live in the SUPER + C scratchpad (silent: don't steal focus on launch)
hl.window_rule({
    name  = "spotify-scratchpad",
    match = {
        class = "^Spotify$"
    },
    workspace = "special:spotifyspace silent"
})

hl.window_rule({
    name  = "vesktop-scratchpad",
    match = {
        class = "^vesktop$"
    },
    workspace = "special:spotifyspace silent"
})

-- The 3D pipes screensaver (settings screensaver.style = "pipes3d") runs xscreensaver's /usr/lib/xscreensaver/pipes in a
-- window; fullscreen it, no animation, no focus. GUESS, not seen running: the class may be "XScreenSaver" or "pipes".
hl.window_rule({
    name  = "screensaver-pipes3d",
    match = {
        class = "^(XScreenSaver|pipes)$"
    },
    fullscreen = true,
    no_anim    = true,
    no_focus   = true
})

-- Steam games (and Steam shortcuts) run as steam_app_<id> under Proton: open them on workspace 2 (DP-2)
hl.window_rule({
    name  = "games-workspace",
    match = {
        class = "^steam_app_\\d+$"
    },
    workspace = "2"
})

hl.window_rule({
    name  = "float-on-7zfm",
    match = {
        initial_class = "7zFM"
    },
    float = true
})

-- Float VLC (class is "vlc" on Qt builds; GUESS, not seen running here)
hl.window_rule({
    name  = "float-on-vlc",
    match = {
        class = "^(vlc|VLC)$"
    },
    float = true
})

-- VLC re-creates its window when a looped video restarts and asks to be activated; with
-- misc.focus_on_activate on (needed for Vesktop notification clicks) that focused it and
-- pulled the cursor onto it. Ignore VLC's own activation requests.
hl.window_rule({
    name  = "vlc-no-focus-steal",
    match = {
        class = "^(vlc|VLC)$"
    },
    suppress_event = "activate activatefocus"
})

-- Floating terminal for doas password prompts (Services System actions, Uninstall): kitty --class qs-dialog.
-- center is a boolean effect and size takes the table form {w, h} (Hyprland wiki, Window Rules > Effects); not seen running here
hl.window_rule({
    name  = "qs-dialog-terminal",
    match = {
        class = "^qs-dialog$"
    },
    float  = true,
    center = true,
    size   = { 960, 460 }
})

-- Quickshell's Task Manager (popups/TaskManager.qml, a FloatingWindow titled "Task Manager"): float,
-- centred, 760x560 by default and never smaller than 600x420 (MenuStyle.task* in quickshell);
-- persistent_size keeps the size you last gave it. Matched by its first title because the class
-- Quickshell gives its windows is not checked yet (probably org.quickshell). Field names from the
-- wiki (Window Rules > Effects); not seen running here
hl.window_rule({
    name  = "task-manager",
    match = {
        initial_title = "^Task Manager$"
    },
    float           = true,
    center          = true,
    size            = { 760, 560 },
    min_size        = { 600, 420 },
    persistent_size = true
})

-- Keys, Network, Services and Settings (quickshell/ToolWindows.qml): same rule as the task-manager above, one per title; not seen running here
hl.window_rule({
    name  = "keys-window",
    match = {
        initial_title = "^Keys$"
    },
    float           = true,
    center          = true,
    size            = { 760, 560 },
    min_size        = { 600, 420 },
    persistent_size = true
})

hl.window_rule({
    name  = "network-window",
    match = {
        initial_title = "^Network$"
    },
    float           = true,
    center          = true,
    size            = { 760, 560 },
    min_size        = { 600, 420 },
    persistent_size = true
})

hl.window_rule({
    name  = "services-window",
    match = {
        initial_title = "^Services$"
    },
    float           = true,
    center          = true,
    size            = { 760, 560 },
    min_size        = { 600, 420 },
    persistent_size = true
})

hl.window_rule({
    name  = "settings-window",
    match = {
        initial_title = "^Settings$"
    },
    float           = true,
    center          = true,
    size            = { 760, 560 },
    min_size        = { 600, 420 },
    persistent_size = true
})

-- Quickshell's Mini player (popups/MiniPlayer.qml, a FloatingWindow titled "Mini player"): float, pinned, bottom-LEFT
-- (the Lyrics window sits bottom-right); field names as in the lyrics rule, height measured by its test, never seen running
hl.window_rule({
    name  = "mini-player",
    match = {
        initial_title = "^Mini player$"
    },
    float = true,
    pin   = true,
    size  = { 320, 182 },
    move  = { "16", "monitor_h-window_h-48" }
})


-- Quickshell's Lyrics window (popups/LyricsWindow.qml, a FloatingWindow titled "Lyrics"): float, pinned (stays on
-- every workspace), bottom-right above the 32px bar. Size = MenuStyle.lyricsWindow*; field names as in the
-- task-manager rule above; `pin` and the `move` expressions are from the wiki, not seen running here
hl.window_rule({
    name  = "lyrics-window",
    match = {
        initial_title = "^Lyrics$"
    },
    float    = true,
    pin      = true,
    size     = { 420, 200 },
    min_size = { 280, 140 },
    move     = { "monitor_w-window_w-16", "monitor_h-window_h-48" }
})

-- HyprEmoji (SUPER + period): float near the cursor. Rule taken from the package's own
-- /usr/share/hypremoji/hypremoji.lua; without it the picker tiles and fills half the screen.
hl.window_rule({
    name  = "float-on-hypremoji",
    match = {
        title = "^(HyprEmoji)$"
    },
    float = true,
    move  = { "cursor_x-(window_w*0.5)", "cursor_y-(window_h*0.05)" }
})

-- Close HyprEmoji once it loses focus (follow_mouse = 1, so moving onto another window does it).
-- Only after it has had focus once, so it is not killed while it is still opening.
local emojiHadFocus = false
hl.on("window.active", function()
    local open, focused = false, false
    for _, w in ipairs(hl.get_windows()) do
        if w.title == "HyprEmoji" then
            open = true
            if w.active then
                focused = true
            end
        end
    end
    if focused then
        emojiHadFocus = true
    elseif open and emojiHadFocus then
        emojiHadFocus = false
        hl.dispatch(hl.dsp.exec_cmd("pkill -x hypremoji"))
    elseif not open then
        emojiHadFocus = false
    end
end)
