---@module 'hl'
-- =========================
-- ENVIRONMENT
-- =========================

-- The cursor: the one picked in the Themes menu (quickshell/scripts/appearance.sh set-cursor writes "<name> <size>" to
-- $XDG_STATE_HOME/qs-cursor, default ~/.local/state/qs-cursor), else posy-black at 24. Hyprland reads the cursor from its
-- environment at start, so this is what makes the pick survive a restart. The name is checked, a bad file means the default.
local function savedCursor()
    local base = os.getenv("XDG_STATE_HOME")
    if not base or base == "" then
        base = (os.getenv("HOME") or "") .. "/.local/state"
    end
    local f = io.open(base .. "/qs-cursor", "r")
    if f then
        local line = f:read("*l") or ""
        f:close()
        local name, size = line:match("^([%w][%w%._-]*)%s+(%d+)$")
        if name and tonumber(size) >= 8 and tonumber(size) <= 256 then
            return name, size
        end
    end
    return "posy-black", "24"
end
local cursorName, cursorSize = savedCursor()

hl.env("XCURSOR_SIZE", cursorSize)
hl.env("HYPRCURSOR_SIZE", cursorSize)
hl.env("XCURSOR_THEME", cursorName)
hl.env("HYPRCURSOR_THEME", cursorName)
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
