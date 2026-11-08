-- Unit tests for EasyGear (WoW Forever edition). Run from the forever/ folder:
--
--     lua5.1 tests/run.lua [pattern]
--
-- Needs only Lua 5.1. The client is modelled by tests/wow_mock.lua.
package.path = "tests/?.lua;" .. package.path

local Mock = require("wow_mock")

local T = { passed = 0, failed = 0, failures = {}, current = nil }
local filter = arg and arg[1]

local function fmt(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

function T.fail(msg)
    error({ assertion = msg }, 3)
end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        T.fail((msg and (msg .. ": ") or "") .. "expected " .. fmt(expected) .. ", got " .. fmt(actual))
    end
end
function T.near(actual, expected, eps, msg)
    eps = eps or 1e-6
    if type(actual) ~= "number" or math.abs(actual - expected) > eps then
        T.fail((msg and (msg .. ": ") or "") .. "expected " .. fmt(expected) .. " (+/-" .. eps .. "), got " .. fmt(actual))
    end
end
function T.ok(v, msg) if not v then T.fail(msg or "expected a true value, got " .. fmt(v)) end end
function T.no(v, msg) if v then T.fail(msg or "expected a false value, got " .. fmt(v)) end end
function T.has(s, sub, msg)
    if type(s) ~= "string" or not s:find(sub, 1, true) then
        T.fail((msg and (msg .. ": ") or "") .. "expected text to contain " .. fmt(sub) .. ", got " .. fmt(s))
    end
end
function T.hasnt(s, sub, msg)
    if type(s) == "string" and s:find(sub, 1, true) then
        T.fail((msg and (msg .. ": ") or "") .. "expected text NOT to contain " .. fmt(sub) .. ", got " .. fmt(s))
    end
end
function T.errors(fn, sub)
    local ok, err = pcall(fn)
    if ok then T.fail("expected an error") end
    if sub and not tostring(err):find(sub, 1, true) then T.fail("error does not mention " .. fmt(sub) .. ": " .. tostring(err)) end
end

T.Mock = Mock
-- the addon folder under test (tests/mutate.py points this at a modified copy)
T.dir = os.getenv("EASYGEAR_DIR") or "EasyGear"

function T.test(name, fn)
    if filter and not name:find(filter, 1, true) then return end
    T.current = name
    local ok, err = xpcall(fn, function(e)
        if type(e) == "table" and e.assertion then return e end
        return { crash = tostring(e), trace = debug.traceback("", 2) }
    end)
    if ok then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        local line = err.assertion or ("ERROR " .. err.crash)
        T.failures[#T.failures + 1] = { name = name, msg = line, trace = err.trace }
    end
end

-- A fresh client with the addon loaded and booted. opts go to Mock.new; setup(W) runs before boot.
function T.world(opts, setup)
    local W = Mock.new(opts)
    W.load(T.dir)
    if setup then setup(W) end
    W.boot()
    return W
end

local files = {
    "t_load", "t_stats", "t_items", "t_specs", "t_profiles", "t_score", "t_recommend", "t_tooltip", "t_marks",
    "t_windows", "t_options", "t_slash", "t_locales", "t_robust", "t_fuzz",
}
for _, f in ipairs(files) do
    local path = "tests/" .. f .. ".lua"
    local fh = io.open(path, "r")
    if fh then
        fh:close()
        local chunk = assert(loadfile(path))
        chunk()(T)
    end
end

for _, f in ipairs(T.failures) do
    io.write("FAIL  ", f.name, "\n      ", f.msg, "\n")
    if f.trace and os.getenv("TRACE") then io.write(f.trace, "\n") end
end
io.write(string.format("%d passed, %d failed\n", T.passed, T.failed))
os.exit(T.failed == 0 and 0 or 1)
