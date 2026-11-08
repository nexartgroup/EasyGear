-- luacheck configuration for EasyGear (WoW Forever edition).
-- tools/check.sh builds .cache/forever_std.lua from the Forever UI source first; without it only
-- the plain Lua 5.1 checks apply.
local ok, forever = pcall(dofile, ".cache/forever_std.lua")
if ok and type(forever) == "table" then
    stds.forever = forever
    std = "lua51+forever"
else
    std = "lua51"
end

max_line_length = false
exclude_files = { ".cache", "tests" }
ignore = {
    "212/self",     -- methods that do not use self
    "212/_.*",      -- arguments named _...
    "213/_.*",      -- loop variables named _...
}

-- Globals the addon defines itself
globals = {
    "EasyGear", "EasyGearDB", "EasyGearCharDB", "EasyGearLocales",
    "SLASH_EASYGEAR1", "SLASH_EASYGEAR2", "SLASH_EASYGEARGUI1",
    "SLASH_EASYGEARPROFILE1", "SLASH_EASYGEARPROFILE2",
    "EasyGear_OnAddonCompartmentClick", "EasyGear_OnAddonCompartmentEnter", "EasyGear_OnAddonCompartmentLeave",
    SlashCmdList = { other_fields = true },
}
