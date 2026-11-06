-- Unit test for hypr/restore.lua with a stub `hl` table (no Hyprland needed).
--   lua tests/restore-test.lua      (or luajit; prints TEST pass|FAIL lines and "TEST done failures=N", exit 1 on a failure)
-- Run it from the repo root. Without lua or luajit installed there is nothing to run: skip it ("lua not installed").
local here = arg and arg[0] and arg[0]:match("^(.*)/tests/[^/]*$") or "."
package.path = here .. "/hypr/?.lua;" .. package.path

local failures = 0
local function check(name, cond)
    print("TEST " .. (cond and "pass " or "FAIL ") .. name)
    if not cond then failures = failures + 1 end
end

-- the stub: a window list and a log of exec calls
local windows, calls = {}, {}
hl = {
    get_windows = function() return windows end,
    exec_cmd = function(cmd, rules) calls[#calls + 1] = { cmd = cmd, rules = rules } end,
}

local M = require("restore")
check("the module returns its table with a restore list and run()", type(M) == "table" and type(M.restore) == "table" and type(M.run) == "function")
check("default entries: Zen on 1, VSCodium on 3", M.restore[1].workspace == 1 and M.restore[1].cmd == "zen" and M.restore[2].workspace == 3 and M.restore[2].cmd == "vscodium")

-- nothing running: both start, silently, on their workspaces
windows, calls = {}, {}
check("run() returns how many it started", M.run() == 2)
check("each command is started with its workspace and silent",
    #calls == 2 and calls[1].cmd == "zen" and calls[1].rules.workspace == "1 silent" and calls[2].cmd == "vscodium" and calls[2].rules.workspace == "3 silent")

-- Zen already open: only VSCodium starts (class match is case-insensitive)
windows, calls = { { class = "Zen" }, { class = "kitty" } }, {}
check("a running program is skipped", M.run() == 1 and #calls == 1 and calls[1].cmd == "vscodium")

-- both open: nothing starts
windows, calls = { { class = "zen" }, { class = "vscodium" } }, {}
check("nothing to do when both run", M.run() == 0 and #calls == 0)

-- an owner-edited table
M.restore = {
    { workspace = 2, cmd = "/usr/bin/foot --title x" },
    { workspace = "special:notes", cmd = "kitty --class notes", class = "notes" },
    { workspace = 4, cmd = "" },
    { cmd = "nope" },
    { workspace = 5, cmd = "foot" },
}
windows, calls = {}, {}
check("classOf: first word, basename, lower case; or the given class", M.classOf(M.restore[1]) == "foot" and M.classOf(M.restore[2]) == "notes")
M.run()
check("invalid entries are ignored and a repeated class starts once",
    #calls == 2 and calls[1].cmd == "/usr/bin/foot --title x" and calls[1].rules.workspace == "2 silent" and calls[2].cmd == "kitty --class notes" and calls[2].rules.workspace == "special:notes silent")

-- pending() is pure
check("pending(): does not touch Hyprland and survives junk", #M.pending(nil, nil) == 0 and #M.pending({ 5, "x" }, { 7 }) == 0)

print("TEST done failures=" .. failures)
os.exit(failures == 0 and 0 or 1)
