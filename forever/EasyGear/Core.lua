--[[---------------------------------------------------------------------------
    EasyGear 4.0.0 - Forever
    Ausruestungsbewertung, Upgrade-Erkennung und Vergleich fuer WoW Forever

    Dieses Addon vergleicht und empfiehlt, mehr nicht: es verschickt keine
    Befehle, legt nichts an und braucht kein weiteres Addon. Es benutzt nur
    die Standard-Oberflaeche des Forever-Clients.

    Dateien (Ladereihenfolge siehe EasyGear.toc):
      Locales/*.lua      Texte, eine Datei je Clientsprache
      Core.lua           Namensraum, Einstellungen, Ereignisse, Zeitgeber, Ausgabe
      Stats.lua          Werte eines Gegenstands lesen (GetItemStats + Tooltip)
      Specs.lua          Gewichtungsprofile der neun Klassen
      Profiles.lua       Profilwahl, Talenterkennung, eigene Profile
      Items.lua          Gegenstandsdaten (mit Zwischenspeicher)
      Score.lua          Bewertung, Plaetze, Vergleich
      Recommend.lua      Empfehlungen: Upgrades in Taschen, beste Questbelohnung
      Tooltip.lua        Zeilen im Gegenstands-Tooltip
      Marks.lua          Markierungen auf Gegenstandssymbolen
      Contexts.lua       Anbindung: Taschen, Bank, Haendler, Beute, Wuerfeln, Quests, ...
      Window.lua         Vergleichsfenster
      ProfileWindow.lua  Profilfenster
      Options.lua        Einstellungsseite (Optionen > AddOns) und Addon-Fach
      Slash.lua          Chatbefehle
-----------------------------------------------------------------------------]]

local ADDON_NAME, EG = ...
if type(EG) ~= "table" then EG = {} end
_G.EasyGear = EG

EG.name = ADDON_NAME or "EasyGear"

-- Lokale Kopien haeufig genutzter Globals
local pairs, type, tostring, tonumber, select = pairs, type, tostring, tonumber, select
local pcall, setmetatable = pcall, setmetatable
local tinsert, tsort = table.insert, table.sort
local sformat = string.format

------------------------------------------------------------------------------
-- 01  Version und Spieltyp
------------------------------------------------------------------------------

do
    local meta
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        meta = C_AddOns.GetAddOnMetadata(EG.name, "Version")
    end
    EG.version = meta or "4.0.0"
end

-- WoW Forever meldet sich ueber WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (Blizzard_ProjectConstants).
-- Auf anderen Clients (Test mit der Retail-Oberflaeche) laeuft das Addon trotzdem, meldet es aber einmal.
EG.isForever = (WOW_PROJECT_CAMELOT ~= nil) and (WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)

------------------------------------------------------------------------------
-- 02  Lokalisierung
------------------------------------------------------------------------------

--[[ Die Texte stehen in Locales/<Sprache>.lua. Jede Datei traegt ihre Tabelle in
     EasyGearLocales[<GetLocale()>] ein. Aufloesung je Schluessel:
         Clientsprache  ->  Englisch  ->  Schluessel.
     Fehlt eine Uebersetzung, erscheint also der englische Text. enUS ist die
     vollstaendige Referenz.                                                     ]]
local L
do
    _G.EasyGearLocales = _G.EasyGearLocales or {}
    local ALIAS = { enGB = "enUS", esMX = "esES" }
    local client = (GetLocale and GetLocale()) or "enUS"
    local active = ALIAS[client] or client
    local base = _G.EasyGearLocales["enUS"]
    local cur = (active ~= "enUS") and _G.EasyGearLocales[active] or nil

    local loaded = {}
    for code in pairs(_G.EasyGearLocales) do loaded[#loaded + 1] = code end
    tsort(loaded)

    EG.locale = {
        client = client,
        active = cur and active or "enUS",
        translated = cur ~= nil,
        baseOK = base ~= nil,
        loaded = loaded,
    }

    L = setmetatable({}, { __index = function(_, k)
        local v = cur and cur[k]
        if v == nil and base then v = base[k] end
        if v == nil then v = k end
        return v
    end })

    function EG:LocaleHas(key)
        return (cur and cur[key] ~= nil) or (base and base[key] ~= nil) or false
    end
end
EG.L = L

------------------------------------------------------------------------------
-- 03  Ausgabe
------------------------------------------------------------------------------

local COLOR = {
    title = "|cff00ccff",
    good  = "|cff00ff00",
    bad   = "|cffff2020",
    warn  = "|cffffcc00",
    value = "|cffffff00",
    grey  = "|cff9d9d9d",
    reset = "|r",
}
EG.COLOR = COLOR

local function Emit(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    elseif print then
        print(text)
    end
end

function EG:Raw(text)
    Emit(tostring(text))
end

function EG:Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    Emit(COLOR.title .. "EasyGear" .. COLOR.reset .. ": " .. table.concat(parts, " "))
end

--[[ Fehler in Rueckrufen (Haken, Zeitgeber, Befehle) duerfen nie das Spiel stoeren: pcall. Jede verschiedene
     Meldung erscheint einmal im Chat (ein Fehler, der bei jedem Tooltip auftritt, soll nicht den Chat fluten,
     aber auch nicht unbemerkt bleiben) und steht danach in EG.lastError (/eg status).                        ]]
local reportedErrors = {}
function EG:Try(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local key = tostring(label) .. ":" .. tostring(err)
        if not reportedErrors[key] then
            reportedErrors[key] = true
            EG.lastError = { label = label, err = err }
            Emit(COLOR.bad .. "EasyGear[" .. tostring(label) .. "]: " .. string.sub(tostring(err), 1, 400) .. COLOR.reset)
        end
        return false, err
    end
    return true, err
end

-- Eine Funktion, die Fehler abfaengt wie EG:Try - fuer die Skripte der eigenen Fenster und Rueckrufe der Einstellungen
function EG:Guard(label, fn)
    return function(...) EG:Try(label, fn, ...) end
end

------------------------------------------------------------------------------
-- 04  Zahlen und Texte
------------------------------------------------------------------------------

function EG.Round(v, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor((v or 0) * m + 0.5) / m
end

-- Punkte ohne unnoetige Nachkommastellen
function EG.FmtScore(v)
    v = tonumber(v) or 0
    if math.abs(v) >= 100 or v == math.floor(v) then return sformat("%d", EG.Round(v)) end
    return sformat("%.1f", v)
end

function EG.FmtSigned(v)
    v = tonumber(v) or 0
    return (v >= 0 and "+" or "-") .. EG.FmtScore(math.abs(v))
end

function EG.FmtPct(v)
    v = tonumber(v) or 0
    return sformat("%s%.1f%%", v >= 0 and "+" or "-", math.abs(v))
end

-- Gewicht mit hoechstens drei Nachkommastellen (0.025 ist ein haeufiger Wert), ohne ueberfluessige Nullen
function EG.FmtWeight(w)
    local s = sformat("%.3f", tonumber(w) or 0)
    if s:find(".", 1, true) then
        s = s:gsub("0+$", "")
        s = s:gsub("%.$", "")
    end
    return s
end

-- Text mit Zwischenraeumen am Rand abschneiden
function EG.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

------------------------------------------------------------------------------
-- 05  Einstellungen
------------------------------------------------------------------------------

local DEFAULTS = {
    ilvlWeight        = 0.5,    -- Punkte je Gegenstandsstufe auf der Hoechststufe
    ilvlScaling       = true,   -- Stufenanteil mit der Charakterstufe skalieren
    socketValue       = nil,    -- nil = automatisch
    showBagIcons      = true,   -- Markierung in Taschen und Bank
    showItemIcons     = true,   -- Haendler, Beute, Wuerfeln, Handel, Post
    showQuestIcons    = true,   -- beste Questbelohnung
    showCharIcons     = true,   -- Hinweis am Charakterfenster: in den Taschen liegt etwas Besseres
    showTooltip       = true,
    showTooltipStats  = true,   -- Platz- und Vergleichszeile im Tooltip
    tooltipDiff       = true,   -- Attribut-Unterschiede im Tooltip
    includeEnchants   = true,   -- Verzauberungen und Edelsteine mitrechnen
    autoLeveling      = true,   -- unter der Hoechststufe das Leveln-Profil der Klasse
    minDelta          = 0,      -- Mindestvorsprung in Punkten fuer "Upgrade"
    minDeltaPercent   = 1,      -- zusaetzlich: Prozent des Vergleichswerts
    custom            = {},     -- eigene Profile (kontoweit)
}
EG.DEFAULTS = DEFAULTS

--[[ Wertebereiche der Zahleneinstellungen. Die Regler der Einstellungsseite und die Chatbefehle benutzen dieselben:
     ein Wert ausserhalb des Reglers wuerde bei offener Seite vom Regler stillschweigend zurechtgestutzt. ]]
EG.RANGES = {
    ilvlWeight      = { 0, 2 },
    minDeltaPercent = { 0, 10 },
    minDelta        = { 0, 1000 },
    socketValue     = { 0, 1000 },
    scale           = { 0.5, 2.0 },
}

local CHAR_DEFAULTS = {
    profile = "AUTO",           -- Profil-ID oder "AUTO" (Talenterkennung)
    gui     = { point = "CENTER", x = 0, y = 0, scale = 1.0 },
}
EG.CHAR_DEFAULTS = CHAR_DEFAULTS

local function CopyDefaults(target, source)
    for k, v in pairs(source) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                CopyDefaults(target[k], v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" and k ~= "custom" then
            CopyDefaults(target[k], v)
        end
    end
end
EG.CopyDefaults = CopyDefaults

function EG:InitDB()
    _G.EasyGearDB = type(_G.EasyGearDB) == "table" and _G.EasyGearDB or {}
    _G.EasyGearCharDB = type(_G.EasyGearCharDB) == "table" and _G.EasyGearCharDB or {}
    self.db = _G.EasyGearDB
    self.cdb = _G.EasyGearCharDB
    CopyDefaults(self.db, DEFAULTS)
    CopyDefaults(self.cdb, CHAR_DEFAULTS)
    if type(self.db.custom) ~= "table" then self.db.custom = {} end
end

-- Alle Einstellungen auf Standard (eigene Profile bleiben); Fensterlage und Massstab auch
function EG:ResetDB()
    local custom = self.db and self.db.custom or {}
    for k in pairs(self.db) do self.db[k] = nil end
    self.db.custom = custom
    CopyDefaults(self.db, DEFAULTS)
    self.cdb.profile = CHAR_DEFAULTS.profile
    self.cdb.gui = nil
    self.cdb.profileGui = nil
    CopyDefaults(self.cdb, CHAR_DEFAULTS)
    self:Fire("GUI_RESET")
    self:InvalidateAll()
end

------------------------------------------------------------------------------
-- 06  Ereignisse und Zeitgeber
------------------------------------------------------------------------------

local handlers = {}         -- Ereignis -> Liste von Funktionen
local eventFrame = CreateFrame("Frame")
EG.eventFrame = eventFrame

local function Dispatch(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        EG:Try("event " .. event, list[i], event, ...)
    end
end

-- Ereignis des Clients abonnieren (mehrere Abonnenten je Ereignis moeglich)
function EG:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    tinsert(handlers[event], fn)
end
eventFrame:SetScript("OnEvent", Dispatch)

-- Eigene Ereignisse zwischen den Modulen
local listeners = {}
function EG:Listen(name, fn)
    listeners[name] = listeners[name] or {}
    tinsert(listeners[name], fn)
end

function EG:Fire(name, ...)
    local list = listeners[name]
    if not list then return end
    for i = 1, #list do
        EG:Try("listener " .. name, list[i], ...)
    end
end

function EG:After(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function() EG:Try("timer", fn) end)
    else
        fn()
    end
end

local debounce = {}
function EG:Debounce(key, delay, fn)
    if debounce[key] then
        debounce[key].again = true
        return
    end
    debounce[key] = { again = false }
    local function run()
        local st = debounce[key]
        if st and st.again then
            st.again = false
            EG:After(delay, run)
            return
        end
        debounce[key] = nil
        fn()
    end
    EG:After(delay, run)
end

-- Module melden sich fuer die Einrichtung an:  OnLoad = Einstellungen sind da, OnLogin = Spieler ist da
local loadFns, loginFns = {}, {}
function EG:OnLoad(name, fn) tinsert(loadFns, { name = name, fn = fn }) end
function EG:OnLogin(name, fn) tinsert(loginFns, { name = name, fn = fn }) end

EG.hookStatus = {}      -- Name -> { ok = bool, note = text }
function EG:HookResult(name, ok, note)
    self.hookStatus[name] = { ok = ok and true or false, note = note }
end

EG:On("ADDON_LOADED", function(_, addon)
    if addon ~= EG.name then return end
    EG:InitDB()
    for i = 1, #loadFns do EG:Try("load " .. loadFns[i].name, loadFns[i].fn) end
end)

EG:On("PLAYER_LOGIN", function()
    if not EG.db then EG:InitDB() end
    for i = 1, #loginFns do EG:Try("login " .. loginFns[i].name, loginFns[i].fn) end
    EG:Print(sformat(L.LOADED, EG.version))
    if not EG.isForever then EG:Print(COLOR.warn .. L.NOT_FOREVER .. COLOR.reset) end
    for _, status in pairs(EG.hookStatus) do
        if not status.ok then
            EG:Print(COLOR.warn .. L.HOOKS_FAILED .. COLOR.reset)
            break
        end
    end
end)

------------------------------------------------------------------------------
-- 07  Zwischenspeicher
------------------------------------------------------------------------------

-- Jede Aenderung an Profil, Ausruestung oder Einstellungen verwirft die berechneten Ergebnisse
local caches = {}
function EG:RegisterCache(tbl) tinsert(caches, tbl) end

function EG:InvalidateComparisons()
    for i = 1, #caches do
        for k in pairs(caches[i]) do caches[i][k] = nil end
    end
end

-- Berechnete Ergebnisse verwerfen (Profilwahl und alle Vergleiche), ohne die Anzeigen zu benachrichtigen
function EG:InvalidateResults()
    if self.Profiles and self.Profiles.Invalidate then self.Profiles.Invalidate() end
    self:InvalidateComparisons()
end

function EG:InvalidateAll()
    self:InvalidateResults()
    self:Fire("INVALIDATED")
end

-- Einstellung setzen; wirkt sofort
function EG:Set(key, value)
    self.db[key] = value
    self:InvalidateAll()
end

function EG:Get(key)
    local v = self.db and self.db[key]
    if v == nil then v = DEFAULTS[key] end
    return v
end
