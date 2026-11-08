--[[---------------------------------------------------------------------------
    Recommend.lua - Empfehlungen

      * Upgrades in Taschen (und der Bank, solange sie offen ist), nach Zugewinn geordnet
      * je Ausruestungsplatz der beste Kandidat
      * die beste Questbelohnung

    Das Addon empfiehlt nur: es legt nichts an und tauscht nichts aus.
-----------------------------------------------------------------------------]]

local _, EG = ...
local Recommend = {}
EG.Recommend = Recommend

local Items, Score = EG.Items, EG.Score

local ipairs, type, pcall, tonumber = ipairs, type, pcall, tonumber
local tsort = table.sort
local mhuge = math.huge

------------------------------------------------------------------------------
-- 01  Taschen
------------------------------------------------------------------------------

-- Behaelter, die durchsucht werden: Rucksack und Taschen; mit includeBank auch die offenen Banktabs
function Recommend.ContainerIDs(includeBank)
    local ids = {}
    local last = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS
    if type(last) ~= "number" then last = (_G.NUM_BAG_SLOTS or 4) + (_G.NUM_REAGENTBAG_SLOTS or 0) end
    for bag = 0, last do ids[#ids + 1] = bag end

    if includeBank and Enum and Enum.BagIndex then
        local B = Enum.BagIndex
        for i = 1, 9 do
            local c, a = B["CharacterBankTab_" .. i], B["AccountBankTab_" .. i]
            if c then ids[#ids + 1] = c end
            if a then ids[#ids + 1] = a end
        end
    end
    return ids
end

local function NumSlots(bag)
    if not (C_Container and C_Container.GetContainerNumSlots) then return 0 end
    local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
    return (ok and tonumber(n)) or 0
end

local function ItemLink(bag, slot)
    local ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
    return ok and link or nil
end

-- Ist es ein Gegenstand fuer einen Ausruestungsplatz? (billige Vorpruefung ohne Tooltip)
local function LooksLikeGear(link)
    if not (C_Item and C_Item.GetItemInfoInstant) then return true end
    local ok, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, link)
    if not ok then return true end
    return Items.GEAR_LOC[equipLoc] == true
end

--[[ Alle echten Upgrades in den Taschen, groesster Zugewinn zuerst.
     Rueckgabe: Liste von { link, bag, slot, result, delta, percent, slotID }, pending (gibt es noch ungeladene Daten?) ]]
function Recommend.Upgrades(includeBank)
    local list, pending = {}, false
    for _, bag in ipairs(Recommend.ContainerIDs(includeBank)) do
        for slot = 1, NumSlots(bag) do
            local link = ItemLink(bag, slot)
            if link and LooksLikeGear(link) then
                local r, why = Score.Compare(link)
                if r then
                    if r.isUpgrade then
                        list[#list + 1] = {
                            link = link, bag = bag, slot = slot, result = r,
                            delta = r.delta, percent = r.percent, slotID = r.candSlot,
                        }
                    end
                elseif why == "loading" then
                    pending = true
                end
            end
        end
    end
    tsort(list, function(a, b)
        if a.delta ~= b.delta then return a.delta > b.delta end
        return (a.link or "") < (b.link or "")
    end)
    return list, pending
end

-- Je Ausruestungsplatz der beste Kandidat: { [slotID] = Eintrag }
function Recommend.BestPerSlot(list)
    local best = {}
    for _, e in ipairs(list or {}) do
        local s = e.slotID
        if s and (not best[s] or e.delta > best[s].delta) then best[s] = e end
    end
    return best
end

--[[ Wie viele Upgrades gibt es und fuer welche Plaetze? Fuer die Hinweise am Charakterfenster.
     Rueckgabe: { [slotID] = Eintrag }, Liste                                               ]]
function Recommend.SlotHints()
    local list = Recommend.Upgrades(false)
    return Recommend.BestPerSlot(list), list
end

------------------------------------------------------------------------------
-- 02  Questbelohnungen
------------------------------------------------------------------------------

--[[ entries = Liste von { index, link, count, apiUsable }
     Auswahl-Logik:
       1. Gibt es mindestens ein echtes Upgrade -> hoechster Zugewinn.
       2. Sonst -> hoechster Gesamtverkaufswert (Stueckpreis x Anzahl).
     Gleichstand wird ueber den Verkaufswert aufgeloest.

     Entscheidend ist der Zugewinn, nicht die absolute Wertung: ein Umhang mit 39 Punkten, der einen
     vorhandenen mit 22 ersetzt, bringt 17; Stiefel mit 35 Punkten in einem leeren Platz bringen 35.
     Rueckgabe: index, art ("UPGRADE" | "VENDOR"), delta, wert, und eine Tabelle index -> Einzelergebnis {state, result, value} ]]
function Recommend.BestReward(entries)
    local bestUp, bestUpDelta, bestUpValue = nil, -mhuge, -1
    local bestVendor, bestVendorValue = nil, -mhuge
    local info = {}

    for _, e in ipairs(entries or {}) do
        local item = e.link and Items.Get(e.link)
        if item then
            local total = (item.sellPrice or 0) * (tonumber(e.count) or 1)
            local entry = { value = total }
            info[e.index] = entry

            if total > bestVendorValue then bestVendorValue, bestVendor = total, e.index end

            if e.apiUsable ~= false then
                local r = Score.Compare(item)
                if r then
                    entry.result = r
                    entry.state = r.isUpgrade and "UPGRADE" or ((r.usable and r.levelTooLow and r.wouldUpgrade) and "LEVEL" or nil)
                    if r.isUpgrade then
                        local delta = r.delta or 0
                        if delta > bestUpDelta or (delta == bestUpDelta and total > bestUpValue) then
                            bestUp, bestUpDelta, bestUpValue = e.index, delta, total
                        end
                    end
                end
            end
        end
    end

    if bestUp then return bestUp, "UPGRADE", bestUpDelta, bestUpValue, info end
    if bestVendor then return bestVendor, "VENDOR", nil, bestVendorValue, info end
    return nil, nil, nil, nil, info
end
