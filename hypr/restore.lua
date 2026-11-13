---@module 'hl'
-- =========================
-- RESTORE WORKSPACES
-- =========================
-- Opens your usual programs on their workspaces, silently (the workspace you are looking at does not change), and skips a
-- program that is already running. Edit the table below; nothing else in this file needs changing.
--   workspace  the workspace number (or a name such as "special:foo")
--   cmd        the command, exactly as you would type it in a terminal
--   class      optional: the window class that tells "already running" (case-insensitive). Without it the first word of the
--              command is used, so "zen" matches a window of class "zen". If a program's class differs from its command
--              (check with `hyprctl clients`), write the class here.
-- Used from autostart.lua (once, a few seconds after login) and from the "restore now" key in binds.lua.
--
-- How it launches: hl.exec_cmd(cmd, { workspace = "<ws> silent" }). The second argument is the "exec rules" table of the Lua API
-- (hl.meta.lua: `exec_cmd fun(cmd: string, rules?: table<string, string|number|boolean>)`); the key and value follow the
-- window-rule effect `workspace = "special:spotifyspace silent"` used in windowrules.lua. GUESS, not seen running: that this
-- table takes the "workspace" key with the "silent" suffix. If a program lands on the wrong workspace, the fallback is a window
-- rule per program (hl.window_rule with match = { class = ... } and workspace = "<n> silent") in windowrules.lua.
local M = {}

M.restore = {
    { workspace = 1, cmd = "zen", class = "zen" },
    { workspace = 3, cmd = "vscodium", class = "VSCodium" },
}

-- The class used to tell that an entry is already running
function M.classOf(entry)
    if type(entry.class) == "string" and entry.class ~= "" then
        return entry.class:lower()
    end
    local first = tostring(entry.cmd or ""):match("^%s*(%S+)") or ""
    return (first:match("([^/]+)$") or first):lower()
end

-- True for an entry that has a workspace and a command
function M.valid(entry)
    return type(entry) == "table"
        and (type(entry.workspace) == "number" or (type(entry.workspace) == "string" and entry.workspace ~= ""))
        and type(entry.cmd) == "string" and entry.cmd:match("%S") ~= nil
end

-- The entries that still need starting, given the windows that exist ({ class = "..." } each): pure, no Hyprland calls.
-- An entry is skipped when a window of its class exists; the same class listed twice is started once.
function M.pending(entries, windows)
    local running = {}
    for _, w in ipairs(windows or {}) do
        if type(w) == "table" and type(w.class) == "string" then
            running[w.class:lower()] = true
        end
    end
    local out = {}
    for _, e in ipairs(entries or {}) do
        if M.valid(e) then
            local c = M.classOf(e)
            if not running[c] then
                running[c] = true
                out[#out + 1] = e
            end
        end
    end
    return out
end

-- Starts what is missing; returns how many programs were started
function M.run()
    local todo = M.pending(M.restore, hl.get_windows())
    for _, e in ipairs(todo) do
        hl.exec_cmd(e.cmd, { workspace = tostring(e.workspace) .. " silent" })
    end
    return #todo
end

return M
