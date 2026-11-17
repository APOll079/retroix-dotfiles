---@module 'hl'
-- =========================
-- INPUTS: keyboard layout, pointer settings and mouse-button binds
-- =========================

hl.config({
    input = {
        kb_layout = "se",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = -0.5 -- -1.0 - 1.0, 0 means no modification.
    }
})

-- mainMod + LMB drags a window
hl.bind(mainMod .. " + " .. "mouse:272", hl.dsp.window.drag(), { mouse = true })  -- help: Mouse | Drag a window

-- Side buttons: drag (276) and fullscreen (275) with no modifier
local sideDragBind = hl.bind("mouse:276", hl.dsp.window.drag(), { mouse = true })  -- help: Mouse | Drag a window
local sideFullscreenBind = hl.bind("mouse:275", hl.dsp.window.fullscreen({ mode = 1 }))  -- help: Mouse | Maximise window

-- Game mode: SUPER + G. On: side-button binds off, animations off, and Quickshell (GameModeState.qml) does caffeine, DND, the
-- pause list and the GAME indicator. A Steam window (steam_app_<id>) switches it on by itself and off when the last one closes,
-- unless you toggled it by hand; autoSteam = false turns that off. A reload of this file always ends game mode (see the end).
-- hl.config() at runtime and the window.open / window.close handlers follow the API stubs, never seen running here.
local autoSteam = true
local gameMode = false
local autoOn = false          -- this game mode was switched on by a Steam window, so its last window closing may end it
local animationsWere = true   -- what animations.enabled was before game mode, put back on leaving

local function steamWindowsExcept(address)
    local n = 0
    for _, w in ipairs(hl.get_windows()) do
        if w.class and w.class:match("^steam_app_%d+$") and w.address ~= address then n = n + 1 end
    end
    return n
end

local function setGameMode(on, auto)
    if on == gameMode then return end
    gameMode = on
    autoOn = on and auto or false
    sideDragBind:set_enabled(not on)
    sideFullscreenBind:set_enabled(not on)
    if on then
        local was = hl.get_config("animations.enabled")
        if was ~= nil then animationsWere = was end
    end
    hl.config({ animations = { enabled = on and false or animationsWere } })
    hl.dispatch(hl.dsp.exec_cmd("qs ipc call gamemode set " .. (on and "true" or "false")))
end

hl.bind(mainMod .. " + G", function()  -- help: Desktop | Game mode
    setGameMode(not gameMode, false)
end)

if autoSteam then
    hl.on("window.open", function(window)
        if window and window.class and window.class:match("^steam_app_%d+$") and not gameMode then
            setGameMode(true, true)
        end
    end)
    hl.on("window.close", function(window)
        if autoOn and gameMode and steamWindowsExcept(window and window.address) == 0 then
            setGameMode(false, true)
        end
    end)
end

-- Loading (or reloading) this file starts with game mode off, so Quickshell must not keep thinking it is on.
hl.dispatch(hl.dsp.exec_cmd("qs ipc call gamemode set false"))
