--[[---------------------------------------------------------------------------
    Stats.lua - Werte eines Gegenstands lesen

    Zwei Quellen, die zusammengefuehrt werden:

      1. C_Item.GetItemStats(link): die Basiswerte, sprachunabhaengig (ITEM_MOD_*-Schluessel).
      2. Die Tooltip-Daten (C_TooltipInfo.GetHyperlink): Verzauberungen, Edelsteine, Sockelbonus
         und Werte, die GetItemStats nicht liefert. Die Zeilen werden mit Mustern gelesen, die zur
         Laufzeit aus den lokalisierten Blizzard-Globals (ITEM_MOD_*) gebaut werden - das Addon
         kennt also keine Texte einer bestimmten Sprache.

    Alle Werte laufen unter kurzen, sprachunabhaengigen Schluesseln (STR, AGI, ...) weiter.
    Schluessel, die das Addon nicht kennt, bleiben unter ihrem ITEM_MOD-Namen erhalten
    (/eg unknown listet sie), damit ein eigenes Profil sie trotzdem gewichten kann.
-----------------------------------------------------------------------------]]

local _, EG = ...
local Stats = {}
EG.Stats = Stats

local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring
local sfind, smatch, sgsub, slower, ssub, srep = string.find, string.match, string.gsub, string.lower, string.sub, string.rep
local tsort = table.sort

------------------------------------------------------------------------------
-- 01  Schluessel
------------------------------------------------------------------------------

-- Anzeigereihenfolge
Stats.ORDER = {
    "STR", "AGI", "STA", "INT", "SPI",
    "AP", "RAP", "FAP", "SP", "SPDMG", "SPHEAL", "SPEN",
    "HIT", "EXP", "CRIT", "HASTE", "ARP", "RESIL", "MASTERY", "VERS",
    "DEF", "DODGE", "PARRY", "BLOCKR", "BLOCKV",
    "MP5", "HP5", "HEALTH", "MANA", "ARMOR",
}

-- Pseudo-Schluessel, die nicht aus GetItemStats stammen
Stats.DPS, Stats.RDPS, Stats.SOCKET = "DPS", "RDPS", "SOCKET"

-- Kurzschluessel -> ITEM_MOD-Namen (der erste liefert den Anzeigenamen; mehrere Namen eines
-- Schluessels beschreiben denselben Wert und werden nicht addiert, sondern nur einmal gezaehlt)
Stats.ITEMMOD = {
    STR    = { "ITEM_MOD_STRENGTH_SHORT" },
    AGI    = { "ITEM_MOD_AGILITY_SHORT" },
    STA    = { "ITEM_MOD_STAMINA_SHORT" },
    INT    = { "ITEM_MOD_INTELLECT_SHORT" },
    SPI    = { "ITEM_MOD_SPIRIT_SHORT" },
    AP     = { "ITEM_MOD_ATTACK_POWER_SHORT" },
    RAP    = { "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" },
    FAP    = { "ITEM_MOD_FERAL_ATTACK_POWER_SHORT" },
    SP     = { "ITEM_MOD_SPELL_POWER_SHORT" },
    SPDMG  = { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" },
    SPHEAL = { "ITEM_MOD_SPELL_HEALING_DONE_SHORT" },
    SPEN   = { "ITEM_MOD_SPELL_PENETRATION_SHORT" },
    HIT    = { "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT",
               "ITEM_MOD_HIT_RANGED_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT" },
    EXP    = { "ITEM_MOD_EXPERTISE_RATING_SHORT" },
    CRIT   = { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT",
               "ITEM_MOD_CRIT_RANGED_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT" },
    HASTE  = { "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HASTE_MELEE_RATING_SHORT",
               "ITEM_MOD_HASTE_RANGED_RATING_SHORT", "ITEM_MOD_HASTE_SPELL_RATING_SHORT" },
    ARP    = { "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT" },
    RESIL  = { "ITEM_MOD_RESILIENCE_RATING_SHORT" },
    MASTERY= { "ITEM_MOD_MASTERY_RATING_SHORT" },
    VERS   = { "ITEM_MOD_VERSATILITY" },
    DEF    = { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" },
    DODGE  = { "ITEM_MOD_DODGE_RATING_SHORT" },
    PARRY  = { "ITEM_MOD_PARRY_RATING_SHORT" },
    BLOCKR = { "ITEM_MOD_BLOCK_RATING_SHORT" },
    BLOCKV = { "ITEM_MOD_BLOCK_VALUE_SHORT" },
    MP5    = { "ITEM_MOD_POWER_REGEN0_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT" },
    HP5    = { "ITEM_MOD_HEALTH_REGEN_SHORT", "ITEM_MOD_HEALTH_REGENERATION_SHORT" },
    HEALTH = { "ITEM_MOD_HEALTH_SHORT" },
    MANA   = { "ITEM_MOD_MANA_SHORT" },
    ARMOR  = { "RESISTANCE0_NAME" },
}

-- ITEM_MOD-Name -> Kurzschluessel
local NAME2KEY = {}
for key, names in pairs(Stats.ITEMMOD) do
    for _, name in ipairs(names) do NAME2KEY[name] = key end
end
Stats.NAME2KEY = NAME2KEY

-- Die Waffen-DPS liefert GetItemStats unter diesem Namen
local DPS_NAME = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"

local SOCKET_NAMES = {
    EMPTY_SOCKET_RED = true, EMPTY_SOCKET_YELLOW = true, EMPTY_SOCKET_BLUE = true,
    EMPTY_SOCKET_META = true, EMPTY_SOCKET_PRISMATIC = true, EMPTY_SOCKET_COGWHEEL = true,
    EMPTY_SOCKET_HYDRAULIC = true, EMPTY_SOCKET_NO_COLOR = true, EMPTY_SOCKET_PRIMORDIAL = true,
    EMPTY_SOCKET_DOMINATION = true, EMPTY_SOCKET_TINKER = true, EMPTY_SOCKET_PUNCHCARDRED = true,
    EMPTY_SOCKET_PUNCHCARDYELLOW = true, EMPTY_SOCKET_PUNCHCARDBLUE = true,
}

-- Lesbarer Name eines Schluessels fuer Anzeigen (Kurzschluessel oder roher ITEM_MOD-Name)
function Stats.Label(key)
    if key == Stats.DPS then return EG.L.WEAPON_DPS end
    if key == Stats.RDPS then return EG.L.RANGED_DPS end
    if key == Stats.SOCKET then return EG.L.SOCKETS end
    local names = Stats.ITEMMOD[key]
    local raw = names and names[1] or key
    -- Die Namen liefert der Client selbst (ITEM_MOD_*-Texte): in jeder Sprache richtig, ohne eigene Uebersetzung
    local text = _G[raw]
    if type(text) == "string" and text ~= "" then return text end
    return tostring(key)
end

-- Ist es ein Kurzschluessel (kein roher ITEM_MOD-Name)?
function Stats.IsKnownKey(key)
    return Stats.ITEMMOD[key] ~= nil or key == Stats.DPS or key == Stats.RDPS or key == Stats.SOCKET
end

------------------------------------------------------------------------------
-- 02  Basiswerte aus GetItemStats
------------------------------------------------------------------------------

--[[ Rueckgabe: stats (Kurzschluessel -> Wert), unknown (ITEM_MOD-Name -> Wert), sockets (Zahl), dps (Zahl|nil)

     Mehrere ITEM_MOD-Namen derselben Familie (Treffer allgemein/Nahkampf/Fernkampf/Zauber) beschreiben
     denselben Wert: es zaehlt der groesste, nicht die Summe.                                            ]]
function Stats.FromItemStats(tbl)
    local stats, unknown, sockets, dps = {}, {}, 0, nil
    if type(tbl) ~= "table" then return stats, unknown, sockets, dps end
    for name, value in pairs(tbl) do
        value = tonumber(value)
        if value then
            local key = NAME2KEY[name]
            if key then
                if value > (stats[key] or 0) then stats[key] = value end
            elseif name == DPS_NAME then
                dps = value
            elseif SOCKET_NAMES[name] then
                sockets = sockets + value
            elseif type(name) == "string" and sfind(name, "^EMPTY_SOCKET") then
                sockets = sockets + value
            elseif type(name) == "string" then
                unknown[name] = value
            end
        end
    end
    return stats, unknown, sockets, dps
end

------------------------------------------------------------------------------
-- 03  Tooltip-Zeilen
------------------------------------------------------------------------------

local function EscapePattern(s)
    return (sgsub(s, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"))
end
Stats.EscapePattern = EscapePattern

-- Vorlage der Blizzard-Globals ("%s Schaden pro Sekunde") in ein Muster wandeln
local function TemplateToPattern(tpl, capture)
    tpl = sgsub(tpl, "%%%d%$[sd]", "\1")
    tpl = sgsub(tpl, "%%[sd]", "\1")
    tpl = EscapePattern(tpl)
    return (sgsub(tpl, "\1", capture))
end
Stats.TemplateToPattern = TemplateToPattern

-- Zeilentypen (Enum.TooltipDataLineType), die nie Werte enthalten
local function LineTypes()
    local e = Enum and Enum.TooltipDataLineType or {}
    return e
end

local patternCache, segmentCache, built

-- Muster fuer ganze Zeilen:  "+55 Ausdauer", "Verbessert Tempowertung um 55.", "Ausruesten: ... 55."
local function BuildPatterns()
    if built then return end
    built = true
    patternCache, segmentCache = {}, {}

    local equipPrefix = _G.ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:"
    local escPrefix = EscapePattern(equipPrefix)

    -- %c steht in einigen Vorlagen fuer das Vorzeichen ("%c%s Staerke")
    local function LongTemplateToPattern(tpl)
        local pat = sgsub(tpl, "%%c", "\2")
        pat = sgsub(pat, "%%%d%$[sd]", "\1")
        pat = sgsub(pat, "%%[sd]", "\1")
        pat = EscapePattern(pat)
        pat = sgsub(pat, "\1", "([%%d%%.,]+)")
        pat = sgsub(pat, "\2", "%%+?")
        return pat
    end

    for _, key in ipairs(Stats.ORDER) do
        for _, name in ipairs(Stats.ITEMMOD[key]) do
            -- Kurzform: "+55 Ausdauer" / "524 Ruestung"
            local short = _G[name]
            if type(short) == "string" and short ~= "" then
                patternCache[#patternCache + 1] = { key = key, pattern = "^%+?([%d%.,]+)%s+" .. EscapePattern(short) .. "%.?$" }
                local lname = sgsub(slower(short), "%.$", "")
                segmentCache[#segmentCache + 1] = { key = key, name = lname, esc = EscapePattern(lname) }
            end
            -- Langform: "Verbessert Tempowertung um 55."
            local longName = smatch(name, "^(.+)_SHORT$")
            local long = longName and _G[longName]
            if type(long) == "string" and long ~= "" then
                local pat = LongTemplateToPattern(long)
                patternCache[#patternCache + 1] = { key = key, pattern = "^" .. pat .. "$" }
                patternCache[#patternCache + 1] = { key = key, pattern = "^" .. escPrefix .. "%s*" .. pat .. "$" }
            end
        end
    end

    -- "Alle Werte" (+10 Alle Werte): addiert zu den fuenf Hauptwerten
    local all = _G.SPELL_STATALL or "All Stats"
    local lall = sgsub(slower(all), "%.$", "")
    segmentCache[#segmentCache + 1] = { key = "__ALLSTATS", name = lall, esc = EscapePattern(lall) }

    -- laengste Namen zuerst ("Ruestungsdurchschlag" vor "Ruestung", "Mana alle 5 Sek." vor "Mana")
    tsort(segmentCache, function(a, b) return #a.name > #b.name end)
end

local ALL_STATS = { "STR", "AGI", "STA", "INT", "SPI" }

local function AddStat(stats, key, value)
    if key == "__ALLSTATS" then
        for _, k in ipairs(ALL_STATS) do stats[k] = (stats[k] or 0) + value end
    else
        stats[key] = (stats[key] or 0) + value
    end
end

-- Liest jedes "+Zahl Attributname" einer Zeile (Edelsteine, Verzauberungen, Sockelbonus).
-- Rueckgabe: wurde etwas gefunden?
function Stats.ScanSegments(text, stats)
    BuildPatterns()
    local work, found = slower(text), false
    for _, seg in ipairs(segmentCache) do
        local init = 1
        while true do
            local s, e, num = sfind(work, "%+([%d%.,]+)%s*" .. seg.esc, init)
            if not s then break end
            -- der Name muss hier enden: kein Buchstabe dahinter
            local nextc = ssub(work, e + 1, e + 1)
            if nextc == "" or not smatch(nextc, "%a") then
                local v = tonumber((sgsub(num, ",", ".")))
                if v and v > 0 then
                    AddStat(stats, seg.key, v)
                    found = true
                end
                -- Treffer unkenntlich machen, damit kuerzere Namen nicht noch einmal darauf anspringen
                work = ssub(work, 1, s - 1) .. srep("\1", e - s + 1) .. ssub(work, e + 1)
            end
            init = e + 1
        end
    end
    return found
end

-- Ganze Zeile gegen die Muster halten. Rueckgabe: Schluessel, Wert | nil
local function MatchWholeLine(text)
    BuildPatterns()
    for _, p in ipairs(patternCache) do
        local v = smatch(text, p.pattern)
        if v then
            v = tonumber((sgsub(v, ",", ".")))
            if v and v > 0 then return p.key, v end
            return p.key, nil
        end
    end
end
Stats.MatchWholeLine = MatchWholeLine

-- Zeilen mit diesen Praefixen sind Effekte (Benutzen, Proc), keine festen Werte
local function StartsWithTrigger(text)
    local list = { _G.ITEM_SPELL_TRIGGER_ONUSE, _G.ITEM_SPELL_TRIGGER_ONPROC }
    for _, p in ipairs(list) do
        if p and p ~= "" and ssub(text, 1, #p) == p then return true end
    end
    return false
end

-- Farbe einer Zeile: rot = nicht erfuellt, grau = inaktiv
local function ColorOf(color)
    if type(color) ~= "table" then return nil end
    local r, g, b = color.r, color.g, color.b
    if (not r) and color.GetRGB then r, g, b = color:GetRGB() end
    return r, g, b
end

local function IsRed(color)
    local r, g, b = ColorOf(color)
    return r and r > 0.85 and g < 0.25 and b < 0.25 or false
end

local function IsGrey(color)
    local r, g, b = ColorOf(color)
    if not r then return false end
    return r > 0.4 and r < 0.62 and g > 0.4 and g < 0.62 and b > 0.4 and b < 0.62
end
Stats.IsRed, Stats.IsGrey = IsRed, IsGrey

-- Kopfzeile eines Ausruestungssets: "Name (2/5)"
local SET_HEADER_PATTERN = "^.+%s%((%d+)/(%d+)%)$"

local function IsUniqueLine(text)
    return text == (_G.ITEM_UNIQUE or "Unique")
        or text == (_G.ITEM_UNIQUE_EQUIPPABLE or "Unique-Equipped")
end

--[[ Einmaliger Durchlauf durch die Tooltip-Daten eines Gegenstands.

     lines   tooltipData.lines (Liste von Zeilen mit type, leftText, leftColor, rightText, ...)

     Rueckgabe:
       base       Werte aus Basiszeilen (je Schluessel der groesste; gleiche Werte in mehreren Zeilen)
       extra      Werte aus Verzauberung, Edelsteinen und aktivem Sockelbonus (Summe)
       hasStats   wurde ueberhaupt ein Wert gelesen?
       dps        Waffen-DPS aus dem Text, falls vorhanden
       unique     "Einzigartig" / "Einzigartig anlegbar"
       validType  EquipSlot-Zeile: ist die Ruestungs-/Waffenart fuer den Spieler verwendbar? (nil = unbekannt)
       validSlot  EquipSlot-Zeile: passt der Platz? (nil = unbekannt)
       reason     Text der ersten roten Anforderungszeile (ohne Stufe)
       reqLevel   benoetigte Stufe laut Zeile
       slotText, typeText   Platz und Art als Text                                                    ]]
function Stats.ScanLines(lines)
    local res = { base = {}, extra = {}, hasStats = false }
    if type(lines) ~= "table" then return res end

    local T = LineTypes()
    local reqLevelType = Enum and Enum.TooltipDataUsageRequirementType and Enum.TooltipDataUsageRequirementType.Level
    local skip = {}
    for _, name in ipairs({ "ItemName", "ItemBinding", "EquipSlot", "SellPrice", "FlavorText", "ItemLevel",
                            "ItemUpgradeLevel", "ItemSpellTriggerOnUse", "ItemSpellTriggerOnProc",
                            "ItemSpellTriggerLearn", "Blank", "Separator", "UsageRequirement", "ErrorLine",
                            "DisabledLine", "ItemQuality", "TradeTimeRemaining", "LearnTransmogSet",
                            "LearnTransmogIllusion", "GemSocket" }) do
        if T[name] then skip[T[name]] = true end
    end

    local minLevelPattern = TemplateToPattern(_G.ITEM_MIN_LEVEL or "Requires Level %d", "(%%d+)")
    local dpsPattern = TemplateToPattern(_G.DPS_TEMPLATE or "(%s damage per second)", "([%%d%%.,]+)")
    local enchantPattern = _G.ENCHANTED_TOOLTIP_LINE and ("^" .. TemplateToPattern(_G.ENCHANTED_TOOLTIP_LINE, "(.+)") .. "$")
    local socketBonusPattern = "^" .. TemplateToPattern(_G.ITEM_SOCKET_BONUS or "Socket Bonus: %s", "(.+)") .. "$"
    local stopAtSet = false

    for i = 1, #lines do
        local line = lines[i]
        local ltype = line.type
        local text = line.leftText

        if ltype == T.EquipSlot then
            res.validType = line.isValidItemType
            res.validSlot = line.isValidInvSlot
            res.slotText, res.typeText = line.leftText, line.rightText
            if res.validType == nil and res.validSlot == nil and IsRed(line.rightColor) then res.validType = false end

        elseif ltype == T.UsageRequirement or ltype == T.ErrorLine then
            if type(text) == "string" and IsRed(line.leftColor) then
                local lvl = smatch(text, minLevelPattern)
                if lvl then
                    res.reqLevel = tonumber(lvl)
                elseif reqLevelType ~= nil and ltype == T.UsageRequirement and line.requirementType == reqLevelType then
                    res.reqLevel = res.reqLevel or tonumber(smatch(text, "(%d+)"))
                elseif not res.reason then
                    res.reason = text
                end
            end

        elseif type(text) == "string" and text ~= "" and not skip[ltype] and not stopAtSet then
            -- Ab der Set-Kopfzeile nicht weiter auswerten: Setboni haengen an anderen Teilen
            if smatch(text, SET_HEADER_PATTERN) then
                stopAtSet = true
            elseif IsRed(line.leftColor) then
                local lvl = smatch(text, minLevelPattern)
                if lvl then
                    res.reqLevel = tonumber(lvl)
                elseif not res.reason then
                    res.reason = text
                end
            elseif not IsGrey(line.leftColor) then
                -- graue Zeilen sind inaktive Sockel- und Setboni
                if not res.unique and IsUniqueLine(text) then res.unique = true end

                if not res.dps then
                    local v = smatch(text, dpsPattern)
                    if v then res.dps = tonumber((sgsub(v, ",", "."))) end
                end

                local isExtra = (T.ItemEnchantmentPermanent and ltype == T.ItemEnchantmentPermanent)
                             or (T.GemSocketEnchantment and ltype == T.GemSocketEnchantment)
                             or (enchantPattern and smatch(text, enchantPattern) ~= nil)
                local target = isExtra and res.extra or nil

                local key, value = MatchWholeLine(text)
                if key then
                    if value then
                        if target then
                            target[key] = (target[key] or 0) + value
                        elseif value > (res.base[key] or 0) then
                            res.base[key] = value
                        end
                        res.hasStats = true
                    end
                else
                    local bonus = smatch(text, socketBonusPattern)
                    if bonus then
                        -- aktiver Sockelbonus (inaktiv waere grau und uebersprungen)
                        if Stats.ScanSegments(bonus, res.extra) then res.hasStats = true end
                    elseif not StartsWithTrigger(text) and (isExtra or sfind(text, "%+%d")) then
                        -- Edelstein- und Verzauberungszeilen ("+10 Staerke und +15 Ausdauer")
                        if Stats.ScanSegments(text, res.extra) then res.hasStats = true end
                    end
                end
            end
        end
    end
    return res
end

------------------------------------------------------------------------------
-- 04  Zusammenfuehren
------------------------------------------------------------------------------

--[[ Aus Basiswerten (GetItemStats) und Tooltip-Auswertung die Werte des Gegenstands bilden.
     Basiszeilen und API-Werte beschreiben dieselben Zahlen -> Maximum; Verzauberung, Steine und
     Sockelbonus kommen obendrauf.
     Rueckgabe: stats (gesamt), extra (nur der Anteil aus Verzauberung/Steinen)                  ]]
function Stats.Merge(apiStats, scan, includeExtras)
    local stats, extra = {}, {}
    for k, v in pairs(apiStats or {}) do stats[k] = v end
    if scan then
        for k, v in pairs(scan.base) do
            if v > (stats[k] or 0) then stats[k] = v end
        end
        if includeExtras then
            for k, v in pairs(scan.extra) do
                stats[k] = (stats[k] or 0) + v
                extra[k] = v
            end
        end
    end
    return stats, extra
end
