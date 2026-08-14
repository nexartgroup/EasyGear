--[[---------------------------------------------------------------------------
    EasyGear 2.3.1
    Gear-Bewertung, Upgrade-Erkennung und Vergleich fuer WoW 3.3.5a (WotLK)

    Kompatibilitaet:
      * Client 3.3.5a / Interface 30300
      * deDE (HD-Client) und enUS
      * Lua 5.1

    Struktur dieser Datei:
      01  Namespace & Konstanten
      02  Lokalisierung
      03  Hilfsfunktionen (Timer, Ausgabe, Farben)
      04  Scan-Tooltip (Verwendbarkeit, DPS, Heirloom-Werte)
      05  Statistik-Schluessel & Gewichtungsprofile
      06  Spec-/Rollen-Erkennung
      07  Item-Daten (mit Cache)
      08  Bewertung & Berechnungsgrundlagen
      09  Slot-Aufloesung
      10  Verwendbarkeit (Ruestungsklasse, Waffen, Tooltip)
      11  Vergleichs-Engine
      12  Taschen-Indikatoren + Hooks (Blizzard / ElvUI / Bagnon / Bank)
      13  Questbelohnungen
      14  Tooltip-Integration
      15  EGUP (GM-Paket) und EGUPCLEAN
      16  Slash-Befehle
      17  Initialisierung
-----------------------------------------------------------------------------]]

------------------------------------------------------------------------------
-- 01  Namespace & Konstanten
------------------------------------------------------------------------------

local ADDON_NAME    = "EasyGear"
local ADDON_VERSION = "2.3.1"

EasyGear = EasyGear or {}
local EG = EasyGear

EG.name    = ADDON_NAME
EG.version = ADDON_VERSION

-- Lokale Kopien haeufig genutzter Globals (Lua-5.1-Performance)
local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring
local select, unpack, wipe = select, unpack, wipe
local tinsert, tremove, tconcat, tsort = table.insert, table.remove, table.concat, table.sort
local sformat, smatch, sgsub, sfind, slower = string.format, string.match, string.gsub, string.find, string.lower
local mhuge, mfloor, mmin, mmax = math.huge, math.floor, math.min, math.max

local HEIRLOOM_QUALITY  = 7
local HEIRLOOM_MAX_LEVEL= 80
local MAX_EQUIP_SLOT    = 19

-- Texturen
local TEX_UPGRADE = "Interface\\Buttons\\UI-CheckBox-Check"
local TEX_VENDOR  = "Interface\\MoneyFrame\\UI-GoldIcon"

-- Standardeinstellungen (SavedVariables)
local DEFAULTS = {
    ilvlWeight       = 0.5,     -- Punkte pro Gegenstandsstufe (auf Stufe 80)
    ilvlScaling      = true,    -- Gegenstandsstufen-Basis mit Charakterstufe skalieren
    dpsWeight        = nil,     -- nil = Wert aus dem Rollenprofil
    socketValue      = 8,       -- Punkte pro freiem Sockelplatz
    showBagIcons     = true,
    showQuestIcons   = true,
    showTooltip      = true,
    showTooltipStats = true,    -- Detailzeilen im Tooltip
    protectHeirlooms = true,
    iconSize         = 20,
    minDelta         = 0,       -- Mindestpunkte-Vorsprung fuer "Upgrade"
    minDeltaPercent  = 1,       -- zusaetzlich: Prozent des Vergleichswerts
    egupCommand      = ".additem {name} {id} {count}",
    egupConfirm      = true,
    egupDelay        = 0.35,
    debug            = false,
    custom           = {},      -- eigene Profile (accountweit)
}

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

local L
do
    local strings = {
        -- allgemein
        LOADED            = "EasyGear %s loaded.",
        CMD_HEADER        = "Commands:",
        CMD_EG            = "/eg            - open the comparison window",
        CMD_EG_LINK       = "/eg <itemlink> - evaluate an item in chat",
        CMD_EG_HELP       = "/eg help       - show all options",
        CMD_EGUP          = "/egup          - GM: give the target the class package",
        CMD_EGUPCLEAN     = "/egupclean     - remove recorded EGUP items from bags",
        INVALID_ITEM      = "Could not read item information. Please supply a valid item link.",
        ITEM_LOADING      = "Item data is not cached yet - please try again in a moment.",
        -- Bewertung
        TITLE             = "EasyGear - Item comparison",
        CANDIDATE         = "Item to compare",
        EQUIPPED          = "Currently equipped",
        NOTHING_EQUIPPED  = "Slot is empty",
        DROP_HINT         = "Drag an item here\nor shift-click it",
        SCORE             = "Score",
        ILVL              = "Item level",
        SLOT              = "Slot",
        TYPE              = "Type",
        SUBTYPE           = "Subtype",
        REQLEVEL          = "Required level",
        SELLPRICE         = "Vendor price",
        QUALITY           = "Quality",
        STAT              = "Attribute",
        VALUE             = "Value",
        WEIGHT            = "Weight",
        POINTS            = "Points",
        TOTAL             = "Total",
        BASE_ILVL         = "Item level base",
        WEAPON_DPS        = "Weapon DPS",
        SOCKETS           = "Empty sockets",
        DIFFERENCE        = "Difference",
        UPGRADE           = "UPGRADE",
        NO_UPGRADE        = "NO UPGRADE",
        NOT_USABLE        = "NOT USABLE",
        PROFILE           = "Profile",
        HEIRLOOM          = "Heirloom",
        PROTECTED         = "protected",
        -- Begruendungen
        R_HEIRLOOM        = "An equipped heirloom is treated as best in slot below level %d.",
        R_LOWER           = "The equipped item has a higher score.",
        R_EQUAL           = "Same score as the equipped item.",
        R_CLASS           = "Not usable by your class or armor proficiency.",
        R_LEVEL           = "You need level %d for this item.",
        R_EMPTY           = "The slot is empty - anything is an improvement.",
        R_MINDELTA        = "The advantage of %s points is within noise - not counted as an upgrade.",
        NOTE_2H           = "A two-handed weapon replaces main hand and off hand.",
        NOTE_OFFHAND      = "A two-handed weapon is equipped and would have to be removed - compared against main hand plus off hand.",
        NOTE_MH_2H        = "Would replace the equipped two-handed weapon.",
        NOTE_HEIRLOOM_EST = "Heirloom values are read from the tooltip and are approximate.",
        -- GUI
        BTN_CLEAR         = "Clear",
        BTN_CHAT          = "Print to chat",
        BTN_CLOSE         = "Close",
        GUI_SLOT1         = "Slot 1",
        GUI_SLOT2         = "Slot 2",
        GUI_COMPARED      = "compared against",
        -- Rollen
        ROLE_AUTO         = "Automatic",
        ROLE_TANK         = "Tank",
        ROLE_MELEE        = "Melee DPS",
        ROLE_RANGED       = "Ranged DPS",
        ROLE_CASTER       = "Caster DPS",
        ROLE_HEAL         = "Healer",
        -- Einstellungen
        SET_ROLE          = "Role set to: %s",
        ENCHANTED         = "enchanted",
        GEMMED            = "%d gem(s)",
        P_CANDIDATE       = "Comparison profile",
        P_ACTIVEPROF      = "Active profile",
        P_CLASS           = "Class",
        P_MYCLASS         = "My class",
        P_GEAR            = "Your equipped gear",
        P_GEAR_SCORE      = "Gear score",
        P_ITEM_LINE       = "Item from the comparison window",
        P_SAVE_NEW        = "Save as new profile",
        P_OVERWRITE       = "Save",
        P_IS_ACTIVE       = "This is already the active profile.",
        P_EDIT_HINT       = "Edit mode: change the weights on the left, then save.",
        P_BETTER          = "Your gear collects more points under this weighting.",
        P_WORSE           = "Your gear collects fewer points under this weighting.",
        P_SAME            = "Same score under both weightings.",
        P_CAVEAT          = "Totals of different profiles are only roughly comparable - what matters is which attributes carry the points.",
        P_NOGEAR          = "No gear equipped.",
        P_ITEMS           = "%d items",
        SET_PROFILE       = "Active profile: %s",
        SET_PVP           = "PvP mode: %s",
        PROFILE_LIST      = "Available profiles",
        PROFILE_AUTO_HINT = "detect from talent tree",
        PROFILE_CMD_HINT  = "* = own profile   |   /eg profile <id>   |   /egprofile for the window",
        PROFILE_UNKNOWN   = "Unknown profile: %s",
        CMD_EGPROFILE     = "- profile overview and comparison",
        P_TITLE           = "EasyGear - Profiles",
        P_ACTIVATE        = "Activate A",
        P_EDIT            = "Edit",
        P_DELETE          = "Delete",
        P_PVP             = "PvP mode (resilience and stamina)",
        P_NEW_PROMPT      = "Name for the new profile:",
        P_ONLY_CUSTOM     = "Only your own profiles can be edited - use Copy A first.",
        SET_ILVL          = "Item level weight: %s",
        SET_ON            = "enabled",
        SET_OFF           = "disabled",
        SET_RESET         = "Settings reset to defaults.",
        SET_SCALE         = "Window scale: %s",
        SET_MINDELTA      = "Minimum difference: %s points (+ %s%% relative)",
        SET_ILVLSCALE     = "Item level base scales with character level: %s (currently x%s)",
        -- EGUP
        EGUP_NO_TARGET    = "Target a player first.",
        EGUP_NOT_PLAYER   = "The target is not a player.",
        EGUP_NO_CLASS     = "Could not determine the target's class.",
        EGUP_NO_PACKAGE   = "No package configured for %s.",
        EGUP_CONFIRM      = "Send the %s package (%d entries) to %s?",
        EGUP_RUNNING      = "Sending package to %s ...",
        EGUP_DONE         = "EGUP completed.",
        EGUP_HINT         = "After equipping the desired items use /egupclean.",
        EGUP_NO_SESSION   = "No EGUP session available to clean.",
        EGUP_WRONG_CHAR   = "EGUPCLEAN must be run by the character that received the package (%s).",
        EGUP_CLEAN_START  = "Scanning bags for items from the last EGUP session ...",
        EGUP_CLEAN_NONE   = "Nothing to clean.",
        EGUP_CLEAN_DONE   = "EGUPCLEAN completed - %d item(s) removed.",
        -- Integrationen
        HOOK_ELVUI        = "ElvUI bag support enabled.",
        HOOK_BAGNON       = "Bagnon bag support enabled.",
    }

    if GetLocale() == "deDE" then
        local de = {
            LOADED            = "EasyGear %s geladen.",
            CMD_HEADER        = "Befehle:",
            CMD_EG            = "/eg            - Vergleichsfenster \195\182ffnen",
            CMD_EG_LINK       = "/eg <itemlink> - Item im Chat auswerten",
            CMD_EG_HELP       = "/eg help       - alle Optionen anzeigen",
            CMD_EGUP          = "/egup          - GM: Klassenpaket an das Ziel geben",
            CMD_EGUPCLEAN     = "/egupclean     - erfasste EGUP-Items aus den Taschen entfernen",
            INVALID_ITEM      = "Item-Informationen konnten nicht gelesen werden. Bitte einen g\195\188ltigen Itemlink angeben.",
            ITEM_LOADING      = "Die Item-Daten sind noch nicht im Cache - bitte gleich noch einmal versuchen.",
            TITLE             = "EasyGear - Item-Vergleich",
            CANDIDATE         = "Zu vergleichendes Item",
            EQUIPPED          = "Aktuell angelegt",
            NOTHING_EQUIPPED  = "Slot ist leer",
            DROP_HINT         = "Item hierher ziehen\noder anklicken mit Shift",
            SCORE             = "Wertung",
            ILVL              = "Gegenstandsstufe",
            SLOT              = "Slot",
            TYPE              = "Typ",
            SUBTYPE           = "Untertyp",
            REQLEVEL          = "Ben\195\182tigte Stufe",
            SELLPRICE         = "H\195\164ndlerpreis",
            QUALITY           = "Qualit\195\164t",
            STAT              = "Attribut",
            VALUE             = "Wert",
            WEIGHT            = "Gewicht",
            POINTS            = "Punkte",
            TOTAL             = "Gesamt",
            BASE_ILVL         = "Basis Gegenstandsstufe",
            WEAPON_DPS        = "Waffen-DPS",
            SOCKETS           = "Freie Sockel",
            DIFFERENCE        = "Differenz",
            UPGRADE           = "VERBESSERUNG",
            NO_UPGRADE        = "KEINE VERBESSERUNG",
            NOT_USABLE        = "NICHT VERWENDBAR",
            PROFILE           = "Profil",
            HEIRLOOM          = "Erbst\195\188ck",
            PROTECTED         = "gesch\195\188tzt",
            R_HEIRLOOM        = "Ein angelegtes Erbst\195\188ck gilt unterhalb von Stufe %d als bestes Item des Slots.",
            R_LOWER           = "Das angelegte Item hat die h\195\182here Wertung.",
            R_EQUAL           = "Gleiche Wertung wie das angelegte Item.",
            R_CLASS           = "F\195\188r deine Klasse bzw. R\195\188stungsklasse nicht verwendbar.",
            R_LEVEL           = "Du ben\195\182tigst Stufe %d f\195\188r dieses Item.",
            R_EMPTY           = "Der Slot ist leer - alles ist eine Verbesserung.",
            R_MINDELTA        = "Der Vorsprung liegt unter der Schwelle von %s Punkten - das ist Rauschen.",
            NOTE_2H           = "Eine Zweihandwaffe ersetzt Waffenhand und Schildhand.",
            NOTE_OFFHAND      = "Die angelegte Zweihandwaffe m\195\188sste daf\195\188r abgelegt werden - verglichen wird gegen Waffenhand + Schildhand.",
            NOTE_MH_2H        = "W\195\188rde die angelegte Zweihandwaffe ersetzen.",
            NOTE_HEIRLOOM_EST = "Erbst\195\188ck-Werte werden aus dem Tooltip gelesen und sind N\195\164herungswerte.",
            BTN_CLEAR         = "Leeren",
            BTN_CHAT          = "In den Chat",
            BTN_CLOSE         = "Schlie\195\159en",
            GUI_SLOT1         = "Slot 1",
            GUI_SLOT2         = "Slot 2",
            GUI_COMPARED      = "verglichen mit",
            ROLE_AUTO         = "Automatisch",
            ROLE_TANK         = "Tank",
            ROLE_MELEE        = "Nahkampf-DD",
            ROLE_RANGED       = "Fernkampf-DD",
            ROLE_CASTER       = "Zauber-DD",
            ROLE_HEAL         = "Heiler",
            SET_ROLE          = "Rolle gesetzt: %s",
            ENCHANTED         = "verzaubert",
            GEMMED            = "%d Sockelstein(e)",
            P_CANDIDATE       = "Vergleichsprofil",
            P_ACTIVEPROF      = "Aktives Profil",
            P_CLASS           = "Klasse",
            P_MYCLASS         = "Meine Klasse",
            P_GEAR            = "Deine angelegte Ausr\195\188stung",
            P_GEAR_SCORE      = "Ausr\195\188stungswertung",
            P_ITEM_LINE       = "Item aus dem Vergleichsfenster",
            P_SAVE_NEW        = "Als neues Profil speichern",
            P_OVERWRITE       = "Speichern",
            P_IS_ACTIVE       = "Das ist bereits das aktive Profil.",
            P_EDIT_HINT       = "Bearbeitungsmodus: links die Gewichte \195\164ndern, dann speichern.",
            P_BETTER          = "Deine Ausr\195\188stung sammelt unter dieser Gewichtung mehr Punkte.",
            P_WORSE           = "Deine Ausr\195\188stung sammelt unter dieser Gewichtung weniger Punkte.",
            P_SAME            = "Gleiche Wertung unter beiden Gewichtungen.",
            P_CAVEAT          = "Gesamtsummen verschiedener Profile sind nur grob vergleichbar - aussagekr\195\164ftig ist, welche Attribute die Punkte tragen.",
            P_NOGEAR          = "Keine Ausr\195\188stung angelegt.",
            P_ITEMS           = "%d Teile",
            SET_PROFILE       = "Aktives Profil: %s",
            SET_PVP           = "PvP-Modus: %s",
            PROFILE_LIST      = "Verf\195\188gbare Profile",
            PROFILE_AUTO_HINT = "\195\188ber Talentbaum erkennen",
            PROFILE_CMD_HINT  = "* = eigenes Profil   |   /eg profile <id>   |   /egprofile \195\182ffnet das Fenster",
            PROFILE_UNKNOWN   = "Unbekanntes Profil: %s",
            CMD_EGPROFILE     = "- Profil\195\188bersicht und Vergleich",
            P_TITLE           = "EasyGear - Profile",
            P_ACTIVATE        = "A aktivieren",
            P_EDIT            = "Bearbeiten",
            P_DELETE          = "L\195\182schen",
            P_PVP             = "PvP-Modus (Abh\195\164rtung und Ausdauer)",
            P_NEW_PROMPT      = "Name f\195\188r das neue Profil:",
            P_ONLY_CUSTOM     = "Nur eigene Profile lassen sich bearbeiten - zuerst A kopieren.",
            SET_ILVL          = "Gewicht Gegenstandsstufe: %s",
            SET_ON            = "aktiviert",
            SET_OFF           = "deaktiviert",
            SET_RESET         = "Einstellungen auf Standard zur\195\188ckgesetzt.",
            SET_SCALE         = "Fenstergr\195\182\195\159e: %s",
            SET_MINDELTA      = "Mindestdifferenz: %s Punkte (+ %s%% relativ)",
            SET_ILVLSCALE     = "Basis Gegenstandsstufe skaliert mit Charakterstufe: %s (aktuell x%s)",
            EGUP_NO_TARGET    = "Bitte zuerst einen Spieler anvisieren.",
            EGUP_NOT_PLAYER   = "Das Ziel ist kein Spieler.",
            EGUP_NO_CLASS     = "Die Klasse des Ziels konnte nicht ermittelt werden.",
            EGUP_NO_PACKAGE   = "Kein Paket f\195\188r %s konfiguriert.",
            EGUP_CONFIRM      = "Paket %s (%d Eintr\195\164ge) an %s senden?",
            EGUP_RUNNING      = "Sende Paket an %s ...",
            EGUP_DONE         = "EGUP abgeschlossen.",
            EGUP_HINT         = "Nach dem Anlegen der gew\195\188nschten Items /egupclean benutzen.",
            EGUP_NO_SESSION   = "Keine EGUP-Sitzung zum Aufr\195\164umen vorhanden.",
            EGUP_WRONG_CHAR   = "EGUPCLEAN muss von dem Charakter ausgef\195\188hrt werden, der das Paket erhalten hat (%s).",
            EGUP_CLEAN_START  = "Durchsuche Taschen nach Items der letzten EGUP-Sitzung ...",
            EGUP_CLEAN_NONE   = "Nichts aufzur\195\164umen.",
            EGUP_CLEAN_DONE   = "EGUPCLEAN abgeschlossen - %d Item(s) entfernt.",
            HOOK_ELVUI        = "ElvUI-Taschenunterst\195\188tzung aktiviert.",
            HOOK_BAGNON       = "Bagnon-Taschenunterst\195\188tzung aktiviert.",
        }
        for k, v in pairs(de) do strings[k] = v end
    end

    L = setmetatable(strings, { __index = function(_, k) return k end })
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

-- Muster-Sonderzeichen entschaerfen
local function EscapePattern(s)
    return (sgsub(s or "", "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

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

-- Muster fuer "(x.y Schaden pro Sekunde)" bzw. "(x.y damage per second)"
local dpsPattern
do
    local tpl = DPS_TEMPLATE or "(%s damage per second)"
    tpl = sgsub(tpl, "%%%d%$s", "\1")
    tpl = sgsub(tpl, "%%s", "\1")
    tpl = EscapePattern(tpl)
    dpsPattern = sgsub(tpl, "\1", "([%%d%%.,]+)")
end

-- Muster fuer "Benoetigt Stufe X" - solche roten Zeilen behandeln wir separat
local minLevelPattern
do
    local tpl = ITEM_MIN_LEVEL or "Requires Level %d"
    tpl = sgsub(tpl, "%%%d%$d", "\1")
    tpl = sgsub(tpl, "%%d", "\1")
    tpl = EscapePattern(tpl)
    minLevelPattern = sgsub(tpl, "\1", "(%%d+)")
end

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
-- 05  Statistik-Schluessel & Gewichtungsprofile
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

-- Pseudo-Schluessel, die nicht aus GetItemStats() stammen
local PSEUDO_DPS    = "__DPS"
local PSEUDO_SOCKET = "__SOCKET"
EG.PSEUDO_DPS    = PSEUDO_DPS
EG.PSEUDO_SOCKET = PSEUDO_SOCKET

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
    DPS    = "__DPS",
    SOCKET = "__SOCKET",
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
-- 06  Spec-/Rollen-Erkennung
------------------------------------------------------------------------------

EG.profileCache = nil
EG.epoch = 0

-- Jede Aenderung an Profil oder Einstellungen erhoeht die Epoche; daran
-- erkennen die Taschen-Buttons, dass ihr zwischengespeichertes Ergebnis
-- veraltet ist.
function EG:InvalidateProfile()
    self.profileCache = nil
    self.scoreCache = {}
    self.epoch = (self.epoch or 0) + 1
end

--[[--------------------------------------------------------------------
     Profilverwaltung

     Alle Profile liegen in EG.SPECS (klassenweise) und EG.SPECS_ANY
     (klassenunabhaengig); eigene Profile kommen aus EasyGearDB.custom.
     Ausgewaehlt wird ueber die ID in EasyGearCharDB.profile, "AUTO"
     bedeutet Erkennung ueber den Talentbaum.
----------------------------------------------------------------------]]

-- PvP-Aufschlag: Abhaertung und Ausdauer werden aufgewertet
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

function EG:GetProfileName(spec)
    if not spec then return "?" end
    if spec.custom then return spec.name or spec.id end
    if GetLocale() == "deDE" then return spec.de or spec.en or spec.id end
    return spec.en or spec.de or spec.id
end

function EG:GetProfileDesc(spec)
    if not spec then return "" end
    if spec.custom then return spec.desc or "" end
    if GetLocale() == "deDE" then return spec.hd or spec.he or "" end
    return spec.he or spec.hd or ""
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

-- Talentbaum mit den meisten Punkten -> passendes Profil
function EG:DetectProfile(class)
    class = class or self:GetPlayerClass()
    local list = self.SPECS and self.SPECS[class]

    local bestTab, bestPoints = nil, 0
    local numTabs = (GetNumTalentTabs and GetNumTalentTabs()) or 3
    for i = 1, (numTabs or 3) do
        local _, _, points = GetTalentTabInfo(i)
        if points and points > bestPoints then
            bestPoints, bestTab = points, i
        end
    end

    -- Zu wenige Punkte gesetzt: neutrales Levelprofil
    if not list or not bestTab or bestPoints < 5 then
        return self:GetProfileByID("LEVELING"), true
    end

    local fallback
    for _, spec in ipairs(list) do
        if spec.tab == bestTab then
            if spec.auto then return spec, true end
            fallback = fallback or spec
        end
    end
    return fallback or list[1], true
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

-- Endgueltige Gewichte eines Profils (inklusive PvP-Aufschlag)
function EG:GetWeightsFor(spec, withPvP)
    if not spec then return {} end
    local w = spec.weights or {}
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
        spec = { id = "LEVELING", weights = {}, de = "Levelphase", en = "Leveling" }
    end

    local pvp     = self:IsPvPMode()
    local weights = self:GetWeightsFor(spec, pvp)

    local label = self:GetProfileName(spec)
    if auto then label = label .. " (" .. L.ROLE_AUTO .. ")" end
    if pvp   then label = label .. " [PvP]" end

    local sig = class .. ":" .. tostring(spec.id) .. ":" .. tostring(pvp)
        .. ":" .. tostring(UnitLevel("player"))
        .. ":" .. tostring(self.db and self.db.ilvlWeight)
        .. ":" .. tostring(self.db and self.db.ilvlScaling)
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

    name = (name and name ~= "") and name or "Profil"

    -- eindeutige ID erzeugen
    local base, n = "CUSTOM_" .. sgsub(name, "[^%w]", ""), 1
    if base == "CUSTOM_" then base = "CUSTOM_PROFIL" end
    local id = base
    while self.db.custom[id] or self:GetProfileByID(id) do
        n = n + 1
        id = base .. n
    end

    local source = baseID and self:GetProfileByID(baseID)
    local weights = {}
    if source and source.weights then
        for k, v in pairs(source.weights) do weights[k] = v end
    end

    self.db.custom[id] = {
        id = id, name = name, custom = true, rev = 1,
        class = class or self:GetPlayerClass(),
        role = source and source.role or "MELEE",
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
    return self.profileCache and self.profileCache.profile or "LOWLEVEL"
end

------------------------------------------------------------------------------
-- 07  Item-Daten (mit Cache)
------------------------------------------------------------------------------

EG.itemCache  = {}
EG.scoreCache = {}
local itemCacheCount = 0

function EG:WipeItemCache()
    self.itemCache      = {}
    self.scoreCache     = {}
    self.tipCache       = {}
    self.equippedTotals = nil
    itemCacheCount      = 0
end

-- Statwerte aus dem Tooltip lesen (fuer Erbstuecke, deren GetItemStats()
-- nur die ungeskalierten Basiswerte liefert)
--[[--------------------------------------------------------------------
     Tooltip-Auswertung

     GetItemStats() liest nur die Basiswerte aus dem Itemlink.
     Verzauberungen stehen in SpellItemEnchantment.dbc und tauchen dort
     nicht auf - eine verzauberte Waffe liefert also dieselben Werte wie
     eine unverzauberte. Die einzige verlaessliche Quelle ist der Tooltip,
     denn dort steht die Verzauberung als eigene gruene Zeile.

     WotLK benutzt dabei zwei Formate:
       "+55 Ausdauer"                                (Primaerattribute)
       "Ausruesten: Verbessert Tempowertung um 55."  (Wertungen)
     Deshalb werden Muster aus beiden Globals gebaut: dem kurzen Namen
     (ITEM_MOD_X_SHORT) und der langen Vorlage (ITEM_MOD_X).

     Alle Muster sind vorne und hinten verankert. Das ist wichtig, damit
     Proc-Texte wie "Erhoeht Eure Angriffskraft um 340 fuer 10 Sek." nicht
     als dauerhafter Wert gezaehlt werden.
----------------------------------------------------------------------]]

local statPatternCache

local function LongTemplateToPattern(tpl)
    -- %c steht in einigen Vorlagen fuer das Vorzeichen ("%c%s Staerke")
    local pat = sgsub(tpl, "%%c", "\2")
    pat = sgsub(pat, "%%%d%$s", "\1")
    pat = sgsub(pat, "%%%d%$d", "\1")
    pat = sgsub(pat, "%%s", "\1")
    pat = sgsub(pat, "%%d", "\1")
    pat = EscapePattern(pat)
    pat = sgsub(pat, "\1", "([%%d%%.,]+)")
    pat = sgsub(pat, "\2", "%%+?")
    return pat
end

local function BuildStatPatterns()
    if statPatternCache then return statPatternCache end
    statPatternCache = {}

    local equipPrefix = ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:"
    local escPrefix   = EscapePattern(equipPrefix)

    local function Add(key, pattern)
        statPatternCache[#statPatternCache + 1] = { key = key, pattern = pattern }
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

    return statPatternCache
end

-- Kopfzeile eines Ausruestungssets: "Name (2/5)"
local SET_HEADER_PATTERN = "^.+%s%((%d+)/(%d+)%)$"

EG.tipCache = {}

--[[ Einmaliger Durchlauf durch den Tooltip.
     Rueckgabe: { reason, dps, stats, enchanted }                          ]]
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

                if not result.dps then
                    local v = smatch(text, dpsPattern)
                    if v then result.dps = tonumber((sgsub(v, ",", "."))) end
                end

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
                        break
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
     Haendler-Verkaufspreis pro Einheit.                                   ]]
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
                data.stats[stat] = (tonumber(value) or 0)
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
    end

    if data.isHeirloom then
        -- Erbstuecke skalieren mit der Charakterstufe; GetItemStats()
        -- liefert dafuer nicht die angezeigten Werte, deshalb ersetzen
        -- statt zusammenfuehren.
        local playerLevel = UnitLevel("player") or 1
        data.level = mmin(playerLevel, HEIRLOOM_MAX_LEVEL)
        data.estimated = true
        if scan and scan.hasStats then
            data.stats = scan.stats
        end
    elseif scan and scan.hasStats then
        --[[ Verzauberungen und Sockelsteine stehen nur im Tooltip.
             Zusammengefuehrt wird ueber das Maximum: der Tooltipwert ist
             die Summe aus Basiswert, Verzauberung und Steinen und damit
             normalerweise der groessere. Scheitert das Auslesen einer
             Zeile, bleibt der Basiswert erhalten - so kann nichts
             verlorengehen und nichts doppelt gezaehlt werden.            ]]
        for key, value in pairs(scan.stats) do
            local base = data.stats[key] or 0
            if value > base then
                data.stats[key] = value
                if base > 0 or data.enchanted then data.hasExtraStats = true end
            end
        end
    end

    -- Waffen-DPS
    if equipLoc and (equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_2HWEAPON"
        or equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_WEAPONOFFHAND"
        or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
        or equipLoc == "INVTYPE_THROWN") then
        data.dps = (scan and scan.dps) or 0
    end

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
    if stat == PSEUDO_DPS    then return L.WEAPON_DPS end
    if stat == PSEUDO_SOCKET then return L.SOCKETS end
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

--[[ Liefert Wertung + vollstaendige Berechnungsgrundlage.
     breakdown = Liste von { key, label, value, weight, points }           ]]
function EG:GetScoreBreakdown(item)
    local rows, total = {}, 0
    if not item then return rows, 0 end

    local weights = self:GetProfile()
    local db = self.db or DEFAULTS

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
    if item.dps and item.dps > 0 then
        local w = tonumber(db.dpsWeight) or weights[PSEUDO_DPS] or 0
        if w ~= 0 then
            local points = item.dps * w
            total = total + points
            rows[#rows + 1] = {
                key = PSEUDO_DPS, label = L.WEAPON_DPS,
                value = item.dps, weight = w, points = points,
            }
        end
    end

    -- 5) Freie Sockelplaetze
    if item.sockets and item.sockets > 0 then
        local w = tonumber(db.socketValue) or DEFAULTS.socketValue
        if w ~= 0 then
            local points = item.sockets * w
            total = total + points
            rows[#rows + 1] = {
                key = PSEUDO_SOCKET, label = L.SOCKETS,
                value = item.sockets, weight = w, points = points,
            }
        end
    end

    return rows, total
end

--[[ Summiert alle Werte der angelegten Ausruestung.

     Die Wertung ist linear (Summe aus Gegenstandsstufe x Gewicht und
     Attribut x Gewicht), deshalb ergibt die Summe der Einzelwerte,
     multipliziert mit den Gewichten, exakt dieselbe Gesamtwertung wie das
     Aufaddieren der einzelnen Itemwertungen. Damit laesst sich die
     komplette Ausruestung unter beliebigen Gewichten durchrechnen.       ]]
function EG:GetEquippedTotals(force)
    if self.equippedTotals and not force then return self.equippedTotals end

    local t = { __ILVL = 0, __DPS = 0, __SOCKET = 0, __COUNT = 0 }
    for slot = 1, MAX_EQUIP_SLOT do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local item = self:GetItemData(link)
            if item then
                t.__COUNT  = t.__COUNT + 1
                t.__ILVL   = t.__ILVL + (item.level or 0)
                t.__DPS    = t.__DPS + (item.dps or 0)
                t.__SOCKET = t.__SOCKET + (item.sockets or 0)
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
        if not seen[key] and key ~= "__ILVL" and key ~= "__DPS"
            and key ~= "__SOCKET" and key ~= "__COUNT" then
            local w = weights[key]
            if v ~= 0 and w and w ~= 0 then
                local pts = v * w
                total = total + pts
                rows[#rows + 1] = { key = key, label = self:GetLocalizedStatName(key),
                                    value = v, weight = w, points = pts }
            end
        end
    end

    local dw = weights[PSEUDO_DPS]
    if (totals.__DPS or 0) > 0 and dw and dw ~= 0 then
        local pts = totals.__DPS * dw
        total = total + pts
        rows[#rows + 1] = { key = PSEUDO_DPS, label = L.WEAPON_DPS,
                            value = totals.__DPS, weight = dw, points = pts }
    end

    local sw = tonumber(self.db and self.db.socketValue) or DEFAULTS.socketValue
    if (totals.__SOCKET or 0) > 0 and sw and sw ~= 0 then
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
    local _, total = self:GetScoreBreakdown(item)
    self.profileCache = saved
    return total
end

function EG:GetItemScore(item)
    if not item then return 0 end
    local key = item.link
    if key then
        local _, _, sig = self:GetProfile()
        local cacheKey = sig .. "|" .. key
        local hit = self.scoreCache[cacheKey]
        if hit then return hit end
        local _, total = self:GetScoreBreakdown(item)
        self.scoreCache[cacheKey] = total
        return total
    end
    local _, total = self:GetScoreBreakdown(item)
    return total
end

function EG:GetLinkScore(link)
    local item = self:GetItemData(link)
    if not item then return 0 end
    return self:GetItemScore(item)
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

local SLOT_NAME_FALLBACK_DE = {
    [1]="Kopf", [2]="Hals", [3]="Schultern", [4]="Hemd", [5]="Brust",
    [6]="Taille", [7]="Beine", [8]="F\195\188\195\159e", [9]="Handgelenke", [10]="H\195\164nde",
    [11]="Ring 1", [12]="Ring 2", [13]="Schmuck 1", [14]="Schmuck 2",
    [15]="R\195\188cken", [16]="Waffenhand", [17]="Schildhand", [18]="Distanz",
    [19]="Wappenrock",
}

local SLOT_NAME_FALLBACK_EN = {
    [1]="Head", [2]="Neck", [3]="Shoulder", [4]="Shirt", [5]="Chest",
    [6]="Waist", [7]="Legs", [8]="Feet", [9]="Wrist", [10]="Hands",
    [11]="Finger 1", [12]="Finger 2", [13]="Trinket 1", [14]="Trinket 2",
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
    local fb = (GetLocale() == "deDE") and SLOT_NAME_FALLBACK_DE or SLOT_NAME_FALLBACK_EN
    return fb[slotID] or tostring(slotID)
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

-- Klassen, die grundsaetzlich beidhaendig kaempfen koennen
local DUAL_WIELD_CLASSES = {
    WARRIOR = 20, ROGUE = 10, HUNTER = 20, SHAMAN = 40, DEATHKNIGHT = 55,
}

function EG:CanDualWield()
    local _, class = UnitClass("player")
    local req = DUAL_WIELD_CLASSES[class or ""]
    if not req then return false end
    if (UnitLevel("player") or 1) >= req then return true end
    -- Sicherheitsnetz: Waffe in der Schildhand angelegt
    local off = GetInventoryItemLink("player", 17)
    if off then
        local d = self:GetItemData(off)
        if d and d.equipLoc == "INVTYPE_WEAPON" then return true end
    end
    return false
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

--[[ Liefert die relevanten Ausruestungsslots.
     Rueckgabe: slots (Tabelle), mode
       mode = "SINGLE"  ein Slot
       mode = "EITHER"  einer von mehreren (Ringe, Schmuck, Einhandwaffen)
       mode = "BOTH"    ersetzt alle genannten Slots (Zweihandwaffe)       ]]
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

function EG:GetEquipSlots(itemOrLink)
    local item = type(itemOrLink) == "table" and itemOrLink or self:GetItemData(itemOrLink)
    if not item or not item.equipLoc then return nil end

    local loc = item.equipLoc
    local slots = EQUIP_LOC_SLOTS[loc]
    if not slots then return nil end

    if loc == "INVTYPE_2HWEAPON" then
        return { 16, 17 }, "BOTH"
    end

    --[[ Solange eine Zweihandwaffe gefuehrt wird, ist die Schildhand nicht
         frei verfuegbar - sie wird von der Zweihandwaffe belegt.

         Ein Schild oder Nebenhand-Item anzulegen kostet also die komplette
         Zweihandwaffe. Verglichen wird deshalb gegen Waffenhand UND
         Schildhand zusammen, nicht gegen den scheinbar leeren Slot 17.
         Sonst gilt jedes beliebige Nebenhand-Item als Verbesserung, weil
         der leere Slot mit 0 Punkten bewertet wird.                       ]]
    local twoHand = self:HasTwoHandEquipped()

    if OFFHAND_LOCS[loc] then
        if twoHand then
            return { 16, 17 }, "BOTH"
        end
        return { 17 }, "SINGLE"
    end

    if loc == "INVTYPE_WEAPON" then
        -- Einhandwaffe: bei gefuehrter Zweihandwaffe geht sie nur in die
        -- Waffenhand und ersetzt dort die Zweihandwaffe.
        if twoHand then
            return { 16 }, "SINGLE"
        end
        if self:CanDualWield() then
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

--[[ Untertyp-Namen -> sprachunabhaengiges Token.
     Das Original verglich direkt gegen lokalisierte Strings; hier werden
     enUS und deDE (inklusive gaengiger Schreibvarianten) auf Tokens
     abgebildet. Zusaetzlich prueft der Tooltip-Scan die tatsaechliche
     Verwendbarkeit, was auch Klassenbindungen abdeckt.                    ]]
local SUBTYPE_TOKEN = {}

local function RegisterSubtype(token, ...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if name and name ~= "" then
            SUBTYPE_TOKEN[slower(name)] = token
        end
    end
end

-- Ruestung
RegisterSubtype("CLOTH",    "Cloth", "Stoff")
RegisterSubtype("LEATHER",  "Leather", "Leder")
RegisterSubtype("MAIL",     "Mail", "Schwere Ruestung", "Schwere R\195\188stung",
                            "Kettenruestung", "Kettenr\195\188stung", "Kette")
RegisterSubtype("PLATE",    "Plate", "Platte", "Plattenruestung", "Plattenr\195\188stung")
RegisterSubtype("SHIELD",   "Shields", "Shield", "Schilde", "Schild")
RegisterSubtype("LIBRAM",   "Librams", "Libram", "Libramme", "Buchband")
RegisterSubtype("IDOL",     "Idols", "Idol", "Goetzen", "G\195\182tzen", "Goetze")
RegisterSubtype("TOTEM",    "Totems", "Totem")
RegisterSubtype("SIGIL",    "Sigils", "Sigil", "Sigelrunen", "Sigelrune")
RegisterSubtype("MISC",     "Miscellaneous", "Verschiedenes", "Sonstiges")

-- Waffen
RegisterSubtype("AXE1",     "One-Handed Axes", "Einhandaexte", "Einhand\195\164xte", "Aexte", "\195\132xte")
RegisterSubtype("AXE2",     "Two-Handed Axes", "Zweihandaexte", "Zweihand\195\164xte")
RegisterSubtype("MACE1",    "One-Handed Maces", "Einhandstreitkolben")
RegisterSubtype("MACE2",    "Two-Handed Maces", "Zweihandstreitkolben")
RegisterSubtype("SWORD1",   "One-Handed Swords", "Einhandschwerter")
RegisterSubtype("SWORD2",   "Two-Handed Swords", "Zweihandschwerter")
RegisterSubtype("DAGGER",   "Daggers", "Dolche", "Dolch")
RegisterSubtype("FIST",     "Fist Weapons", "Faustwaffen", "Faustwaffe")
RegisterSubtype("POLEARM",  "Polearms", "Stangenwaffen", "Stangenwaffe")
RegisterSubtype("STAFF",    "Staves", "Staff", "Staebe", "St\195\164be", "Stab")
RegisterSubtype("BOW",      "Bows", "Bow", "Bogen", "Boegen", "B\195\182gen")
RegisterSubtype("GUN",      "Guns", "Gun", "Schusswaffen", "Schusswaffe")
RegisterSubtype("CROSSBOW", "Crossbows", "Armbrueste", "Armbr\195\188ste", "Armbrust")
RegisterSubtype("WAND",     "Wands", "Zauberstaebe", "Zauberst\195\164be", "Zauberstab")
RegisterSubtype("THROWN",   "Thrown", "Wurfwaffen", "Wurfwaffe")
RegisterSubtype("FISHING",  "Fishing Poles", "Angelruten", "Angelrute")

function EG:GetSubtypeToken(subType)
    if not subType then return nil end
    return SUBTYPE_TOKEN[slower(subType)]
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

-- Untertypen, die jede Klasse tragen kann (Hals, Ring, Schmuck, Umhang, ...)
local FREE_TOKENS = { MISC = true, FISHING = true }

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

    local token = self:GetSubtypeToken(item.itemSubType)

    if token and not FREE_TOKENS[token] then
        local armorReq  = ARMOR_PROFICIENCY[class]  and ARMOR_PROFICIENCY[class][token]
        local weaponReq = WEAPON_PROFICIENCY[class] and WEAPON_PROFICIENCY[class][token]
        local req = armorReq or weaponReq

        if not req then
            -- Untertyp ist fuer diese Klasse nicht vorgesehen
            return false, L.R_CLASS
        end
        if level < req then
            return false, sformat(L.R_LEVEL, req), true
        end
    end

    -- Zweihandwaffen ohne Titanengriff sind fuer die Schildhand tabu -
    -- das faengt bereits die Slot-Logik ab.

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

function EG:IsHeirloom(item)
    if not item then return false end
    if not (self.db and self.db.protectHeirlooms) then return false end
    if (UnitLevel("player") or 1) >= HEIRLOOM_MAX_LEVEL then return false end
    return item.quality == HEIRLOOM_QUALITY
end

------------------------------------------------------------------------------
-- 11  Vergleichs-Engine
------------------------------------------------------------------------------

--[[ Zentrale Auswertung. Alle Anzeigen (Chat, GUI, Taschen, Quest) bauen
     auf dieses Ergebnis auf.

     result = {
       item, score, breakdown,
       slots, mode, slotName,
       equipped   = { { item, link, slotID, score, breakdown }, ... },
       target     = Eintrag aus equipped, gegen den verglichen wird (oder nil)
       targetScore, delta, isUpgrade, protected,
       usable, reason, levelTooLow, note
     }                                                                     ]]
function EG:Compare(itemLink)
    local item = self:GetItemData(itemLink)
    if not item then return nil end

    local result = { item = item, equipped = {} }

    result.breakdown, result.score = self:GetScoreBreakdown(item)

    local usable, reason, levelTooLow = self:CanUseItem(item)
    result.usable      = usable
    result.reason      = reason
    result.levelTooLow = levelTooLow and true or false

    local slots, mode = self:GetEquipSlots(item)
    result.slots = slots
    result.mode  = mode
    result.slotName = slots and self:GetSlotName(slots) or (item.equipLoc or "?")

    if not slots then
        result.isUpgrade = false
        return result
    end

    -- Angelegte Gegenstuecke einsammeln
    local anyHeirloom = false
    for _, slotID in ipairs(slots) do
        local eq, link = self:GetEquippedData(slotID)
        if eq then
            local bd, sc = self:GetScoreBreakdown(eq)
            local entry = {
                item = eq, link = link, slotID = slotID,
                score = sc, breakdown = bd,
                isHeirloom = self:IsHeirloom(eq),
            }
            if entry.isHeirloom then anyHeirloom = true end
            result.equipped[#result.equipped + 1] = entry
        else
            result.equipped[#result.equipped + 1] = {
                item = nil, link = nil, slotID = slotID,
                score = 0, breakdown = {}, empty = true,
            }
        end
    end

    -- Hinweise zu Zweihand-/Schildhand-Situationen
    if item.equipLoc == "INVTYPE_2HWEAPON" then
        result.note = L.NOTE_2H
    elseif OFFHAND_LOCS[item.equipLoc] and mode == "BOTH" then
        result.note = L.NOTE_OFFHAND
    elseif item.equipLoc == "INVTYPE_WEAPON" and self:HasTwoHandEquipped() then
        result.note = L.NOTE_MH_2H
    end
    if item.estimated then
        result.note = (result.note and (result.note .. " ") or "") .. L.NOTE_HEIRLOOM_EST
    end

    -- Erbstueck-Schutz
    if anyHeirloom then
        result.protected   = true
        result.targetScore = mhuge
        result.delta       = -mhuge
        result.isUpgrade   = false
        result.reason      = result.reason or sformat(L.R_HEIRLOOM, HEIRLOOM_MAX_LEVEL)
        for _, e in ipairs(result.equipped) do
            if e.isHeirloom then result.target = e break end
        end
        return result
    end

    -- Vergleichsziel bestimmen
    if mode == "BOTH" then
        -- Zweihandwaffe: gegen die Summe aus Waffenhand + Schildhand
        local sum = 0
        for _, e in ipairs(result.equipped) do sum = sum + (e.score or 0) end
        result.targetScore = sum
        result.target      = result.equipped[1]
        result.combined    = true
    else
        -- Einer von mehreren Slots: gegen den schwaechsten
        local worst, worstScore = nil, mhuge
        for _, e in ipairs(result.equipped) do
            local sc = e.empty and 0 or (e.score or 0)
            if sc < worstScore then worstScore, worst = sc, e end
        end
        result.target      = worst
        result.targetScore = (worstScore == mhuge) and 0 or worstScore
    end

    result.delta = result.score - result.targetScore

    --[[ Schwelle fuer "Verbesserung".
         Absolut UND relativ: bei kleinen Wertungen (niedrige Stufen) ist
         ein Vorsprung von 0.1 Punkten Rauschen, kein Upgrade.            ]]
    local minDelta = tonumber(self.db and self.db.minDelta) or 0
    local pct      = tonumber(self.db and self.db.minDeltaPercent) or 0
    local relative = (result.targetScore > 0) and (result.targetScore * pct / 100) or 0
    local threshold = mmax(minDelta, relative)
    result.threshold = threshold

    result.isUpgrade = (usable == true) and (result.delta > 0)
        and (result.delta >= threshold)

    if not result.reason then
        if usable ~= true then
            -- reason wurde bereits von CanUseItem gesetzt
        elseif result.target and result.target.empty then
            result.reason = L.R_EMPTY
        elseif result.delta > 0 and result.delta < threshold then
            result.reason = sformat(L.R_MINDELTA, FmtScore(threshold))
        elseif result.delta == 0 then
            result.reason = L.R_EQUAL
        elseif result.delta < 0 then
            result.reason = L.R_LOWER
        end
    end

    return result
end

-- Schlanke Variante fuer Taschen-Icons: nur ja/nein, mit Score-Cache
function EG:IsUpgrade(itemLink)
    local r = self:Compare(itemLink)
    if not r then return false, 0, 0, nil end
    return (r.isUpgrade == true), r.score or 0, r.targetScore or 0, r.slots
end

------------------------------------------------------------------------------
-- 12  Taschen-Indikatoren
------------------------------------------------------------------------------

EG.hooks = { default = false, elvui = false, bagnon = false, quest = false,
             bank = false, tooltip = false }

function EG:CreateUpgradeIcon(button)
    if button.EGIcon then return button.EGIcon end
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(TEX_UPGRADE)
    icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    local size = tonumber(self.db and self.db.iconSize) or DEFAULTS.iconSize
    icon:SetWidth(size)
    icon:SetHeight(size)
    icon:Hide()
    button.EGIcon = icon
    return icon
end

--[[ Aktualisiert das Icon eines Taschen-Buttons.
     state:  "UPGRADE"  gruen  - echtes Upgrade
             "LEVEL"    gelb   - Upgrade, aber Charakterstufe zu niedrig
             nil               - kein Icon                                 ]]
function EG:UpdateBagButton(button, bagID, slotID)
    if not button then return end
    if not (self.db and self.db.showBagIcons) then
        if button.EGIcon then button.EGIcon:Hide() end
        return
    end

    bagID  = tonumber(bagID)
    slotID = tonumber(slotID)
    if not bagID or not slotID then return end

    local link = GetContainerItemLink(bagID, slotID)
    local sig  = (self.profileCache and self.profileCache.sig or "") .. "#" .. (self.epoch or 0)

    -- Nur neu rechnen, wenn sich Inhalt, Profil oder Einstellungen geaendert haben
    if button.EGLink == link and button.EGSig == sig then
        return
    end
    button.EGLink = link
    button.EGSig  = sig

    local icon = self:CreateUpgradeIcon(button)

    if not link then
        icon:Hide()
        return
    end

    local item = self:GetItemData(link)
    if not item then
        -- Item noch nicht im Client-Cache: Markierung loeschen und
        -- gleich noch einmal versuchen
        button.EGLink = nil
        icon:Hide()
        self:Debounce("bagretry", 0.5, function() self:RefreshAllBags() end)
        return
    end
    if not item.equipLoc or item.equipLoc == "" then
        icon:Hide()
        return
    end

    local result = self:Compare(link)
    if not result or not result.slots then
        icon:Hide()
        return
    end

    if result.isUpgrade then
        icon:SetTexture(TEX_UPGRADE)
        icon:SetVertexColor(0, 1, 0)
        icon:Show()
        return
    end

    -- Nur wegen der Charakterstufe (noch) nicht anlegbar, waere aber besser
    if result.levelTooLow and (result.delta or 0) > 0 then
        icon:SetTexture(TEX_UPGRADE)
        icon:SetVertexColor(1, 0.85, 0)
        icon:Show()
        return
    end

    icon:Hide()
end

function EG:RefreshAllBags()
    if ContainerFrame_Update then
        for i = 1, NUM_CONTAINER_FRAMES or 13 do
            local frame = _G["ContainerFrame" .. i]
            if frame and frame:IsShown() then
                -- Cache invalidieren, damit neu gerechnet wird
                local name = frame:GetName()
                for j = 1, (frame.size or MAX_CONTAINER_ITEMS or 36) do
                    local b = _G[name .. "Item" .. j]
                    if b then b.EGLink = nil end
                end
                ContainerFrame_Update(frame)
            end
        end
    end
    if self.RefreshElvUI then self:RefreshElvUI() end
end

------------------------------------------------------------------------------
-- 12a  Blizzard-Taschen
------------------------------------------------------------------------------

function EG:HookDefaultBags()
    if self.hooks.default or not ContainerFrame_Update then return end

    hooksecurefunc("ContainerFrame_Update", function(frame)
        if not frame then return end
        local bagID = frame:GetID()
        local name  = frame:GetName()
        if not name then return end
        local size  = frame.size or MAX_CONTAINER_ITEMS or 36
        for i = 1, size do
            local button = _G[name .. "Item" .. i]
            if button then
                -- WICHTIG: Der Button-Index entspricht NICHT dem Taschenplatz.
                -- Die Blizzard-Taschen vergeben die IDs rueckwaerts, deshalb
                -- immer button:GetID() verwenden.
                EG:UpdateBagButton(button, bagID, button:GetID())
            end
        end
    end)

    self.hooks.default = true
end

function EG:HookBank()
    if self.hooks.bank or not BankFrameItemButton_Update then return end

    hooksecurefunc("BankFrameItemButton_Update", function(button)
        if not button or button.isBag then return end
        EG:UpdateBagButton(button, BANK_CONTAINER or -1, button:GetID())
    end)

    self.hooks.bank = true
end

------------------------------------------------------------------------------
-- 12b  ElvUI
------------------------------------------------------------------------------

function EG:HookElvUI()
    if self.hooks.elvui or not ElvUI then return end

    local ok, E = pcall(unpack, ElvUI)
    if not ok or not E then return end

    local B = E.GetModule and E:GetModule("Bags", true)
    if not B or not B.UpdateSlot then return end

    self.elvBags = B

    --[[ Die ElvUI-Signaturen unterscheiden sich zwischen den 3.3.5a-Forks:
           B:UpdateSlot(bagID, slotID)
           B:UpdateSlot(frame, bagID, slotID)
         Deshalb werden die Argumente zur Laufzeit ausgewertet.            ]]
    hooksecurefunc(B, "UpdateSlot", function(self_, a, b, c)
        local frame, bagID, slotID
        if type(a) == "table" then
            frame, bagID, slotID = a, b, c
        else
            bagID, slotID = a, b
            frame = self_ and (self_.BagFrame or self_.BankFrame)
        end

        bagID, slotID = tonumber(bagID), tonumber(slotID)
        if not bagID or not slotID then return end

        local button
        if frame and frame.Bags and frame.Bags[bagID] then
            button = frame.Bags[bagID][slotID]
        end
        if not button and self_ and self_.BagFrame and self_.BagFrame.Bags
            and self_.BagFrame.Bags[bagID] then
            button = self_.BagFrame.Bags[bagID][slotID]
        end
        if not button and self_ and self_.BankFrame and self_.BankFrame.Bags
            and self_.BankFrame.Bags[bagID] then
            button = self_.BankFrame.Bags[bagID][slotID]
        end

        if button then
            EG:UpdateBagButton(button, bagID, slotID)
        end
    end)

    function EG:RefreshElvUI()
        local Bmod = self.elvBags
        if not Bmod then return end
        for bagID = 0, NUM_BAG_SLOTS or 4 do
            local numSlots = GetContainerNumSlots(bagID) or 0
            for slotID = 1, numSlots do
                local frame = Bmod.BagFrame
                if frame and frame.Bags and frame.Bags[bagID] then
                    local button = frame.Bags[bagID][slotID]
                    if button then
                        button.EGLink = nil
                        self:UpdateBagButton(button, bagID, slotID)
                    end
                end
            end
        end
    end

    self.hooks.elvui = true
    self:Print(L.HOOK_ELVUI)
end

------------------------------------------------------------------------------
-- 12c  Bagnon
------------------------------------------------------------------------------

function EG:HookBagnon()
    if self.hooks.bagnon or not Bagnon then return end
    if not Bagnon.ItemSlot or not Bagnon.ItemSlot.Update then return end

    hooksecurefunc(Bagnon.ItemSlot, "Update", function(button)
        if not button then return end
        local bag = button.GetBag and button:GetBag() or button.bag
        local slot = button.GetID and button:GetID() or button.slot
        if bag and slot then
            EG:UpdateBagButton(button, bag, slot)
        end
    end)

    self.hooks.bagnon = true
    self:Print(L.HOOK_BAGNON)
end

------------------------------------------------------------------------------
-- 13  Questbelohnungen
------------------------------------------------------------------------------

function EG:GetQuestRewardLink(index)
    if not index or not GetQuestItemLink then return nil end
    return GetQuestItemLink("choice", index)
end

--[[ Anzahl und Verwendbarkeit kommen direkt aus der Blizzard-API.
     Das Original las button.count aus dem Frame - dieses Feld existiert
     in 3.3.5a nicht und lieferte deshalb immer 1.                         ]]
function EG:GetQuestRewardInfo(index)
    if not GetQuestItemInfo then return nil end
    local name, texture, numItems, quality, isUsable = GetQuestItemInfo("choice", index)
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
       1. Existiert mindestens ein echtes Upgrade -> hoechste Wertung.
       2. Sonst -> hoechster Gesamtverkaufswert (Stueckpreis * Anzahl).
     Gleichstand wird ueber den Verkaufswert aufgeloest.                   ]]
function EG:GetBestQuestReward()
    local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
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

function EG:UpdateQuestRewards()
    if not (self.db and self.db.showQuestIcons) then return end

    local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if not numChoices or numChoices <= 0 then return end

    for i = 1, numChoices do
        local button = _G["QuestInfoItem" .. i]
        if button then
            self:CreateQuestIcon(button):Hide()
        end
    end

    local best, score, isUpgrade, value, mode, delta = self:GetBestQuestReward()
    if not best then
        self.selectedQuestReward = nil
        return
    end

    local link = self:GetQuestRewardLink(best)
    self.selectedQuestReward = {
        index = best, link = link, score = score, delta = delta,
        value = value, isUpgrade = isUpgrade, mode = mode,
    }

    local button = _G["QuestInfoItem" .. best]
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

local function AddTooltipInfo(tooltip)
    if not (EG.db and EG.db.showTooltip) then return end
    if tooltip.EGDone then return end

    local _, link = tooltip:GetItem()
    if not link then return end

    local item = EG:GetItemData(link)
    if not item or not item.equipLoc or item.equipLoc == "" then return end

    local result = EG:Compare(link)
    if not result or not result.slots then return end

    tooltip.EGDone = true

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(
        COLOR.title .. "EasyGear" .. COLOR.reset,
        COLOR.value .. L.SCORE .. ": " .. FmtScore(result.score) .. COLOR.reset)

    if result.usable ~= true then
        tooltip:AddLine(COLOR.bad .. (result.reason or L.NOT_USABLE) .. COLOR.reset, nil, nil, nil, true)
        tooltip:Show()
        return
    end

    if result.protected then
        tooltip:AddLine(COLOR.warn .. L.HEIRLOOM .. " " .. L.PROTECTED .. COLOR.reset)
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
        tooltip:AddDoubleLine(
            COLOR.grey .. EG:GetSlotName(result.target.slotID) .. COLOR.reset,
            COLOR.grey .. targetText .. COLOR.reset)
    end

    local delta = result.delta or 0
    if result.isUpgrade then
        tooltip:AddLine(COLOR.good .. L.UPGRADE .. "  +" .. FmtScore(delta) .. COLOR.reset)
    elseif delta > 0 then
        tooltip:AddLine(COLOR.warn .. L.NO_UPGRADE .. "  +" .. FmtScore(delta) .. COLOR.reset)
    else
        tooltip:AddLine(COLOR.bad .. L.NO_UPGRADE .. "  " .. FmtScore(delta) .. COLOR.reset)
    end

    tooltip:Show()
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
    self.hooks.tooltip = true
end

------------------------------------------------------------------------------
-- 15  EGUP - Klassenpaket (GM) und Aufraeumen
------------------------------------------------------------------------------

local EGUP_BAG_ITEM_ID = 51809   -- Tragbares Loch
local EGUP_BAG_COUNT   = 4

local EGUP_ITEMS = {
    TRINKETS = {
        { id = 42991, count = 2, name = "Swift Hand of Justice" },
        { id = 42992, count = 2, name = "Discerning Eye of the Beast" },
    },
    RING = { id = 50255, count = 1, name = "Dread Pirate Ring" },
    BAGS = {
        { id = EGUP_BAG_ITEM_ID, count = EGUP_BAG_COUNT, name = "Portable Hole" },
    },
    CLOTH = {
        CHEST     = { id = 48691, count = 1, name = "Tattered Dreadmist Robe" },
        SHOULDERS = { id = 42985, count = 1, name = "Tattered Dreadmist Mantle" },
        WEAPON    = { id = 42947, count = 1, name = "Dignified Headmaster's Charge" },
    },
    LEATHER_AGI = {
        CHEST          = { id = 48689, count = 1, name = "Stained Shadowcraft Tunic" },
        SHOULDERS      = { id = 42952, count = 1, name = "Stained Shadowcraft Spaulders" },
        DAGGER         = { id = 42944, count = 1, name = "Balanced Heartseeker" },
        SWORD          = { id = 42945, count = 1, name = "Venerable Dal'Rend's Sacred Charge" },
        THRASH_BLADE   = { id = 44096, count = 1, name = "Battleworn Thrash Blade" },
        OFFHAND_DAGGER = { id = 44091, count = 1, name = "Sharpened Scarlet Kris" },
    },
    LEATHER_INT = {
        CHEST     = { id = 48687, count = 1, name = "Preened Ironfeather Breastplate" },
        SHOULDERS = { id = 42984, count = 1, name = "Preened Ironfeather Shoulders" },
        WEAPON    = { id = 42947, count = 1, name = "Dignified Headmaster's Charge" },
    },
    MAIL_AGI = {
        CHEST     = { id = 48677, count = 1, name = "Champion's Deathdealer Breastplate" },
        SHOULDERS = { id = 42950, count = 1, name = "Champion Herod's Shoulder" },
        MACE      = { id = 48716, count = 1, name = "Venerable Mass of McGowan" },
        BOW       = { id = 42946, count = 1, name = "Charmed Ancient Bone Bow" },
    },
    MAIL_INT = {
        CHEST     = { id = 48683, count = 1, name = "Mystical Vest of Elements" },
        SHOULDERS = { id = 42951, count = 1, name = "Mystical Pauldrons of Elements" },
        WEAPON    = { id = 42948, count = 1, name = "Devout Aurastone Hammer" },
    },
    PLATE = {
        CHEST     = { id = 48685, count = 1, name = "Polished Breastplate of Valor" },
        SHOULDERS = { id = 42949, count = 1, name = "Polished Spaulders of Valor" },
        WEAPON    = { id = 44092, count = 1, name = "Reforged Truesilver Champion" },
    },
}
EG.EGUP_ITEMS = EGUP_ITEMS

-- Klasse -> Liste der Pfade in EGUP_ITEMS
local EGUP_PACKAGES = {
    ROGUE       = { "LEATHER_AGI.CHEST", "LEATHER_AGI.SHOULDERS", "LEATHER_AGI.DAGGER",
                    "LEATHER_AGI.SWORD", "LEATHER_AGI.THRASH_BLADE",
                    "LEATHER_AGI.OFFHAND_DAGGER" },
    DRUID       = { "LEATHER_INT.CHEST", "LEATHER_INT.SHOULDERS", "LEATHER_INT.WEAPON",
                    "LEATHER_AGI.CHEST", "LEATHER_AGI.SHOULDERS" },
    HUNTER      = { "MAIL_AGI.CHEST", "MAIL_AGI.SHOULDERS", "MAIL_AGI.BOW",
                    "LEATHER_AGI.SWORD" },
    SHAMAN      = { "MAIL_AGI.CHEST", "MAIL_AGI.SHOULDERS", "MAIL_AGI.MACE",
                    "MAIL_INT.CHEST", "MAIL_INT.SHOULDERS", "MAIL_INT.WEAPON" },
    WARRIOR     = { "PLATE.CHEST", "PLATE.SHOULDERS", "PLATE.WEAPON",
                    "LEATHER_AGI.SWORD", "MAIL_AGI.MACE" },
    PALADIN     = { "PLATE.CHEST", "PLATE.SHOULDERS", "PLATE.WEAPON", "MAIL_INT.WEAPON" },
    DEATHKNIGHT = { "PLATE.CHEST", "PLATE.SHOULDERS", "PLATE.WEAPON",
                    "LEATHER_AGI.SWORD" },
    PRIEST      = { "CLOTH.CHEST", "CLOTH.SHOULDERS", "CLOTH.WEAPON" },
    MAGE        = { "CLOTH.CHEST", "CLOTH.SHOULDERS", "CLOTH.WEAPON" },
    WARLOCK     = { "CLOTH.CHEST", "CLOTH.SHOULDERS", "CLOTH.WEAPON" },
}

local function ResolvePath(path)
    local node = EGUP_ITEMS
    for part in string.gmatch(path, "[^%.]+") do
        node = node and node[part]
    end
    return node
end

function EG:GetEGUPPackage(class)
    local package, seen = {}, {}

    local function Add(entry)
        if not entry or not entry.id then return end
        if seen[entry.id] then return end
        seen[entry.id] = true
        package[#package + 1] = {
            id = entry.id, count = entry.count or 1,
            name = entry.name or ("Item " .. tostring(entry.id)),
        }
    end

    for _, t in ipairs(EGUP_ITEMS.TRINKETS) do Add(t) end
    Add(EGUP_ITEMS.RING)
    for _, b in ipairs(EGUP_ITEMS.BAGS) do Add(b) end

    local list = EGUP_PACKAGES[class or ""]
    if list then
        for _, path in ipairs(list) do Add(ResolvePath(path)) end
    end

    return package
end

function EG:SendEGUPCommand(command)
    SendChatMessage(command, "SAY")
end

function EG:BuildEGUPCommand(targetName, id, count)
    local template = (self.db and self.db.egupCommand) or DEFAULTS.egupCommand
    local cmd = sgsub(template, "{name}",  tostring(targetName))
    cmd = sgsub(cmd, "{id}",    tostring(id))
    cmd = sgsub(cmd, "{count}", tostring(count))
    return cmd
end

EG.EGUPQueue   = {}
EG.EGUPRunning = false

function EG:ProcessEGUPQueue()
    if self.EGUPRunning then return end
    if #self.EGUPQueue == 0 then return end

    self.EGUPRunning = true
    local index = 1
    local delay = tonumber(self.db and self.db.egupDelay) or DEFAULTS.egupDelay

    local function SendNext()
        if index > #self.EGUPQueue then
            self.EGUPQueue   = {}
            self.EGUPRunning = false
            self:Print(COLOR.good .. L.EGUP_DONE .. COLOR.reset)
            self:Print(L.EGUP_HINT)
            return
        end
        local command = self.EGUPQueue[index]
        index = index + 1
        self:SendEGUPCommand(command)
        self:After(delay, SendNext)
    end

    SendNext()
end

function EG:StartEGUP(targetName, class)
    local package = self:GetEGUPPackage(class)
    if not package or #package == 0 then
        self:Print(COLOR.bad .. sformat(L.EGUP_NO_PACKAGE, tostring(class)) .. COLOR.reset)
        return
    end

    local session = {
        targetName = targetName,
        targetGUID = UnitGUID("target"),
        class      = class,
        items      = {},
        active     = true,
        time       = time and time() or 0,
    }

    self.EGUPQueue = {}
    for _, item in ipairs(package) do
        local rec = session.items[item.id]
        if not rec then
            rec = { id = item.id, name = item.name, count = 0 }
            session.items[item.id] = rec
        end
        rec.count = rec.count + (item.count or 1)
        self.EGUPQueue[#self.EGUPQueue + 1] =
            self:BuildEGUPCommand(targetName, item.id, item.count or 1)
    end

    self.charDB.egup = session
    self.EGUPSession = session

    self:Print(sformat(L.EGUP_RUNNING, COLOR.value .. targetName .. COLOR.reset))
    self:Print("Klasse/Class:", COLOR.value .. tostring(class) .. COLOR.reset,
               "- Eintraege/Entries:", COLOR.value .. #package .. COLOR.reset)

    self:ProcessEGUPQueue()
end

StaticPopupDialogs["EASYGEAR_EGUP_CONFIRM"] = {
    text = "%s",
    button1 = YES or "Ja",
    button2 = NO or "Nein",
    OnAccept = function(self)
        local d = self.data or EasyGear.pendingEGUP
        if d then EasyGear:StartEGUP(d.name, d.class) end
        EasyGear.pendingEGUP = nil
    end,
    OnCancel = function() EasyGear.pendingEGUP = nil end,
    timeout = 30, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function EG:RunEGUP()
    if not UnitExists("target") then
        self:Print(COLOR.bad .. L.EGUP_NO_TARGET .. COLOR.reset); return
    end
    if not UnitIsPlayer("target") then
        self:Print(COLOR.bad .. L.EGUP_NOT_PLAYER .. COLOR.reset); return
    end

    local targetName = UnitName("target")
    local _, class   = UnitClass("target")

    if not targetName then
        self:Print(COLOR.bad .. L.EGUP_NO_TARGET .. COLOR.reset); return
    end
    if not class then
        self:Print(COLOR.bad .. L.EGUP_NO_CLASS .. COLOR.reset); return
    end

    local package = self:GetEGUPPackage(class)
    if not package or #package == 0 then
        self:Print(COLOR.bad .. sformat(L.EGUP_NO_PACKAGE, class) .. COLOR.reset); return
    end

    if self.db.egupConfirm then
        self.pendingEGUP = { name = targetName, class = class }
        local dialog = StaticPopup_Show("EASYGEAR_EGUP_CONFIRM",
            sformat(L.EGUP_CONFIRM, class, #package, targetName))
        if dialog then dialog.data = self.pendingEGUP end
        return
    end

    self:StartEGUP(targetName, class)
end

------------------------------------------------------------------------------
-- 15a  EGUPCLEAN
------------------------------------------------------------------------------

function EG:IsItemIDEquipped(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    for slot = 1, MAX_EQUIP_SLOT do
        local link = GetInventoryItemLink("player", slot)
        if link and self:GetItemIDFromLink(link) == itemID then
            return true
        end
    end
    return false
end

function EG:GetBagItemLocations(itemID)
    local locations = {}
    itemID = tonumber(itemID)
    if not itemID then return locations end

    for bagID = 0, (NUM_BAG_SLOTS or 4) do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
            local link = GetContainerItemLink(bagID, slotID)
            if link and self:GetItemIDFromLink(link) == itemID then
                local _, count = GetContainerItemInfo(bagID, slotID)
                locations[#locations + 1] = {
                    bag = bagID, slot = slotID, count = tonumber(count) or 1, link = link,
                }
            end
        end
    end
    return locations
end

function EG:DeleteBagSlot(bagID, slotID, count, stackSize)
    if CursorHasItem() then ClearCursor() end

    if count and stackSize and count < stackSize and SplitContainerItem then
        SplitContainerItem(bagID, slotID, count)
    else
        PickupContainerItem(bagID, slotID)
    end

    if CursorHasItem() then
        DeleteCursorItem()
        return true
    end
    ClearCursor()
    return false
end

--[[ Entfernt bis zu requestedCount Exemplare eines Items aus den Taschen.
     Angelegte Exemplare bleiben unangetastet; ein angelegtes Exemplar
     reduziert die zu loeschende Menge um eins.                            ]]
function EG:CleanupEGUPItem(itemID, requestedCount, callback)
    local locations = self:GetBagItemLocations(itemID)
    if #locations == 0 then
        if callback then callback(0) end
        return
    end

    local remaining = tonumber(requestedCount) or 0
    if self:IsItemIDEquipped(itemID) then
        remaining = remaining - 1
    end

    local index, removed = 1, 0

    local function DeleteNext()
        if remaining <= 0 or index > #locations then
            if callback then callback(removed) end
            return
        end

        local loc = locations[index]
        index = index + 1

        local deleteCount = mmin(loc.count, remaining)
        if deleteCount > 0 then
            if self:DeleteBagSlot(loc.bag, loc.slot, deleteCount, loc.count) then
                remaining = remaining - deleteCount
                removed   = removed + deleteCount
            end
        end

        self:After(0.12, DeleteNext)
    end

    DeleteNext()
end

function EG:RunEGUPClean()
    local session = self.charDB and self.charDB.egup
    if not session or not session.active then
        self:Print(COLOR.bad .. L.EGUP_NO_SESSION .. COLOR.reset); return
    end

    local playerName = UnitName("player")
    if session.targetName and playerName and session.targetName ~= playerName then
        -- Zusaetzliche GUID-Pruefung, falls verfuegbar
        if session.targetGUID and session.targetGUID ~= UnitGUID("player") then
            self:Print(COLOR.bad .. sformat(L.EGUP_WRONG_CHAR,
                tostring(session.targetName)) .. COLOR.reset)
            return
        end
    end

    self:Print(L.EGUP_CLEAN_START)

    local list = {}
    for _, data in pairs(session.items) do list[#list + 1] = data end
    if #list == 0 then
        self:Print(L.EGUP_CLEAN_NONE); return
    end

    local index, totalRemoved = 1, 0
    local function CleanNext()
        if index > #list then
            self:Print(COLOR.good .. sformat(L.EGUP_CLEAN_DONE, totalRemoved) .. COLOR.reset)
            session.active = false
            return
        end
        local data = list[index]
        index = index + 1
        self:CleanupEGUPItem(data.id, data.count, function(removed)
            totalRemoved = totalRemoved + (removed or 0)
            self:After(0.10, CleanNext)
        end)
    end

    CleanNext()
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
    local result = self:Compare(itemLink)
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
    if item.enchanted or (item.gemCount or 0) > 0 then
        local parts = {}
        if item.enchanted then parts[#parts + 1] = L.ENCHANTED end
        if (item.gemCount or 0) > 0 then
            parts[#parts + 1] = sformat(L.GEMMED, item.gemCount)
        end
        self:Raw(COLOR.good .. tconcat(parts, ", ") .. COLOR.reset)
    end
    if (item.sellPrice or 0) > 0 and GetCoinTextureString then
        self:Raw(L.SELLPRICE .. ": " .. GetCoinTextureString(item.sellPrice))
    end

    self:Raw(LINE)
    self:Raw(COLOR.title .. L.CANDIDATE .. " - " .. L.POINTS .. COLOR.reset)
    self:PrintBreakdown(result.breakdown, result.score)

    self:Raw(LINE)
    self:Raw(COLOR.title .. L.EQUIPPED .. COLOR.reset)
    if not result.equipped or #result.equipped == 0 then
        self:Raw("  " .. COLOR.warn .. L.NOTHING_EQUIPPED .. COLOR.reset)
    else
        for _, e in ipairs(result.equipped) do
            local slotName = self:GetSlotName(e.slotID)
            if e.empty then
                self:Raw(sformat("%s: %s%s%s", slotName, COLOR.warn, L.NOTHING_EQUIPPED, COLOR.reset))
            else
                self:Raw(sformat("%s: %s", slotName, e.link or e.item.link))
                if e.isHeirloom then
                    self:Raw("  " .. COLOR.warn .. L.HEIRLOOM .. " (" .. L.PROTECTED .. ")" .. COLOR.reset)
                end
                self:PrintBreakdown(e.breakdown, e.score)
            end
        end
    end

    self:Raw(LINE)
    if result.usable ~= true then
        self:Raw(COLOR.bad .. L.NOT_USABLE .. COLOR.reset .. " " .. tostring(result.reason or ""))
    elseif result.protected then
        self:Raw(COLOR.warn .. L.NO_UPGRADE .. COLOR.reset .. " " .. tostring(result.reason or ""))
    else
        local delta = result.delta or 0
        local sign  = delta > 0 and "+" or ""
        local col   = result.isUpgrade and COLOR.good or (delta > 0 and COLOR.warn or COLOR.bad)
        self:Raw(sformat("%s: %s%s%s   %s -> %s",
            L.DIFFERENCE, col, sign .. FmtScore(delta), COLOR.reset,
            FmtScore(result.targetScore), FmtScore(result.score)))
        if result.isUpgrade then
            self:Raw(COLOR.good .. ">> " .. L.UPGRADE .. COLOR.reset)
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

function EG:PrintHelp()
    self:Raw(COLOR.title .. "EasyGear " .. ADDON_VERSION .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg" .. COLOR.reset .. "                  " .. L.CMD_EG)
    self:Raw(COLOR.value .. "/eg <itemlink>" .. COLOR.reset .. "       " .. L.CMD_EG_LINK)
    self:Raw(COLOR.value .. "/eggui" .. COLOR.reset)
    self:Raw(COLOR.value .. "/egprofile" .. COLOR.reset .. "           " .. L.CMD_EGPROFILE)
    self:Raw(COLOR.value .. "/eg profile list" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg profile <id|auto>" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg pvp" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg role <auto|tank|melee|ranged|caster|heal>" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg ilvl <zahl>" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg ilvlscale <on|off>" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg mindelta <zahl>" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg mindeltapct <prozent>" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg icons | quest | tooltip | heirloom" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg scale <0.6-1.5>" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg status" .. COLOR.reset)
    self:Raw(COLOR.value .. "/eg reset" .. COLOR.reset)
    self:Raw(COLOR.value .. "/egup" .. COLOR.reset .. "                " .. L.CMD_EGUP)
    self:Raw(COLOR.value .. "/egupclean" .. COLOR.reset .. "           " .. L.CMD_EGUPCLEAN)
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
    self:Raw("PvP: " .. OnOff(self:IsPvPMode()))
    local eff, base, factor = self:GetEffectiveIlvlWeight()
    self:Raw(L.SET_ILVL:format(FmtWeight(base) .. " -> " .. FmtWeight(eff)))
    self:Raw(L.SET_ILVLSCALE:format(OnOff(self.db.ilvlScaling ~= false),
        FmtWeight(factor)))
    self:Raw(L.SET_MINDELTA:format(FmtScore(self.db.minDelta or 0),
        tostring(self.db.minDeltaPercent or 0)))
    self:Raw("Bags: " .. OnOff(self.db.showBagIcons)
        .. " | Quest: " .. OnOff(self.db.showQuestIcons)
        .. " | Tooltip: " .. OnOff(self.db.showTooltip)
        .. " | " .. L.HEIRLOOM .. ": " .. OnOff(self.db.protectHeirlooms))
end

local function Toggle(key)
    EG.db[key] = not EG.db[key]
    EG:Print(key .. ": " .. OnOff(EG.db[key]))
    EG:InvalidateProfile()
    EG:RefreshAllBags()
    if EG.GUI then EG.GUI:Refresh() end
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
    elseif cmd == "ilvl" then
        local v = tonumber(rest)
        if v then
            EG.db.ilvlWeight = v
            EG:InvalidateProfile()
            EG:RefreshAllBags()
            if EG.GUI then EG.GUI:Refresh() end
        end
        local eff = EG:GetEffectiveIlvlWeight()
        EG:Print(L.SET_ILVL:format(FmtWeight(EG.db.ilvlWeight) .. " -> " .. FmtWeight(eff)))
        return
    elseif cmd == "mindelta" then
        local v = tonumber(rest)
        if v then EG.db.minDelta = v; EG:InvalidateProfile(); EG:RefreshAllBags() end
        EG:Print(L.SET_MINDELTA:format(FmtScore(EG.db.minDelta or 0),
            tostring(EG.db.minDeltaPercent or 0)))
        return
    elseif cmd == "mindeltapct" then
        local v = tonumber(rest)
        if v then EG.db.minDeltaPercent = v; EG:InvalidateProfile(); EG:RefreshAllBags() end
        EG:Print(L.SET_MINDELTA:format(FmtScore(EG.db.minDelta or 0),
            tostring(EG.db.minDeltaPercent or 0)))
        return
    elseif cmd == "ilvlscale" then
        if rest == "on"  then EG.db.ilvlScaling = true  end
        if rest == "off" then EG.db.ilvlScaling = false end
        if rest == ""    then EG.db.ilvlScaling = (EG.db.ilvlScaling == false) end
        EG:InvalidateProfile()
        EG:WipeItemCache()
        EG:RefreshAllBags()
        if EG.GUI then EG.GUI:Refresh() end
        local eff, _, factor = EG:GetEffectiveIlvlWeight()
        EG:Print(L.SET_ILVLSCALE:format(OnOff(EG.db.ilvlScaling ~= false),
            FmtWeight(factor)) .. "  ->  " .. FmtWeight(eff))
        return
    elseif cmd == "icons" then
        Toggle("showBagIcons"); return
    elseif cmd == "quest" then
        Toggle("showQuestIcons"); return
    elseif cmd == "tooltip" then
        Toggle("showTooltip"); return
    elseif cmd == "heirloom" then
        Toggle("protectHeirlooms"); return
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
        for k, v in pairs(DEFAULTS) do EG.db[k] = v end
        EG.charDB.role    = "AUTO"
        EG.charDB.profile = "AUTO"
        EG.charDB.pvp     = false
        EG.charDB.gui     = { point = "CENTER", x = 0, y = 0, scale = 1.0 }
        EG:InvalidateProfile()
        EG:WipeItemCache()
        EG:RefreshAllBags()
        if EG.GUI and EG.GUI.frame then
            EG.GUI.frame:ClearAllPoints()
            EG.GUI.frame:SetPoint("CENTER")
            EG.GUI.frame:SetScale(1.0)
        end
        EG:Print(L.SET_RESET)
        return
    end

    -- Itemname oder Item-ID
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

SLASH_EGUP1 = "/egup"
SlashCmdList["EGUP"] = function() EG:RunEGUP() end

SLASH_EGUPCLEAN1 = "/egupclean"
SlashCmdList["EGUPCLEAN"] = function() EG:RunEGUPClean() end

------------------------------------------------------------------------------
-- 17  Initialisierung
------------------------------------------------------------------------------

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

function EG:InitDB()
    EasyGearDB     = EasyGearDB     or {}
    EasyGearCharDB = EasyGearCharDB or {}
    self.db     = CopyDefaults(EasyGearDB, DEFAULTS)
    self.charDB = CopyDefaults(EasyGearCharDB, CHAR_DEFAULTS)
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

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            EG:InitDB()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        if not EG.db then EG:InitDB() end
        EG.loaded = true

        EG:Print(sformat(L.LOADED, ADDON_VERSION))
        EG:Raw(COLOR.grey .. L.CMD_HEADER .. "  " .. COLOR.value
            .. "/eg  /eggui  /egup  /egupclean" .. COLOR.reset)

        -- Taschen-Integrationen
        if IsAddOnLoaded("ElvUI") then
            EG:HookElvUI()
        elseif IsAddOnLoaded("Bagnon") then
            EG:HookBagnon()
        end
        -- Blizzard-Taschen zusaetzlich haken (Bank / Fallback)
        EG:HookDefaultBags()
        EG:HookBank()

        EG:HookQuestRewards()
        EG:HookTooltips()

        if EG.GUI and EG.GUI.OnInit then EG.GUI:OnInit() end
        if EG.ProfileGUI and EG.ProfileGUI.OnInit then EG.ProfileGUI:OnInit() end
        return
    end

    if event == "PLAYER_LEVEL_UP" or event == "CHARACTER_POINTS_CHANGED" then
        EG:InvalidateProfile()
        EG:WipeItemCache()
        EG:InvalidateEquippedTotals()
        EG:Debounce("refresh", 0.5, function()
            EG:RefreshAllBags()
            if EG.GUI then EG.GUI:Refresh() end
        end)
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            -- Die Slot-Aufloesung haengt jetzt davon ab, ob eine
            -- Zweihandwaffe gefuehrt wird - deshalb alle Taschen-Buttons
            -- ueber die Epoche invalidieren, nicht nur den Score-Cache.
            EG.scoreCache = {}
            EG.epoch = (EG.epoch or 0) + 1
            EG:InvalidateEquippedTotals()
            EG:Debounce("inv", 0.3, function()
                EG:RefreshAllBags()
                if EG.GUI then EG.GUI:Refresh() end
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
