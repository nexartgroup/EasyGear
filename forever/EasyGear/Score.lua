--[[---------------------------------------------------------------------------
    Score.lua - Bewertung, Ausruestungsplaetze, Vergleich

    Bewertung eines Gegenstands (Punkte):

        Gegenstandsstufe x Stufengewicht x (Charakterstufe / Hoechststufe)
      + Summe (Wert x Gewicht)                inklusive Verzauberung, Steine, aktivem Sockelbonus
      + Waffen-DPS x Gewicht                  die Nebenhand zaehlt halb
      + leere Sockel x Sockelwert

    Verglichen wird je Ausruestungsplatz: der Kandidat wird in jeden moeglichen Platz "eingesetzt"
    und mit dem dort angelegten Gegenstand verglichen; der Platz mit dem groessten Zugewinn gewinnt.
    Dadurch stimmen die Sonderfaelle von selbst (Ringe, Schmuck, Einhandwaffen, Zweihandwaffen,
    Schild bei gefuehrter Zweihandwaffe, einzigartige Gegenstaende).
-----------------------------------------------------------------------------]]

local _, EG = ...
local Score = {}
EG.Score = Score

local L = EG.L
local Stats, Items, Profiles = EG.Stats, EG.Items, EG.Profiles

local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring
local tsort, tconcat = table.sort, table.concat
local sformat = string.format
local mmax, mmin = math.max, math.min

local OFFHAND_FACTOR = 0.5          -- Nebenhand-Waffen verursachen nur halben Schaden
local MAX_EQUIP_SLOT = 19

local scoreCache, stateCache, compareCache = {}, {}, {}
EG:RegisterCache(scoreCache)
EG:RegisterCache(stateCache)
EG:RegisterCache(compareCache)

------------------------------------------------------------------------------
-- 01  Bausteine der Bewertung
------------------------------------------------------------------------------

--[[ Der Anteil der Gegenstandsstufe waechst mit der Charakterstufe und erreicht erst auf der
     Hoechststufe das volle Gewicht: auf niedrigen Stufen tragen Gegenstaende kleine Werte, und ein
     fester Punktwert je Stufe uebertoente sonst die eigentlichen Attribute. Abschaltbar (/eg ilvlscale). ]]
function Score.EffectiveIlvlWeight()
    local w = tonumber(EG:Get("ilvlWeight")) or EG.DEFAULTS.ilvlWeight
    if EG:Get("ilvlScaling") == false then return w, w, 1 end
    local maxLevel = Profiles.MaxLevel()
    local level = mmin(Profiles.PlayerLevel(), maxLevel)
    local factor = level / maxLevel
    return w * factor, w, factor
end

local GEM_PRIMARY = { "STR", "AGI", "INT", "SP", "STA" }

--[[ Wert eines freien Sockelplatzes: ein typischer Stein der Stufe (ca. 0.22 Punkte je Stufe) mal dem
     staerksten Hauptattributgewicht des Profils, mit 10 % Abschlag fuer nicht passende Farbe.
     Ein fester Wert laesst sich mit /eg socket <zahl> setzen.                                     ]]
function Score.SocketPoints(weights)
    local override = tonumber(EG:Get("socketValue"))
    if override then return override end
    weights = weights or Profiles.Resolve().weights
    local best = 0
    for _, key in ipairs(GEM_PRIMARY) do
        local w = weights[key]
        if w and w > best then best = w end
    end
    local level = mmin(Profiles.PlayerLevel(), Profiles.MaxLevel())
    return level * 0.22 * best * 0.9
end

-- Gewicht der Waffen-DPS: Nahkampf (DPS) oder Fernkampf (RDPS, sonst DPS)
function Score.HandWeight(weights, kind)
    weights = weights or {}
    if kind == "RANGED" then return weights.RDPS or weights.DPS or 0 end
    return weights.DPS or 0
end

local function IsOffhandWeapon(item, slot)
    return slot == 17 and item.handKind == "MELEE"
end

local function Row(key, label, value, weight, points)
    return { key = key, label = label, value = value, weight = weight, points = points }
end

--[[ Wertung + vollstaendige Berechnungsgrundlage.
     rows = Liste von { key, label, value, weight, points }
     slot ist nur bei Nebenhand-Waffen von Belang (halbe DPS).                                 ]]
function Score.Breakdown(item, slot, weights)
    local rows, total = {}, 0
    if not item then return rows, 0 end
    weights = weights or Profiles.Resolve().weights

    -- 1) Basis aus der Gegenstandsstufe
    local ilvlWeight = Score.EffectiveIlvlWeight()
    local ilvlPoints = (item.ilvl or 0) * ilvlWeight
    if ilvlWeight > 0 then
        rows[#rows + 1] = Row("ILVL", L.BASE_ILVL, item.ilvl or 0, ilvlWeight, ilvlPoints)
    end
    total = total + ilvlPoints

    -- 2) Attribute in fester Reihenfolge, danach alles Uebrige (eigene Gewichte auf rohe ITEM_MOD-Namen)
    local seen = {}
    local function Add(key, value)
        local w = weights[key]
        if w and w ~= 0 and value and value ~= 0 then
            local pts = value * w
            total = total + pts
            rows[#rows + 1] = Row(key, Stats.Label(key), value, w, pts)
        end
    end
    for _, key in ipairs(Stats.ORDER) do
        seen[key] = true
        Add(key, item.stats and item.stats[key])
    end
    for key, value in pairs(item.stats or {}) do
        if not seen[key] then seen[key] = true Add(key, value) end
    end
    for key, value in pairs(item.unknown or {}) do
        if not seen[key] then seen[key] = true Add(key, value) end
    end

    -- 3) Waffen-DPS
    if item.dps and item.dps > 0 and item.handKind then
        local w = Score.HandWeight(weights, item.handKind)
        if IsOffhandWeapon(item, slot) then w = w * OFFHAND_FACTOR end
        if w ~= 0 then
            local pts = item.dps * w
            total = total + pts
            local key = (item.handKind == "RANGED") and Stats.RDPS or Stats.DPS
            rows[#rows + 1] = Row(key, Stats.Label(key), item.dps, w, pts)
        end
    end

    -- 4) Freie Sockelplaetze (gefuellte stehen schon in den Attributen)
    if item.sockets and item.sockets > 0 then
        local w = Score.SocketPoints(weights)
        if w ~= 0 then
            local pts = item.sockets * w
            total = total + pts
            rows[#rows + 1] = Row(Stats.SOCKET, Stats.Label(Stats.SOCKET), item.sockets, w, pts)
        end
    end

    return rows, total
end

-- Wertung mit Zwischenspeicher
function Score.Of(item, slot)
    if not item then return 0 end
    local key = item.link
    if not key then
        local _, total = Score.Breakdown(item, slot)
        return total
    end
    local profile = Profiles.Resolve()
    local cacheKey = profile.sig .. "|" .. key .. "|" .. (IsOffhandWeapon(item, slot) and "o" or "m")
    local hit = scoreCache[cacheKey]
    if hit then return hit end
    local _, total = Score.Breakdown(item, slot, profile.weights)
    scoreCache[cacheKey] = total
    return total
end

function Score.OfLink(link)
    local item = Items.Get(link)
    if not item then return nil end
    return Score.Of(item)
end

-- Punkte, die ein Gegenstand allein durch Verzauberung und Steine traegt. Wichtig fuer die Einordnung:
-- ein neuer Gegenstand kommt unverzaubert, der angelegte ist es meist.
function Score.ExtraPoints(item)
    if not (item and item.hasExtraStats) then return 0 end
    local weights = Profiles.Resolve().weights
    local pts = 0
    for key, v in pairs(item.extraStats) do
        local w = weights[key]
        if w and w ~= 0 then pts = pts + v * w end
    end
    return pts
end

--[[ Attribut-Unterschiede zwischen einem Kandidaten und den Gegenstaenden, die er ersetzt.
     targets = Liste von { item, slotID }; candSlot = Platz des Kandidaten (in der Nebenhand zaehlt seine
     Waffe nur halb, wie in der Wertung). Rueckgabe: nach Gewicht sortierte Liste
     { key, label, delta, points } - nur Attribute, die das Profil bewertet.                  ]]
function Score.StatDiff(item, targets, candSlot)
    local out = {}
    if not item then return out end
    local weights = Profiles.Resolve().weights

    local tstats, tdps, trdps = {}, 0, 0
    for _, t in ipairs(targets or {}) do
        local ti = t.item
        if ti then
            for k, v in pairs(ti.stats or {}) do tstats[k] = (tstats[k] or 0) + v end
            for k, v in pairs(ti.unknown or {}) do tstats[k] = (tstats[k] or 0) + v end
            if ti.handKind == "MELEE" then
                tdps = tdps + (ti.dps or 0) * (IsOffhandWeapon(ti, t.slotID) and OFFHAND_FACTOR or 1)
            elseif ti.handKind == "RANGED" then
                trdps = trdps + (ti.dps or 0)
            end
        end
    end

    local keys, seen = {}, {}
    local function Collect(tbl)
        for k in pairs(tbl or {}) do
            if not seen[k] then seen[k] = true keys[#keys + 1] = k end
        end
    end
    Collect(item.stats) Collect(item.unknown) Collect(tstats)

    for _, k in ipairs(keys) do
        local w = weights[k]
        if w and w ~= 0 then
            local mine = ((item.stats and item.stats[k]) or 0) + ((item.unknown and item.unknown[k]) or 0)
            local d = mine - (tstats[k] or 0)
            if d ~= 0 then
                out[#out + 1] = { key = k, label = Stats.Label(k), delta = d, points = d * w }
            end
        end
    end

    -- Waffen-DPS
    if item.handKind then
        local cand = (item.dps or 0) * (IsOffhandWeapon(item, candSlot) and OFFHAND_FACTOR or 1)
        local w = Score.HandWeight(weights, item.handKind)
        local have = (item.handKind == "RANGED") and trdps or tdps
        local d = cand - have
        if w ~= 0 and d ~= 0 and (cand > 0 or have > 0) then
            local key = (item.handKind == "RANGED") and Stats.RDPS or Stats.DPS
            out[#out + 1] = { key = key, label = Stats.Label(key), delta = d, points = d * w, decimals = 1 }
        end
    end

    tsort(out, function(a, b) return math.abs(a.points) > math.abs(b.points) end)
    return out
end

------------------------------------------------------------------------------
-- 02  Ausruestungsplaetze
------------------------------------------------------------------------------

-- Platznamen: die Blizzard-Globals der Plaetze (lokalisiert)
local SLOT_NAME_GLOBALS = {
    [1] = "HEADSLOT", [2] = "NECKSLOT", [3] = "SHOULDERSLOT", [4] = "SHIRTSLOT",
    [5] = "CHESTSLOT", [6] = "WAISTSLOT", [7] = "LEGSSLOT", [8] = "FEETSLOT",
    [9] = "WRISTSLOT", [10] = "HANDSSLOT", [11] = "FINGER0SLOT", [12] = "FINGER1SLOT",
    [13] = "TRINKET0SLOT", [14] = "TRINKET1SLOT", [15] = "BACKSLOT",
    [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT", [18] = "RANGEDSLOT",
    [19] = "TABARDSLOT",
}
local SLOT_NAME_FALLBACK = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest",
    [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands",
    [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket",
    [15] = "Back", [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged",
    [19] = "Tabard",
}
-- Beide Ring- und beide Schmuckplaetze tragen denselben Namen: dann wird nummeriert
local SLOT_PAIRS = {
    [11] = { partner = 12, index = 1 }, [12] = { partner = 11, index = 2 },
    [13] = { partner = 14, index = 1 }, [14] = { partner = 13, index = 2 },
}

local function RawSlotName(slot)
    local g = SLOT_NAME_GLOBALS[slot]
    local name = g and _G[g]
    if type(name) == "string" and name ~= "" then return name end
    return SLOT_NAME_FALLBACK[slot] or tostring(slot)
end

function Score.SlotName(slot)
    if type(slot) == "table" then
        local names = {}
        for _, id in ipairs(slot) do names[#names + 1] = Score.SlotName(id) end
        return tconcat(names, " / ")
    end
    slot = tonumber(slot)
    if not slot then return "?" end
    local name = RawSlotName(slot)
    local pair = SLOT_PAIRS[slot]
    if pair and name == RawSlotName(pair.partner) then name = name .. " " .. pair.index end
    return name
end

local EQUIP_LOC_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16, 17 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
}
Score.EQUIP_LOC_SLOTS = EQUIP_LOC_SLOTS

local OFFHAND_LOCS = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true }

local function EquippedLoc(slot)
    local item = Items.Equipped(slot)
    return item and item.equipLoc or nil
end

-- Fuehrt der Charakter gerade eine Zweihandwaffe?
function Score.HasTwoHandEquipped()
    return EquippedLoc(16) == "INVTYPE_2HWEAPON"
end

--[[ Kann der Charakter beidhaendig kaempfen? CanDualWield() ist die Abfrage des Clients; als
     Sicherheitsnetz gilt: liegt in der Nebenhand schon eine Waffe, geht es offenbar.            ]]
function Score.CanDualWield()
    local loc = EquippedLoc(17)
    if loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" then return true end
    if type(CanDualWield) == "function" then
        local ok, can = pcall(CanDualWield)
        if ok then return can and true or false end
    end
    return false
end

--[[ Darf eine Einhandwaffe auch in die Nebenhand? Beidhaendigkeit allein reicht nicht: ein
     Schutzkrieger kann zwar beidhaendig kaempfen, traegt aber ein Schild. Liegt in der Nebenhand ein Schild
     oder Buch, gilt sie nie als Waffenplatz; bei Tank-, Heiler- und Zauberprofilen auch dann nicht, wenn sie
     leer ist (dort muss schon eine Waffe liegen).                                                       ]]
function Score.WantsDualWield()
    if not Score.CanDualWield() then return false end
    local loc = EquippedLoc(17)
    -- Wer Schild oder Buch in der Nebenhand fuehrt, kaempft nicht beidhaendig - gleich in welchem Profil
    if loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then return false end
    local spec = Profiles.ActiveSpec()
    local role = spec and spec.role
    if role == "TANK" or role == "HEAL" or role == "CASTER" then
        return (loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND") and true or false
    end
    return true
end

--[[ Die relevanten Ausruestungsplaetze. Rueckgabe: slots, mode, candSlot
       mode = "SINGLE"  ein Platz
       mode = "EITHER"  einer von mehreren (Ringe, Schmuck, Einhandwaffen)
       mode = "BOTH"    ersetzt alle genannten Plaetze (Zweihandwaffe, oder ein Schild bei gefuehrter Zweihandwaffe)
       candSlot         Platz, in dem der Kandidat bei "BOTH" landet                                   ]]
function Score.EquipSlots(item)
    if not item or not item.equipLoc then return nil end
    local loc = item.equipLoc
    local slots = EQUIP_LOC_SLOTS[loc]
    if not slots then return nil end

    if loc == "INVTYPE_2HWEAPON" then return { 16, 17 }, "BOTH", 16 end

    -- Solange eine Zweihandwaffe gefuehrt wird, belegt sie auch die Nebenhand: ein Schild anzulegen kostet
    -- die ganze Zweihandwaffe. Verglichen wird deshalb gegen Waffenhand UND Nebenhand zusammen, nicht gegen
    -- den scheinbar leeren Platz 17 (sonst gaelte jedes Nebenhand-Item als Verbesserung).
    if OFFHAND_LOCS[loc] then
        if Score.HasTwoHandEquipped() then return { 16, 17 }, "BOTH", 17 end
        return { 17 }, "SINGLE"
    end

    if loc == "INVTYPE_WEAPON" then
        if Score.HasTwoHandEquipped() then return { 16 }, "SINGLE" end
        if Score.WantsDualWield() then return { 16, 17 }, "EITHER" end
        return { 16 }, "SINGLE"
    end

    if #slots > 1 then return slots, "EITHER" end
    return slots, "SINGLE"
end

------------------------------------------------------------------------------
-- 03  Vergleich
------------------------------------------------------------------------------

--[[ Zentrale Auswertung. Alle Anzeigen (Tooltip, Fenster, Taschen, Quest, Haendler) bauen darauf auf.

     result = {
       item, score, breakdown (nur mit detail),
       slots, mode, slotName,
       equipped = { { item, link, slotID, score, breakdown, empty }, ... },
       target   = Eintrag aus equipped, gegen den verglichen wird
       targetScore, delta, threshold, wouldUpgrade, isUpgrade, combined, percent,
       usable, reason, levelTooLow, replaced, notes, note
     }                                                                                    ]]
function Score.Compare(linkOrItem, detail)
    local item, why = linkOrItem, nil
    if type(linkOrItem) ~= "table" then item, why = Items.Get(linkOrItem) end
    if not item then return nil, why or "loading" end

    local profile = Profiles.Resolve()
    local cacheKey
    if not detail and item.link then
        cacheKey = profile.sig .. "|" .. item.link
        local hit = compareCache[cacheKey]
        if hit then return hit end
    end

    local result = { item = item, equipped = {} }

    -- Verwendbarkeit
    local level = Profiles.PlayerLevel()
    result.usable = item.usable ~= false
    result.reason = (not result.usable) and (item.reason or L.R_CLASS) or nil
    result.levelTooLow = (item.reqLevel or 0) > level
    if result.usable and result.levelTooLow then
        result.reason = sformat(L.R_LEVEL, item.reqLevel)
    end

    local slots, mode, candSlot = Score.EquipSlots(item)
    result.slots, result.mode = slots, mode
    result.slotName = slots and Score.SlotName(slots) or (item.equipLoc or "?")

    -- Hemd und Wappenrock zaehlen nicht als Ausruestung (Items.GEAR_LOC), ebensowenig alles Uebrige
    if not item.isGear or not slots then
        result.score = Score.Of(item)
        if detail then result.breakdown = (Score.Breakdown(item)) end
        result.isUpgrade, result.wouldUpgrade, result.noCompare = false, false, true
        if cacheKey then compareCache[cacheKey] = result end
        return result
    end

    -- Angelegte Gegenstuecke einsammeln
    for _, slotID in ipairs(slots) do
        local link = Items.EquippedLink(slotID)
        if link then
            local eq, eqWhy = Items.Get(link)
            if not eq then return nil, eqWhy or "loading" end
            local entry = { item = eq, link = link, slotID = slotID, score = Score.Of(eq, slotID) }
            if detail then entry.breakdown = (Score.Breakdown(eq, slotID)) end
            result.equipped[#result.equipped + 1] = entry
        else
            result.equipped[#result.equipped + 1] = { slotID = slotID, score = 0, breakdown = {}, empty = true }
        end
    end

    -- Den Platz mit dem groessten Zugewinn bestimmen
    local best
    if mode == "BOTH" then
        local sum = 0
        for _, e in ipairs(result.equipped) do sum = sum + (e.score or 0) end
        local target = result.equipped[1]
        for _, e in ipairs(result.equipped) do
            if e.item and e.item.equipLoc == "INVTYPE_2HWEAPON" then target = e break end
        end
        best = { entry = target, cs = Score.Of(item, candSlot), es = sum, slot = candSlot }
        result.combined = true
    else
        local pool = result.equipped
        -- Einzigartige Gegenstaende: ein zweites Exemplar darf nicht daneben, es ersetzt das angelegte
        if item.unique and #pool > 1 then
            for _, e in ipairs(pool) do
                if e.item and e.item.id == item.id then pool = { e } break end
            end
        end
        for _, e in ipairs(pool) do
            local cs = Score.Of(item, e.slotID)
            local es = e.score or 0
            local d = cs - es
            if not best or d > best.d + 1e-9 or (d > best.d - 1e-9 and es < best.es) then
                best = { entry = e, cs = cs, es = es, d = d, slot = e.slotID }
            end
        end
    end

    result.target = best.entry
    result.targetScore = best.es
    result.score = best.cs
    result.candSlot = best.slot
    result.delta = best.cs - best.es
    if detail then result.breakdown = (Score.Breakdown(item, best.slot)) end

    --[[ Schwelle fuer "Verbesserung": absolut UND relativ. Bei kleinen Wertungen (niedrige Stufen) ist
         ein Vorsprung von 0.1 Punkten Rauschen, kein Upgrade.                                         ]]
    local minDelta = tonumber(EG:Get("minDelta")) or 0
    local pct = tonumber(EG:Get("minDeltaPercent")) or 0
    local relative = (result.targetScore > 0) and (result.targetScore * pct / 100) or 0
    result.threshold = mmax(minDelta, relative)
    result.wouldUpgrade = (result.delta > 0 and result.delta >= result.threshold)
    result.isUpgrade = result.usable and (not result.levelTooLow) and result.wouldUpgrade
    result.percent = (result.targetScore > 0) and (result.delta / result.targetScore * 100) or nil

    -- Wer wird ersetzt? (fuer die Attribut-Unterschiede)
    local replaced = {}
    if result.combined then
        for _, e in ipairs(result.equipped) do
            if e.item then replaced[#replaced + 1] = { item = e.item, slotID = e.slotID } end
        end
    elseif best.entry.item then
        replaced[1] = { item = best.entry.item, slotID = best.entry.slotID }
    end
    result.replaced = replaced

    -- Begruendung
    if result.usable and not result.levelTooLow then
        if result.wouldUpgrade then
            if best.entry.empty then result.reason = L.R_EMPTY end
        elseif result.delta > 0 then
            result.reason = sformat(L.R_MINDELTA, EG.FmtScore(result.threshold))
        elseif result.delta == 0 then
            result.reason = L.R_EQUAL
        else
            result.reason = L.R_LOWER
        end
    end

    -- Hinweise
    local notes = {}
    if item.equipLoc == "INVTYPE_2HWEAPON" then
        notes[#notes + 1] = L.NOTE_2H
    elseif OFFHAND_LOCS[item.equipLoc] and mode == "BOTH" then
        notes[#notes + 1] = L.NOTE_OFFHAND
    elseif item.equipLoc == "INVTYPE_WEAPON" and Score.HasTwoHandEquipped() then
        notes[#notes + 1] = L.NOTE_MH_2H
    end
    if item.unique and best.entry.item and best.entry.item.id == item.id and mode == "EITHER" then
        notes[#notes + 1] = L.NOTE_UNIQUE
    end
    if not result.wouldUpgrade then
        local extra = 0
        for _, r in ipairs(replaced) do extra = extra + Score.ExtraPoints(r.item) end
        if extra > 0 then notes[#notes + 1] = sformat(L.NOTE_EXTRAS, EG.FmtScore(extra)) end
    end
    result.notes = notes
    result.note = (#notes > 0) and tconcat(notes, " ") or nil

    if cacheKey then compareCache[cacheKey] = result end
    return result
end

-- Schlanke Variante: ja/nein
function Score.IsUpgrade(link)
    local r = Score.Compare(link)
    if not r then return false end
    return r.isUpgrade == true, r.score or 0, r.targetScore or 0, r.slots
end

--[[ Zustand fuer die Markierungen an Taschen, Haendlern, Beute usw.:
       "UPGRADE"  echte Verbesserung
       "LEVEL"    waere eine, aber die Charakterstufe reicht noch nicht
       nil        keine Markierung
     Zweiter Rueckgabewert: true, wenn die Daten noch nicht im Client liegen und es sich lohnt,
     gleich noch einmal zu fragen.                                                              ]]
function Score.UpgradeState(link)
    if not link then return nil end
    local hit = stateCache[link]
    if hit ~= nil then return hit or nil end

    local item, why = Items.Get(link)
    if not item then return nil, why == "loading" end

    local state = false
    if item.isGear then
        local r, rwhy = Score.Compare(item)
        if not r then return nil, rwhy == "loading" end
        if r.isUpgrade then
            state = "UPGRADE"
        elseif r.usable and r.levelTooLow and r.wouldUpgrade then
            state = "LEVEL"
        end
    end
    stateCache[link] = state
    return state or nil
end

------------------------------------------------------------------------------
-- 04  Summen der Ausruestung (Profilvergleich)
------------------------------------------------------------------------------

--[[ Summiert alle Werte der angelegten Ausruestung. Die Wertung ist linear, deshalb ergibt die Summe der
     Einzelwerte mal den Gewichten genau dieselbe Gesamtwertung wie das Aufaddieren der Einzelwertungen:
     die komplette Ausruestung laesst sich so unter beliebigen Gewichten durchrechnen.                ]]
local totalsCache = {}                      -- .t = die Summen; bei Core angemeldet, wird mit den Vergleichen geleert
EG:RegisterCache(totalsCache)

function Score.EquippedTotals(force)
    if totalsCache.t and not force then return totalsCache.t end
    local t = { ILVL = 0, DPS = 0, RDPS = 0, SOCKET = 0, COUNT = 0, stats = {} }
    local complete = true
    for slot = 1, MAX_EQUIP_SLOT do
        local link = Items.EquippedLink(slot)
        if link then
            local item = Items.Get(link)
            if not item then
                complete = false                        -- noch nicht geladen: die Summe ist vorlaeufig
            elseif item.isGear then                     -- Hemd und Wappenrock gehoeren nicht dazu
                t.COUNT = t.COUNT + 1
                t.ILVL = t.ILVL + (item.ilvl or 0)
                t.SOCKET = t.SOCKET + (item.sockets or 0)
                if item.handKind == "MELEE" then
                    t.DPS = t.DPS + (item.dps or 0) * (IsOffhandWeapon(item, slot) and OFFHAND_FACTOR or 1)
                elseif item.handKind == "RANGED" then
                    t.RDPS = t.RDPS + (item.dps or 0)
                end
                for k, v in pairs(item.stats or {}) do t.stats[k] = (t.stats[k] or 0) + v end
                for k, v in pairs(item.unknown or {}) do t.stats[k] = (t.stats[k] or 0) + v end
            end
        end
    end
    if complete then totalsCache.t = t end               -- eine unvollstaendige Summe nicht festhalten
    return t
end

-- Berechnungsgrundlage einer Wertesammlung unter beliebigen Gewichten (Profilvergleich)
function Score.TotalsBreakdown(totals, weights)
    local rows, total = {}, 0
    if not totals or not weights then return rows, 0 end

    local ilvlWeight = Score.EffectiveIlvlWeight()
    if ilvlWeight > 0 and (totals.ILVL or 0) > 0 then
        local pts = totals.ILVL * ilvlWeight
        total = total + pts
        rows[#rows + 1] = Row("ILVL", L.BASE_ILVL, totals.ILVL, ilvlWeight, pts)
    end

    local seen = {}
    local function Add(key, v)
        local w = weights[key]
        if v and v ~= 0 and w and w ~= 0 then
            local pts = v * w
            total = total + pts
            rows[#rows + 1] = Row(key, Stats.Label(key), v, w, pts)
        end
    end
    for _, key in ipairs(Stats.ORDER) do seen[key] = true Add(key, totals.stats[key]) end
    for key, v in pairs(totals.stats) do
        if not seen[key] then seen[key] = true Add(key, v) end
    end

    local dw = Score.HandWeight(weights, "MELEE")
    if (totals.DPS or 0) > 0 and dw ~= 0 then
        local pts = totals.DPS * dw
        total = total + pts
        rows[#rows + 1] = Row(Stats.DPS, Stats.Label(Stats.DPS), totals.DPS, dw, pts)
    end
    local rw = Score.HandWeight(weights, "RANGED")
    if (totals.RDPS or 0) > 0 and rw ~= 0 then
        local pts = totals.RDPS * rw
        total = total + pts
        rows[#rows + 1] = Row(Stats.RDPS, Stats.Label(Stats.RDPS), totals.RDPS, rw, pts)
    end
    local sw = Score.SocketPoints(weights)
    if (totals.SOCKET or 0) > 0 and sw ~= 0 then
        local pts = totals.SOCKET * sw
        total = total + pts
        rows[#rows + 1] = Row(Stats.SOCKET, Stats.Label(Stats.SOCKET), totals.SOCKET, sw, pts)
    end
    return rows, total
end

------------------------------------------------------------------------------
-- 05  Ereignisse
------------------------------------------------------------------------------

--[[ Die Ausruestung hat sich geaendert. Was von ihr abhaengt, wird sofort verworfen: die Fenster der Oberflaeche
     frischen ihre Symbole im selben Augenblick auf und sollen nicht mehr mit dem alten Stand rechnen. Das
     Auffrischen der eigenen Anzeigen folgt gebuendelt.                                                      ]]
local function Changed()
    EG:InvalidateResults()              -- auch die Profilwahl: bei manchen Baeumen entscheiden die getragenen Waffen
    EG:Debounce("gearChanged", 0.2, function() EG:InvalidateAll() end)
end
EG:On("PLAYER_EQUIPMENT_CHANGED", Changed)
EG:On("ITEM_UPGRADE_MASTER_UPDATE", Changed)
-- Verzauberung und Edelsteine aendern den Link, ohne dass der Platz wechselt
EG:On("UNIT_INVENTORY_CHANGED", function(_, unit)
    if unit == "player" then Changed() end
end)
EG:Listen("ITEMS_LOADED", function()
    EG:InvalidateComparisons()
    EG:Fire("REFRESH")
end)
