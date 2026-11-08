--[[---------------------------------------------------------------------------
    Items.lua - Gegenstandsdaten (mit Zwischenspeicher)

    Items.Get(linkOrID) liefert eine Tabelle mit allem, was die Bewertung braucht:

      id link name quality ilvl minLevel itemType itemSubType equipLoc texture sellPrice
      classID subclassID
      stats       alles, was zaehlt: Basiswerte, Verzauberung, Steine, Sockelbonus (Kurzschluessel)
      baseStats   nur die Basiswerte (GetItemStats und Basiszeilen)
      extraStats  der Anteil von Verzauberung und Steinen
      unknown     ITEM_MOD-Werte, die das Addon nicht kennt (roher Name -> Wert)
      sockets     leere Sockel
      dps         Waffen-DPS (Nahkampf: handKind "MELEE", Fernkampf/Zauberstab: "RANGED")
      isGear      kann in einen Ausruestungsplatz
      usable      false, wenn der Client den Gegenstand fuer diesen Spieler als unbrauchbar kennzeichnet

    Ist der Gegenstand noch nicht im Client-Zwischenspeicher, gibt Get nil und "loading" zurueck und
    stoesst das Laden an; GET_ITEM_INFO_RECEIVED meldet das Ergebnis ueber das interne Ereignis
    ITEMS_LOADED.
-----------------------------------------------------------------------------]]

local _, EG = ...
local Items = {}
EG.Items = Items

local pairs, type, tonumber, tostring, pcall = pairs, type, tonumber, tostring, pcall
local smatch = string.match

local Stats = EG.Stats

------------------------------------------------------------------------------
-- 01  Einbauplaetze und Gegenstandsarten
------------------------------------------------------------------------------

Items.WEAPON_LOC = {
    INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
}
Items.RANGED_LOC = {
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true,
}

-- Alles, was ein Spieler in einen Ausruestungsplatz legen und vergleichen kann
Items.GEAR_LOC = {
    INVTYPE_HEAD = true, INVTYPE_NECK = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true,
    INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true, INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true,
    INVTYPE_HOLDABLE = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true,
    INVTYPE_THROWN = true, INVTYPE_RELIC = true,
}

------------------------------------------------------------------------------
-- 02  Links
------------------------------------------------------------------------------

function Items.IDFromLink(link)
    if type(link) == "number" then return link end
    if type(link) ~= "string" then return nil end
    return tonumber(smatch(link, "item:(%d+)"))
end

-- Schluessel fuer den Zwischenspeicher: der Link, bei einer Nummer "item:<id>"
local function KeyOf(linkOrID)
    if type(linkOrID) == "number" then return "item:" .. linkOrID end
    if type(linkOrID) == "string" and linkOrID ~= "" then return linkOrID end
    return nil
end

------------------------------------------------------------------------------
-- 03  Laden
------------------------------------------------------------------------------

local cache, cacheCount = {}, 0
local requested = {}                -- itemID -> true: Laden ist angestossen
local failed = {}                   -- itemID -> Zeitpunkt: der Client kennt den Gegenstand nicht (eine Weile nicht erneut fragen)
local FAILED_RETRY = 60               -- Sekunden; ein Fehlschlag kann auch eine Zeitueberschreitung gewesen sein
local partialTries = {}             -- Schluessel -> Versuche, bei denen die Tooltip-Daten noch fehlten
local MAX_PARTIAL_TRIES = 3

local function Now() return GetTime and GetTime() or 0 end

local function Request(id)
    if id and not requested[id] and C_Item and C_Item.RequestLoadItemDataByID then
        requested[id] = true
        pcall(C_Item.RequestLoadItemDataByID, id)
    end
end

-- Einstellungen, die in die Gegenstandsdaten eingehen; aendern sie sich, wird der Speicher geleert
local lastSig
local function Signature()
    return tostring(EG:Get("includeEnchants")) .. ":" .. tostring(UnitLevel and UnitLevel("player"))
end

function Items.Wipe()
    cache, cacheCount = {}, 0
    requested, failed, partialTries = {}, {}, {}
    lastSig = Signature()
end

local function CheckSignature()
    local sig = Signature()
    if sig ~= lastSig then Items.Wipe() end
end

EG:Listen("INVALIDATED", CheckSignature)

local function GetInfo(link)
    if not (C_Item and C_Item.GetItemInfo) then return nil end
    return C_Item.GetItemInfo(link)
end

-- Rueckgabe: Zeilen | nil, gibt es die Schnittstelle ueberhaupt?  (nil bei vorhandener Schnittstelle = Daten fehlen noch)
local function TooltipLines(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil, false end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if ok and type(data) == "table" and type(data.lines) == "table" then return data.lines, true end
    return nil, true
end

--[[ Rueckgabe: data | nil, grund
     grund "loading"  - noch nicht im Client-Zwischenspeicher, wurde angefordert
     grund "invalid"  - kein Gegenstand (oder dem Client unbekannt)                            ]]
function Items.Get(linkOrID)
    local key = KeyOf(linkOrID)
    if not key then return nil, "invalid" end
    if lastSig == nil then lastSig = Signature() end

    local hit = cache[key]
    if hit then return hit end

    local id = Items.IDFromLink(key)
    local name, link, quality, ilvl, minLevel, itemType, itemSubType, stackCount, equipLoc, texture,
          sellPrice, classID, subclassID, bindType = GetInfo(key)

    if not name or not ilvl then
        local when = id and failed[id]
        if when and Now() - when < FAILED_RETRY then return nil, "invalid" end
        Request(id)
        return nil, id and "loading" or "invalid"
    end

    local effectiveLevel = ilvl
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, actual = pcall(C_Item.GetDetailedItemLevelInfo, link or key)
        if ok and type(actual) == "number" and actual > 0 then effectiveLevel = actual end
    end

    local data = {
        id = id, name = name, link = link or key, quality = quality or 0,
        ilvl = effectiveLevel, baseIlvl = ilvl, minLevel = minLevel or 0,
        itemType = itemType, itemSubType = itemSubType, stackCount = stackCount or 1,
        equipLoc = equipLoc or "", texture = texture, sellPrice = tonumber(sellPrice) or 0,
        classID = classID, subclassID = subclassID, bindType = bindType,
        stats = {}, baseStats = {}, extraStats = {}, unknown = {}, sockets = 0,
        usable = true,
    }

    data.isGear = Items.GEAR_LOC[data.equipLoc] == true
    if data.isGear and C_Item and C_Item.IsCosmeticItem then
        local ok, cosmetic = pcall(C_Item.IsCosmeticItem, data.link)
        if ok and cosmetic then data.isGear = false end
    end

    if data.isGear then
        local apiStats, unknown, sockets, apiDps = {}, {}, 0, nil
        if C_Item and C_Item.GetItemStats then
            local ok, tbl = pcall(C_Item.GetItemStats, data.link)
            if ok then apiStats, unknown, sockets, apiDps = Stats.FromItemStats(tbl) end
        end

        local lines, tooltipsExist = TooltipLines(data.link)
        -- Die Tooltip-Daten tragen Verzauberung, Steine, Einzigartigkeit und Verwendbarkeit; fehlen sie noch, ist das
        -- Ergebnis vorlaeufig und wird nicht festgehalten
        data.partial = (lines == nil and tooltipsExist) or nil
        local scan = Stats.ScanLines(lines)
        local withExtras = EG:Get("includeEnchants") ~= false
        local stats, extra = Stats.Merge(apiStats, scan, withExtras)

        for k, v in pairs(apiStats) do data.baseStats[k] = v end
        for k, v in pairs(scan.base) do
            if v > (data.baseStats[k] or 0) then data.baseStats[k] = v end
        end
        -- Freie Sockel sind ein Edelsteinwert: wer Steine nicht mitrechnet, rechnet auch die leeren Plaetze nicht
        data.stats, data.extraStats, data.unknown = stats, extra, unknown
        data.sockets = withExtras and sockets or 0
        data.hasExtraStats = next(extra) ~= nil
        data.unique = scan.unique and true or false
        data.scan = scan

        -- Waffen-DPS: aus GetItemStats, sonst aus dem Tooltip-Text
        if Items.WEAPON_LOC[data.equipLoc] then
            data.dps, data.handKind = apiDps or scan.dps or 0, "MELEE"
        elseif Items.RANGED_LOC[data.equipLoc] then
            data.dps, data.handKind = apiDps or scan.dps or 0, "RANGED"
        end

        -- Verwendbarkeit laut Client
        if scan.validType == false or scan.validSlot == false then
            data.usable = false
            data.reason = EG.L.R_CLASS
        elseif scan.reason then
            data.usable = false
            data.reason = scan.reason
        end
        data.reqLevel = math.max(data.minLevel or 0, scan.reqLevel or 0)
        data.slotText, data.typeText = scan.slotText, scan.typeText
    else
        data.reqLevel = data.minLevel or 0
    end

    if data.partial then
        local tries = (partialTries[key] or 0) + 1
        partialTries[key] = tries
        if tries <= MAX_PARTIAL_TRIES then
            -- Nicht festhalten: in einem Augenblick alles neu berechnen lassen, dann stehen die Zeilen meist da
            EG:Debounce("itemsPartial", 0.5, function() EG:Fire("ITEMS_LOADED") end)
            return data
        end
    end
    partialTries[key] = nil

    cacheCount = cacheCount + 1
    if cacheCount > 1500 then
        -- begrenzen, damit lange Sitzungen nicht wachsen
        Items.Wipe()
        cacheCount = 1
    end
    cache[key] = data
    return data
end

------------------------------------------------------------------------------
-- 04  Ausgeruestete Gegenstaende
------------------------------------------------------------------------------

function Items.EquippedLink(slot)
    return GetInventoryItemLink and GetInventoryItemLink("player", slot) or nil
end

function Items.Equipped(slot)
    local link = Items.EquippedLink(slot)
    if not link then return nil end
    return Items.Get(link)
end

------------------------------------------------------------------------------
-- 05  Ereignisse
------------------------------------------------------------------------------

EG:On("GET_ITEM_INFO_RECEIVED", function(_, id, success)
    if id then requested[id] = nil end
    if success == false then
        -- Der Client kennt den Gegenstand nicht: eine Weile nicht noch einmal fragen und nichts neu berechnen, aber
        -- die Anzeigen aktualisieren, die auf ihn warten ("ungueltig" statt "wird geladen")
        if id then failed[id] = Now() end
        EG:Debounce("itemsFailed", 0.25, function() EG:Fire("REFRESH") end)
        return
    end
    if id then failed[id] = nil end
    EG:Debounce("itemsLoaded", 0.25, function() EG:Fire("ITEMS_LOADED") end)
end)

EG:On("PLAYER_LEVEL_UP", function() Items.Wipe() end)
