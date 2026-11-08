--[[---------------------------------------------------------------------------
    Slash.lua - Chatbefehle und Berichte

      /eg                 Vergleichsfenster
      /eg <Link|ID>       Bericht im Chat und im Fenster
      /eg upgrades        alle Verbesserungen in den Taschen
      /eggui              Vergleichsfenster
      /egprofile          Profilvergleich
      /eg help            alle Befehle

    Die Befehle sind in jeder Sprache gleich; nur die Beschreibungen kommen aus den Sprachdateien.
-----------------------------------------------------------------------------]]

local _, EG = ...
local Slash = {}
EG.Slash = Slash

local L, C = EG.L, EG.COLOR
local Items, Score, Profiles, Recommend, Stats = EG.Items, EG.Score, EG.Profiles, EG.Recommend, EG.Stats

local ipairs, pairs, type, tonumber, tostring, pcall = ipairs, pairs, type, tonumber, tostring, pcall
local sformat, slower, supper, smatch, sgsub = string.format, string.lower, string.upper, string.match, string.gsub
local tsort, tconcat = table.sort, table.concat

local LINE = C.grey .. "----------------------------------------" .. C.reset
local MAX_LIST = 25

local function OnOff(v) return v and L.SET_ON or L.SET_OFF end
Slash.OnOff = OnOff

-- "on" / "off" / leer (= umschalten) -> neuer Wert
local function ParseSwitch(arg, current)
    arg = slower(arg or "")
    if arg == "on" or arg == "1" or arg == "an" then return true end
    if arg == "off" or arg == "0" or arg == "aus" then return false end
    return not current
end
Slash.ParseSwitch = ParseSwitch

local function ParseNumber(text)
    if type(text) ~= "string" or text == "" then return nil end
    return tonumber((sgsub(text, ",", ".")))
end

-- Der erste Gegenstandslink einer Eingabe (mit Farbcode, wenn vorhanden) oder nil
local function ExtractLink(text)
    if type(text) ~= "string" then return nil end
    return smatch(text, "(|c%x+|Hitem:.-|h%[.-%]|h|r)") or smatch(text, "(|Hitem:.-|h%[.-%]|h)")
end

------------------------------------------------------------------------------
-- 01  Berichte
------------------------------------------------------------------------------

local function FmtRow(row)
    local v = tonumber(row.value) or 0
    local num = (v % 1 ~= 0) and sformat("%.1f", v) or sformat("%d", v)
    return sformat("  %-24s %8s  x %-6s = %s%s%s",
        tostring(row.label), num, EG.FmtWeight(row.weight), C.value, EG.FmtScore(row.points), C.reset)
end

function Slash.PrintBreakdown(rows, total)
    if not rows or #rows == 0 then
        EG:Raw("  " .. C.grey .. "-" .. C.reset)
        return
    end
    EG:Raw(sformat("  %-24s %8s  %-8s   %s", L.STAT, L.VALUE, L.WEIGHT, L.POINTS))
    for _, row in ipairs(rows) do EG:Raw(FmtRow(row)) end
    EG:Raw(sformat("  %-24s %8s  %-8s   %s%s%s", L.TOTAL, "", "", C.good, EG.FmtScore(total), C.reset))
end

function Slash.PrintReport(link)
    local result, why = Score.Compare(link, true)
    if not result then
        if why == "loading" then
            EG:Print(L.ITEM_LOADING)
        else
            EG:Print(C.bad .. L.INVALID_ITEM .. C.reset)
        end
        return false
    end

    local item = result.item
    EG:Raw(C.title .. "===== EasyGear =====" .. C.reset)
    EG:Raw(L.CANDIDATE .. ": " .. (item.link or tostring(link)))
    EG:Raw(sformat("%s: %s%s%s   %s: %s%s%s   %s: %s%s%s",
        L.ILVL, C.value, tostring(item.ilvl), C.reset,
        L.SLOT, C.value, tostring(result.slotName), C.reset,
        L.PROFILE, C.value, tostring(Profiles.Resolve().name), C.reset))
    if item.itemType or item.itemSubType then
        EG:Raw(sformat("%s: %s  |  %s: %s", L.TYPE, tostring(item.itemType or "-"),
            L.SUBTYPE, tostring(item.itemSubType or "-")))
    end
    if (item.reqLevel or 0) > 0 then
        EG:Raw(L.REQLEVEL .. ": " .. C.value .. item.reqLevel .. C.reset)
    end
    if item.hasExtraStats then
        EG:Raw(C.good .. L.HAS_EXTRAS .. C.reset)
    end
    if (item.sellPrice or 0) > 0 and C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        local ok, text = pcall(C_CurrencyInfo.GetCoinTextureString, item.sellPrice)
        if ok and text then EG:Raw(L.SELLPRICE .. ": " .. text) end
    end

    EG:Raw(LINE)
    EG:Raw(C.title .. L.CANDIDATE .. " - " .. L.POINTS .. C.reset)
    Slash.PrintBreakdown(result.breakdown, result.score)

    if result.noCompare then
        if result.note then EG:Raw(C.grey .. result.note .. C.reset) end
        EG:Raw(C.title .. "====================" .. C.reset)
        return true
    end

    EG:Raw(LINE)
    EG:Raw(C.title .. L.EQUIPPED .. C.reset)
    if not result.equipped or #result.equipped == 0 then
        EG:Raw("  " .. C.warn .. L.NOTHING_EQUIPPED .. C.reset)
    else
        for _, e in ipairs(result.equipped) do
            local name = Score.SlotName(e.slotID)
            local mark = (e == result.target) and (C.good .. "> " .. C.reset) or ""
            if e.empty then
                EG:Raw(sformat("%s%s: %s%s%s", mark, name, C.warn, L.NOTHING_EQUIPPED, C.reset))
            else
                EG:Raw(sformat("%s%s: %s", mark, name, e.link or e.item.link))
                Slash.PrintBreakdown(e.breakdown, e.score)
            end
        end
    end

    EG:Raw(LINE)
    if not result.usable then
        EG:Raw(C.bad .. L.NOT_USABLE .. C.reset .. " " .. tostring(result.reason or ""))
    else
        local delta = result.delta or 0
        local col = result.isUpgrade and C.good or (delta > 0 and C.warn or C.bad)
        local pct = result.percent and ("  (" .. EG.FmtPct(result.percent) .. ")") or ""
        EG:Raw(sformat("%s: %s%s%s%s   %s -> %s", L.DIFFERENCE, col, EG.FmtSigned(delta), pct, C.reset,
            EG.FmtScore(result.targetScore), EG.FmtScore(result.score)))
        if result.isUpgrade then
            EG:Raw(C.good .. ">> " .. L.UPGRADE .. C.reset .. (result.reason and (" " .. result.reason) or ""))
        elseif result.levelTooLow and result.wouldUpgrade then
            EG:Raw(C.warn .. ">> " .. sformat(L.UPGRADE_AT_LEVEL, item.reqLevel or 0) .. C.reset)
        else
            EG:Raw(C.bad .. ">> " .. L.NO_UPGRADE .. C.reset .. " " .. tostring(result.reason or ""))
        end
    end
    if result.note then EG:Raw(C.grey .. result.note .. C.reset) end
    EG:Raw(C.title .. "====================" .. C.reset)
    return true
end

-- Was der Parser aus einem Gegenstand gelesen hat (zur Fehlersuche, wenn eine Wertung seltsam wirkt)
function Slash.PrintParse(link)
    local item, why = Items.Get(link)
    if not item then
        EG:Print(why == "loading" and L.ITEM_LOADING or (C.bad .. L.INVALID_ITEM .. C.reset))
        return false
    end
    EG:Raw(C.title .. "EasyGear - " .. L.PARSE_HEAD .. C.reset)
    EG:Raw(sformat("%s  equipLoc=%s  ilvl=%s  reqLevel=%s  quality=%s  gear=%s",
        tostring(item.link), tostring(item.equipLoc), tostring(item.ilvl), tostring(item.reqLevel),
        tostring(item.quality), tostring(item.isGear)))
    if not item.isGear then return true end
    EG:Raw(sformat("usable=%s  reason=%s  unique=%s  sockets=%s  dps=%s  hand=%s",
        tostring(item.usable), tostring(item.reason), tostring(item.unique), tostring(item.sockets),
        tostring(item.dps), tostring(item.handKind)))

    local function Dump(label, tbl)
        local keys = {}
        for k in pairs(tbl or {}) do keys[#keys + 1] = k end
        tsort(keys)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. EG.FmtScore(tbl[k]) end
        EG:Raw(label .. ": " .. (#parts > 0 and tconcat(parts, " ") or "-"))
    end
    Dump("base", item.baseStats)
    Dump("total", item.stats)
    Dump("extras", item.extraStats)
    Dump("unknown", item.unknown)
    return true
end

function Slash.PrintUpgrades()
    local list, pending = Recommend.Upgrades(true)
    if #list == 0 then
        EG:Print(L.UPGRADES_NONE)
        if pending then EG:Print(L.ITEM_LOADING) end
        return
    end
    EG:Raw(C.title .. L.UPGRADES_HEAD .. C.reset)
    for i, u in ipairs(list) do
        if i > MAX_LIST then
            EG:Raw(C.grey .. sformat("... +%d", #list - MAX_LIST) .. C.reset)
            break
        end
        local r = u.result
        local slotName = r.combined and r.slotName or Score.SlotName(u.slotID or (r.target and r.target.slotID))
        local gain = EG.FmtSigned(u.delta or 0)
        if r.target and r.target.empty then
            gain = L.NOTHING_EQUIPPED
        elseif u.percent then
            gain = gain .. "  (" .. EG.FmtPct(u.percent) .. ")"
        end
        EG:Raw(sformat("  %s  %s%s%s  %s%s%s", u.link, C.grey, tostring(slotName), C.reset, C.good, gain, C.reset))
    end
    if pending then EG:Print(L.ITEM_LOADING) end
end

function Slash.PrintProfileList()
    local activeID = Profiles.ActiveID()
    local active = Profiles.ActiveSpec()

    EG:Raw(C.title .. L.PROFILE_LIST .. C.reset)
    EG:Raw(sformat("  %s%-18s%s %s", C.value, "AUTO", C.reset, L.PROFILE_AUTO_HINT))
    for _, spec in ipairs(Profiles.List()) do
        local mark = "  "
        if activeID == spec.id or (activeID == "AUTO" and active and active.id == spec.id) then
            mark = C.good .. ">>" .. C.reset
        end
        local tag = spec.custom and (C.warn .. "*" .. C.reset) or " "
        EG:Raw(sformat("%s%s %s%-18s%s %s", mark, tag, C.value, spec.id, C.reset, Profiles.Name(spec)))
    end
    EG:Raw(C.grey .. L.PROFILE_CMD_HINT .. C.reset)
end

local function SocketText()
    local v = tonumber(EG:Get("socketValue"))
    if v then return tostring(v) end
    return L.ROLE_AUTO .. " " .. EG.FmtScore(Score.SocketPoints())
end

function Slash.PrintStatus()
    local profile = Profiles.Resolve()
    EG:Raw(C.title .. "EasyGear " .. tostring(EG.version) .. C.reset
        .. (EG.isForever and "" or ("  " .. C.warn .. L.NOT_FOREVER .. C.reset)))
    if type(GetBuildInfo) == "function" then
        local version, build, _, toc = GetBuildInfo()
        EG:Raw(sformat("%s: %s (%s)  interface %s", L.ST_CLIENT, tostring(version), tostring(build), tostring(toc)))
    end
    EG:Raw(L.PROFILE .. ": " .. C.value .. tostring(profile.name) .. C.reset .. "  [" .. tostring(Profiles.ActiveID()) .. "]")
    local t = Profiles.Talents()
    if t then
        EG:Raw(sformat("%s: %s  (%s)", L.ST_TALENTS, tconcat(t.points, " / "), tostring(t.source)))
    else
        EG:Raw(L.ST_TALENTS .. ": " .. C.warn .. L.ST_TALENTS_NONE .. C.reset)
    end
    EG:Raw(L.ST_AUTOLEVEL .. ": " .. OnOff(EG:Get("autoLeveling")))
    local eff, base, factor = Score.EffectiveIlvlWeight()
    EG:Raw(sformat(L.SET_ILVL, EG.FmtWeight(base) .. " -> " .. EG.FmtWeight(eff)))
    EG:Raw(sformat(L.SET_ILVLSCALE, OnOff(EG:Get("ilvlScaling") ~= false), EG.FmtWeight(factor)))
    EG:Raw(sformat(L.SET_MINDELTA, EG.FmtScore(EG:Get("minDelta") or 0), tostring(EG:Get("minDeltaPercent") or 0)))
    EG:Raw(L.ST_ENCHANTS .. ": " .. OnOff(EG:Get("includeEnchants") ~= false) .. " | " .. L.SOCKETS .. ": " .. SocketText())
    EG:Raw(L.OPT_BAGS .. ": " .. OnOff(EG:Get("showBagIcons"))
        .. " | " .. L.OPT_QUESTREWARD .. ": " .. OnOff(EG:Get("showQuestIcons"))
        .. " | " .. L.OPT_ITEMS .. ": " .. OnOff(EG:Get("showItemIcons"))
        .. " | " .. L.OPT_CHARHINT .. ": " .. OnOff(EG:Get("showCharIcons")))
    EG:Raw(L.OPT_TOOLTIP .. ": " .. OnOff(EG:Get("showTooltip"))
        .. " | " .. L.OPT_DIFF .. ": " .. OnOff(EG:Get("tooltipDiff")))

    local names = {}
    for name in pairs(EG.hookStatus) do names[#names + 1] = name end
    tsort(names)
    local parts = {}
    for _, name in ipairs(names) do
        local s = EG.hookStatus[name]
        parts[#parts + 1] = s.ok and (C.good .. name .. C.reset)
            or (C.bad .. name .. C.reset .. (s.note and (" (" .. s.note .. ")") or ""))
    end
    EG:Raw(L.ST_HOOKS .. ": " .. (#parts > 0 and tconcat(parts, ", ") or "-"))
    if EG.lastError then
        EG:Raw(C.bad .. L.ST_LASTERROR .. ": [" .. tostring(EG.lastError.label) .. "] " .. tostring(EG.lastError.err) .. C.reset)
    end
end

function Slash.PrintLocale()
    local loc = EG.locale or {}
    EG:Raw(C.title .. "EasyGear - " .. L.LOCALE_HEAD .. C.reset)
    EG:Raw(L.LOCALE_CLIENT .. ": " .. C.value .. tostring(loc.client) .. C.reset
        .. "  ->  " .. L.LOCALE_FILE .. ": " .. C.value .. tostring(loc.active) .. ".lua" .. C.reset
        .. (loc.translated and "" or ("  " .. C.warn .. "(" .. L.LOCALE_FALLBACK .. ")" .. C.reset)))
    EG:Raw(L.LOCALE_LOADED .. ": " .. tconcat(loc.loaded or {}, ", "))
    if not loc.baseOK then EG:Raw(C.bad .. L.LOCALE_BROKEN .. C.reset) end

    local base = _G.EasyGearLocales and _G.EasyGearLocales["enUS"]
    local cur = _G.EasyGearLocales and _G.EasyGearLocales[loc.active or "enUS"]
    if base and cur then
        local total, have = 0, 0
        for k in pairs(base) do
            total = total + 1
            if cur[k] ~= nil then have = have + 1 end
        end
        EG:Raw(sformat(L.LOCALE_COVERAGE, have, total))
    end
end

-- ITEM_MOD-Werte, die das Addon nicht kennt: in Ausruestung und Taschen
function Slash.PrintUnknown()
    local seen, items = {}, 0
    local function Scan(link)
        local item = link and Items.Get(link)
        if item and item.isGear then
            items = items + 1
            for name in pairs(item.unknown or {}) do seen[name] = (seen[name] or 0) + 1 end
        end
    end
    for slot = 1, 19 do Scan(Items.EquippedLink(slot)) end
    for _, bag in ipairs(Recommend.ContainerIDs(true)) do
        local n = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, n do
            local ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
            if ok then Scan(link) end
        end
    end

    local names = {}
    for name in pairs(seen) do names[#names + 1] = name end
    tsort(names)
    EG:Raw(C.title .. "EasyGear - " .. L.UNKNOWN_HEAD .. C.reset .. "  (" .. sformat(L.P_ITEMS, items) .. ")")
    if #names == 0 then
        EG:Raw(L.UNKNOWN_NONE)
        return
    end
    for _, name in ipairs(names) do
        EG:Raw(sformat("  %s%s%s  x%d", C.value, name, C.reset, seen[name]))
    end
    EG:Raw(C.grey .. L.UNKNOWN_HINT .. C.reset)
end

------------------------------------------------------------------------------
-- 02  Hilfe
------------------------------------------------------------------------------

-- Befehl, Beschreibungsschluessel (Befehle sind in jeder Sprache gleich)
local HELP = {
    { "/eg",                                  "H_EG" },
    { "/eg <itemlink | itemID>",              "H_EG_LINK" },
    { "/eg upgrades",                         "H_UPGRADES" },
    { "/eggui",                               "H_GUI" },
    { "/egprofile",                           "H_PROFILE_WIN" },
    { "/eg profile list",                     "H_PROFILE_LIST" },
    { "/eg profile <id | auto>",              "H_PROFILE_SET" },
    { "/eg weight <stat> <value>",            "H_WEIGHT" },
    { "/eg autolevel [on|off]",               "H_AUTOLEVEL" },
    { "/eg enchants [on|off]",                "H_ENCHANTS" },
    { "/eg socket <number | auto>",           "H_SOCKET" },
    { "/eg ilvl <number>",                    "H_ILVL" },
    { "/eg ilvlscale [on|off]",               "H_ILVLSCALE" },
    { "/eg mindelta <number>",                "H_MINDELTA" },
    { "/eg mindeltapct <percent>",            "H_MINDELTAPCT" },
    { "/eg icons | items | quest | char | tooltip | diff", "H_TOGGLES" },
    { "/eg options",                          "H_OPTIONS" },
    { "/eg scale <0.5-2.0>",                  "H_SCALE" },
    { "/eg status",                           "H_STATUS" },
    { "/eg parse <itemlink>",                 "H_PARSE" },
    { "/eg unknown",                          "H_UNKNOWN" },
    { "/eg locale",                           "H_LOCALE" },
    { "/eg reset",                            "H_RESET" },
}

function Slash.PrintHelp()
    EG:Raw(C.title .. "EasyGear " .. tostring(EG.version) .. C.reset)
    for _, h in ipairs(HELP) do
        EG:Raw(C.value .. h[1] .. C.reset .. "  " .. C.grey .. L[h[2]] .. C.reset)
    end
end

------------------------------------------------------------------------------
-- 03  Befehle
------------------------------------------------------------------------------

-- Umschalter: Befehl -> { Einstellung, Beschriftung }
local TOGGLES = {
    icons   = { "showBagIcons",     "OPT_BAGS" },
    items   = { "showItemIcons",    "OPT_ITEMS" },
    quest   = { "showQuestIcons",   "OPT_QUESTREWARD" },
    char    = { "showCharIcons",    "OPT_CHARHINT" },
    tooltip = { "showTooltip",      "OPT_TOOLTIP" },
    stats   = { "showTooltipStats", "OPT_TOOLTIP_STATS" },
    diff    = { "tooltipDiff",      "OPT_DIFF" },
    debug   = { "debug",            "ST_DEBUG" },
}

local function Toggle(cmd, rest)
    local def = TOGGLES[cmd]
    local value = ParseSwitch(rest, EG:Get(def[1]))
    EG:Set(def[1], value)
    EG:Print(L[def[2]] .. ": " .. OnOff(value))
end

local function ShowProfile(spec)
    EG:Print(sformat(L.SET_PROFILE, Profiles.Name(spec)))
end

local function ProfileCommand(rest)
    local arg = EG.Trim(rest)
    local low = slower(arg)
    if arg == "" or low == "list" then
        Slash.PrintProfileList()
    elseif low == "gui" or low == "window" then
        EG.ProfileWindow.Toggle()
    elseif low == "auto" then
        Profiles.SetActive("AUTO")
        EG:Print(sformat(L.SET_PROFILE, Profiles.Resolve().name))
    else
        -- IDs der eingebauten Profile sind gross geschrieben, eigene Profile koennen gemischt sein
        local spec = Profiles.Get(arg) or Profiles.Get(supper(arg))
        if spec then
            Profiles.SetActive(spec.id)
            ShowProfile(spec)
        else
            EG:Print(C.bad .. sformat(L.PROFILE_UNKNOWN, arg) .. C.reset)
            Slash.PrintProfileList()
        end
    end
end

local function WeightCommand(rest)
    local key, value = smatch(rest or "", "^(%S+)%s+(%S+)$")
    local spec = Profiles.ActiveSpec()
    if not key then
        EG:Print(L.WEIGHT_USAGE)
        return
    end
    if not (spec and spec.custom) then
        EG:Print(C.warn .. L.WEIGHT_NEED_CUSTOM .. C.reset)
        return
    end
    -- Kurzschluessel gross, rohe ITEM_MOD-Namen unveraendert
    local k = supper(key)
    if not (Stats.IsKnownKey(k) or k == key) then k = key end
    local v = ParseNumber(value)
    if not v then
        EG:Print(L.WEIGHT_USAGE)
        return
    end
    Profiles.SetCustomWeight(spec.id, k, v)
    EG:Print(sformat("%s: %s = %s", Profiles.Name(spec), k, EG.FmtWeight(v)))
end

local function ShowIlvl()
    local eff, base = Score.EffectiveIlvlWeight()
    EG:Print(sformat(L.SET_ILVL, EG.FmtWeight(base) .. " -> " .. EG.FmtWeight(eff)))
end

local function ShowMinDelta()
    EG:Print(sformat(L.SET_MINDELTA, EG.FmtScore(EG:Get("minDelta") or 0), tostring(EG:Get("minDeltaPercent") or 0)))
end

local function Reset()
    EG:ResetDB()
    EG:Print(L.SET_RESET)
end

local function ReportFor(link)
    if EG.Window then EG.Window.SetItem(link) end
    return Slash.PrintReport(link)
end

function Slash.Handle(msg)
    msg = msg or ""

    local cmd, rest = smatch(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = slower(cmd or "")

    if cmd == "" or cmd == "gui" then
        EG.Window.Toggle()
    elseif cmd == "help" or cmd == "?" then
        Slash.PrintHelp()
    elseif cmd == "status" then
        Slash.PrintStatus()
    elseif cmd == "locale" or cmd == "lang" then
        Slash.PrintLocale()
    elseif cmd == "upgrades" or cmd == "upgrade" or cmd == "bags" then
        Slash.PrintUpgrades()
    elseif cmd == "profile" or cmd == "profiles" then
        ProfileCommand(rest)
    elseif cmd == "weight" then
        WeightCommand(rest)
    elseif cmd == "parse" then
        local link = ExtractLink(rest) or tonumber(rest)
        if link then Slash.PrintParse(link) else EG:Print(L.PARSE_USAGE) end
    elseif cmd == "unknown" then
        Slash.PrintUnknown()
    elseif cmd == "autolevel" then
        local v = ParseSwitch(rest, EG:Get("autoLeveling"))
        EG:Set("autoLeveling", v)
        EG:Print(L.ST_AUTOLEVEL .. ": " .. OnOff(v))
    elseif cmd == "enchants" then
        local v = ParseSwitch(rest, EG:Get("includeEnchants") ~= false)
        EG:Set("includeEnchants", v)
        EG:Print(L.ST_ENCHANTS .. ": " .. OnOff(v))
    elseif cmd == "socket" then
        if slower(rest) == "auto" then
            EG:Set("socketValue", nil)
        elseif ParseNumber(rest) then
            EG:Set("socketValue", ParseNumber(rest))
        end
        EG:Print(L.SOCKETS .. ": " .. SocketText())
    elseif cmd == "ilvl" then
        local v = ParseNumber(rest)
        if v and v >= 0 then EG:Set("ilvlWeight", v) end
        ShowIlvl()
    elseif cmd == "ilvlscale" then
        local v = ParseSwitch(rest, EG:Get("ilvlScaling") ~= false)
        EG:Set("ilvlScaling", v)
        local eff, _, factor = Score.EffectiveIlvlWeight()
        EG:Print(sformat(L.SET_ILVLSCALE, OnOff(v), EG.FmtWeight(factor)) .. "  ->  " .. EG.FmtWeight(eff))
    elseif cmd == "mindelta" then
        local v = ParseNumber(rest)
        if v and v >= 0 then EG:Set("minDelta", v) end
        ShowMinDelta()
    elseif cmd == "mindeltapct" then
        local v = ParseNumber(rest)
        if v and v >= 0 then EG:Set("minDeltaPercent", v) end
        ShowMinDelta()
    elseif TOGGLES[cmd] then
        Toggle(cmd, rest)
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        EG.Options.Open()
    elseif cmd == "scale" then
        local v = ParseNumber(rest)
        if v and v >= 0.5 and v <= 2.0 then
            EG.cdb.gui.scale = v
            EG:Fire("GUI_SCALE")
        end
        EG:Print(sformat(L.SET_SCALE, tostring(EG.cdb.gui.scale)))
    elseif cmd == "reset" then
        Reset()
    else
        -- kein Befehl: ein Gegenstandslink irgendwo in der Eingabe (der Link selbst enthaelt Leerzeichen und
        -- beginnt mit einem Farbcode, ist also nie ein Befehl) oder eine Gegenstands-ID
        local link = ExtractLink(msg)
        local id = tonumber(cmd) or tonumber(rest)
        if link then
            ReportFor(link)
        elseif id then
            ReportFor(id)
        else
            Slash.PrintHelp()
        end
    end
end

_G.SLASH_EASYGEAR1 = "/eg"
_G.SLASH_EASYGEAR2 = "/easygear"
SlashCmdList["EASYGEAR"] = function(msg) EG:Try("slash", Slash.Handle, msg) end

_G.SLASH_EASYGEARGUI1 = "/eggui"
SlashCmdList["EASYGEARGUI"] = function() EG:Try("slash", EG.Window.Toggle) end

_G.SLASH_EASYGEARPROFILE1 = "/egprofile"
_G.SLASH_EASYGEARPROFILE2 = "/egprofil"
SlashCmdList["EASYGEARPROFILE"] = function() EG:Try("slash", EG.ProfileWindow.Toggle) end
