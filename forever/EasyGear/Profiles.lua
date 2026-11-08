--[[---------------------------------------------------------------------------
    Profiles.lua - Profilwahl, Talenterkennung, eigene Profile

    Ausgewaehlt wird ueber die ID in EasyGearCharDB.profile; "AUTO" heisst: Erkennung ueber
    Talentbaum, Stufe und angelegte Waffen. Eigene Profile liegen in EasyGearDB.custom.

    Talente in Forever: pro Klasse ein Talentbaum mit drei Gruppen (den drei klassischen Baeumen),
    dazu zwei Talentsaetze (Zweitspezialisierung). Gelesen wird in dieser Reihenfolge:

      1. C_SpecializationInfo.GetSpecializationInfo(i): liefert in Forever je Baum pointsSpent.
      2. C_Traits.GetGroupCurrencyInfo des aktiven Talentsatzes (so zaehlt auch die Talentseite).
      3. C_SpecializationInfo.GetSpecialization(): nur der gewaehlte Baum, ohne Punktzahl.

    Gelingt keine, bleibt es bei "Leveln" bzw. "Allround".
-----------------------------------------------------------------------------]]

local _, EG = ...
local Profiles = {}
EG.Profiles = Profiles

local L = EG.L
local Specs = EG.Specs

local pairs, ipairs, type, tonumber, tostring, pcall = pairs, ipairs, type, tonumber, tostring, pcall
local tsort = table.sort
local sgsub = string.gsub

local MIN_POINTS = 5            -- darunter gilt der Charakter als "ohne Talente"

------------------------------------------------------------------------------
-- 01  Spieler
------------------------------------------------------------------------------

function Profiles.PlayerClass()
    local _, class, classID = UnitClass("player")
    return class or "WARRIOR", classID
end

function Profiles.MaxLevel()
    local v = GetMaxPlayerLevel and GetMaxPlayerLevel()
    if type(v) == "number" and v > 0 then return v end
    return 60
end

function Profiles.PlayerLevel()
    return UnitLevel("player") or 1
end

------------------------------------------------------------------------------
-- 02  Talente
------------------------------------------------------------------------------

local talentCache = nil         -- { points = {..}, total = n, role = "TANK"|..., source = text }

function Profiles.InvalidateTalents()
    talentCache = nil
end

-- Die drei Baeume einer Klasse: Index 1..3 in der Reihenfolge, in der das Talentfenster sie zeigt.
-- GetNumSpecializationsForClassID wird nicht befragt: in Forever kann die Zahl der "Spezialisierungen" einer
-- Klasse kleiner sein als die der Baeume (die Talentvorlage ist eine je Klasse).
local TREES = 3

-- Rollen (und, wenn der Client sie fuellt, die Punkte) aus C_SpecializationInfo.GetSpecializationInfo
local function ReadSpecInfo()
    local SI = C_SpecializationInfo
    local get = SI and SI.GetSpecializationInfo
    if type(get) ~= "function" then return nil end

    local points, roles, known = {}, {}, false
    for i = 1, TREES do
        local ok, specId, _, _, _, role, _, pointsSpent = pcall(get, i)
        if ok and specId then
            known = true
            points[i] = tonumber(pointsSpent) or 0
            roles[i] = role
        else
            points[i] = 0
        end
    end
    if not known then return nil end
    return points, roles
end

-- Punkte je Baum aus den Talentgruppen des aktiven Talentsatzes - so zaehlt auch das Talentfenster
local function ReadTraitGroups()
    local SI, T = C_SpecializationInfo, C_Traits
    if not (SI and T and SI.GetActiveSpecGroup and SI.GetCombatConfigIDForSpecGroup
            and T.GetConfigInfo and T.GetGroupDisplayInfoByTreeID and T.GetGroupCurrencyInfo) then
        return nil
    end
    local group = SI.GetActiveSpecGroup()
    if not group then return nil end
    local configID = SI.GetCombatConfigIDForSpecGroup(group)
    if not configID then return nil end
    local info = T.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return nil end

    -- Das Talentfenster von Forever legt die Kopfzeilen in genau dieser Reihenfolge von links nach rechts
    -- (Blizzard_PlayerSpells/Camelot/ClassTalents), also ist die Listenreihenfolge die Baumreihenfolge
    local displays = T.GetGroupDisplayInfoByTreeID(treeID)
    if type(displays) ~= "table" or #displays == 0 then return nil end

    local groupIDs = {}
    for i, d in ipairs(displays) do groupIDs[i] = d.groupID end
    local infos = T.GetGroupCurrencyInfo(configID, groupIDs)
    if type(infos) ~= "table" then return nil end

    local points = {}
    for i, d in ipairs(displays) do
        points[i] = 0
        for _, gi in ipairs(infos) do
            if gi.traitNodeGroupID == d.groupID then
                local cur = gi.currencyInfos and gi.currencyInfos[1]
                points[i] = (cur and tonumber(cur.spent)) or 0
            end
        end
    end
    return points
end

-- Der Baum, den der Client als Hauptbaum fuehrt (das Charakterfenster zeigt seinen Namen); ohne Punktzahl
local function ReadSelectedSpec()
    local SI = C_SpecializationInfo
    local get = SI and SI.GetSpecialization
    if type(get) ~= "function" then return nil end
    local index = get()
    if type(index) ~= "number" or index < 1 or index > TREES then return nil end
    local points = {}
    for i = 1, TREES do points[i] = (i == index) and MIN_POINTS or 0 end
    return points
end

local function Safe(fn)
    local ok, a, b = pcall(fn)
    if ok then return a, b end
    return nil
end

local function Sum(points)
    local sum = 0
    for i = 1, #(points or {}) do sum = sum + (points[i] or 0) end
    return sum
end

--[[ Rueckgabe: { points = { [1..n] }, total, tab = dominanter Baum | nil, role = API-Rolle des Baums | nil, source }
     oder nil, wenn der Client gar nichts herausgibt.

     Mehrere Quellen, die erste mit Punkten gewinnt (eine, die nur Nullen liefert, ist keine Antwort - der Client
     fuellt die Punkte in GetSpecializationInfo womoeglich nicht):
       "traits"    C_Traits-Gruppen des aktiven Talentsatzes (wie das Talentfenster)
       "specinfo"  C_SpecializationInfo.GetSpecializationInfo(i).pointsSpent
       "selected"  C_SpecializationInfo.GetSpecialization(): nur der Hauptbaum
     Die Rollen der Baeume kommen immer aus GetSpecializationInfo.                                           ]]
function Profiles.Talents()
    if talentCache ~= nil then return talentCache or nil end

    local infoPoints, roles = Safe(ReadSpecInfo)
    local sources = {
        { "traits", (Safe(ReadTraitGroups)) },
        { "specinfo", infoPoints },
        { "selected", (Safe(ReadSelectedSpec)) },
    }

    local points, source, anyAnswer
    for _, s in ipairs(sources) do
        if s[2] then
            anyAnswer = anyAnswer or s
            if Sum(s[2]) > 0 then points, source = s[2], s[1] break end
        end
    end
    if not points then
        if not anyAnswer then
            talentCache = false
            return nil
        end
        points, source = anyAnswer[2], anyAnswer[1]       -- eine Quelle antwortet, aber ohne Punkte: keine Talente
    end

    local total, bestTab, bestPoints = 0, nil, 0
    for i = 1, #points do
        total = total + (points[i] or 0)
        if (points[i] or 0) > bestPoints then bestTab, bestPoints = i, points[i] end
    end
    talentCache = {
        points = points, total = total, tab = bestTab, bestPoints = bestPoints,
        role = bestTab and roles and roles[bestTab] or nil, source = source,
    }
    return talentCache
end

-- Talentbaum mit den meisten Punkten (nil, wenn zu wenig Punkte verteilt sind)
function Profiles.DominantTab()
    local t = Profiles.Talents()
    if t and t.tab and t.bestPoints >= MIN_POINTS then return t.tab, t.bestPoints, t.role end
    return nil, t and t.bestPoints or 0, nil
end

------------------------------------------------------------------------------
-- 03  Profile
------------------------------------------------------------------------------

function Profiles.Name(spec)
    if not spec then return "?" end
    if spec.custom then return spec.name or spec.id end
    local key = "SPEC_" .. tostring(spec.id)
    if EG:LocaleHas(key) then return L[key] end
    return spec.id
end

function Profiles.Desc(spec)
    if not spec then return "" end
    if spec.custom then return spec.desc or "" end
    local key = "SPEC_" .. tostring(spec.id) .. "_D"
    if EG:LocaleHas(key) then return L[key] end
    return ""
end

function Profiles.ClassProfileID(class, kind)
    return class .. "_" .. kind
end

--[[ Alle fuer diese Klasse waehlbaren Profile, in fester Reihenfolge:
     Klassenprofile, eigene Profile, klassenunabhaengige Profile.               ]]
function Profiles.List(class)
    class = class or Profiles.PlayerClass()
    local list = {}
    for _, spec in ipairs(Specs.CLASS[class] or {}) do list[#list + 1] = spec end

    local custom = EG.db and EG.db.custom
    if custom then
        local ids = {}
        for id in pairs(custom) do ids[#ids + 1] = id end
        tsort(ids)
        for _, id in ipairs(ids) do
            local c = custom[id]
            if type(c) == "table" and (not c.class or c.class == "ANY" or c.class == class) then
                list[#list + 1] = c
            end
        end
    end

    for _, spec in ipairs(Specs.ANY) do list[#list + 1] = spec end
    return list
end

function Profiles.Get(id)
    if not id or id == "AUTO" then return nil end
    local custom = EG.db and EG.db.custom
    if custom and type(custom[id]) == "table" then return custom[id] end
    return Specs.BY_ID[id]
end

local function WeaponLoc(slot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if not link then return nil end
    local info = C_Item and C_Item.GetItemInfoInstant
    if not info then return nil end
    local _, _, _, equipLoc = info(link)
    return equipLoc
end

local ONEHAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true }

--[[ Mehrere Profile im selben Baum (Druide Katze/Baer): entschieden wird nach der Rolle, die der
     Client dem Baum gibt, nach der angelegten Waffenhaltung, sonst gilt das als auto markierte Profil. ]]
function Profiles.PickTabSpec(list, tab, apiRole)
    local candidates, default = {}, nil
    for _, spec in ipairs(list or {}) do
        if spec.tab == tab then
            candidates[#candidates + 1] = spec
            if spec.auto and not default then default = spec end
        end
    end
    if #candidates == 0 then return nil end
    default = default or candidates[1]
    if #candidates == 1 then return default end

    -- Rolle des Baums laut Client
    local want = (apiRole == "TANK" and "TANK") or (apiRole == "HEALER" and "HEAL") or nil
    if want then
        for _, spec in ipairs(candidates) do
            if spec.role == want then return spec end
        end
    end

    local mh, oh = WeaponLoc(16), WeaponLoc(17)
    local style
    if mh == "INVTYPE_2HWEAPON" then
        style = "2H"
    elseif oh and ONEHAND[oh] then
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

       * kaum Talente        -> Leveln (unter der Hoechststufe) bzw. Allround (auf der Hoechststufe)
       * unter der Hoechststufe -> Leveln-Profil der Klasse. Ausnahme: Tank- und Heilbaeume behalten ihr
                                Profil, weil sich dort die Gewichtung grundlegend unterscheidet
       * Hoechststufe        -> Profil des Talentbaums                                              ]]
function Profiles.Detect(class)
    class = class or Profiles.PlayerClass()
    local list = Specs.CLASS[class]
    local level, maxLevel = Profiles.PlayerLevel(), Profiles.MaxLevel()

    local leveling = Profiles.Get(Profiles.ClassProfileID(class, "LEVELING")) or Profiles.Get("LEVELING")
    local allround = Profiles.Get(Profiles.ClassProfileID(class, "ALLROUND")) or leveling

    local tab, _, apiRole = Profiles.DominantTab()
    if not list or not tab then
        if level < maxLevel then return leveling end
        return allround
    end

    local spec = Profiles.PickTabSpec(list, tab, apiRole) or list[1]
    if EG:Get("autoLeveling") and level < maxLevel and leveling and spec
       and spec.role ~= "TANK" and spec.role ~= "HEAL" then
        return leveling
    end
    return spec
end

function Profiles.ActiveID()
    return (EG.cdb and EG.cdb.profile) or "AUTO"
end

function Profiles.SetActive(id)
    if not EG.cdb then return false end
    if id ~= "AUTO" and not Profiles.Get(id) then return false end
    EG.cdb.profile = id
    EG:InvalidateAll()
    return true
end

------------------------------------------------------------------------------
-- 04  Gewichte
------------------------------------------------------------------------------

-- Zauberkraft ist in Forever nicht ueberall ein Wert: manche Gegenstaende tragen Heilung und Schaden
-- getrennt. Fehlen die Einzelgewichte, werden sie aus der Zauberkraft und der Rolle des Profils gebildet.
local function Derive(w, spec)
    local out = {}
    for k, v in pairs(w) do out[k] = v end
    local sp = out.SP
    if sp then
        local role, kind = spec.role, spec.kind
        if out.SPDMG == nil then
            out.SPDMG = (role == "HEAL") and sp * 0.35 or sp
        end
        if out.SPHEAL == nil then
            if role == "HEAL" then out.SPHEAL = sp
            elseif role == "CASTER" and kind == "SPEC" then out.SPHEAL = 0
            else out.SPHEAL = sp end
        end
    end
    return out
end

-- Gewichte eines Profils; Profile mit Varianten waehlen nach dem Talentbaum mit den meisten Punkten
function Profiles.VariantTab(spec)
    if not (spec and spec.variants) then return nil end
    local tab = Profiles.DominantTab()
    if tab and spec.variants[tab] then return tab end
    return nil
end

-- Die gespeicherten Gewichte eines Profils als Kopie, ohne abgeleitete Werte (Grundlage fuers Bearbeiten)
function Profiles.RawWeights(spec)
    local out = {}
    if not spec then return out end
    local w = spec.w or spec.weights or {}
    local vt = Profiles.VariantTab(spec)
    if vt then w = spec.variants[vt].w or w end
    for k, v in pairs(w) do out[k] = v end
    return out
end

-- Gewichte mit ergaenzten Einzelwerten fuer Zauberschaden und Heilung
function Profiles.DeriveWeights(weights, spec)
    return Derive(weights or {}, spec or {})
end

function Profiles.WeightsFor(spec)
    if not spec then return {} end
    return Derive(Profiles.RawWeights(spec), spec)
end

local resolved = nil

function Profiles.Invalidate()
    resolved = nil
    talentCache = nil
end

--[[ Das aktive Profil.
     Rueckgabe: { spec, weights, name, auto, sig }                                         ]]
function Profiles.Resolve()
    if resolved then return resolved end

    local class = Profiles.PlayerClass()
    local id = Profiles.ActiveID()
    local spec, auto
    if id == "AUTO" then
        spec, auto = Profiles.Detect(class), true
    else
        spec = Profiles.Get(id)
        if not spec then spec, auto = Profiles.Detect(class), true end
    end
    if not spec then spec = { id = "LEVELING", w = {}, role = "MELEE" } end

    local weights = Profiles.WeightsFor(spec)
    local label = Profiles.Name(spec)
    if auto then label = label .. " (" .. L.ROLE_AUTO .. ")" end

    local db = EG.db or EG.DEFAULTS
    local sig = table.concat({
        class, tostring(spec.id), tostring(UnitLevel("player")),
        tostring(db.ilvlWeight), tostring(db.ilvlScaling), tostring(db.socketValue),
        tostring(db.includeEnchants), tostring(Profiles.VariantTab(spec)), tostring(spec.rev or 0),
    }, ":")

    resolved = { spec = spec, weights = weights, name = label, auto = auto and true or false, sig = sig }
    return resolved
end

function Profiles.ActiveSpec()
    return Profiles.Resolve().spec
end

------------------------------------------------------------------------------
-- 05  Eigene Profile
------------------------------------------------------------------------------

function Profiles.CreateCustom(name, baseID, class)
    if not EG.db then return nil end
    EG.db.custom = EG.db.custom or {}

    name = (name and name ~= "") and name or L.PROFILE

    -- eindeutige ID erzeugen
    local base, n = "CUSTOM_" .. sgsub(name, "[^%w]", ""), 1
    if base == "CUSTOM_" then base = "CUSTOM_PROFILE" end
    local id = base
    while EG.db.custom[id] or Profiles.Get(id) do
        n = n + 1
        id = base .. n
    end

    local source = baseID and Profiles.Get(baseID)
    local weights = source and Profiles.RawWeights(source) or {}

    EG.db.custom[id] = {
        id = id, name = name, custom = true, rev = 1,
        class = class or Profiles.PlayerClass(),
        role = source and source.role or "MELEE",
        hands = source and source.hands or nil,
        kind = source and source.kind or "CUSTOM",          -- Derive (Zauberschaden/Heilung) haengt an der Art
        desc = source and (L.PROFILE .. ": " .. Profiles.Name(source)) or "",
        weights = weights,
    }
    return id
end

function Profiles.DeleteCustom(id)
    if not (EG.db and EG.db.custom and EG.db.custom[id]) then return false end
    EG.db.custom[id] = nil
    if Profiles.ActiveID() == id then EG.cdb.profile = "AUTO" end
    EG:InvalidateAll()
    return true
end

function Profiles.SetCustomWeight(id, key, value)
    local c = EG.db and EG.db.custom and EG.db.custom[id]
    if not c then return false end
    value = tonumber(value)
    if not value or value == 0 then
        c.weights[key] = nil
    else
        c.weights[key] = value
    end
    c.rev = (c.rev or 1) + 1
    EG:InvalidateAll()
    return true
end

-- Alle Gewichte eines eigenen Profils auf einmal ersetzen (eine einzige Neuberechnung)
function Profiles.SetCustomWeights(id, weights)
    local c = EG.db and EG.db.custom and EG.db.custom[id]
    if not c or type(weights) ~= "table" then return false end
    local out = {}
    for k, v in pairs(weights) do
        v = tonumber(v)
        if v and v ~= 0 then out[k] = v end
    end
    c.weights = out
    c.rev = (c.rev or 1) + 1
    EG:InvalidateAll()
    return true
end

function Profiles.RenameCustom(id, name)
    local c = EG.db and EG.db.custom and EG.db.custom[id]
    if not c or not name or name == "" then return false end
    c.name = name
    c.rev = (c.rev or 1) + 1
    EG:InvalidateAll()
    return true
end

------------------------------------------------------------------------------
-- 06  Ereignisse
------------------------------------------------------------------------------

-- Talente koennen beim Anmelden noch nicht gelesen werden; jeder dieser Anlaesse liest sie neu
local function TalentsChanged() EG:Debounce("talents", 0.3, function() EG:InvalidateAll() end) end
for _, event in ipairs({ "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_UPDATED",
                         "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
    EG:On(event, TalentsChanged)
end
