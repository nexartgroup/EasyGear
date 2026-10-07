--[[---------------------------------------------------------------------------
    EasyGear 3.0.0
    Gear-Bewertung, Upgrade-Erkennung und Vergleich fuer WoW 3.3.5a (WotLK)

    Kompatibilitaet:
      * Client 3.3.5a / Interface 30300
      * jede Clientsprache (Texte aus Locales/*.lang.lua, Fallback Englisch)
      * Lua 5.1

    Dateien:
      Locales/*.lang.lua      Sprachdateien (Lua-Syntax, eine je Clientsprache)
      EasyGear.lua            Kern: Bewertung, Slots, Vergleich, Quest, Tooltip
      EasyGearSpecs.lua       Gewichtungsprofile
      EasyGearHeirlooms.lua   Erbstuecke und Klassenpakete
      EasyGearOverlays.lua    Markierungen: Taschen, Haendler, Beute, Wuerfeln, ...
      EasyGearEGUP.lua        GM-Paket und Aufraeumen
      EasyGearGUI.lua         Item-Vergleichsfenster
      EasyGearProfileGUI.lua  Profil-Vergleichsfenster

    Struktur dieser Datei:
      01  Namespace & Konstanten
      02  Lokalisierung
      03  Hilfsfunktionen (Timer, Ausgabe, Farben)
      04  Scan-Tooltip
      05  Statistik-Schluessel
      06  Profilverwaltung und Spec-Erkennung
      07  Item-Daten (mit Cache), Tooltip-Auswertung
      08  Bewertung & Berechnungsgrundlagen
      09  Slot-Aufloesung (Ringe, Schildhand, Zweihand, Titanengriff)
      10  Verwendbarkeit (Ruestungsklasse, Waffen, Tooltip)
      11  Vergleichs-Engine
      13  Questbelohnungen
      14  Tooltip-Integration
      16  Chat-Ausgabe und Slash-Befehle
      17  Initialisierung
-----------------------------------------------------------------------------]]

------------------------------------------------------------------------------
-- 01  Namespace & Konstanten
------------------------------------------------------------------------------

local ADDON_NAME    = "EasyGear"
local ADDON_VERSION = "3.0.0"

EasyGear = EasyGear or {}
local EG = EasyGear

EG.name    = ADDON_NAME
EG.version = ADDON_VERSION

-- Lokale Kopien haeufig genutzter Globals (Lua-5.1-Performance)
local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring
local select, unpack, wipe = select, unpack, wipe
local tremove, tconcat, tsort = table.remove, table.concat, table.sort
local sformat, smatch, sgsub, sfind, slower, ssub, srep =
    string.format, string.match, string.gsub, string.find, string.lower, string.sub, string.rep
local mhuge, mmin, mmax = math.huge, math.min, math.max

local HEIRLOOM_QUALITY  = 7
local HEIRLOOM_MAX_LEVEL= 80
local MAX_EQUIP_SLOT    = 19
local OFFHAND_FACTOR    = 0.5   -- Nebenhand-Waffen verursachen nur halben Schaden

-- Texturen
local TEX_UPGRADE = "Interface\\Buttons\\UI-CheckBox-Check"
local TEX_VENDOR  = "Interface\\MoneyFrame\\UI-GoldIcon"

EG.TEX_UPGRADE = TEX_UPGRADE
EG.TEX_VENDOR  = TEX_VENDOR

-- Standardeinstellungen (SavedVariables)
local DEFAULTS = {
    ilvlWeight       = 0.5,     -- Punkte pro Gegenstandsstufe (auf Stufe 80)
    ilvlScaling      = true,    -- Gegenstandsstufen-Basis mit Charakterstufe skalieren
    dpsWeight        = nil,     -- nil = Wert aus dem Profil
    socketValue      = nil,     -- nil = automatisch (erwarteter Steinwert je Stufe und Profil)
    showBagIcons     = true,
    showQuestIcons   = true,
    showItemIcons    = true,    -- Haendler, Beute, Wuerfeln, Auktionshaus, Handel, Post
    showTooltip      = true,
    showTooltipStats = true,    -- Slot- und Vergleichszeile im Tooltip
    tooltipDiff      = true,    -- Attribut-Differenzen im Tooltip
    protectHeirlooms = true,    -- Erbstuecke beim Leveln bevorzugen
    heirloomBonus    = 1.5,     -- Aufschlag auf die Wertung (voll bis Stufe 60, bis 80 auf 1.0)
    includeEnchants  = true,    -- Verzauberungen und Sockelsteine mitrechnen
    autoLeveling     = true,    -- unter Stufe 80 das Leveln-Profil der Klasse benutzen
    iconSize         = 20,
    minDelta         = 0,       -- Mindestpunkte-Vorsprung fuer "Upgrade"
    minDeltaPercent  = 1,       -- zusaetzlich: Prozent des Vergleichswerts
    egupCommand      = ".additem {name} {id} {count}",
    egupConfirm      = true,
    egupDelay        = 0.35,
    debug            = false,
    custom           = {},      -- eigene Profile (accountweit)
}
EG.DEFAULTS = DEFAULTS

local CHAR_DEFAULTS = {
    profile = "AUTO",           -- Profil-ID oder "AUTO" (Talentbaum-Erkennung)
    pvp     = false,            -- PvP-Aufschlag auf Abhaertung und Ausdauer
    role    = "AUTO",           -- veraltet, nur noch fuer /eg role
    weights = nil,              -- veraltete Einzelgewichte
    gui     = { point = "CENTER", x = 0, y = 0, scale = 1.0 },
    egup    = nil,              -- letzte EGUP-Sitzung (relog-fest)
}

------------------------------------------------------------------------------
-- 02  Lokalisierung
------------------------------------------------------------------------------

--[[ Die Texte stehen in Locales/<Sprache>.lang.lua (.lang = Sprachdatei, .lua
     damit der Client sie sicher laedt). Jede Datei hat Lua-Syntax und
     traegt ihre Tabelle in EasyGearLocales[<GetLocale()>] ein:

         EasyGearLocales = EasyGearLocales or {}
         EasyGearLocales["deDE"] = { LOADED = "EasyGear %s geladen.", ... }

     Aufloesung je Schluessel:  Clientsprache  ->  Englisch  ->  Schluessel.
     Fehlt eine Uebersetzung, erscheint also immer der englische Text. Die
     Tabelle enUS ist die vollstaendige Referenz.

     Sprachabhaengige Texte, die fuer die Grundfunktion noetig sind (Namen der
     Ruestungs- und Waffenuntertypen), tragen den Praefix SUBTYPE_.            ]]
local L
do
    EasyGearLocales = EasyGearLocales or {}

    local ALIAS = { enGB = "enUS", esMX = "esES" }
    local client = (GetLocale and GetLocale()) or "enUS"
    local active = ALIAS[client] or client

    local base = EasyGearLocales["enUS"]
    local cur  = (active ~= "enUS") and EasyGearLocales[active] or nil

    -- Notausgabe, falls die Sprachdateien nicht geladen wurden
    local EMERGENCY = {
        LOADED = "EasyGear %s loaded.",
        LOCALE_BROKEN = "Language files were not loaded - check Locales\\*.lang.lua in EasyGear.toc.",
    }

    local loaded = {}
    for code in pairs(EasyGearLocales) do loaded[#loaded + 1] = code end
    tsort(loaded)

    EG.locale = {
        client    = client,                       -- was GetLocale() liefert
        active    = cur and active or "enUS",     -- tatsaechlich benutzte Sprachdatei
        translated= cur ~= nil,
        baseOK    = base ~= nil,
        loaded    = loaded,
    }

    L = setmetatable({}, { __index = function(_, k)
        local v = cur and cur[k]
        if v == nil and base then v = base[k] end
        if v == nil then v = EMERGENCY[k] end
        if v == nil then v = k end
        return v
    end })

    -- Gibt es fuer diesen Schluessel einen echten Text (nicht nur den Schluessel)?
    function EG:LocaleHas(key)
        return (cur and cur[key] ~= nil) or (base and base[key] ~= nil) or false
    end

    -- Rohzugriff auf eine bestimmte Sprachtabelle (Tests, Untertyp-Namen)
    function EG:LocaleTable(code)
        return EasyGearLocales[code]
    end
end

EG.L = L

------------------------------------------------------------------------------
-- 03  Hilfsfunktionen
------------------------------------------------------------------------------

local COLOR = {
    title  = "|cff00ccff",
    good   = "|cff00ff00",
    bad    = "|cffff2020",
    warn   = "|cffffcc00",
    value  = "|cffffff00",
    grey   = "|cff9d9d9d",
    reset  = "|r",
}
EG.COLOR = COLOR

function EG:Print(...)
    local msg = ""
    for i = 1, select("#", ...) do
        msg = msg .. tostring(select(i, ...)) .. " "
    end
    DEFAULT_CHAT_FRAME:AddMessage(COLOR.title .. "EasyGear:" .. COLOR.reset .. " " .. msg)
end

function EG:Raw(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg or "")
end

function EG:Debug(...)
    if self.db and self.db.debug then
        self:Print("|cff888888[debug]|r", ...)
    end
end

--[[ Wertungen als Text.
     Auf niedrigen Stufen liegen die Wertungen im Bereich 0-5, auf Stufe 80
     im dreistelligen Bereich - die Nachkommastellen richten sich deshalb
     nach der Groessenordnung.                                             ]]
local function FmtScore(v)
    if not v then return "0" end
    if v == mhuge then return "-" end
    if v == -mhuge then return "-" end
    local a = (v < 0) and -v or v
    if a < 10  then return sformat("%.2f", v) end
    if a < 100 then return sformat("%.1f", v) end
    return sformat("%.0f", v)
end

local function FmtWeight(v)
    if not v then return "0" end
    local a = (v < 0) and -v or v
    if a > 0 and a < 0.1 then return sformat("%.3f", v) end
    return sformat("%.2f", v)
end

-- Zahl gerundet als String
local function Num(v, decimals)
    if not v then return "0" end
    if decimals and decimals > 0 then
        return sformat("%." .. decimals .. "f", v)
    end
    return sformat("%d", v + (v >= 0 and 0.5 or -0.5))
end
EG.Num       = function(_, v, d) return Num(v, d) end
EG.FmtScore  = function(_, v) return FmtScore(v) end
EG.FmtWeight = function(_, v) return FmtWeight(v) end

-- Prozentangabe mit Vorzeichen: "+8.2%"
local function FmtPct(v)
    if not v then return "" end
    local a = (v < 0) and -v or v
    local s = (a < 10) and sformat("%.1f", v) or sformat("%.0f", v)
    return ((v > 0) and "+" or "") .. s .. "%"
end
EG.FmtPct = function(_, v) return FmtPct(v) end

-- Muster-Sonderzeichen entschaerfen
local function EscapePattern(s)
    return (sgsub(s or "", "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end
EG.EscapePattern = function(_, s) return EscapePattern(s) end

-- "a|b|c" -> { "a", "b", "c" }
local function SplitAliases(s)
    local out = {}
    if not s or s == "" then return out end
    for part in string.gmatch(s, "[^|]+") do out[#out + 1] = part end
    return out
end
EG.SplitAliases = function(_, s) return SplitAliases(s) end

-- "1.2.10" < "3.0.0" ?
local function VersionLess(a, b)
    local function parts(v)
        local t = {}
        for n in string.gmatch(tostring(v or ""), "%d+") do t[#t + 1] = tonumber(n) end
        return t
    end
    local pa, pb = parts(a), parts(b)
    for i = 1, mmax(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y end
    end
    return false
end
EG.VersionLess = function(_, a, b) return VersionLess(a, b) end

--[[ Timer
     Der Original-Code benutzte einen einzigen Frame; jeder neue Aufruf
     ueberschrieb den vorherigen OnUpdate-Handler und verwarf damit den
     noch laufenden Timer. Hier laufen beliebig viele Timer parallel.      ]]
local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    for i = #timers, 1, -1 do
        local t = timers[i]
        t.left = t.left - elapsed
        if t.left <= 0 then
            tremove(timers, i)
            local ok, err = pcall(t.func)
            if not ok then
                EG:Print("|cffff2020Timer error:|r", err)
            end
        end
    end
    if #timers == 0 then self:Hide() end
end)

function EG:After(delay, func)
    if type(func) ~= "function" then return end
    timers[#timers + 1] = { left = tonumber(delay) or 0, func = func }
    timerFrame:Show()
    return timers[#timers]
end

-- Entprellung: mehrfache Aufrufe innerhalb der Wartezeit werden zusammengefasst
local debounces = {}
function EG:Debounce(key, delay, func)
    if debounces[key] then return end
    debounces[key] = true
    self:After(delay, function()
        debounces[key] = nil
        func()
    end)
end

------------------------------------------------------------------------------
-- 04  Scan-Tooltip
------------------------------------------------------------------------------

local scanTip = CreateFrame("GameTooltip", "EasyGearScanTooltip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")
EG.scanTip = scanTip

local function TipLine(i)
    return _G["EasyGearScanTooltipTextLeft" .. i]
end

local function SetScanTip(link)
    scanTip:ClearLines()
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    local ok = pcall(scanTip.SetHyperlink, scanTip, link)
    if not ok then return false end
    return scanTip:NumLines() > 0
end

-- Vorlage der Blizzard-Globals ("%s Schaden pro Sekunde") in ein Muster wandeln
local function TemplateToPattern(tpl, capture)
    tpl = sgsub(tpl, "%%%d%$[sd]", "\1")
    tpl = sgsub(tpl, "%%[sd]", "\1")
    tpl = EscapePattern(tpl)
    return (sgsub(tpl, "\1", capture))
end

-- Muster fuer "(x.y Schaden pro Sekunde)" bzw. "(x.y damage per second)"
local dpsPattern = TemplateToPattern(DPS_TEMPLATE or "(%s damage per second)", "([%%d%%.,]+)")

-- Muster fuer "Benoetigt Stufe X" - solche roten Zeilen behandeln wir separat
local minLevelPattern = TemplateToPattern(ITEM_MIN_LEVEL or "Requires Level %d", "(%%d+)")

local function IsRed(fs)
    if not fs then return false end
    local r, g, b = fs:GetTextColor()
    return r and r > 0.85 and g < 0.25 and b < 0.25
end

local function IsGrey(fs)
    if not fs then return false end
    local r, g, b = fs:GetTextColor()
    if not r then return false end
    return r > 0.4 and r < 0.62 and g > 0.4 and g < 0.62 and b > 0.4 and b < 0.62
end

EG.IsRedLine  = function(_, fs) return IsRed(fs) end
EG.IsGreyLine = function(_, fs) return IsGrey(fs) end
EG.SetScanTip = function(_, link) return SetScanTip(link) end
EG.TipLine    = function(_, i) return TipLine(i) end
EG.ScanTipObj = scanTip
EG.DpsPattern      = dpsPattern
EG.MinLevelPattern = minLevelPattern

--[[ Die eigentliche Auswertung steht weiter unten bei den Itemdaten
     (EG:ScanItemTooltip), weil sie die Statschluessel aus Abschnitt 05
     braucht. Die folgenden beiden Funktionen sind nur noch bequeme
     Zugriffe auf dasselbe, einmal zwischengespeicherte Ergebnis.          ]]

-- Liefert: verwendbar (bool), Grund (string|nil)
function EG:TooltipUsable(link)
    local scan = self:ScanItemTooltip(link)
    if not scan then return nil end
    if scan.reason then return false, scan.reason end
    return true
end

function EG:TooltipDPS(link)
    local scan = self:ScanItemTooltip(link)
    return scan and scan.dps or nil
end

------------------------------------------------------------------------------
-- 05  Statistik-Schluessel
------------------------------------------------------------------------------

-- Kurzform -> echter Schluessel aus GetItemStats()
local S = {
    STR    = "ITEM_MOD_STRENGTH_SHORT",
    AGI    = "ITEM_MOD_AGILITY_SHORT",
    STA    = "ITEM_MOD_STAMINA_SHORT",
    INT    = "ITEM_MOD_INTELLECT_SHORT",
    SPI    = "ITEM_MOD_SPIRIT_SHORT",
    AP     = "ITEM_MOD_ATTACK_POWER_SHORT",
    RAP    = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    SP     = "ITEM_MOD_SPELL_POWER_SHORT",
    SPEN   = "ITEM_MOD_SPELL_PENETRATION_SHORT",
    CRIT   = "ITEM_MOD_CRIT_RATING_SHORT",
    HASTE  = "ITEM_MOD_HASTE_RATING_SHORT",
    HIT    = "ITEM_MOD_HIT_RATING_SHORT",
    EXP    = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    ARP    = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    RESIL  = "ITEM_MOD_RESILIENCE_RATING_SHORT",
    DEF    = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    DODGE  = "ITEM_MOD_DODGE_RATING_SHORT",
    PARRY  = "ITEM_MOD_PARRY_RATING_SHORT",
    BLOCKR = "ITEM_MOD_BLOCK_RATING_SHORT",
    BLOCKV = "ITEM_MOD_BLOCK_VALUE_SHORT",
    MP5    = "ITEM_MOD_POWER_REGEN0_SHORT",
    HP5    = "ITEM_MOD_HEALTH_REGEN_SHORT",
    HEALTH = "ITEM_MOD_HEALTH_SHORT",
    MANA   = "ITEM_MOD_MANA_SHORT",
    ARMOR  = "RESISTANCE0_NAME",
}
EG.STAT_KEYS = S

-- Aeltere Schluessel, die GetItemStats() je nach Item liefern kann
local STAT_ALIAS = {
    ITEM_MOD_MANA_REGENERATION_SHORT = S.MP5,
}

-- Pseudo-Schluessel, die nicht aus GetItemStats() stammen
local PSEUDO_DPS     = "__DPS"        -- Nahkampfwaffen
local PSEUDO_RDPS    = "__RDPS"       -- Fernkampfwaffen, Wurfwaffen, Zauberstaebe
local PSEUDO_SOCKET  = "__SOCKET"
local PSEUDO_HEIRLOOM= "__HEIRLOOM"
EG.PSEUDO_DPS      = PSEUDO_DPS
EG.PSEUDO_RDPS     = PSEUDO_RDPS
EG.PSEUDO_SOCKET   = PSEUDO_SOCKET
EG.PSEUDO_HEIRLOOM = PSEUDO_HEIRLOOM

local SOCKET_KEYS = {
    "EMPTY_SOCKET_RED", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_BLUE",
    "EMPTY_SOCKET_META", "EMPTY_SOCKET_PRISMATIC",
}

-- Anzeigereihenfolge in den Berechnungsgrundlagen
local STAT_ORDER = {
    S.STR, S.AGI, S.STA, S.INT, S.SPI,
    S.AP, S.RAP, S.SP, S.SPEN,
    S.HIT, S.EXP, S.CRIT, S.HASTE, S.ARP, S.RESIL,
    S.DEF, S.DODGE, S.PARRY, S.BLOCKR, S.BLOCKV,
    S.MP5, S.HP5, S.HEALTH, S.MANA, S.ARMOR,
}
EG.STAT_ORDER = STAT_ORDER

--[[ Kurzform-Tabelle in echte Schluessel uebersetzen.
     "STR" -> ITEM_MOD_STRENGTH_SHORT, "DPS" -> __DPS usw.
     Wird auch von EasyGearSpecs.lua benutzt.                              ]]
local SHORTHAND_EXTRA = {
    DPS    = PSEUDO_DPS,
    RDPS   = PSEUDO_RDPS,
    SOCKET = PSEUDO_SOCKET,
}

local function mk(t)
    local out = {}
    for k, v in pairs(t or {}) do
        out[S[k] or SHORTHAND_EXTRA[k] or k] = v
    end
    return out
end

function EG:MakeWeights(t) return mk(t) end

--[[ Die eigentlichen Gewichtungsprofile stehen in EasyGearSpecs.lua
     (EG.SPECS je Klasse, EG.SPECS_ANY klassenunabhaengig). Eigene Profile
     liegen in EasyGearDB.custom.                                          ]]

------------------------------------------------------------------------------
-- 06  Profilverwaltung und Spec-Erkennung
------------------------------------------------------------------------------

EG.profileCache = nil
EG.epoch = 0
EG.scoreCache = {}
EG.stateCache = {}

--[[ Jede Aenderung an Profil, Ausruestung oder Einstellungen verwirft die
     berechneten Vergleiche und erhoeht die Epoche; daran erkennen die
     Markierungen an Taschen, Haendlern usw., dass ihr Ergebnis veraltet ist. ]]
function EG:InvalidateComparisons()
    self.scoreCache = {}
    self.stateCache = {}
    self.epoch = (self.epoch or 0) + 1
end

function EG:InvalidateProfile()
    self.profileCache = nil
    self:InvalidateComparisons()
end

--[[--------------------------------------------------------------------
     Profilverwaltung

     Alle Profile liegen in EG.SPECS (klassenweise) und EG.SPECS_ANY
     (klassenunabhaengig); eigene Profile kommen aus EasyGearDB.custom.
     Ausgewaehlt wird ueber die ID in EasyGearCharDB.profile, "AUTO"
     bedeutet Erkennung ueber Talentbaum, Stufe und Ausruestung.
----------------------------------------------------------------------]]

-- ApplyPvP: Abhaertung und Ausdauer werden aufgewertet
local function ApplyPvP(weights)
    local out = {}
    for k, v in pairs(weights) do out[k] = v end
    local resil = out[S.RESIL] or 0
    out[S.RESIL] = mmax(resil, 1.00)
    out[S.STA]   = mmax((out[S.STA] or 0) * 2.5, 0.45)
    return out
end

function EG:GetPlayerClass()
    local _, class = UnitClass("player")
    return class or "WARRIOR"
end

-- Profilname und Beschreibung stehen in den Sprachdateien (SPEC_<id>, SPEC_<id>_D)
function EG:GetProfileName(spec)
    if not spec then return "?" end
    if spec.custom then return spec.name or spec.id end
    local key = "SPEC_" .. tostring(spec.id)
    if self:LocaleHas(key) then return L[key] end
    return spec.en or spec.id
end

function EG:GetProfileDesc(spec)
    if not spec then return "" end
    if spec.custom then return spec.desc or "" end
    local key = "SPEC_" .. tostring(spec.id) .. "_D"
    if self:LocaleHas(key) then return L[key] end
    return ""
end

--[[ ID des Standardprofils einer Klasse: <Praefix>_LEVELING / <Praefix>_ALLROUND.
     Der Praefix steht in EasyGearSpecs.lua (DK statt DEATHKNIGHT).         ]]
function EG:ClassProfileID(class, kind)
    local prefix = (self.PROFILE_PREFIX and self.PROFILE_PREFIX[class]) or class
    return prefix .. "_" .. kind
end

--[[ Alle fuer diese Klasse waehlbaren Profile, in fester Reihenfolge:
     Klassenprofile, eigene Profile, klassenunabhaengige Profile.        ]]
function EG:GetAvailableProfiles(class)
    class = class or self:GetPlayerClass()
    local list = {}

    if self.SPECS and self.SPECS[class] then
        for _, spec in ipairs(self.SPECS[class]) do list[#list + 1] = spec end
    end

    local custom = self.db and self.db.custom
    if custom then
        local ids = {}
        for id in pairs(custom) do ids[#ids + 1] = id end
        tsort(ids)
        for _, id in ipairs(ids) do
            local c = custom[id]
            if c and (not c.class or c.class == "ANY" or c.class == class) then
                list[#list + 1] = c
            end
        end
    end

    if self.SPECS_ANY then
        for _, spec in ipairs(self.SPECS_ANY) do list[#list + 1] = spec end
    end

    return list
end

-- Wie GetAvailableProfiles, aber fuer eine frei gewaehlte Klasse
function EG:GetProfilesForClass(class)
    return self:GetAvailableProfiles(class)
end

function EG:GetProfileByID(id)
    if not id or id == "AUTO" then return nil end

    if self.db and self.db.custom and self.db.custom[id] then
        return self.db.custom[id]
    end
    if self.SPECS then
        for _, list in pairs(self.SPECS) do
            for _, spec in ipairs(list) do
                if spec.id == id then return spec end
            end
        end
    end
    if self.SPECS_ANY then
        for _, spec in ipairs(self.SPECS_ANY) do
            if spec.id == id then return spec end
        end
    end
    return nil
end

------------------------------------------------------------------------------
-- Talente
------------------------------------------------------------------------------

EG.talentCache = nil

-- Alle Talente mit Symbol und Rang. Das Symbol ist sprachunabhaengig - Talentnamen
-- sind es nicht, deshalb wird nur ueber den Symbolpfad erkannt.
function EG:GetTalentIcons()
    if self.talentCache then return self.talentCache end
    local list = {}
    local numTabs = (GetNumTalentTabs and GetNumTalentTabs()) or 0
    for tab = 1, numTabs do
        local n = (GetNumTalents and GetNumTalents(tab)) or 0
        for i = 1, n do
            local _, icon, _, _, rank = GetTalentInfo(tab, i)
            if icon then
                list[#list + 1] = { icon = slower(tostring(icon)), rank = tonumber(rank) or 0, tab = tab }
            end
        end
    end
    if #list > 0 then self.talentCache = list end
    return list
end

function EG:HasTalentIcon(fragment)
    fragment = slower(fragment)
    for _, t in ipairs(self:GetTalentIcons()) do
        if t.rank > 0 and sfind(t.icon, fragment, 1, true) then return true end
    end
    return false
end

function EG:InvalidateTalents()
    self.talentCache = nil
    self.hasTG = nil
    self.hasDW = nil
end

-- Talentbaum mit den meisten Punkten
function EG:GetDominantTab()
    local bestTab, bestPoints = nil, 0
    local numTabs = (GetNumTalentTabs and GetNumTalentTabs()) or 3
    for i = 1, (numTabs or 3) do
        local _, _, points = GetTalentTabInfo(i)
        if points and points > bestPoints then
            bestPoints, bestTab = points, i
        end
    end
    return bestTab, bestPoints
end

local WEAPON_LOC = {
    INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
}
local RANGED_LOC = {
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true,
}
EG.WEAPON_LOC = WEAPON_LOC
EG.RANGED_LOC = RANGED_LOC

--[[ Mehrere Profile im selben Baum (Blut Tank/DD, Frost beidhaendig/Zweihand):
     entschieden wird nach der angelegten Waffenhaltung, sonst gilt das als
     auto markierte Profil.                                                ]]
function EG:PickTabSpec(list, tab)
    local candidates, default = {}, nil
    for _, spec in ipairs(list) do
        if spec.tab == tab then
            candidates[#candidates + 1] = spec
            if spec.auto and not default then default = spec end
        end
    end
    if #candidates == 0 then return nil end
    default = default or candidates[1]
    if #candidates == 1 then return default end

    local mh = self:GetEquippedData(16)
    local oh = self:GetEquippedData(17)
    local style
    if mh and mh.equipLoc == "INVTYPE_2HWEAPON" then
        style = "2H"
    elseif oh and WEAPON_LOC[oh.equipLoc] then
        style = "DW"
    end
    if style then
        for _, spec in ipairs(candidates) do
            if spec.hands == style then return spec end
        end
    end
    return default
end

--[[ Automatische Profilwahl.

       * kaum Talente        -> Leveln (unter 80) bzw. Allround (ab 80)
       * Unter Stufe 80      -> Leveln-Profil der Klasse. Ausnahme: Tank- und
                                Heilbaeume behalten ihr Profil, weil sich dort
                                die Gewichtung grundlegend unterscheidet.
       * Stufe 80            -> Profil des Talentbaums                       ]]
function EG:DetectProfile(class)
    class = class or self:GetPlayerClass()
    local list  = self.SPECS and self.SPECS[class]
    local level = UnitLevel("player") or 1

    local leveling = self:GetProfileByID(self:ClassProfileID(class, "LEVELING"))
                  or self:GetProfileByID("LEVELING")
    local allround = self:GetProfileByID(self:ClassProfileID(class, "ALLROUND")) or leveling

    local tab, points = self:GetDominantTab()

    if not list or not tab or points < 5 then
        if level < HEIRLOOM_MAX_LEVEL then return leveling, true end
        return allround, true
    end

    local spec = self:PickTabSpec(list, tab) or list[1]

    if self.db and self.db.autoLeveling and level < HEIRLOOM_MAX_LEVEL
        and leveling and spec and spec.role ~= "TANK" and spec.role ~= "HEAL" then
        return leveling, true
    end
    return spec, true
end

function EG:GetActiveProfileID()
    return (self.charDB and self.charDB.profile) or "AUTO"
end

function EG:SetActiveProfile(id)
    if not self.charDB then return end
    if id ~= "AUTO" and not self:GetProfileByID(id) then return false end
    self.charDB.profile = id
    self:InvalidateProfile()
    self:WipeItemCache()
    self:RefreshAllBags()
    if self.GUI then self.GUI:Refresh() end
    if self.ProfileGUI then self.ProfileGUI:Refresh() end
    return true
end

function EG:IsPvPMode()
    return (self.charDB and self.charDB.pvp) and true or false
end

function EG:SetPvPMode(on)
    if not self.charDB then return end
    self.charDB.pvp = on and true or false
    self:InvalidateProfile()
    self:RefreshAllBags()
    if self.GUI then self.GUI:Refresh() end
    if self.ProfileGUI then self.ProfileGUI:Refresh() end
end

--[[ Endgueltige Gewichte eines Profils (inklusive PvP-Aufschlag).
     Profile mit Varianten (Leveln fuer Hybridklassen) waehlen die Gewichte
     nach dem Talentbaum mit den meisten Punkten.                          ]]
function EG:GetVariantTab(spec)
    if not (spec and spec.variants) then return nil end
    local tab, points = self:GetDominantTab()
    if tab and points >= 5 and spec.variants[tab] then return tab end
    return nil
end

function EG:GetWeightsFor(spec, withPvP)
    if not spec then return {} end
    local w = spec.weights or {}
    local vt = self:GetVariantTab(spec)
    if vt then w = spec.variants[vt].weights or w end
    if withPvP then w = ApplyPvP(w) end
    return w
end

--[[ Ermittelt das aktive Gewichtungsprofil.
     Rueckgabe: weights (Tabelle), name (String), signature (String)       ]]
function EG:GetProfile()
    if self.profileCache then return self.profileCache.weights,
                                     self.profileCache.name,
                                     self.profileCache.sig end

    local class = self:GetPlayerClass()
    local id    = self:GetActiveProfileID()

    local spec, auto
    if id == "AUTO" then
        spec, auto = self:DetectProfile(class)
    else
        spec = self:GetProfileByID(id)
        if not spec then spec, auto = self:DetectProfile(class) end
    end
    if not spec then
        spec = { id = "LEVELING", weights = {} }
    end

    local pvp     = self:IsPvPMode()
    local weights = self:GetWeightsFor(spec, pvp)

    local label = self:GetProfileName(spec)
    if auto then label = label .. " (" .. L.ROLE_AUTO .. ")" end
    if pvp   then label = label .. " [PvP]" end

    local db = self.db or DEFAULTS
    local sig = class .. ":" .. tostring(spec.id) .. ":" .. tostring(pvp)
        .. ":" .. tostring(UnitLevel("player"))
        .. ":" .. tostring(db.ilvlWeight)
        .. ":" .. tostring(db.ilvlScaling)
        .. ":" .. tostring(db.socketValue)
        .. ":" .. tostring(db.dpsWeight)
        .. ":" .. tostring(db.protectHeirlooms)
        .. ":" .. tostring(db.heirloomBonus)
        .. ":" .. tostring(db.includeEnchants)
        .. ":" .. tostring(self:GetVariantTab(spec))
        .. ":" .. tostring(spec.rev or 0)

    self.profileCache = { weights = weights, name = label, sig = sig,
                          profile = spec.id, spec = spec, auto = auto }
    return weights, label, sig
end

function EG:GetActiveSpec()
    self:GetProfile()
    return self.profileCache and self.profileCache.spec
end

------------------------------------------------------------------------------
-- Eigene Profile
------------------------------------------------------------------------------

function EG:CreateCustomProfile(name, baseID, class)
    if not self.db then return nil end
    self.db.custom = self.db.custom or {}

    name = (name and name ~= "") and name or L.PROFILE

    -- eindeutige ID erzeugen
    local base, n = "CUSTOM_" .. sgsub(name, "[^%w]", ""), 1
    if base == "CUSTOM_" then base = "CUSTOM_PROFILE" end
    local id = base
    while self.db.custom[id] or self:GetProfileByID(id) do
        n = n + 1
        id = base .. n
    end

    local source = baseID and self:GetProfileByID(baseID)
    local weights = {}
    if source then
        local src = self:GetWeightsFor(source, false)
        for k, v in pairs(src) do weights[k] = v end
    end

    self.db.custom[id] = {
        id = id, name = name, custom = true, rev = 1,
        class = class or self:GetPlayerClass(),
        role = source and source.role or "MELEE",
        hands = source and source.hands or nil,
        desc = source and (L.PROFILE .. ": " .. self:GetProfileName(source)) or "",
        weights = weights,
    }
    return id
end

function EG:DeleteCustomProfile(id)
    if not (self.db and self.db.custom and self.db.custom[id]) then return false end
    self.db.custom[id] = nil
    if self:GetActiveProfileID() == id then
        self.charDB.profile = "AUTO"
    end
    self:InvalidateProfile()
    self:RefreshAllBags()
    return true
end

function EG:SetCustomWeight(id, statKey, value)
    local c = self.db and self.db.custom and self.db.custom[id]
    if not c then return false end
    value = tonumber(value)
    if not value or value == 0 then
        c.weights[statKey] = nil
    else
        c.weights[statKey] = value
    end
    c.rev = (c.rev or 1) + 1
    self:InvalidateProfile()
    self:WipeItemCache()
    self:RefreshAllBags()
    return true
end

function EG:RenameCustomProfile(id, name)
    local c = self.db and self.db.custom and self.db.custom[id]
    if not c or not name or name == "" then return false end
    c.name = name
    c.rev = (c.rev or 1) + 1
    self:InvalidateProfile()
    return true
end

function EG:GetProfileKey()
    self:GetProfile()
    return self.profileCache and self.profileCache.profile or "LEVELING"
end

------------------------------------------------------------------------------
-- 07  Item-Daten (mit Cache)
------------------------------------------------------------------------------

EG.itemCache  = {}
EG.tipCache   = {}
local itemCacheCount = 0

function EG:WipeItemCache()
    self.itemCache      = {}
    self.scoreCache     = {}
    self.stateCache     = {}
    self.tipCache       = {}
    self.equippedTotals = nil
    itemCacheCount      = 0
    self.epoch          = (self.epoch or 0) + 1
end

-- Zwischenspeicher fuer Tooltip-Bestandteile, die nur einmal gebaut werden
local statPatternCache, segmentCache, socketBonusPattern

--[[--------------------------------------------------------------------
     Tooltip-Auswertung

     GetItemStats() liest nur die Basiswerte aus dem Itemlink.
     Verzauberungen stehen in SpellItemEnchantment.dbc und tauchen dort
     nicht auf - eine verzauberte Waffe liefert also dieselben Werte wie
     eine unverzauberte. Die einzige verlaessliche Quelle ist der Tooltip,
     denn dort steht die Verzauberung als eigene gruene Zeile.

     Im Tooltip kommen vier Zeilenformen vor:

       "+55 Ausdauer"                                   Basiswerte
       "Ausruesten: Verbessert Tempowertung um 55."     Wertungen
       "+10 Staerke und +15 Ausdauer"                   Edelsteine, Verzauberungen
       "Sockelbonus: +4 Ausdauer"                       Sockelbonus (aktiv: gruen)

     Die ersten beiden werden ueber Muster aus den lokalisierten
     Blizzard-Globals erkannt (ITEM_MOD_X_SHORT und ITEM_MOD_X), vorne und
     hinten verankert, damit Proc-Texte wie "Erhoeht Eure Angriffskraft um
     340 fuer 10 Sek." nicht als dauerhafter Wert gezaehlt werden. Die dritte
     und vierte Form werden segmentweise gelesen: jedes "+Zahl Attributname"
     zaehlt, der Rest der Zeile ("und 3% erhoehter kritischer Schaden") wird
     ignoriert. Zeilen mit Ausruesten-/Benutzen-/Proc-Praefix sind davon
     ausgenommen.
----------------------------------------------------------------------]]

local function BuildStatPatterns()
    if statPatternCache then return statPatternCache end
    statPatternCache = {}

    local equipPrefix = ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:"
    local escPrefix   = EscapePattern(equipPrefix)

    local function Add(key, pattern)
        statPatternCache[#statPatternCache + 1] = { key = key, pattern = pattern }
    end

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

    for _, key in ipairs(STAT_ORDER) do
        -- Kurzform:  "+55 Ausdauer"  /  "524 Ruestung"
        local short = _G[key]
        if short and short ~= "" then
            Add(key, "^%+?([%d%.,]+)%s+" .. EscapePattern(short) .. "%.?$")
        end

        -- Langform:  "Verbessert Tempowertung um 55."
        local longKey = smatch(key, "^(.+)_SHORT$")
        local long    = longKey and _G[longKey]
        if long and long ~= "" then
            local pat = LongTemplateToPattern(long)
            Add(key, "^" .. pat .. "$")
            Add(key, "^" .. escPrefix .. "%s*" .. pat .. "$")
        end
    end

    -- "Sockelbonus: %s"
    local sb = _G.ITEM_SOCKET_BONUS or "Socket Bonus: %s"
    socketBonusPattern = "^" .. TemplateToPattern(sb, "(.+)") .. "$"

    return statPatternCache
end

-- Attributnamen fuer die segmentweise Auswertung, laengste zuerst
-- ("Ruestungsdurchschlag" vor "Ruestung", "Mana alle 5 Sek." vor "Mana")
local function BuildSegmentNames()
    if segmentCache then return segmentCache end
    segmentCache = {}

    local function AddName(key, name)
        if name and name ~= "" then
            local lname = sgsub(slower(name), "%.$", "")
            segmentCache[#segmentCache + 1] = {
                key = key, name = lname, esc = EscapePattern(lname),
            }
        end
    end

    for _, key in ipairs(STAT_ORDER) do AddName(key, _G[key]) end
    AddName("__ALLSTATS", _G.SPELL_STATALL or "All Stats")

    tsort(segmentCache, function(a, b) return #a.name > #b.name end)
    return segmentCache
end

local ALL_STATS = { S.STR, S.AGI, S.STA, S.INT, S.SPI }

local function AddStat(stats, key, value)
    if key == "__ALLSTATS" then
        for _, k in ipairs(ALL_STATS) do stats[k] = (stats[k] or 0) + value end
    else
        stats[key] = (stats[key] or 0) + value
    end
end

-- Liest jedes "+Zahl Attributname" einer Zeile. Gibt zurueck, ob etwas gefunden wurde.
local function ScanSegments(text, stats)
    local work  = slower(text)
    local found = false

    for _, seg in ipairs(BuildSegmentNames()) do
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
                -- Treffer unkenntlich machen, damit kuerzere Namen nicht
                -- noch einmal darauf anspringen
                work = ssub(work, 1, s - 1) .. srep("\1", e - s + 1) .. ssub(work, e + 1)
            end
            init = e + 1
        end
    end
    return found
end
EG.ScanSegments = function(_, text, stats) return ScanSegments(text, stats) end

-- Kopfzeile eines Ausruestungssets: "Name (2/5)"
local SET_HEADER_PATTERN = "^.+%s%((%d+)/(%d+)%)$"

-- Zeilen mit diesen Praefixen sind Effekte, keine festen Werte
local function StartsWithTrigger(text)
    local list = { ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONPROC }
    for _, p in ipairs(list) do
        if p and p ~= "" and ssub(text, 1, #p) == p then return true end
    end
    return false
end

local function IsUniqueLine(text)
    return text == (_G.ITEM_UNIQUE or "Unique")
        or text == (_G.ITEM_UNIQUE_EQUIPPABLE or "Unique-Equipped")
end

--[[ Einmaliger Durchlauf durch den Tooltip.
     Rueckgabe: { reason, dps, stats, hasStats, unique }                   ]]
function EG:ScanItemTooltip(link)
    if not link then return nil end

    local hit = self.tipCache[link]
    if hit then return hit end

    if not SetScanTip(link) then return nil end

    local patterns = BuildStatPatterns()
    local result = { stats = {}, hasStats = false }

    for i = 2, scanTip:NumLines() do
        local fs   = TipLine(i)
        local text = fs and fs:GetText()

        if text and text ~= "" then
            -- Ab der Set-Kopfzeile nicht weiter auswerten: Setboni haengen
            -- an anderen Teilen und wuerden sonst mehrfach gezaehlt.
            if smatch(text, SET_HEADER_PATTERN) then break end

            if IsRed(fs) then
                -- Rote Zeile: nicht verwendbar. Die reine Stufenanforderung
                -- wird an anderer Stelle gesondert gemeldet.
                if not result.reason and not smatch(text, minLevelPattern) then
                    result.reason = text
                end
            elseif not IsGrey(fs) then
                -- Graue Zeilen sind inaktive Sockel- und Setboni.

                if not result.unique and IsUniqueLine(text) then
                    result.unique = true
                end

                if not result.dps then
                    local v = smatch(text, dpsPattern)
                    if v then result.dps = tonumber((sgsub(v, ",", "."))) end
                end

                local matched = false
                for _, p in ipairs(patterns) do
                    local v = smatch(text, p.pattern)
                    if v then
                        v = tonumber((sgsub(v, ",", ".")))
                        if v and v > 0 then
                            -- summieren: Basiswert, Verzauberung und Sockel
                            -- stehen in getrennten Zeilen
                            result.stats[p.key] = (result.stats[p.key] or 0) + v
                            result.hasStats = true
                        end
                        matched = true
                        break
                    end
                end

                if not matched then
                    local bonus = smatch(text, socketBonusPattern)
                    if bonus then
                        -- aktiver Sockelbonus (inaktiv waere grau und uebersprungen)
                        if ScanSegments(bonus, result.stats) then result.hasStats = true end
                    elseif not StartsWithTrigger(text) then
                        -- Edelstein- und Verzauberungszeilen
                        if ScanSegments(text, result.stats) then result.hasStats = true end
                    end
                end
            end
        end
    end

    self.tipCache[link] = result
    return result
end

-- Nur die Werte, fuer Erbstuecke (dort ersetzen sie die Basiswerte)
function EG:ScanStatsFromTooltip(link)
    local scan = self:ScanItemTooltip(link)
    if not scan or not scan.hasStats then return nil end
    return scan.stats
end

--[[ Vollstaendige Itemdaten.
     GetItemInfo() liefert in 3.3.5a 11 Werte; Nr. 11 ist der
     Haendler-Verkaufspreis pro Einheit.

     stats       alles, was zaehlt: Basiswerte, Verzauberung, Steine, Sockelbonus
     baseStats   nur die Basiswerte aus dem Itemlink
     extraStats  der Anteil von Verzauberung und Steinen (stats - baseStats)   ]]
function EG:GetItemData(itemLink)
    if not itemLink or itemLink == "" then return nil end

    local cached = self.itemCache[itemLink]
    if cached then return cached end

    local name, link, quality, itemLevel, minLevel, itemType, itemSubType,
          stackCount, equipLoc, texture, sellPrice = GetItemInfo(itemLink)

    if not name or not itemLevel then
        return nil -- noch nicht im Client-Cache
    end

    local data = {
        name        = name,
        link        = link or itemLink,
        quality     = quality or 0,
        level       = itemLevel or 0,
        baseLevel   = itemLevel or 0,
        minLevel    = minLevel or 0,
        itemType    = itemType,
        itemSubType = itemSubType,
        stackCount  = stackCount or 1,
        equipLoc    = equipLoc,
        texture     = texture,
        sellPrice   = tonumber(sellPrice) or 0,
        id          = tonumber(smatch(itemLink, "item:(%d+)")),
        stats       = {},
        baseStats   = {},
        extraStats  = {},
        sockets     = 0,
        isHeirloom  = (quality == HEIRLOOM_QUALITY),
    }

    -- Basiswerte
    local stats = GetItemStats(data.link)
    if stats then
        for stat, value in pairs(stats) do
            local isSocket = false
            for _, sk in ipairs(SOCKET_KEYS) do
                if stat == sk then
                    data.sockets = data.sockets + (tonumber(value) or 0)
                    isSocket = true
                    break
                end
            end
            if not isSocket then
                local key = STAT_ALIAS[stat] or stat
                data.baseStats[key] = (data.baseStats[key] or 0) + (tonumber(value) or 0)
            end
        end
    end

    -- Verzauberung und Sockelsteine aus dem Link
    local _, enchantId, g1, g2, g3, g4 = self:ParseLink(data.link)
    data.enchantId = enchantId or 0
    data.enchanted = (data.enchantId or 0) > 0
    data.gemCount  = 0
    for _, g in ipairs({ g1 or 0, g2 or 0, g3 or 0, g4 or 0 }) do
        if g > 0 then data.gemCount = data.gemCount + 1 end
    end

    -- Tooltip auswerten (Verwendbarkeit, DPS und die tatsaechlichen Werte)
    local scan = self:ScanItemTooltip(data.link)
    if scan then
        data._tipUsable = (scan.reason == nil)
        data._tipReason = scan.reason
        data.unique     = scan.unique and true or false
    end

    local withEnchants = not (self.db and self.db.includeEnchants == false)

    if data.isHeirloom then
        -- Erbstuecke skalieren mit der Charakterstufe; GetItemStats()
        -- liefert dafuer nicht die angezeigten Werte, deshalb ersetzen
        -- statt zusammenfuehren.
        local playerLevel = UnitLevel("player") or 1
        data.level = mmin(playerLevel, HEIRLOOM_MAX_LEVEL)
        data.estimated = true
        if scan and scan.hasStats then
            for k, v in pairs(scan.stats) do data.stats[k] = v end
        else
            for k, v in pairs(data.baseStats) do data.stats[k] = v end
        end
    else
        for k, v in pairs(data.baseStats) do data.stats[k] = v end

        if withEnchants and scan and scan.hasStats then
            --[[ Verzauberungen und Sockelsteine stehen nur im Tooltip.
                 Zusammengefuehrt wird ueber das Maximum: der Tooltipwert ist
                 die Summe aus Basiswert, Verzauberung und Steinen und damit
                 normalerweise der groessere. Scheitert das Auslesen einer
                 Zeile, bleibt der Basiswert erhalten - so kann nichts
                 verlorengehen und nichts doppelt gezaehlt werden.            ]]
            local socketed = data.enchanted or data.gemCount > 0
            for key, value in pairs(scan.stats) do
                local base = data.stats[key] or 0
                if value > base then
                    data.stats[key] = value
                    -- Als "extra" gilt es nur, wenn der Link tatsaechlich
                    -- Verzauberung oder Steine traegt
                    if socketed then data.extraStats[key] = value - base end
                end
            end
        end
    end
    data.hasExtraStats = next(data.extraStats) ~= nil

    -- Waffen-DPS (Nahkampf und Fernkampf getrennt bewertet)
    if equipLoc and WEAPON_LOC[equipLoc] then
        data.dps = (scan and scan.dps) or 0
        data.handKind = "MELEE"
    elseif equipLoc and RANGED_LOC[equipLoc] then
        data.dps = (scan and scan.dps) or 0
        data.handKind = "RANGED"
    end

    -- Untertyp-Token, Werkzeuge usw.
    self:ClassifyItem(data)

    -- Cache begrenzen, damit lange Sitzungen nicht wachsen
    itemCacheCount = itemCacheCount + 1
    if itemCacheCount > 1200 then
        self:WipeItemCache()
        itemCacheCount = 1
    end
    self.itemCache[itemLink] = data

    return data
end

--[[ Zerlegt den Itemlink.
     Format in 3.3.5a:
       item:id:enchantId:gem1:gem2:gem3:gem4:suffixId:uniqueId:level      ]]
function EG:ParseLink(link)
    if not link then return nil end
    local id, enchant, g1, g2, g3, g4 =
        smatch(link, "item:(%d+):(%d*):(%d*):(%d*):(%d*):(%d*)")
    if not id then return nil end
    return tonumber(id), tonumber(enchant) or 0,
           tonumber(g1) or 0, tonumber(g2) or 0, tonumber(g3) or 0, tonumber(g4) or 0
end

function EG:GetItemIDFromLink(link)
    if not link then return nil end
    return tonumber(smatch(link, "item:(%d+)"))
end

function EG:GetLocalizedStatName(stat)
    if stat == PSEUDO_DPS      then return L.WEAPON_DPS end
    if stat == PSEUDO_RDPS     then return L.RANGED_DPS end
    if stat == PSEUDO_SOCKET   then return L.SOCKETS end
    if stat == PSEUDO_HEIRLOOM then return L.HEIRLOOM_BONUS end
    return _G[stat] or stat
end

------------------------------------------------------------------------------
-- 08  Bewertung & Berechnungsgrundlagen
------------------------------------------------------------------------------

--[[ Wirksames Gewicht der Gegenstandsstufe.

     Die Statgewichte sind auf Stufe-80-Groessenordnungen kalibriert: dort
     traegt ein Item dreistellige Attributwerte, auf Stufe 5 dagegen
     einstellige. Ein fester Punktwert pro Gegenstandsstufe uebertoent
     deshalb im gesamten Levelbereich darunter die eigentlichen Attribute -
     eine Gegenstandsstufe mehr wog dann schwerer als der sechsfache
     Ruestungswert.

     Die Basis waechst daher mit der Charakterstufe und erreicht erst auf
     Stufe 80 das volle Gewicht. Abschaltbar mit /eg ilvlscale.            ]]
function EG:GetEffectiveIlvlWeight()
    local db = self.db or DEFAULTS
    local w = tonumber(db.ilvlWeight) or DEFAULTS.ilvlWeight
    if db.ilvlScaling == false then return w, w, 1 end
    local level  = mmin(UnitLevel("player") or 1, HEIRLOOM_MAX_LEVEL)
    local factor = level / HEIRLOOM_MAX_LEVEL
    return w * factor, w, factor
end

--[[ Erbstueck-Aufschlag auf die Wertung.

     Erbstuecke wachsen mit der Charakterstufe und geben zusaetzlich
     Erfahrung; ein normales Item der Levelphase kann dagegen nicht
     anhalten. Statt einer starren Regel ("Erbstueck gewinnt immer") bekommt
     ein Erbstueck deshalb einen Aufschlag auf seine Wertung:

       * bis Stufe 60 der volle Aufschlag (Standard x1.5)
       * zwischen 60 und 80 linear abnehmend auf x1.0
       * ab Stufe 80 keiner - dort skalieren Erbstuecke nicht mehr

     Ein Erbstueck mit unbrauchbaren Werten (Staerke auf einem Heiler) bleibt
     damit trotzdem schlechter als ein passendes normales Item.            ]]
function EG:GetHeirloomFactor()
    local db = self.db or DEFAULTS
    if db.protectHeirlooms == false then return 1 end
    local level = UnitLevel("player") or 1
    if level >= HEIRLOOM_MAX_LEVEL then return 1 end
    local bonus = tonumber(db.heirloomBonus) or DEFAULTS.heirloomBonus
    if bonus <= 1 then return 1 end
    local t = (HEIRLOOM_MAX_LEVEL - level) / 20
    if t > 1 then t = 1 end
    return 1 + (bonus - 1) * t
end

-- Gilt die Erbstueckregel gerade? (Anzeige, Slash-Befehle)
function EG:HeirloomProtectionActive()
    return self:GetHeirloomFactor() > 1
end

local GEM_PRIMARY = { S.STR, S.AGI, S.INT, S.SP, S.STA }

--[[ Wert eines freien Sockelplatzes.

     Automatisch: ein typischer Stein der Stufe (ca. 0.22 Punkte je Stufe,
     also rund 17 auf Stufe 80) mal dem staerksten Hauptattributgewicht des
     Profils, mit 10 % Abschlag fuer nicht passende Sockelfarbe. Ein fester
     Wert laesst sich mit /eg socket <zahl> setzen.                        ]]
function EG:GetSocketPoints(weights)
    local db = self.db or DEFAULTS
    local override = tonumber(db.socketValue)
    if override then return override end

    weights = weights or self:GetProfile()
    local best = 0
    for _, key in ipairs(GEM_PRIMARY) do
        local w = weights[key]
        if w and w > best then best = w end
    end
    local level = mmin(UnitLevel("player") or 1, HEIRLOOM_MAX_LEVEL)
    return level * 0.22 * best * 0.9
end

--[[ Gewicht der Waffen-DPS: Nahkampf (__DPS) oder Fernkampf (__RDPS, sonst
     __DPS). Ein in den Einstellungen gesetztes dpsWeight gilt fuer beide.  ]]
function EG:GetHandWeight(weights, kind)
    local db = self.db or DEFAULTS
    local override = tonumber(db.dpsWeight)
    if override then return override end
    weights = weights or {}
    if kind == "RANGED" then
        return weights[PSEUDO_RDPS] or weights[PSEUDO_DPS] or 0
    end
    return weights[PSEUDO_DPS] or 0
end

local function IsOffhandWeapon(item, slotID)
    return slotID == 17 and item.handKind == "MELEE"
end

--[[ Liefert Wertung + vollstaendige Berechnungsgrundlage.
     breakdown = Liste von { key, label, value, weight, points }

     slotID ist nur bei Nebenhand-Waffen von Belang: sie verursachen im
     Beidhaendig-Kampf nur den halben Schaden, ihre DPS zaehlen deshalb nur
     zur Haelfte. Fuer alle anderen Items ist der Slot ohne Bedeutung.       ]]
function EG:GetScoreBreakdown(item, slotID)
    local rows, total = {}, 0
    if not item then return rows, 0 end

    local weights = self:GetProfile()

    -- 1) Basis aus der Gegenstandsstufe (mit Charakterstufe skaliert)
    local ilvlWeight = self:GetEffectiveIlvlWeight()
    local ilvlPoints = (item.level or 0) * ilvlWeight
    if ilvlWeight > 0 then
        rows[#rows + 1] = {
            key = "__ILVL", label = L.BASE_ILVL,
            value = item.level or 0, weight = ilvlWeight, points = ilvlPoints,
        }
    end
    total = total + ilvlPoints

    -- 2) Attribute in fester Reihenfolge
    local seen = {}
    for _, key in ipairs(STAT_ORDER) do
        local value = item.stats and item.stats[key]
        if value and value ~= 0 then
            seen[key] = true
            local w = weights[key]
            if w and w ~= 0 then
                local points = value * w
                total = total + points
                rows[#rows + 1] = {
                    key = key, label = self:GetLocalizedStatName(key),
                    value = value, weight = w, points = points,
                }
            end
        end
    end

    -- 3) Attribute, die nicht in STAT_ORDER stehen (Resistenzen o. ae.)
    if item.stats then
        for key, value in pairs(item.stats) do
            if not seen[key] and value ~= 0 then
                local w = weights[key]
                if w and w ~= 0 then
                    local points = value * w
                    total = total + points
                    rows[#rows + 1] = {
                        key = key, label = self:GetLocalizedStatName(key),
                        value = value, weight = w, points = points,
                    }
                end
            end
        end
    end

    -- 4) Waffen-DPS
    if item.dps and item.dps > 0 and item.handKind then
        local w = self:GetHandWeight(weights, item.handKind)
        if IsOffhandWeapon(item, slotID) then w = w * OFFHAND_FACTOR end
        if w ~= 0 then
            local points = item.dps * w
            total = total + points
            rows[#rows + 1] = {
                key = (item.handKind == "RANGED") and PSEUDO_RDPS or PSEUDO_DPS,
                label = (item.handKind == "RANGED") and L.RANGED_DPS or L.WEAPON_DPS,
                value = item.dps, weight = w, points = points,
            }
        end
    end

    -- 5) Freie Sockelplaetze (gefuellte stehen schon in den Attributen)
    if item.sockets and item.sockets > 0 then
        local w = self:GetSocketPoints(weights)
        if w ~= 0 then
            local points = item.sockets * w
            total = total + points
            rows[#rows + 1] = {
                key = PSEUDO_SOCKET, label = L.SOCKETS,
                value = item.sockets, weight = w, points = points,
            }
        end
    end

    -- 6) Erbstueck-Aufschlag
    if item.isHeirloom then
        local f = self:GetHeirloomFactor()
        if f > 1 then
            local points = total * (f - 1)
            rows[#rows + 1] = {
                key = PSEUDO_HEIRLOOM, label = L.HEIRLOOM_BONUS,
                value = total, weight = f - 1, points = points,
            }
            total = total + points
        end
    end

    return rows, total
end

--[[ Summiert alle Werte der angelegten Ausruestung.

     Die Wertung ist linear (Summe aus Gegenstandsstufe x Gewicht und
     Attribut x Gewicht), deshalb ergibt die Summe der Einzelwerte,
     multipliziert mit den Gewichten, exakt dieselbe Gesamtwertung wie das
     Aufaddieren der einzelnen Itemwertungen. Damit laesst sich die
     komplette Ausruestung unter beliebigen Gewichten durchrechnen. Der
     Erbstueck-Aufschlag ist bewusst nicht enthalten - er gehoert zum
     Itemvergleich, nicht zum Profilvergleich.                             ]]
function EG:GetEquippedTotals(force)
    if self.equippedTotals and not force then return self.equippedTotals end

    local t = { __ILVL = 0, __DPS = 0, __RDPS = 0, __SOCKET = 0, __COUNT = 0 }
    for slot = 1, MAX_EQUIP_SLOT do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local item = self:GetItemData(link)
            if item then
                t.__COUNT  = t.__COUNT + 1
                t.__ILVL   = t.__ILVL + (item.level or 0)
                t.__SOCKET = t.__SOCKET + (item.sockets or 0)
                if item.handKind == "MELEE" then
                    local f = IsOffhandWeapon(item, slot) and OFFHAND_FACTOR or 1
                    t.__DPS = t.__DPS + (item.dps or 0) * f
                elseif item.handKind == "RANGED" then
                    t.__RDPS = t.__RDPS + (item.dps or 0)
                end
                if item.stats then
                    for k, v in pairs(item.stats) do
                        t[k] = (t[k] or 0) + v
                    end
                end
            end
        end
    end

    self.equippedTotals = t
    return t
end

function EG:InvalidateEquippedTotals()
    self.equippedTotals = nil
end

--[[ Berechnungsgrundlage fuer eine beliebige Wertesammlung unter
     beliebigen Gewichten. Wird fuer den Profilvergleich benutzt.         ]]
local TOTAL_META = { __ILVL = true, __DPS = true, __RDPS = true, __SOCKET = true, __COUNT = true }

function EG:BuildTotalsBreakdown(totals, weights)
    local rows, total = {}, 0
    if not totals or not weights then return rows, 0 end

    local ilvlWeight = self:GetEffectiveIlvlWeight()
    if ilvlWeight > 0 and (totals.__ILVL or 0) > 0 then
        local pts = totals.__ILVL * ilvlWeight
        total = total + pts
        rows[#rows + 1] = { key = "__ILVL", label = L.BASE_ILVL,
                            value = totals.__ILVL, weight = ilvlWeight, points = pts }
    end

    local seen = {}
    for _, key in ipairs(STAT_ORDER) do
        local v = totals[key]
        local w = weights[key]
        if v and v ~= 0 and w and w ~= 0 then
            seen[key] = true
            local pts = v * w
            total = total + pts
            rows[#rows + 1] = { key = key, label = self:GetLocalizedStatName(key),
                                value = v, weight = w, points = pts }
        end
    end

    for key, v in pairs(totals) do
        if not seen[key] and not TOTAL_META[key] then
            local w = weights[key]
            if v ~= 0 and w and w ~= 0 then
                local pts = v * w
                total = total + pts
                rows[#rows + 1] = { key = key, label = self:GetLocalizedStatName(key),
                                    value = v, weight = w, points = pts }
            end
        end
    end

    local dw = self:GetHandWeight(weights, "MELEE")
    if (totals.__DPS or 0) > 0 and dw ~= 0 then
        local pts = totals.__DPS * dw
        total = total + pts
        rows[#rows + 1] = { key = PSEUDO_DPS, label = L.WEAPON_DPS,
                            value = totals.__DPS, weight = dw, points = pts }
    end

    local rw = self:GetHandWeight(weights, "RANGED")
    if (totals.__RDPS or 0) > 0 and rw ~= 0 then
        local pts = totals.__RDPS * rw
        total = total + pts
        rows[#rows + 1] = { key = PSEUDO_RDPS, label = L.RANGED_DPS,
                            value = totals.__RDPS, weight = rw, points = pts }
    end

    local sw = self:GetSocketPoints(weights)
    if (totals.__SOCKET or 0) > 0 and sw ~= 0 then
        local pts = totals.__SOCKET * sw
        total = total + pts
        rows[#rows + 1] = { key = PSEUDO_SOCKET, label = L.SOCKETS,
                            value = totals.__SOCKET, weight = sw, points = pts }
    end

    return rows, total
end

-- Wertung eines einzelnen Items unter beliebigen Gewichten
function EG:GetItemScoreUnder(item, weights)
    if not item or not weights then return 0 end
    local saved = self.profileCache
    self.profileCache = { weights = weights, name = "tmp", profile = "tmp" }
    local ok, _, total = pcall(self.GetScoreBreakdown, self, item)
    self.profileCache = saved
    return ok and total or 0
end

function EG:GetItemScore(item, slotID)
    if not item then return 0 end
    local key = item.link
    if key then
        local sk = IsOffhandWeapon(item, slotID) and "o" or "m"
        local _, _, sig = self:GetProfile()
        local cacheKey = sig .. "|" .. key .. "|" .. sk
        local hit = self.scoreCache[cacheKey]
        if hit then return hit end
        local _, total = self:GetScoreBreakdown(item, slotID)
        self.scoreCache[cacheKey] = total
        return total
    end
    local _, total = self:GetScoreBreakdown(item, slotID)
    return total
end

function EG:GetLinkScore(link)
    local item = self:GetItemData(link)
    if not item then return 0 end
    return self:GetItemScore(item)
end

--[[ Punkte, die ein Item allein durch Verzauberung und Sockelsteine traegt.
     Wichtig fuer die Einordnung: ein neues Item kommt unverzaubert, das
     angelegte ist es meist.                                               ]]
function EG:GetExtraPoints(item)
    if not (item and item.extraStats and item.hasExtraStats) then return 0 end
    local weights = self:GetProfile()
    local pts = 0
    for key, v in pairs(item.extraStats) do
        local w = weights[key]
        if w and w ~= 0 then pts = pts + v * w end
    end
    return pts
end

--[[ Attribut-Unterschiede zwischen einem Kandidaten und den Items, die er
     ersetzt. targets = Liste von { item, slotID }. Rueckgabe: sortierte Liste
     { key, label, delta, points } - nur Attribute, die das Profil bewertet. ]]
function EG:GetStatDiff(item, targets)
    local out = {}
    if not item then return out end
    local weights = self:GetProfile()

    local tstats, tdps, trdps = {}, 0, 0
    for _, t in ipairs(targets or {}) do
        local ti = t.item
        if ti then
            for k, v in pairs(ti.stats or {}) do tstats[k] = (tstats[k] or 0) + v end
            if ti.handKind == "MELEE" then
                tdps = tdps + (ti.dps or 0) * (IsOffhandWeapon(ti, t.slotID) and OFFHAND_FACTOR or 1)
            elseif ti.handKind == "RANGED" then
                trdps = trdps + (ti.dps or 0)
            end
        end
    end

    local keys, seen = {}, {}
    for k in pairs(item.stats or {}) do if not seen[k] then seen[k] = true; keys[#keys + 1] = k end end
    for k in pairs(tstats) do if not seen[k] then seen[k] = true; keys[#keys + 1] = k end end

    for _, k in ipairs(keys) do
        local w = weights[k]
        if w and w ~= 0 then
            local d = ((item.stats and item.stats[k]) or 0) - (tstats[k] or 0)
            if d ~= 0 then
                out[#out + 1] = { key = k, label = self:GetLocalizedStatName(k),
                                  delta = d, points = d * w }
            end
        end
    end

    -- Waffen-DPS
    if item.handKind then
        local cand = item.dps or 0
        local w = self:GetHandWeight(weights, item.handKind)
        local have = (item.handKind == "RANGED") and trdps or tdps
        local d = cand - have
        if w ~= 0 and d ~= 0 and (cand > 0 or have > 0) then
            out[#out + 1] = {
                key = (item.handKind == "RANGED") and PSEUDO_RDPS or PSEUDO_DPS,
                label = (item.handKind == "RANGED") and L.RANGED_DPS or L.WEAPON_DPS,
                delta = d, points = d * w, decimals = 1,
            }
        end
    end

    tsort(out, function(a, b)
        local pa, pb = (a.points < 0) and -a.points or a.points, (b.points < 0) and -b.points or b.points
        return pa > pb
    end)
    return out
end

------------------------------------------------------------------------------
-- 09  Slot-Aufloesung
------------------------------------------------------------------------------

local SLOT_NAME_GLOBALS = {
    [1]="HEADSLOT", [2]="NECKSLOT", [3]="SHOULDERSLOT", [4]="SHIRTSLOT",
    [5]="CHESTSLOT", [6]="WAISTSLOT", [7]="LEGSSLOT", [8]="FEETSLOT",
    [9]="WRISTSLOT", [10]="HANDSSLOT", [11]="FINGER0SLOT", [12]="FINGER1SLOT",
    [13]="TRINKET0SLOT", [14]="TRINKET1SLOT", [15]="BACKSLOT",
    [16]="MAINHANDSLOT", [17]="SECONDARYHANDSLOT", [18]="RANGEDSLOT",
    [19]="TABARDSLOT",
}

-- Notnamen, falls ein Global fehlt (kommt in der Praxis nicht vor)
local SLOT_NAME_FALLBACK = {
    [1]="Head", [2]="Neck", [3]="Shoulder", [4]="Shirt", [5]="Chest",
    [6]="Waist", [7]="Legs", [8]="Feet", [9]="Wrist", [10]="Hands",
    [11]="Finger", [12]="Finger", [13]="Trinket", [14]="Trinket",
    [15]="Back", [16]="Main Hand", [17]="Off Hand", [18]="Ranged",
    [19]="Tabard",
}

--[[ Blizzard liefert fuer beide Ring- und beide Schmuckslots denselben
     lokalisierten String (deDE: zweimal "Schmuck", zweimal "Ring"). Damit
     sich Slot 1 und Slot 2 unterscheiden lassen, wird in diesem Fall
     nummeriert.                                                           ]]
local SLOT_PAIRS = {
    [11] = { partner = 12, index = 1 },
    [12] = { partner = 11, index = 2 },
    [13] = { partner = 14, index = 1 },
    [14] = { partner = 13, index = 2 },
}

local function RawSlotName(slotID)
    local g = SLOT_NAME_GLOBALS[slotID]
    local name = g and _G[g]
    if name and name ~= "" then return name end
    return SLOT_NAME_FALLBACK[slotID] or tostring(slotID)
end

function EG:GetSlotName(slotID)
    if type(slotID) == "table" then
        local names = {}
        for _, id in ipairs(slotID) do names[#names + 1] = self:GetSlotName(id) end
        return tconcat(names, " / ")
    end
    slotID = tonumber(slotID)
    if not slotID then return "?" end

    local name = RawSlotName(slotID)
    local pair = SLOT_PAIRS[slotID]
    if pair and name == RawSlotName(pair.partner) then
        name = name .. " " .. pair.index
    end
    return name
end

-- Klassen, die grundsaetzlich beidhaendig kaempfen koennen (Mindeststufe)
local DUAL_WIELD_CLASSES = {
    WARRIOR = 20, ROGUE = 10, HUNTER = 20, SHAMAN = 40, DEATHKNIGHT = 55,
}

--[[ Beidhaendigkeit.
     Der Schamane lernt sie nur ueber das Verstaerkungs-Talent; erkannt wird
     es am (sprachunabhaengigen) Talentsymbol. Sicherheitsnetz fuer alle: ist
     in der Schildhand bereits eine Waffe angelegt, geht es offenbar.      ]]
function EG:CanDualWield()
    local _, class = UnitClass("player")
    local req = DUAL_WIELD_CLASSES[class or ""]
    if not req then return false end

    local off = GetInventoryItemLink("player", 17)
    if off then
        local d = self:GetItemData(off)
        if d and (d.equipLoc == "INVTYPE_WEAPON" or d.equipLoc == "INVTYPE_WEAPONOFFHAND") then
            return true
        end
    end

    if (UnitLevel("player") or 1) < req then return false end

    if class == "SHAMAN" then
        if self.hasDW == nil then
            self.hasDW = self:HasTalentIcon("Ability_DualWield")
        end
        return self.hasDW
    end
    return true
end

--[[ Titanengriff: der Krieger fuehrt zwei Zweihandwaffen. Erkannt am
     Talentsymbol oder - als Sicherheitsnetz - daran, dass bereits in beiden
     Haenden eine Zweihandwaffe liegt.                                      ]]
function EG:HasTitansGrip()
    local _, class = UnitClass("player")
    if class ~= "WARRIOR" then return false end

    local mh, oh = self:GetEquippedData(16), self:GetEquippedData(17)
    if mh and oh and mh.equipLoc == "INVTYPE_2HWEAPON" and oh.equipLoc == "INVTYPE_2HWEAPON" then
        return true
    end

    if self.hasTG == nil then
        self.hasTG = self:HasTalentIcon("TitansGrip")
    end
    return self.hasTG
end

local EQUIP_LOC_SLOTS = {
    INVTYPE_HEAD            = { 1 },
    INVTYPE_NECK            = { 2 },
    INVTYPE_SHOULDER        = { 3 },
    INVTYPE_BODY            = { 4 },
    INVTYPE_CHEST           = { 5 },
    INVTYPE_ROBE            = { 5 },
    INVTYPE_WAIST           = { 6 },
    INVTYPE_LEGS            = { 7 },
    INVTYPE_FEET            = { 8 },
    INVTYPE_WRIST           = { 9 },
    INVTYPE_HAND            = { 10 },
    INVTYPE_FINGER          = { 11, 12 },
    INVTYPE_TRINKET         = { 13, 14 },
    INVTYPE_CLOAK           = { 15 },
    INVTYPE_WEAPON          = { 16, 17 },
    INVTYPE_2HWEAPON        = { 16, 17 },
    INVTYPE_WEAPONMAINHAND  = { 16 },
    INVTYPE_WEAPONOFFHAND   = { 17 },
    INVTYPE_SHIELD          = { 17 },
    INVTYPE_HOLDABLE        = { 17 },
    INVTYPE_RANGED          = { 18 },
    INVTYPE_RANGEDRIGHT     = { 18 },
    INVTYPE_THROWN          = { 18 },
    INVTYPE_RELIC           = { 18 },
    INVTYPE_TABARD          = { 19 },
}
EG.EQUIP_LOC_SLOTS = EQUIP_LOC_SLOTS

-- Hemd und Wappenrock tragen keine Werte - sie werden nie als Verbesserung markiert
local COSMETIC_LOC = { INVTYPE_BODY = true, INVTYPE_TABARD = true }

local OFFHAND_LOCS = {
    INVTYPE_SHIELD        = true,
    INVTYPE_HOLDABLE      = true,
    INVTYPE_WEAPONOFFHAND = true,
}

-- Fuehrt der Charakter gerade eine Zweihandwaffe?
function EG:HasTwoHandEquipped()
    local mh = self:GetEquippedData(16)
    return (mh and mh.equipLoc == "INVTYPE_2HWEAPON") and true or false
end

--[[ Darf eine Einhandwaffe auch in die Schildhand?

     Beidhaendigkeit allein reicht nicht: ein Schutzkrieger kann zwar
     beidhaendig kaempfen, traegt aber ein Schild. Fuer Tank-, Heiler- und
     Zauberprofile gilt die Schildhand deshalb nur dann als Waffenplatz, wenn
     dort schon eine Waffe liegt.                                          ]]
function EG:WantsDualWield()
    if not self:CanDualWield() then return false end
    local spec = self:GetActiveSpec()
    local role = spec and spec.role
    if role == "TANK" or role == "HEAL" or role == "CASTER" then
        local oh = self:GetEquippedData(17)
        return (oh and (oh.equipLoc == "INVTYPE_WEAPON" or oh.equipLoc == "INVTYPE_WEAPONOFFHAND")) and true or false
    end
    return true
end

--[[ Liefert die relevanten Ausruestungsslots.
     Rueckgabe: slots (Tabelle), mode, candSlot
       mode = "SINGLE"  ein Slot
       mode = "EITHER"  einer von mehreren (Ringe, Schmuck, Einhandwaffen,
                        Zweihandwaffen mit Titanengriff)
       mode = "BOTH"    ersetzt alle genannten Slots (Zweihandwaffe, oder ein
                        Schild bei gefuehrter Zweihandwaffe)
       candSlot         Slot, in dem der Kandidat bei "BOTH" landet          ]]
function EG:GetEquipSlots(itemOrLink)
    local item = type(itemOrLink) == "table" and itemOrLink or self:GetItemData(itemOrLink)
    if not item or not item.equipLoc then return nil end

    local loc = item.equipLoc
    local slots = EQUIP_LOC_SLOTS[loc]
    if not slots then return nil end

    if loc == "INVTYPE_2HWEAPON" then
        if self:HasTitansGrip() then
            return { 16, 17 }, "EITHER"
        end
        return { 16, 17 }, "BOTH", 16
    end

    --[[ Solange eine Zweihandwaffe gefuehrt wird, ist die Schildhand nicht
         frei verfuegbar - sie wird von der Zweihandwaffe belegt.

         Ein Schild oder Nebenhand-Item anzulegen kostet also die komplette
         Zweihandwaffe. Verglichen wird deshalb gegen Waffenhand UND
         Schildhand zusammen, nicht gegen den scheinbar leeren Slot 17.
         Sonst gilt jedes beliebige Nebenhand-Item als Verbesserung, weil
         der leere Slot mit 0 Punkten bewertet wird.                       ]]
    if OFFHAND_LOCS[loc] then
        if self:HasTwoHandEquipped() then
            return { 16, 17 }, "BOTH", 17
        end
        return { 17 }, "SINGLE"
    end

    if loc == "INVTYPE_WEAPON" then
        -- Einhandwaffe: bei gefuehrter Zweihandwaffe geht sie nur in die
        -- Waffenhand und ersetzt dort die Zweihandwaffe.
        if self:HasTwoHandEquipped() and not self:HasTitansGrip() then
            return { 16 }, "SINGLE"
        end
        if self:WantsDualWield() then
            return { 16, 17 }, "EITHER"
        end
        return { 16 }, "SINGLE"
    end

    if #slots > 1 then
        return slots, "EITHER"
    end

    return slots, "SINGLE"
end

-- Rueckwaertskompatible Fassung der alten API
function EG:GetEquipSlot(itemLink)
    local slots = self:GetEquipSlots(itemLink)
    if not slots then return nil end
    if #slots == 1 then return slots[1] end
    return slots
end

-- Wichtig: das gecachte Item-Objekt darf NICHT mit slotID mutiert werden,
-- sonst teilen sich zwei identische Ringe denselben Slot-Eintrag.
function EG:GetEquippedData(slotID)
    local link = GetInventoryItemLink("player", slotID)
    if not link then return nil end
    local item = self:GetItemData(link)
    if not item then return nil end
    return item, link
end

------------------------------------------------------------------------------
-- 10  Verwendbarkeit
------------------------------------------------------------------------------

--[[ Untertypen -> sprachunabhaengiges Token (CLOTH, PLATE, AXE2, ...).

     GetItemInfo() liefert den Untertyp nur als lokalisierten Text. Damit die
     Zuordnung in jeder Clientsprache klappt, wird sie in dieser Reihenfolge
     aufgebaut:

       1. Aus den Kategorielisten des Auktionshauses, die der Client in
          seiner Sprache und in fester Reihenfolge fuehrt
          (GetAuctionItemSubClasses). Das braucht keinerlei Textkenntnis.
       2. Aus den Namen in den Sprachdateien (SUBTYPE_<TOKEN>, mehrere
          Schreibweisen mit | getrennt) fuer alles, was Schritt 1 nicht
          liefert.

     Jedes Token wird zusaetzlich gegen den Ausruestungsplatz des Items
     geprueft; passt es nicht, wird es verworfen. Faellt die Zuordnung
     dadurch mehrfach auf, wird Schritt 1 abgeschaltet.                    ]]
local WEAPON_SUB_ORDER = {
    "AXE1", "AXE2", "BOW", "GUN", "MACE1", "MACE2", "POLEARM", "SWORD1", "SWORD2",
    "STAFF", "FIST", "MISC", "DAGGER", "THROWN", "CROSSBOW", "WAND", "FISHING",
}
local ARMOR_SUB_ORDER = {
    "MISC", "CLOTH", "LEATHER", "MAIL", "PLATE", "SHIELD", "LIBRAM", "IDOL", "TOTEM", "SIGIL",
}
EG.WEAPON_SUB_ORDER = WEAPON_SUB_ORDER
EG.ARMOR_SUB_ORDER  = ARMOR_SUB_ORDER

local ALL_TOKENS = {}
for _, t in ipairs(WEAPON_SUB_ORDER) do ALL_TOKENS[t] = true end
for _, t in ipairs(ARMOR_SUB_ORDER)  do ALL_TOKENS[t] = true end

local SUBTYPE_TOKEN = {}     -- kleingeschriebener Name -> Token
local subtypeSource = {}     -- Token -> "client" | "lang"

local function RegisterSubtype(token, name, source)
    if name and name ~= "" then
        local key = slower(name)
        if not SUBTYPE_TOKEN[key] then
            SUBTYPE_TOKEN[key] = token
            subtypeSource[token] = subtypeSource[token] or source
        end
    end
end

-- Welche Untertypen sind an welchem Ausruestungsplatz ueberhaupt moeglich?
local ARMOR_TOKENS = { CLOTH = true, LEATHER = true, MAIL = true, PLATE = true, MISC = true }
local LOC_TOKENS = {
    INVTYPE_HEAD = ARMOR_TOKENS, INVTYPE_SHOULDER = ARMOR_TOKENS, INVTYPE_CHEST = ARMOR_TOKENS,
    INVTYPE_ROBE = ARMOR_TOKENS, INVTYPE_WAIST = ARMOR_TOKENS, INVTYPE_LEGS = ARMOR_TOKENS,
    INVTYPE_FEET = ARMOR_TOKENS, INVTYPE_WRIST = ARMOR_TOKENS, INVTYPE_HAND = ARMOR_TOKENS,
    INVTYPE_CLOAK = ARMOR_TOKENS,
    INVTYPE_SHIELD = { SHIELD = true },
    INVTYPE_RELIC = { LIBRAM = true, IDOL = true, TOTEM = true, SIGIL = true },
    INVTYPE_THROWN = { THROWN = true },
    INVTYPE_RANGED = { BOW = true, CROSSBOW = true, GUN = true },
    INVTYPE_RANGEDRIGHT = { GUN = true, CROSSBOW = true, WAND = true, BOW = true },
    INVTYPE_2HWEAPON = { AXE2 = true, MACE2 = true, SWORD2 = true, POLEARM = true, STAFF = true,
                         FISHING = true, MISC = true, FIST = true },
    INVTYPE_WEAPON = { AXE1 = true, MACE1 = true, SWORD1 = true, DAGGER = true, FIST = true, MISC = true },
    INVTYPE_WEAPONMAINHAND = { AXE1 = true, MACE1 = true, SWORD1 = true, DAGGER = true, FIST = true, MISC = true },
    INVTYPE_WEAPONOFFHAND  = { AXE1 = true, MACE1 = true, SWORD1 = true, DAGGER = true, FIST = true, MISC = true },
}

function EG:BuildSubtypeTokens(useClientLists)
    SUBTYPE_TOKEN, subtypeSource = {}, {}

    if useClientLists and GetAuctionItemSubClasses then
        local function Map(classIndex, order)
            local list = { GetAuctionItemSubClasses(classIndex) }
            if #list ~= #order then return false end
            for i, name in ipairs(list) do RegisterSubtype(order[i], name, "client") end
            return true
        end
        self.subtypeFromClient = (Map(1, WEAPON_SUB_ORDER) and Map(2, ARMOR_SUB_ORDER)) and true or false
    else
        self.subtypeFromClient = false
    end

    -- Namen aus den Sprachdateien: Clientsprache zuerst, dann Englisch
    for token in pairs(ALL_TOKENS) do
        local key = "SUBTYPE_" .. token
        for _, name in ipairs(SplitAliases(L[key] ~= key and L[key] or "")) do
            RegisterSubtype(token, name, "lang")
        end
        local en = EasyGearLocales and EasyGearLocales.enUS
        if en and en[key] then
            for _, name in ipairs(SplitAliases(en[key])) do RegisterSubtype(token, name, "lang") end
        end
    end
    self.subtypeBuilt = true
    self.subtypeMismatch = 0
end

function EG:GetSubtypeToken(subType)
    if not subType or subType == "" then return nil end
    if not self.subtypeBuilt then self:BuildSubtypeTokens(true) end
    return SUBTYPE_TOKEN[slower(subType)]
end

--[[ Ergaenzt ein Item um sein Untertyp-Token und markiert Werkzeuge
     (Angelruten, Spitzhacken ...), die nie als Verbesserung gelten.        ]]
function EG:ClassifyItem(data)
    local token = self:GetSubtypeToken(data.itemSubType)

    -- Plausibilitaet: passt das Token zum Ausruestungsplatz?
    local allowed = data.equipLoc and LOC_TOKENS[data.equipLoc]
    if token and allowed and not allowed[token] then
        self.subtypeMismatch = (self.subtypeMismatch or 0) + 1
        if self.subtypeMismatch == 3 and self.subtypeFromClient then
            -- Die Reihenfolge der Auktionshaus-Listen stimmt hier offenbar
            -- nicht - nur noch die Namen aus den Sprachdateien benutzen.
            self:BuildSubtypeTokens(false)
            self.subtypeMismatch = 3
            if self.itemCache then self.itemCache = {} end
        end
        token = nil
    end
    -- Ein Schild ist immer ein Schild, egal wie der Untertyp heisst
    if data.equipLoc == "INVTYPE_SHIELD" and not token then token = "SHIELD" end

    data.token = token
    data.isCosmetic = COSMETIC_LOC[data.equipLoc] and true or false
    data.isTool = (data.handKind == "MELEE" and (token == "FISHING" or token == "MISC")) and true or false
    return data
end

-- Ruestungsklasse -> ab welcher Charakterstufe tragbar
local ARMOR_PROFICIENCY = {
    WARRIOR     = { CLOTH = 1, LEATHER = 1, MAIL = 1,  PLATE = 40, SHIELD = 1 },
    PALADIN     = { CLOTH = 1, LEATHER = 1, MAIL = 1,  PLATE = 40, SHIELD = 1, LIBRAM = 1 },
    DEATHKNIGHT = { CLOTH = 1, LEATHER = 1, MAIL = 1,  PLATE = 1,  SIGIL = 1 },
    HUNTER      = { CLOTH = 1, LEATHER = 1, MAIL = 40 },
    SHAMAN      = { CLOTH = 1, LEATHER = 1, MAIL = 40, SHIELD = 1, TOTEM = 1 },
    ROGUE       = { CLOTH = 1, LEATHER = 1 },
    DRUID       = { CLOTH = 1, LEATHER = 1, IDOL = 1 },
    PRIEST      = { CLOTH = 1 },
    MAGE        = { CLOTH = 1 },
    WARLOCK     = { CLOTH = 1 },
}

-- Waffenkenntnisse (WotLK 3.3.5a)
local WEAPON_PROFICIENCY = {
    WARRIOR = { AXE1=1, AXE2=1, MACE1=1, MACE2=1, SWORD1=1, SWORD2=1, DAGGER=1,
                FIST=1, POLEARM=1, STAFF=1, BOW=1, GUN=1, CROSSBOW=1, THROWN=1 },
    PALADIN = { AXE1=1, AXE2=1, MACE1=1, MACE2=1, SWORD1=1, SWORD2=1, POLEARM=1 },
    HUNTER  = { AXE1=1, AXE2=1, SWORD1=1, SWORD2=1, DAGGER=1, FIST=1, POLEARM=1,
                STAFF=1, BOW=1, GUN=1, CROSSBOW=1, THROWN=1 },
    ROGUE   = { DAGGER=1, FIST=1, AXE1=1, MACE1=1, SWORD1=1,
                BOW=1, GUN=1, CROSSBOW=1, THROWN=1 },
    PRIEST  = { DAGGER=1, MACE1=1, STAFF=1, WAND=1 },
    SHAMAN  = { AXE1=1, AXE2=1, MACE1=1, MACE2=1, DAGGER=1, FIST=1, STAFF=1 },
    MAGE    = { DAGGER=1, SWORD1=1, STAFF=1, WAND=1 },
    WARLOCK = { DAGGER=1, SWORD1=1, STAFF=1, WAND=1 },
    DRUID   = { DAGGER=1, FIST=1, MACE1=1, MACE2=1, POLEARM=1, STAFF=1 },
    DEATHKNIGHT = { AXE1=1, AXE2=1, MACE1=1, MACE2=1, SWORD1=1, SWORD2=1, POLEARM=1 },
}
EG.ARMOR_PROFICIENCY  = ARMOR_PROFICIENCY
EG.WEAPON_PROFICIENCY = WEAPON_PROFICIENCY

-- Untertypen, die jede Klasse tragen kann (Hals, Ring, Schmuck, Halteitems, ...)
local FREE_TOKENS = { MISC = true, FISHING = true }

--[[ Ab welcher Stufe darf die Klasse dieses Token tragen? nil = nie.

     Erbstueck-Ruestung wechselt mit Stufe 40 die Klasse: Kette zaehlt
     darunter als Leder, Platte als Kette. Ein Schamane kann die
     Todesbotenbrustplatte also ab Stufe 1 tragen, Krieger und Paladine die
     Plattenteile ebenfalls. Sie koennen es, sobald sie die Ruestungsklasse
     ueberhaupt beherrschen - die Stufenanforderung entfaellt.             ]]
function EG:GetProficiencyLevel(class, token, heirloom)
    if not token or FREE_TOKENS[token] then return 1 end
    local armorReq  = ARMOR_PROFICIENCY[class]  and ARMOR_PROFICIENCY[class][token]
    local weaponReq = WEAPON_PROFICIENCY[class] and WEAPON_PROFICIENCY[class][token]
    local req = armorReq or weaponReq
    if not req then return nil end
    if heirloom and (token == "MAIL" or token == "PLATE") then req = 1 end
    return req
end

--[[ Rueckgabe: usable (bool), reason (string|nil), levelTooLow (bool)     ]]
function EG:CanUseItem(itemOrLink)
    local item = type(itemOrLink) == "table" and itemOrLink or self:GetItemData(itemOrLink)
    if not item then return false, L.INVALID_ITEM end
    if not item.equipLoc or item.equipLoc == "" then
        return false, L.R_CLASS
    end
    if not EQUIP_LOC_SLOTS[item.equipLoc] then
        return false, L.R_CLASS
    end

    local level = UnitLevel("player") or 1

    -- Stufenanforderung
    local levelTooLow = (item.minLevel or 0) > level

    local _, class = UnitClass("player")
    class = class or ""

    -- Hemd und Wappenrock kann jeder tragen
    if item.equipLoc == "INVTYPE_BODY" or item.equipLoc == "INVTYPE_TABARD" then
        return not levelTooLow, levelTooLow and sformat(L.R_LEVEL, item.minLevel) or nil, levelTooLow
    end

    local token = item.token

    if token and not FREE_TOKENS[token] then
        local req = self:GetProficiencyLevel(class, token, item.isHeirloom)
        if not req then
            -- Untertyp ist fuer diese Klasse nicht vorgesehen
            return false, L.R_CLASS
        end
        if level < req then
            return false, sformat(L.R_LEVEL, req), true
        end
    end

    -- Tooltip-Check: deckt Klassenbindung, Ruf, Rasse und Beruf ab.
    -- Ergebnis am Item merken - der Scan ist vergleichsweise teuer und das
    -- Ergebnis aendert sich nur bei Stufenaufstieg (dann wird der Cache
    -- ohnehin komplett verworfen).
    if item._tipUsable == nil then
        local u, r = self:TooltipUsable(item.link)
        item._tipUsable = (u ~= false)
        item._tipReason = r
    end
    if item._tipUsable == false then
        return false, item._tipReason or L.R_CLASS
    end

    if levelTooLow then
        return false, sformat(L.R_LEVEL, item.minLevel), true
    end

    return true
end

-- Alte API beibehalten
function EG:CanEquipItem(link)
    local ok = self:CanUseItem(link)
    return ok and true or false
end

function EG:IsItemLevelTooHigh(link)
    local item = self:GetItemData(link)
    if not item then return false end
    return (item.minLevel or 0) > (UnitLevel("player") or 1)
end

-- Ist das Item ein Erbstueck? (reine Qualitaetspruefung)
function EG:IsHeirloomItem(item)
    return (item and item.quality == HEIRLOOM_QUALITY) and true or false
end

-- Alte API: Erbstueck UND Regel aktiv
function EG:IsHeirloom(item)
    return self:IsHeirloomItem(item) and self:HeirloomProtectionActive()
end

------------------------------------------------------------------------------
-- 11  Vergleichs-Engine
------------------------------------------------------------------------------

--[[ Zentrale Auswertung. Alle Anzeigen (Chat, GUI, Taschen, Quest, Haendler)
     bauen auf dieses Ergebnis auf.

     Verglichen wird je Ausruestungsslot: der Kandidat wird in jeden moeglichen
     Slot "eingesetzt" und mit dem dort angelegten Item verglichen. Der Slot
     mit dem groessten Zugewinn gewinnt. Dadurch stimmen alle Sonderfaelle
     von selbst:

       * Ringe, Schmuck        der schwaechere der beiden Plaetze
       * Einhandwaffen         Waffenhand oder Schildhand - die Schildhand
                               zaehlt Waffen-DPS nur zur Haelfte
       * Zweihandwaffe         Waffenhand und Schildhand zusammen; mit
                               Titanengriff stattdessen einer der beiden
       * Schild bei Zweihaender  gegen Waffenhand + Schildhand zusammen
       * einzigartige Items    ein zweites Exemplar ersetzt das erste

     result = {
       item, score, breakdown (nur mit detail),
       slots, mode, slotName,
       equipped   = { { item, link, slotID, score, breakdown, empty }, ... },
       target     = Eintrag aus equipped, gegen den verglichen wird
       targetScore, delta, threshold, wouldUpgrade, isUpgrade, combined,
       usable, reason, levelTooLow, note
     }                                                                     ]]
function EG:Compare(itemLink, detail)
    local item = self:GetItemData(itemLink)
    if not item then return nil end

    local result = { item = item, equipped = {} }

    local usable, reason, levelTooLow = self:CanUseItem(item)
    result.usable      = usable
    result.reason      = reason
    result.levelTooLow = levelTooLow and true or false

    local slots, mode, candSlot = self:GetEquipSlots(item)
    result.slots = slots
    result.mode  = mode
    result.slotName = slots and self:GetSlotName(slots) or (item.equipLoc or "?")

    if not slots or item.isTool or item.isCosmetic then
        result.score = self:GetItemScore(item)
        if detail then result.breakdown = (self:GetScoreBreakdown(item)) end
        result.isUpgrade    = false
        result.wouldUpgrade = false
        result.noCompare    = true
        return result
    end

    -- Angelegte Gegenstuecke einsammeln
    for _, slotID in ipairs(slots) do
        local link = GetInventoryItemLink("player", slotID)
        if link then
            local eq = self:GetItemData(link)
            if not eq then return nil end   -- noch nicht im Client-Cache
            local entry = {
                item = eq, link = link, slotID = slotID,
                score = self:GetItemScore(eq, slotID),
                isHeirloom = eq.isHeirloom,
            }
            if detail then entry.breakdown = (self:GetScoreBreakdown(eq, slotID)) end
            result.equipped[#result.equipped + 1] = entry
        else
            result.equipped[#result.equipped + 1] = {
                item = nil, link = nil, slotID = slotID,
                score = 0, breakdown = {}, empty = true,
            }
        end
    end

    -- Den Slot mit dem groessten Zugewinn bestimmen
    local best
    if mode == "BOTH" then
        -- beide Haende zusammen
        local sum = 0
        for _, e in ipairs(result.equipped) do sum = sum + (e.score or 0) end
        local target = result.equipped[1]
        for _, e in ipairs(result.equipped) do
            if e.item and e.item.equipLoc == "INVTYPE_2HWEAPON" then target = e break end
        end
        best = { entry = target, cs = self:GetItemScore(item, candSlot), es = sum, slot = candSlot }
        result.combined = true
    else
        local pool = result.equipped

        -- Einzigartige Items: ein zweites Exemplar darf nicht daneben, es
        -- ersetzt das angelegte.
        if item.unique and #pool > 1 then
            for _, e in ipairs(pool) do
                if e.item and e.item.id == item.id then pool = { e } break end
            end
        end

        for _, e in ipairs(pool) do
            local cs = self:GetItemScore(item, e.slotID)
            local es = e.score or 0
            local d  = cs - es
            if not best or d > best.d + 1e-9 or (d > best.d - 1e-9 and es < best.es) then
                best = { entry = e, cs = cs, es = es, d = d, slot = e.slotID }
            end
        end
    end

    result.target      = best.entry
    result.targetScore = best.es
    result.score       = best.cs
    result.candSlot    = best.slot
    result.delta       = best.cs - best.es

    if detail then result.breakdown = (self:GetScoreBreakdown(item, best.slot)) end

    --[[ Schwelle fuer "Verbesserung".
         Absolut UND relativ: bei kleinen Wertungen (niedrige Stufen) ist
         ein Vorsprung von 0.1 Punkten Rauschen, kein Upgrade.            ]]
    local minDelta = tonumber(self.db and self.db.minDelta) or 0
    local pct      = tonumber(self.db and self.db.minDeltaPercent) or 0
    local relative = (result.targetScore > 0) and (result.targetScore * pct / 100) or 0
    local threshold = mmax(minDelta, relative)
    result.threshold = threshold

    result.wouldUpgrade = (result.delta > 0 and result.delta >= threshold)
    result.isUpgrade    = (usable == true) and result.wouldUpgrade

    result.percent = (result.targetScore > 0) and (result.delta / result.targetScore * 100) or nil

    -- Wer wird ersetzt? (Items und Slots, fuer die Attribut-Differenzen)
    local replaced = {}
    if result.combined then
        for _, e in ipairs(result.equipped) do
            if e.item then replaced[#replaced + 1] = { item = e.item, slotID = e.slotID } end
        end
    elseif best.entry.item then
        replaced[1] = { item = best.entry.item, slotID = best.entry.slotID }
    end
    result.replaced = replaced

    -- Erbstuecke
    local factor     = self:GetHeirloomFactor()
    local candHL     = item.isHeirloom and true or false
    local targetHL   = false
    for _, r in ipairs(replaced) do if r.item.isHeirloom then targetHL = true end end
    result.heirloomActive = (factor > 1) and (candHL or targetHL)

    -- Begruendung
    if result.reason == nil then
        if usable ~= true then
            -- reason wurde bereits von CanUseItem gesetzt
        elseif result.wouldUpgrade then
            if best.entry.empty then
                result.reason = L.R_EMPTY
            elseif candHL and not targetHL and factor > 1 then
                result.reason = L.R_HEIRLOOM_WINS
            end
        else
            if result.delta > 0 then
                result.reason = sformat(L.R_MINDELTA, FmtScore(threshold))
            elseif targetHL and not candHL and factor > 1 then
                result.reason = L.R_HEIRLOOM_KEEP
            elseif result.delta == 0 then
                result.reason = L.R_EQUAL
            else
                result.reason = L.R_LOWER
            end
        end
    end

    -- Hinweise
    local notes = {}
    if item.equipLoc == "INVTYPE_2HWEAPON" then
        notes[#notes + 1] = (mode == "EITHER") and L.NOTE_2H_TG or L.NOTE_2H
    elseif OFFHAND_LOCS[item.equipLoc] and mode == "BOTH" then
        notes[#notes + 1] = L.NOTE_OFFHAND
    elseif item.equipLoc == "INVTYPE_WEAPON" and self:HasTwoHandEquipped() and not self:HasTitansGrip() then
        notes[#notes + 1] = L.NOTE_MH_2H
    end
    if item.unique and best.entry.item and best.entry.item.id == item.id and mode == "EITHER" then
        notes[#notes + 1] = L.NOTE_UNIQUE
    end
    if result.heirloomActive then
        notes[#notes + 1] = sformat(L.NOTE_HEIRLOOM_PREF, FmtWeight(factor))
    end
    if candHL and item.estimated then
        notes[#notes + 1] = L.NOTE_HEIRLOOM_EST
    end
    if not result.wouldUpgrade then
        local extra = 0
        for _, r in ipairs(replaced) do extra = extra + self:GetExtraPoints(r.item) end
        if extra > 0 then
            notes[#notes + 1] = sformat(L.NOTE_EXTRAS, FmtScore(extra))
        end
    end
    result.notes = notes
    result.note  = (#notes > 0) and tconcat(notes, " ") or nil

    return result
end

-- Schlanke Variante: nur ja/nein
function EG:IsUpgrade(itemLink)
    local r = self:Compare(itemLink)
    if not r then return false, 0, 0, nil end
    return (r.isUpgrade == true), r.score or 0, r.targetScore or 0, r.slots
end

--[[ Zustand fuer die Markierungen an Taschen, Haendlern, Beute usw.:
       "UPGRADE"  echte Verbesserung
       "LEVEL"    waere eine, aber die Charakterstufe reicht noch nicht
       nil        keine Markierung
     Zweiter Rueckgabewert: true, wenn die Itemdaten noch nicht im Client
     liegen und es sich lohnt, gleich noch einmal zu fragen.               ]]
function EG:GetUpgradeState(link)
    if not link then return nil end

    local hit = self.stateCache[link]
    if hit ~= nil then return hit or nil end

    local item = self:GetItemData(link)
    if not item then return nil, true end

    local state = false
    if item.equipLoc and item.equipLoc ~= "" then
        local r = self:Compare(link)
        if not r then return nil, true end
        if r.isUpgrade then
            state = "UPGRADE"
        elseif r.levelTooLow and r.wouldUpgrade then
            state = "LEVEL"
        end
    end
    self.stateCache[link] = state
    return state or nil
end

------------------------------------------------------------------------------
-- 13  Questbelohnungen
------------------------------------------------------------------------------

EG.hooks = { default = false, elvui = false, bagnon = false, quest = false,
             bank = false, tooltip = false, immersion = false, overlays = false }

-- Stand-in, bis EasyGearOverlays.lua die echte Fassung liefert
function EG:RefreshAllBags() end

--[[ Aufgenommene Quests (Questlog) und das NPC-Fenster benutzen verschiedene
     API-Funktionen. Das Flag QuestInfoFrame.questLog allein genuegt nicht: es
     bleibt gesetzt, wenn man das Log schliesst und danach mit einem NPC
     spricht - vor allem unter Immersion, das dieses Flag nie zuruecksetzt.   ]]
local function InQuestLog()
    return (QuestInfoFrame and QuestInfoFrame.questLog and GetQuestLogItemLink
        and QuestLogFrame and QuestLogFrame:IsShown()) and true or false
end

function EG:GetQuestChoiceCount()
    if InQuestLog() then return (GetNumQuestLogChoices and GetNumQuestLogChoices()) or 0 end
    return (GetNumQuestChoices and GetNumQuestChoices()) or 0
end

function EG:GetQuestRewardLink(index)
    if not index then return nil end
    if InQuestLog() then return GetQuestLogItemLink("choice", index) end
    if not GetQuestItemLink then return nil end
    return GetQuestItemLink("choice", index)
end

--[[ Anzahl und Verwendbarkeit kommen direkt aus der Blizzard-API.
     Das Original las button.count aus dem Frame - dieses Feld existiert
     in 3.3.5 nicht und lieferte deshalb immer 1.                         ]]
function EG:GetQuestRewardInfo(index)
    local name, texture, numItems, quality, isUsable
    if InQuestLog() and GetQuestLogChoiceInfo then
        name, texture, numItems, quality, isUsable = GetQuestLogChoiceInfo(index)
    elseif GetQuestItemInfo then
        name, texture, numItems, quality, isUsable = GetQuestItemInfo("choice", index)
    else
        return nil
    end
    return name, texture, tonumber(numItems) or 1, quality, isUsable
end

function EG:IsQuestRewardUsable(index)
    local link = self:GetQuestRewardLink(index)
    if not link then return false end

    local _, _, _, _, isUsable = self:GetQuestRewardInfo(index)
    if isUsable == false then return false end

    if self:IsItemLevelTooHigh(link) then return false end

    return self:CanEquipItem(link)
end

--[[ Auswahl-Logik:
       1. Existiert mindestens ein echtes Upgrade -> hoechster Zugewinn.
       2. Sonst -> hoechster Gesamtverkaufswert (Stueckpreis * Anzahl).
     Gleichstand wird ueber den Verkaufswert aufgeloest.                   ]]
function EG:GetBestQuestReward()
    local numChoices = self:GetQuestChoiceCount()
    if not numChoices or numChoices <= 0 then return nil end

    --[[ Entscheidend ist der Zugewinn, nicht die absolute Wertung.

         Ein Umhang mit 0.39 Punkten, der einen vorhandenen mit 0.22
         ersetzt, bringt 0.17. Stiefel mit 0.35 Punkten in einem leeren
         Slot bringen 0.35. Nach absoluter Wertung gewinnt der Umhang,
         tatsaechlich sind die Stiefel die deutlich bessere Wahl.       ]]
    local bestUp, bestUpDelta, bestUpScore, bestUpValue = nil, -mhuge, 0, -1
    local bestVendor, bestVendorValue, bestVendorScore = nil, -mhuge, 0

    for i = 1, numChoices do
        local link = self:GetQuestRewardLink(i)
        if link then
            local item = self:GetItemData(link)
            if item then
                local _, _, count = self:GetQuestRewardInfo(i)
                local totalValue = (item.sellPrice or 0) * (count or 1)
                local score = self:GetItemScore(item)

                if totalValue > bestVendorValue then
                    bestVendorValue, bestVendor, bestVendorScore = totalValue, i, score
                end

                if self:IsQuestRewardUsable(i) then
                    local result = self:Compare(link)
                    if result and result.isUpgrade then
                        local delta = result.delta or 0
                        if delta > bestUpDelta
                            or (delta == bestUpDelta and totalValue > bestUpValue) then
                            bestUpDelta  = delta
                            bestUpScore  = result.score
                            bestUp       = i
                            bestUpValue  = totalValue
                        end
                    end
                end
            end
        end
    end

    if bestUp then
        return bestUp, bestUpScore, true, bestUpValue, "UPGRADE", bestUpDelta
    end
    if bestVendor then
        return bestVendor, bestVendorScore, false, bestVendorValue, "VENDOR"
    end
    return nil
end

function EG:CreateQuestIcon(button)
    if button.EGQuestIcon then return button.EGQuestIcon end
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    local size = tonumber(self.db and self.db.iconSize) or DEFAULTS.iconSize
    icon:SetWidth(size)
    icon:SetHeight(size)
    icon:Hide()
    button.EGQuestIcon = icon
    return icon
end

--[[ Immersion ersetzt das komplette Questfenster durch eine eigene
     Oberflaeche. Die Belohnungsknoepfe liegen dort unter
       ImmersionFrame.TalkBox.Elements.Content.RewardsFrame.Buttons
     und tragen .type == "choice" sowie den Auswahlindex in :GetID().
     Beim Aufklappen der Grossansicht werden dieselben Knopfobjekte in den
     Inspector umgehaengt - da das Icon am Knopf haengt, wandert es mit.  ]]
function EG:GetImmersionFrames()
    local frame = _G.ImmersionFrame
    if not frame then return nil end
    local talkbox = frame.TalkBox
    local elements = talkbox and talkbox.Elements
    local rewards = elements and elements.Content and elements.Content.RewardsFrame
    return frame, elements, rewards
end

--[[ Liefert eine Zuordnung Auswahlindex -> Knopf fuer die gerade
     sichtbare Oberflaeche.                                               ]]
function EG:GetQuestRewardButtons()
    local buttons, source = {}, nil

    local frame, _, rewards = self:GetImmersionFrames()
    if frame and frame:IsShown() and rewards and rewards.Buttons then
        for _, b in ipairs(rewards.Buttons) do
            if b and b.type == "choice" and b.GetID and b:IsShown() then
                local id = b:GetID()
                if id and id > 0 then
                    buttons[id] = b
                    source = "IMMERSION"
                end
            end
        end
    end

    if not source then
        for i = 1, 10 do
            local b = _G["QuestInfoItem" .. i]
            if b then buttons[i] = b end
        end
        source = "BLIZZARD"
    end

    return buttons, source
end

-- Alle bekannten Knoepfe zuruecksetzen, egal welche Oberflaeche aktiv ist
function EG:ClearQuestIcons()
    for i = 1, 10 do
        local b = _G["QuestInfoItem" .. i]
        if b and b.EGQuestIcon then b.EGQuestIcon:Hide() end
    end
    local _, _, rewards = self:GetImmersionFrames()
    if rewards and rewards.Buttons then
        for _, b in ipairs(rewards.Buttons) do
            if b and b.EGQuestIcon then b.EGQuestIcon:Hide() end
        end
    end
end

--[[ Die Auswahl wird immer berechnet, auch wenn die Icons abgeschaltet
     sind - die Grossansicht von Immersion braucht sie fuer ihre
     Empfehlungszeile.                                                    ]]
function EG:UpdateQuestRewards()
    self.selectedQuestReward = nil
    self:ClearQuestIcons()

    local numChoices = self:GetQuestChoiceCount()
    if not numChoices or numChoices <= 0 then return end

    local best, score, isUpgrade, value, mode, delta = self:GetBestQuestReward()
    if not best then return end

    local link = self:GetQuestRewardLink(best)
    self.selectedQuestReward = {
        index = best, link = link, score = score, delta = delta,
        value = value, isUpgrade = isUpgrade, mode = mode,
    }

    if not (self.db and self.db.showQuestIcons) then return end

    local buttons = self:GetQuestRewardButtons()
    local button = buttons[best]
    if not button then return end

    local icon = self:CreateQuestIcon(button)
    if mode == "UPGRADE" then
        icon:SetTexture(TEX_UPGRADE)
        icon:SetVertexColor(0, 1, 0)
    else
        icon:SetTexture(TEX_VENDOR)
        icon:SetVertexColor(1, 1, 1)
    end
    icon:Show()
end

function EG:HookImmersion()
    if self.hooks.immersion then return end

    local frame, elements = self:GetImmersionFrames()
    if not frame or not elements or type(elements.Display) ~= "function" then
        return false
    end

    --[[ Gehakt wird Elements:Display(), nicht Elements:ShowRewards().

         Immersion legt seine Vorlagen als Liste von Funktionsreferenzen an
         (TEMPLATE.QUEST_DETAIL.elements enthaelt Elements.ShowRewards
         direkt) und ruft sie ueber elementsTable[i](self) auf. Diese
         Referenz zeigt weiterhin auf die urspruengliche Funktion, ein Hook
         auf dem Frame wuerde also nie ausloesen. Display() dagegen wird in
         Frame:AddQuestInfo() als echte Methode aufgerufen und arbeitet die
         Vorlage ab - der Hook greift dort zuverlaessig.                  ]]
    hooksecurefunc(elements, "Display", function()
        EG:Debounce("questimm", 0.05, function()
            EG:UpdateQuestRewards()
            -- zweiter Durchlauf, weil Itemdaten nachladen koennen
            EG:After(0.6, function() EG:UpdateQuestRewards() end)
        end)
    end)

    -- Grossansicht (Shift) mitnehmen
    self:HookImmersionInspector()

    self.hooks.immersion = true
    self:Print(L.HOOK_IMMERSION)
    return true
end

function EG:HookQuestRewards()
    if self.hooks.quest or not QuestInfo_Display then return end

    hooksecurefunc("QuestInfo_Display", function()
        -- Zweiter Durchlauf, weil Itemdaten noch nachladen koennen
        EG:Debounce("quest", 0.15, function()
            EG:UpdateQuestRewards()
            EG:After(0.6, function() EG:UpdateQuestRewards() end)
        end)
    end)

    self.hooks.quest = true
end

------------------------------------------------------------------------------
-- 14  Tooltip-Integration
------------------------------------------------------------------------------

--[[ Auf angelegten Items (Charakterfenster, Inspektion, Vergleichstooltips)
     ergibt "Verbesserung gegenueber sich selbst" keinen Sinn - dort erscheint
     nur die Wertung.                                                      ]]
local function IsEquippedContext(tooltip)
    if tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2 then return true end
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    local name  = owner and owner.GetName and owner:GetName()
    if name and (sfind(name, "^Character") or sfind(name, "^Inspect")) then return true end
    return false
end

-- "+23" / "-5" / "+4.2"
local function FmtDelta(v, decimals)
    local s
    if decimals and decimals > 0 then
        s = sformat("%." .. decimals .. "f", v)
    else
        s = sformat("%d", v + ((v >= 0) and 0.5 or -0.5))
    end
    if v > 0 then s = "+" .. s end
    return s
end

local MAX_DIFF_LINES = 6

local function AddTooltipInfo(tooltip, forcedLink)
    if not (EG.db and EG.db.showTooltip) then return end
    if tooltip.EGDone then return end

    local link = forcedLink
    if not link then
        local _
        _, link = tooltip:GetItem()
    end
    if not link then return end

    local item = EG:GetItemData(link)
    if not item or not item.equipLoc or item.equipLoc == "" then return end

    local result = EG:Compare(link)
    if not result then return end

    tooltip.EGDone = true

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(
        COLOR.title .. "EasyGear" .. COLOR.reset,
        COLOR.value .. L.SCORE .. ": " .. FmtScore(result.score) .. COLOR.reset)

    if result.noCompare or IsEquippedContext(tooltip) then
        tooltip:Show()
        return
    end

    if result.usable ~= true then
        tooltip:AddLine(COLOR.bad .. (result.reason or L.NOT_USABLE) .. COLOR.reset, nil, nil, nil, true)
        tooltip:Show()
        return
    end

    if EG.db.showTooltipStats and result.target then
        local targetText
        if result.target.empty then
            targetText = L.NOTHING_EQUIPPED
        else
            targetText = FmtScore(result.targetScore)
        end
        local slotText = result.combined and EG:GetSlotName(result.slots)
                         or EG:GetSlotName(result.target.slotID)
        tooltip:AddDoubleLine(
            COLOR.grey .. slotText .. COLOR.reset,
            COLOR.grey .. targetText .. COLOR.reset)
    end

    local delta = result.delta or 0
    local pct   = result.percent and ("  (" .. FmtPct(result.percent) .. ")") or ""
    if result.isUpgrade then
        local sign = (delta > 0) and "+" or ""
        tooltip:AddLine(COLOR.good .. L.UPGRADE .. "  " .. sign .. FmtScore(delta) .. pct .. COLOR.reset)
    elseif delta > 0 then
        tooltip:AddLine(COLOR.warn .. L.NO_UPGRADE .. "  +" .. FmtScore(delta) .. pct .. COLOR.reset)
    else
        tooltip:AddLine(COLOR.bad .. L.NO_UPGRADE .. "  " .. FmtScore(delta) .. pct .. COLOR.reset)
    end
    if result.reason then
        tooltip:AddLine(COLOR.grey .. result.reason .. COLOR.reset, nil, nil, nil, true)
    end

    -- Attribut-Unterschiede zum ersetzten Item, wie bei RatingBuster
    if EG.db.tooltipDiff then
        local diffs = EG:GetStatDiff(item, result.replaced)
        for i = 1, mmin(#diffs, MAX_DIFF_LINES) do
            local d = diffs[i]
            local col = (d.delta > 0) and COLOR.good or COLOR.bad
            tooltip:AddLine(col .. FmtDelta(d.delta, d.decimals) .. COLOR.reset .. " " .. d.label)
        end
    end

    tooltip:Show()
end
EG.AddTooltipInfo = AddTooltipInfo

--[[--------------------------------------------------------------------
     Immersion: Grossansicht (Shift)

     Der Shift-Modus zeigt die Belohnungen nicht ueber die Knoepfe aus dem
     Sprechfenster, sondern ueber gepoolte Tooltip-Frames
     (ImmersionItemTooltipTemplate), die in Frame:SetItemTooltip() mit
     tooltip:SetQuestItem(...) befuellt werden. Das sind eigene
     Frame-Objekte, der Hook auf GameTooltip greift dort also nicht.

     Gehakt wird deshalb Frame:SetItemTooltip auf dem ImmersionFrame -
     Logic/Frame.lua haengt seine Methoden per L.Mixin(L.frame, Frame)
     direkt an das Frame, und der Aufruf erfolgt als echte Methode.
----------------------------------------------------------------------]]
function EG:MarkImmersionTooltip(tooltip, recommended)
    if not tooltip.EGPickIcon then
        local anchor = tooltip.Icon or tooltip
        local icon = tooltip:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(TEX_UPGRADE)
        icon:SetVertexColor(0, 1, 0)
        local size = tonumber(self.db and self.db.iconSize) or DEFAULTS.iconSize
        icon:SetWidth(size)
        icon:SetHeight(size)
        icon:SetPoint("CENTER", anchor, "BOTTOMLEFT", 6, 6)
        tooltip.EGPickIcon = icon
    end
    if recommended then
        tooltip.EGPickIcon:Show()
    else
        tooltip.EGPickIcon:Hide()
    end
end

function EG:DecorateImmersionTooltip(tooltip, item)
    if not tooltip or not item then return end
    if not (self.db and self.db.showTooltip) then return end
    if item.objectType and item.objectType ~= "item" then return end

    local itemType = item.type
    local index    = item.GetID and item:GetID()
    if not itemType or not index or not GetQuestItemLink then return end

    local link = GetQuestItemLink(itemType, index)
    if not link then return end

    -- Die Frames kommen aus einem Pool und werden wiederverwendet,
    -- deshalb den Merker vor jedem Befuellen zuruecksetzen.
    tooltip.EGDone = nil
    AddTooltipInfo(tooltip, link)

    local recommended = false
    if itemType == "choice" then
        if not self.selectedQuestReward then self:UpdateQuestRewards() end
        local sel = self.selectedQuestReward
        recommended = (sel and sel.index == index) and true or false
        if recommended then
            tooltip:AddLine(COLOR.good .. L.QUEST_PICK .. COLOR.reset)
            tooltip:Show()
        end
    end
    self:MarkImmersionTooltip(tooltip, recommended)
end

function EG:HookImmersionInspector()
    local frame = self:GetImmersionFrames()
    if not frame or type(frame.SetItemTooltip) ~= "function" then return false end

    hooksecurefunc(frame, "SetItemTooltip", function(_, tooltip, item)
        EG:DecorateImmersionTooltip(tooltip, item)
    end)
    return true
end

function EG:HookTooltips()
    if self.hooks.tooltip then return end

    for _, tip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        if tip then
            tip:HookScript("OnTooltipSetItem", AddTooltipInfo)
            tip:HookScript("OnTooltipCleared", function(self_) self_.EGDone = nil end)
            tip:HookScript("OnHide", function(self_) self_.EGDone = nil end)
        end
    end

    --[[ Questbelohnungen werden ueber SetQuestItem (NPC-Fenster) bzw.
         SetQuestLogItem (Questlog) angezeigt, nicht ueber SetHyperlink -
         GetItem() liefert dabei nicht zuverlaessig einen Link. Deshalb wird
         der Link hier direkt uebergeben. Das gilt fuer das Blizzard-
         Questfenster ebenso wie fuer Immersion, das denselben GameTooltip
         benutzt.                                                          ]]
    if GameTooltip.SetQuestItem then
        hooksecurefunc(GameTooltip, "SetQuestItem", function(tip, itemType, index)
            if not GetQuestItemLink then return end
            local link = GetQuestItemLink(itemType, index)
            if link then AddTooltipInfo(tip, link) end
        end)
    end
    if GameTooltip.SetQuestLogItem and GetQuestLogItemLink then
        hooksecurefunc(GameTooltip, "SetQuestLogItem", function(tip, itemType, index)
            local link = GetQuestLogItemLink(itemType, index)
            if link then AddTooltipInfo(tip, link) end
        end)
    end

    self.hooks.tooltip = true
end


------------------------------------------------------------------------------
-- 16  Chat-Ausgabe & Slash-Befehle
------------------------------------------------------------------------------

local LINE = COLOR.grey .. "----------------------------------------" .. COLOR.reset

local function FmtRow(row)
    return sformat("  %-24s %8s  x %-6s = %s%s%s",
        tostring(row.label),
        Num(row.value, (row.value % 1 ~= 0) and 1 or 0),
        FmtWeight(row.weight),
        COLOR.value, FmtScore(row.points), COLOR.reset)
end

function EG:PrintBreakdown(rows, total)
    if not rows or #rows == 0 then
        self:Raw("  " .. COLOR.grey .. "-" .. COLOR.reset)
        return
    end
    self:Raw(sformat("  %-24s %8s  %-7s   %s",
        L.STAT, L.VALUE, L.WEIGHT, L.POINTS))
    for _, row in ipairs(rows) do
        self:Raw(FmtRow(row))
    end
    self:Raw(sformat("  %-24s %8s  %-7s   %s%s%s",
        L.TOTAL, "", "", COLOR.good, FmtScore(total), COLOR.reset))
end

function EG:PrintReport(itemLink)
    local result = self:Compare(itemLink, true)
    if not result then
        self:Print(COLOR.bad .. L.INVALID_ITEM .. COLOR.reset)
        self:Print(L.ITEM_LOADING)
        return
    end

    local item = result.item
    local _, profileName = self:GetProfile()

    self:Raw(COLOR.title .. "===== EasyGear =====" .. COLOR.reset)
    self:Raw(L.CANDIDATE .. ": " .. (item.link or itemLink))
    self:Raw(sformat("%s: %s%s%s   %s: %s%s%s   %s: %s%s%s",
        L.ILVL,  COLOR.value, tostring(item.level), COLOR.reset,
        L.SLOT,  COLOR.value, tostring(result.slotName), COLOR.reset,
        L.PROFILE, COLOR.value, tostring(profileName), COLOR.reset))
    if item.itemType or item.itemSubType then
        self:Raw(sformat("%s: %s  |  %s: %s",
            L.TYPE, tostring(item.itemType or "-"),
            L.SUBTYPE, tostring(item.itemSubType or "-")))
    end
    if (item.minLevel or 0) > 0 then
        self:Raw(L.REQLEVEL .. ": " .. COLOR.value .. item.minLevel .. COLOR.reset)
    end
    if EG:IsHeirloomItem(item) then
        self:Raw(COLOR.warn .. L.HEIRLOOM .. COLOR.reset)
    end
    if item.enchanted or (item.gemCount or 0) > 0 or item.hasExtraStats then
        local parts = {}
        if item.enchanted then parts[#parts + 1] = L.ENCHANTED end
        if (item.gemCount or 0) > 0 then
            parts[#parts + 1] = sformat(L.GEMMED, item.gemCount)
        end
        if #parts > 0 then
            self:Raw(COLOR.good .. tconcat(parts, ", ") .. COLOR.reset)
        end
    end
    if (item.sellPrice or 0) > 0 and GetCoinTextureString then
        self:Raw(L.SELLPRICE .. ": " .. GetCoinTextureString(item.sellPrice))
    end

    self:Raw(LINE)
    self:Raw(COLOR.title .. L.CANDIDATE .. " - " .. L.POINTS .. COLOR.reset)
    self:PrintBreakdown(result.breakdown, result.score)

    if result.noCompare then
        if result.note then self:Raw(COLOR.grey .. result.note .. COLOR.reset) end
        self:Raw(COLOR.title .. "====================" .. COLOR.reset)
        return
    end

    self:Raw(LINE)
    self:Raw(COLOR.title .. L.EQUIPPED .. COLOR.reset)
    if not result.equipped or #result.equipped == 0 then
        self:Raw("  " .. COLOR.warn .. L.NOTHING_EQUIPPED .. COLOR.reset)
    else
        for _, e in ipairs(result.equipped) do
            local slotName = self:GetSlotName(e.slotID)
            local mark = (e == result.target) and (COLOR.good .. "> " .. COLOR.reset) or ""
            if e.empty then
                self:Raw(sformat("%s%s: %s%s%s", mark, slotName, COLOR.warn, L.NOTHING_EQUIPPED, COLOR.reset))
            else
                self:Raw(sformat("%s%s: %s", mark, slotName, e.link or e.item.link))
                if e.isHeirloom then
                    self:Raw("  " .. COLOR.warn .. L.HEIRLOOM .. COLOR.reset)
                end
                self:PrintBreakdown(e.breakdown, e.score)
            end
        end
    end

    self:Raw(LINE)
    if result.usable ~= true then
        self:Raw(COLOR.bad .. L.NOT_USABLE .. COLOR.reset .. " " .. tostring(result.reason or ""))
    else
        local delta = result.delta or 0
        local sign  = delta > 0 and "+" or ""
        local col   = result.isUpgrade and COLOR.good or (delta > 0 and COLOR.warn or COLOR.bad)
        local pct   = result.percent and ("  (" .. FmtPct(result.percent) .. ")") or ""
        self:Raw(sformat("%s: %s%s%s%s   %s -> %s",
            L.DIFFERENCE, col, sign .. FmtScore(delta), pct, COLOR.reset,
            FmtScore(result.targetScore), FmtScore(result.score)))
        if result.isUpgrade then
            self:Raw(COLOR.good .. ">> " .. L.UPGRADE .. COLOR.reset
                .. (result.reason and (" " .. result.reason) or ""))
        else
            self:Raw(COLOR.bad .. ">> " .. L.NO_UPGRADE .. COLOR.reset
                .. " " .. tostring(result.reason or ""))
        end
    end
    if result.note then
        self:Raw(COLOR.grey .. result.note .. COLOR.reset)
    end
    self:Raw(COLOR.title .. "====================" .. COLOR.reset)
end

------------------------------------------------------------------------------

local function OnOff(v) return v and L.SET_ON or L.SET_OFF end

-- Befehl, Beschreibungsschluessel. Die Befehle selbst sind in jeder Sprache gleich.
local HELP = {
    { "/eg",                                  "H_EG" },
    { "/eg <itemlink>",                       "H_EG_LINK" },
    { "/eg upgrades",                         "H_UPGRADES" },
    { "/eggui",                               "H_GUI" },
    { "/egprofile",                           "H_PROFILE_WIN" },
    { "/eg profile list",                     "H_PROFILE_LIST" },
    { "/eg profile <id|auto>",                "H_PROFILE_SET" },
    { "/eg autolevel [on|off]",               "H_AUTOLEVEL" },
    { "/eg pvp",                              "H_PVP" },
    { "/eg role <auto|tank|melee|ranged|caster|heal>", "H_ROLE" },
    { "/eg heirloom [on|off]",                "H_HEIRLOOM" },
    { "/eg heirloombonus <1.0-3.0>",          "H_HEIRLOOMBONUS" },
    { "/eg enchants [on|off]",                "H_ENCHANTS" },
    { "/eg socket <number|auto>",             "H_SOCKET" },
    { "/eg ilvl <number>",                    "H_ILVL" },
    { "/eg ilvlscale [on|off]",               "H_ILVLSCALE" },
    { "/eg mindelta <number>",                "H_MINDELTA" },
    { "/eg mindeltapct <percent>",            "H_MINDELTAPCT" },
    { "/eg icons | quest | items | tooltip | diff", "H_TOGGLES" },
    { "/eg scale <0.5-2.0>",                  "H_SCALE" },
    { "/eg status",                           "H_STATUS" },
    { "/eg locale",                           "H_LOCALE" },
    { "/eg reset",                            "H_RESET" },
    { "/egup",                                "H_EGUP" },
    { "/egup list|verify [class]",            "H_EGUP_LIST" },
    { "/egupclean [list]",                    "H_EGUPCLEAN" },
}

function EG:PrintHelp()
    self:Raw(COLOR.title .. "EasyGear " .. ADDON_VERSION .. COLOR.reset)
    for _, h in ipairs(HELP) do
        self:Raw(COLOR.value .. h[1] .. COLOR.reset .. "  " .. COLOR.grey .. L[h[2]] .. COLOR.reset)
    end
end

function EG:PrintProfileList()
    local activeID = self:GetActiveProfileID()
    local active   = self:GetActiveSpec()

    self:Raw(COLOR.title .. L.PROFILE_LIST .. COLOR.reset)
    self:Raw(sformat("  %s%-16s%s %s", COLOR.value, "AUTO", COLOR.reset,
        L.PROFILE_AUTO_HINT))

    for _, spec in ipairs(self:GetAvailableProfiles()) do
        local mark = "  "
        if activeID == spec.id or (activeID == "AUTO" and active and active.id == spec.id) then
            mark = COLOR.good .. ">>" .. COLOR.reset
        end
        local tag = spec.custom and (COLOR.warn .. "*" .. COLOR.reset) or " "
        self:Raw(sformat("%s%s %s%-18s%s %s", mark, tag,
            COLOR.value, spec.id, COLOR.reset, self:GetProfileName(spec)))
    end
    self:Raw(COLOR.grey .. L.PROFILE_CMD_HINT .. COLOR.reset)
end

function EG:PrintStatus()
    local _, profileName = self:GetProfile()
    self:Raw(COLOR.title .. "EasyGear " .. ADDON_VERSION .. COLOR.reset)
    self:Raw(L.PROFILE .. ": " .. COLOR.value .. tostring(profileName) .. COLOR.reset
        .. "  [" .. tostring(self:GetActiveProfileID()) .. "]")
    self:Raw("PvP: " .. OnOff(self:IsPvPMode()) .. " | " .. L.ST_AUTOLEVEL .. ": " .. OnOff(self.db.autoLeveling))
    local eff, base, factor = self:GetEffectiveIlvlWeight()
    self:Raw(L.SET_ILVL:format(FmtWeight(base) .. " -> " .. FmtWeight(eff)))
    self:Raw(L.SET_ILVLSCALE:format(OnOff(self.db.ilvlScaling ~= false),
        FmtWeight(factor)))
    self:Raw(L.SET_MINDELTA:format(FmtScore(self.db.minDelta or 0),
        tostring(self.db.minDeltaPercent or 0)))
    self:Raw(L.ST_ENCHANTS .. ": " .. OnOff(self.db.includeEnchants ~= false)
        .. " | " .. L.SOCKETS .. ": " .. (tonumber(self.db.socketValue) and tostring(self.db.socketValue)
            or (L.ROLE_AUTO .. " " .. FmtScore(self:GetSocketPoints()))))
    self:Raw(L.HEIRLOOM .. ": " .. OnOff(self.db.protectHeirlooms)
        .. " x" .. FmtWeight(tonumber(self.db.heirloomBonus) or 1)
        .. " (" .. L.ST_NOW .. " x" .. FmtWeight(self:GetHeirloomFactor()) .. ")")
    self:Raw("Bags: " .. OnOff(self.db.showBagIcons)
        .. " | Quest: " .. OnOff(self.db.showQuestIcons)
        .. " | " .. L.ST_ITEMS .. ": " .. OnOff(self.db.showItemIcons)
        .. " | Tooltip: " .. OnOff(self.db.showTooltip)
        .. " | " .. L.ST_DIFF .. ": " .. OnOff(self.db.tooltipDiff))
end

--[[ /eg upgrades: alle Verbesserungen in den Taschen (und der Bank, wenn offen),
     die groesste zuerst. Ein leerer Slot geht vor, danach nach Prozent.      ]]
function EG:CollectUpgrades()
    local found = {}
    local bags = {}
    for bagID = 0, (NUM_BAG_SLOTS or 4) do bags[#bags + 1] = bagID end
    if BankFrame and BankFrame:IsShown() then
        bags[#bags + 1] = BANK_CONTAINER or -1
        local first = (NUM_BAG_SLOTS or 4) + 1
        for bagID = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do bags[#bags + 1] = bagID end
    end

    for _, bagID in ipairs(bags) do
        for slotID = 1, (GetContainerNumSlots(bagID) or 0) do
            local link = GetContainerItemLink(bagID, slotID)
            if link then
                local r = self:Compare(link)
                if r and r.isUpgrade then
                    local slotName = r.combined and r.slotName
                        or self:GetSlotName(r.candSlot or (r.target and r.target.slotID))
                    found[#found + 1] = {
                        link = link, slot = slotName, delta = r.delta or 0,
                        percent = r.percent, empty = r.target and r.target.empty,
                    }
                end
            end
        end
    end

    tsort(found, function(a, b)
        if (a.empty and true or false) ~= (b.empty and true or false) then return a.empty and true or false end
        return (a.percent or 0) > (b.percent or 0)
    end)
    return found
end

function EG:PrintUpgrades()
    local found = self:CollectUpgrades()
    if #found == 0 then
        self:Print(L.UPGRADES_NONE)
        return
    end
    self:Raw(COLOR.title .. L.UPGRADES_HEAD .. COLOR.reset)
    for i, u in ipairs(found) do
        if i > 25 then
            self:Raw(COLOR.grey .. sformat("... +%d", #found - 25) .. COLOR.reset)
            break
        end
        local gain = u.empty and L.NOTHING_EQUIPPED
            or (("+" .. FmtScore(u.delta)) .. (u.percent and ("  (" .. FmtPct(u.percent) .. ")") or ""))
        self:Raw(sformat("  %s  %s%s%s  %s%s%s", u.link, COLOR.grey, u.slot, COLOR.reset,
            COLOR.good, gain, COLOR.reset))
    end
end

-- /eg locale: welche Sprachdatei greift, woher kommen die Untertyp-Namen?
function EG:PrintLocale()
    local loc = self.locale or {}
    self:Raw(COLOR.title .. "EasyGear - " .. L.LOCALE_HEAD .. COLOR.reset)
    self:Raw(L.LOCALE_CLIENT .. ": " .. COLOR.value .. tostring(loc.client) .. COLOR.reset
        .. "  ->  " .. L.LOCALE_FILE .. ": " .. COLOR.value .. tostring(loc.active) .. ".lang.lua" .. COLOR.reset
        .. (loc.translated and "" or ("  " .. COLOR.warn .. "(" .. L.LOCALE_FALLBACK .. ")" .. COLOR.reset)))
    self:Raw(L.LOCALE_LOADED .. ": " .. tconcat(loc.loaded or {}, ", "))
    if not loc.baseOK then
        self:Raw(COLOR.bad .. L.LOCALE_BROKEN .. COLOR.reset)
    end
    if not self.subtypeBuilt then self:BuildSubtypeTokens(true) end
    local n = 0
    for _ in pairs(ALL_TOKENS) do n = n + 1 end
    local fromClient, fromLang = 0, 0
    for token in pairs(ALL_TOKENS) do
        if subtypeSource[token] == "client" then fromClient = fromClient + 1
        elseif subtypeSource[token] == "lang" then fromLang = fromLang + 1 end
    end
    self:Raw(sformat("%s: %s%d/%d%s  (%s %d, %s %d)", L.LOCALE_SUBTYPES, COLOR.value,
        fromClient + fromLang, n, COLOR.reset, L.LOCALE_FROM_CLIENT, fromClient,
        L.LOCALE_FROM_LANG, fromLang))
    if (self.subtypeMismatch or 0) > 0 then
        self:Raw(COLOR.warn .. sformat(L.LOCALE_MISMATCH, self.subtypeMismatch) .. COLOR.reset)
    end
end

local function Toggle(key)
    EG.db[key] = not EG.db[key]
    EG:Print(key .. ": " .. OnOff(EG.db[key]))
    EG:InvalidateProfile()
    EG:RefreshAllBags()
    if EG.GUI then EG.GUI:Refresh() end
end

-- "on" / "off" / leer (= umschalten) -> neuer Wert
local function ParseSwitch(arg, current)
    arg = slower(arg or "")
    if arg == "on" or arg == "1" or arg == "an" then return true end
    if arg == "off" or arg == "0" or arg == "aus" then return false end
    return not current
end

local function CopyDefaults(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            CopyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

-- Aenderung einer Einstellung, die alle Bewertungen betrifft
local function ApplySettingChange(wipeItems)
    EG:InvalidateProfile()
    if wipeItems then EG:WipeItemCache() end
    EG:RefreshAllBags()
    if EG.GUI then EG.GUI:Refresh() end
    if EG.ProfileGUI then EG.ProfileGUI:Refresh() end
end

SLASH_EASYGEAR1 = "/eg"
SLASH_EASYGEAR2 = "/easygear"
SlashCmdList["EASYGEAR"] = function(msg)
    msg = msg or ""

    -- Itemlink? -> Auswertung
    if sfind(msg, "|Hitem:") then
        EG:PrintReport(msg)
        if EG.GUI then EG.GUI:SetItem(msg, true) end
        return
    end

    local cmd, rest = smatch(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = slower(cmd or "")

    if cmd == "" then
        if EG.GUI then EG.GUI:Toggle() else EG:PrintHelp() end
        return
    elseif cmd == "help" or cmd == "?" then
        EG:PrintHelp(); return
    elseif cmd == "gui" then
        if EG.GUI then EG.GUI:Toggle() end; return
    elseif cmd == "status" then
        EG:PrintStatus(); return
    elseif cmd == "locale" or cmd == "lang" then
        EG:PrintLocale(); return
    elseif cmd == "upgrades" or cmd == "upgrade" or cmd == "bags" then
        EG:PrintUpgrades(); return
    elseif cmd == "profiles" or cmd == "profile" then
        if rest == "" or rest == "list" then
            EG:PrintProfileList()
        elseif slower(rest) == "gui" then
            if EG.ProfileGUI then EG.ProfileGUI:Toggle() end
        elseif slower(rest) == "auto" then
            EG:SetActiveProfile("AUTO")
            EG:Print(L.SET_PROFILE:format(L.ROLE_AUTO))
        else
            local id = string.upper(rest)
            local spec = EG:GetProfileByID(id)
            if spec then
                EG:SetActiveProfile(id)
                EG:Print(L.SET_PROFILE:format(EG:GetProfileName(spec)))
            else
                EG:Print(COLOR.bad .. L.PROFILE_UNKNOWN:format(rest) .. COLOR.reset)
                EG:PrintProfileList()
            end
        end
        return
    elseif cmd == "pvp" then
        EG:SetPvPMode(not EG:IsPvPMode())
        EG:Print(L.SET_PVP:format(OnOff(EG:IsPvPMode())))
        return
    elseif cmd == "autolevel" then
        EG.db.autoLeveling = ParseSwitch(rest, EG.db.autoLeveling)
        ApplySettingChange(false)
        EG:Print(L.ST_AUTOLEVEL .. ": " .. OnOff(EG.db.autoLeveling))
        return
    elseif cmd == "role" then
        -- Alter Befehl: waehlt das erste Profil der Klasse mit dieser Rolle
        local role = string.upper(rest or "")
        if role == "" or role == "AUTO" then
            EG:SetActiveProfile("AUTO")
            EG:Print(L.SET_PROFILE:format(L.ROLE_AUTO))
            return
        end
        for _, spec in ipairs(EG:GetAvailableProfiles()) do
            if spec.role == role then
                EG:SetActiveProfile(spec.id)
                EG:Print(L.SET_PROFILE:format(EG:GetProfileName(spec)))
                return
            end
        end
        EG:Print("auto | tank | melee | ranged | caster | heal")
        return
    elseif cmd == "heirloom" then
        EG.db.protectHeirlooms = ParseSwitch(rest, EG.db.protectHeirlooms)
        ApplySettingChange(false)
        EG:Print(L.HEIRLOOM .. ": " .. OnOff(EG.db.protectHeirlooms))
        return
    elseif cmd == "heirloombonus" then
        local v = tonumber(rest)
        if v then
            EG.db.heirloomBonus = mmax(1.0, mmin(3.0, v))
            ApplySettingChange(false)
        end
        EG:Print(L.HEIRLOOM .. ": x" .. FmtWeight(EG.db.heirloomBonus)
            .. " (" .. L.ST_NOW .. " x" .. FmtWeight(EG:GetHeirloomFactor()) .. ")")
        return
    elseif cmd == "enchants" then
        EG.db.includeEnchants = ParseSwitch(rest, EG.db.includeEnchants ~= false)
        ApplySettingChange(true)
        EG:Print(L.ST_ENCHANTS .. ": " .. OnOff(EG.db.includeEnchants))
        return
    elseif cmd == "socket" then
        if slower(rest) == "auto" then
            EG.db.socketValue = nil
            ApplySettingChange(false)
        elseif tonumber(rest) then
            EG.db.socketValue = tonumber(rest)
            ApplySettingChange(false)
        end
        EG:Print(L.SOCKETS .. ": " .. (tonumber(EG.db.socketValue) and tostring(EG.db.socketValue)
            or (L.ROLE_AUTO .. " " .. FmtScore(EG:GetSocketPoints()))))
        return
    elseif cmd == "ilvl" then
        local v = tonumber(rest)
        if v then
            EG.db.ilvlWeight = v
            ApplySettingChange(false)
        end
        local eff = EG:GetEffectiveIlvlWeight()
        EG:Print(L.SET_ILVL:format(FmtWeight(EG.db.ilvlWeight) .. " -> " .. FmtWeight(eff)))
        return
    elseif cmd == "mindelta" then
        local v = tonumber(rest)
        if v then EG.db.minDelta = v; ApplySettingChange(false) end
        EG:Print(L.SET_MINDELTA:format(FmtScore(EG.db.minDelta or 0),
            tostring(EG.db.minDeltaPercent or 0)))
        return
    elseif cmd == "mindeltapct" then
        local v = tonumber(rest)
        if v then EG.db.minDeltaPercent = v; ApplySettingChange(false) end
        EG:Print(L.SET_MINDELTA:format(FmtScore(EG.db.minDelta or 0),
            tostring(EG.db.minDeltaPercent or 0)))
        return
    elseif cmd == "ilvlscale" then
        EG.db.ilvlScaling = ParseSwitch(rest, EG.db.ilvlScaling ~= false)
        ApplySettingChange(true)
        local eff, _, factor = EG:GetEffectiveIlvlWeight()
        EG:Print(L.SET_ILVLSCALE:format(OnOff(EG.db.ilvlScaling ~= false),
            FmtWeight(factor)) .. "  ->  " .. FmtWeight(eff))
        return
    elseif cmd == "icons" then
        Toggle("showBagIcons"); return
    elseif cmd == "quest" then
        Toggle("showQuestIcons"); return
    elseif cmd == "items" then
        Toggle("showItemIcons"); return
    elseif cmd == "tooltip" then
        Toggle("showTooltip"); return
    elseif cmd == "diff" then
        Toggle("tooltipDiff"); return
    elseif cmd == "debug" then
        Toggle("debug"); return
    elseif cmd == "scale" then
        local v = tonumber(rest)
        if v and v >= 0.5 and v <= 2.0 then
            EG.charDB.gui.scale = v
            if EG.GUI and EG.GUI.frame then EG.GUI.frame:SetScale(v) end
        end
        EG:Print(L.SET_SCALE:format(tostring(EG.charDB.gui.scale)))
        return
    elseif cmd == "reset" then
        -- eigene Profile bleiben erhalten
        for k in pairs(EG.db) do
            if k ~= "custom" then EG.db[k] = nil end
        end
        CopyDefaults(EG.db, DEFAULTS)
        EG.db.version = ADDON_VERSION
        EG.charDB.role    = "AUTO"
        EG.charDB.profile = "AUTO"
        EG.charDB.pvp     = false
        EG.charDB.gui     = { point = "CENTER", x = 0, y = 0, scale = 1.0 }
        EG:InvalidateTalents()
        ApplySettingChange(true)
        if EG.GUI and EG.GUI.frame then
            EG.GUI.frame:ClearAllPoints()
            EG.GUI.frame:SetPoint("CENTER")
            EG.GUI.frame:SetScale(1.0)
        end
        EG:Print(L.SET_RESET)
        return
    end

    -- Item-ID
    local id = tonumber(rest ~= "" and rest or cmd)
    if id then
        local _, link = GetItemInfo(id)
        if link then
            EG:PrintReport(link)
            if EG.GUI then EG.GUI:SetItem(link, true) end
        else
            EG:Print(L.ITEM_LOADING)
        end
        return
    end

    EG:PrintHelp()
end

SLASH_EASYGEARGUI1 = "/eggui"
SlashCmdList["EASYGEARGUI"] = function()
    if EG.GUI then EG.GUI:Toggle() else EG:Print("GUI not loaded.") end
end

SLASH_EASYGEARPROFILE1 = "/egprofile"
SLASH_EASYGEARPROFILE2 = "/egprofil"
SlashCmdList["EASYGEARPROFILE"] = function()
    if EG.ProfileGUI then EG.ProfileGUI:Toggle() else EG:PrintProfileList() end
end


------------------------------------------------------------------------------
-- 17  Initialisierung
------------------------------------------------------------------------------

function EG:InitDB()
    EasyGearDB     = EasyGearDB     or {}
    EasyGearCharDB = EasyGearCharDB or {}
    local previous = EasyGearDB.version

    self.db     = CopyDefaults(EasyGearDB, DEFAULTS)
    self.charDB = CopyDefaults(EasyGearCharDB, CHAR_DEFAULTS)

    -- Migration: bis 2.x war 8 Punkte pro freiem Sockel der Standard; jetzt
    -- gilt "automatisch". Ein dort gespeicherter 8er ist kein Nutzerwunsch.
    if previous and VersionLess(previous, "3.0.0") and tonumber(self.db.socketValue) == 8 then
        self.db.socketValue = nil
    end
    self.db.version = ADDON_VERSION

    -- Alte Sitzung wiederherstellen (relog-fest)
    self.EGUPSession = self.charDB.egup or { items = {}, active = false }
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("QUEST_COMPLETE")
eventFrame:RegisterEvent("QUEST_DETAIL")
eventFrame:RegisterEvent("QUEST_ITEM_UPDATE")
-- Talentwechsel (Doppelspezialisierung); nicht jeder 3.3.5a-Fork kennt alle Namen
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_TALENT_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "ACTIVE_TALENT_GROUP_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            EG:InitDB()
        end
        if EG.OnAddonLoaded then EG:OnAddonLoaded(arg1) end
        return
    end

    if event == "PLAYER_LOGIN" then
        if not EG.db then EG:InitDB() end
        EG.loaded = true

        EG:Print(sformat(L.LOADED, ADDON_VERSION))
        EG:Raw(COLOR.grey .. L.CMD_HEADER .. "  " .. COLOR.value
            .. "/eg  /eggui  /egprofile  /egup  /egupclean" .. COLOR.reset)
        if not EG.locale.baseOK then
            EG:Print(COLOR.bad .. L.LOCALE_BROKEN .. COLOR.reset)
        end

        -- Taschen, Haendler, Beute usw.
        if EG.HookOverlays then EG:HookOverlays() end

        EG:HookQuestRewards()
        if IsAddOnLoaded("Immersion") then
            -- Immersion baut seine Frames beim Laden auf; falls es noch
            -- nicht so weit ist, spaeter erneut versuchen
            if not EG:HookImmersion() then
                EG:After(2, function() EG:HookImmersion() end)
            end
        end
        EG:HookTooltips()

        if EG.GUI and EG.GUI.OnInit then EG.GUI:OnInit() end
        if EG.ProfileGUI and EG.ProfileGUI.OnInit then EG.ProfileGUI:OnInit() end
        return
    end

    if event == "PLAYER_LEVEL_UP" or event == "CHARACTER_POINTS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        EG:InvalidateTalents()
        EG:InvalidateProfile()
        EG:WipeItemCache()
        EG:InvalidateEquippedTotals()
        EG:Debounce("refresh", 0.5, function()
            EG:RefreshAllBags()
            if EG.GUI then EG.GUI:Refresh() end
            if EG.ProfileGUI then EG.ProfileGUI:Refresh() end
        end)
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            --[[ Die Slot-Aufloesung haengt davon ab, ob eine Zweihandwaffe
                 gefuehrt wird, die automatische Profilwahl von der
                 Waffenhaltung - deshalb alles verwerfen, nicht nur den
                 Score-Cache.                                              ]]
            if EG:GetActiveProfileID() == "AUTO" then EG.profileCache = nil end
            EG:InvalidateComparisons()
            EG:InvalidateEquippedTotals()
            EG:Debounce("inv", 0.3, function()
                EG:RefreshAllBags()
                if EG.GUI then EG.GUI:Refresh() end
                if EG.ProfileGUI then EG.ProfileGUI:Refresh() end
            end)
        end
        return
    end

    if event == "BAG_UPDATE" then
        EG:Debounce("bag", 0.3, function() EG:RefreshAllBags() end)
        return
    end

    if event == "QUEST_COMPLETE" or event == "QUEST_DETAIL"
        or event == "QUEST_ITEM_UPDATE" then
        EG:Debounce("questevt", 0.2, function() EG:UpdateQuestRewards() end)
        return
    end
end)
