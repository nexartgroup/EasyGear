--[[---------------------------------------------------------------------------
    Tooltip.lua - Zeilen im Gegenstands-Tooltip

    Haengt sich ueber TooltipDataProcessor.AddTooltipPostCall(Item) an jeden Gegenstands-Tooltip
    der Standard-Oberflaeche: Taschen, Bank, Haendler, Beute, Wuerfeln, Handel, Post, Auktionshaus,
    Questbelohnungen, Chat-Links. Es braucht dafuer keine Kenntnis der einzelnen Fenster.

        EasyGear                          Score: 412
        Brust                                  378
        UPGRADE  +34  (+9.0%)
        +50 Staerke
        +22 Kritische Trefferwertung
        -14 Ausdauer

    Auf dem Charakterfenster und in den Vergleichs-Tooltips steht nur die Wertung: einen Gegenstand
    mit sich selbst zu vergleichen ist sinnlos.
-----------------------------------------------------------------------------]]

local _, EG = ...
local Tooltip = {}
EG.Tooltip = Tooltip

local L = EG.L
local Items, Score = EG.Items, EG.Score

local ipairs, type, pcall = ipairs, type, pcall
local sformat, smatch = string.format, string.match
local mmin = math.min

local MAX_DIFF_LINES = 8

local GREEN  = { 0.25, 1.00, 0.25 }
local RED    = { 1.00, 0.35, 0.35 }
local YELLOW = { 1.00, 0.82, 0.00 }
local GREY   = { 0.62, 0.62, 0.62 }
local TITLE  = { 0.00, 0.80, 1.00 }
local WHITE  = { 1.00, 1.00, 1.00 }

------------------------------------------------------------------------------
-- 01  Zeilen bauen (rein, ohne Tooltip - leicht zu pruefen)
------------------------------------------------------------------------------

local function FmtDelta(v, decimals)
    if decimals then return (v >= 0 and "+" or "-") .. sformat("%." .. decimals .. "f", math.abs(v)) end
    return EG.FmtSigned(v)
end

local function PickLine(kind)
    return { left = (kind == "VENDOR") and L.QUEST_PICK_VENDOR or L.QUEST_PICK, color = GREEN }
end

--[[ Liste von Zeilen { left, right, color, rightColor, wrap }.
     mode "FULL" = mit Vergleich, "SCORE" = nur die Wertung.
     extra (optional): { pick = "UPGRADE"|"VENDOR"  - beste Questbelohnung,
                         hint = Eintrag             - in den Taschen liegt etwas Besseres,
                         slot = Platznummer         - der Gegenstand ist dort angelegt }              ]]
function Tooltip.BuildLines(item, result, mode, extra)
    local lines = {}
    if not item then return lines end
    if not item.isGear then
        -- Auch ein Verbrauchsgegenstand kann die beste Questwahl sein (hoechster Verkaufswert)
        if extra and extra.pick then lines[#lines + 1] = PickLine(extra.pick) end
        return lines
    end

    -- extra.slot: der Platz, in dem der Gegenstand liegt (Charakterfenster, Vergleichs-Tooltip) - in der Nebenhand
    -- zaehlt die Waffe nur halb, wie im Vergleich
    local score = result and result.score or Score.Of(item, extra and extra.slot)
    lines[#lines + 1] = { left = "EasyGear", right = L.SCORE .. ": " .. EG.FmtScore(score), color = TITLE, rightColor = WHITE }

    if extra and extra.pick then lines[#lines + 1] = PickLine(extra.pick) end
    if extra and extra.hint then
        local h = extra.hint
        lines[#lines + 1] = {
            left = L.BAG_HINT .. " " .. EG.FmtSigned(h.delta or 0), right = h.link,
            color = YELLOW, rightColor = WHITE,
        }
    end

    if mode ~= "FULL" or not result or result.noCompare then return lines end

    if EG:Get("showTooltipStats") then
        -- Platz und Wertung dessen, was ersetzt wird
        local tgt = result.target
        local slotText = result.slotName
        if result.combined then
            lines[#lines + 1] = { left = slotText, right = EG.FmtScore(result.targetScore), color = GREY, rightColor = GREY }
        elseif tgt and tgt.empty then
            lines[#lines + 1] = { left = slotText, right = L.NOTHING_EQUIPPED, color = GREY, rightColor = GREY }
        elseif tgt then
            lines[#lines + 1] = { left = slotText, right = EG.FmtScore(tgt.score), color = GREY, rightColor = GREY }
        end
    end

    -- Urteil
    local verdict
    if not result.usable then
        verdict = { left = L.NOT_USABLE, color = RED }
    elseif result.levelTooLow and result.wouldUpgrade then
        verdict = { left = sformat(L.UPGRADE_AT_LEVEL, item.reqLevel or 0), color = YELLOW }
    elseif result.isUpgrade then
        local t = L.UPGRADE
        if result.target and result.target.empty then t = t .. " (" .. L.R_EMPTY_SHORT .. ")" end
        verdict = { left = t, color = GREEN }
    else
        verdict = { left = L.NO_UPGRADE, color = RED }
    end
    if result.usable and result.delta then
        local d = EG.FmtSigned(result.delta)
        if result.percent then d = d .. "  (" .. EG.FmtPct(result.percent) .. ")" end
        verdict.right = d
        verdict.rightColor = (result.delta > 0) and GREEN or ((result.delta < 0) and RED or GREY)
    end
    lines[#lines + 1] = verdict

    if not result.usable and result.reason then
        lines[#lines + 1] = { left = result.reason, color = GREY, wrap = true }
    end

    -- Attribut-Unterschiede
    if EG:Get("tooltipDiff") and result.usable and result.replaced and #result.replaced > 0 then
        local diffs = Score.StatDiff(item, result.replaced, result.candSlot)
        for i = 1, mmin(#diffs, MAX_DIFF_LINES) do
            local d = diffs[i]
            lines[#lines + 1] = {
                left = FmtDelta(d.delta, d.decimals) .. " " .. d.label,
                color = (d.delta > 0) and GREEN or RED,
            }
        end
    elseif EG:Get("tooltipDiff") and result.usable and result.target and result.target.empty then
        local diffs = Score.StatDiff(item, {}, result.candSlot)
        for i = 1, mmin(#diffs, MAX_DIFF_LINES) do
            local d = diffs[i]
            lines[#lines + 1] = { left = FmtDelta(d.delta, d.decimals) .. " " .. d.label, color = GREEN }
        end
    end

    if result.note then
        lines[#lines + 1] = { left = result.note, color = GREY, wrap = true }
    end
    return lines
end

------------------------------------------------------------------------------
-- 02  In den Tooltip schreiben
------------------------------------------------------------------------------

local function Emit(tooltip, lines)
    for _, ln in ipairs(lines) do
        local c = ln.color or WHITE
        if ln.right then
            local rc = ln.rightColor or c
            tooltip:AddDoubleLine(ln.left, ln.right, c[1], c[2], c[3], rc[1], rc[2], rc[3])
        else
            tooltip:AddLine(ln.left, c[1], c[2], c[3], ln.wrap and true or nil)
        end
    end
end

-- Gehoert der Tooltip zu einem Platz des Charakterfensters (oder der Inspektion)?
-- Rueckgabe: "Character" | "Inspect", Platznummer - oder nil
local function EquippedOwner(tooltip)
    local Contexts = EG.Contexts
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    local name = type(owner) == "table" and owner.GetName and owner:GetName()
    if Contexts and type(name) == "string" then return Contexts.SlotOfName(name) end
    return nil
end

-- Vergleichs-Tooltip neben dem Haupt-Tooltip? Die Oberflaeche gibt ihnen den Rahmen CompareHeader
-- (ShoppingTooltipTemplate); Name und das Merkmal isShopping sind die Reserve.
local function IsShoppingTooltip(tooltip)
    if tooltip.isShopping or tooltip.CompareHeader then return true end
    local name = tooltip.GetName and tooltip:GetName()
    return type(name) == "string" and smatch(name, "ShoppingTooltip%d$") ~= nil
end

-- Der Teil eines Links, der den Gegenstand festlegt ("item:1234:0:..."), ohne Farbe und Namen
local function ItemString(link)
    return type(link) == "string" and smatch(link, "item:[%-%d:]*") or nil
end

--[[ In welchem Platz ist dieser Gegenstand angelegt? (Vergleichs-Tooltips zeigen angelegte Gegenstaende.)
     Der Link aus GetItemInfo muss dem aus GetInventoryItemLink nicht Zeichen fuer Zeichen gleichen: darum gilt auch
     der Gegenstandsteil des Links, und zuletzt die Gegenstandsnummer.                                       ]]
local function WornSlotOf(item)
    local slots = Score.EQUIP_LOC_SLOTS[item.equipLoc]
    local want, byId = ItemString(item.link), nil
    for _, slot in ipairs(slots or {}) do
        local worn = Items.EquippedLink(slot)
        if worn then
            if worn == item.link or (want and ItemString(worn) == want) then return slot end
            if item.id and Items.IDFromLink(worn) == item.id then byId = byId or slot end
        end
    end
    return byId
end

local function LinkOf(tooltip, data)
    if type(data) ~= "table" then return nil end
    if data.guid and C_Item and C_Item.GetItemLinkByGUID then
        local ok, link = pcall(C_Item.GetItemLinkByGUID, data.guid)
        if ok and link then return link end
    end
    if type(data.hyperlink) == "string" and data.hyperlink ~= "" then return data.hyperlink end
    if TooltipUtil and TooltipUtil.GetDisplayedItem and tooltip.IsTooltipType then
        local ok, _, link = pcall(TooltipUtil.GetDisplayedItem, tooltip)
        if ok and link then return link end
    end
    return nil
end

--[[ Zusaetze, die vom Besitzer des Tooltips abhaengen: die empfohlene Questbelohnung und der Charakterplatz,
     fuer den in den Taschen etwas Besseres liegt (siehe Contexts.lua).                                 ]]
function Tooltip.ExtraFor(tooltip)
    local Contexts = EG.Contexts
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if not (Contexts and type(owner) == "table") then return nil end

    local extra = {}
    local recommended, kind = Contexts.IsRecommended(owner)
    if recommended then extra.pick = kind or "UPGRADE" end

    local where, slot = EquippedOwner(tooltip)
    if where == "Character" then extra.hint = Contexts.SlotHint(slot) end
    if extra.pick or extra.hint then return extra end
    return nil
end

function Tooltip.OnItem(tooltip, data)
    if not EG:Get("showTooltip") then return end
    if not tooltip or not tooltip.AddLine then return end
    -- die Symbole in den eigenen Fenstern zeigen die Rechnung ohnehin
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if type(owner) == "table" and owner.EasyGearPlain then return end

    local link = LinkOf(tooltip, data)
    if not link then return end

    local item = Items.Get(link)
    if not item then return end
    local extra = Tooltip.ExtraFor(tooltip)
    if not item.isGear and not (extra and extra.pick) then return end

    -- Auf dem Charakterfenster und in den Vergleichs-Tooltips steht nur die Wertung (mit dem Platz des Gegenstands)
    local mode, slot = "FULL", nil
    local where, ownerSlot = EquippedOwner(tooltip)
    if where then
        mode, slot = "SCORE", ownerSlot
    elseif IsShoppingTooltip(tooltip) then
        mode, slot = "SCORE", WornSlotOf(item)
    end
    if slot then
        extra = extra or {}
        extra.slot = slot
    end

    local result
    if mode == "FULL" and item.isGear then
        result = Score.Compare(item)
        if not result then return end
    end
    Emit(tooltip, Tooltip.BuildLines(item, result, mode, extra))
end

------------------------------------------------------------------------------
-- 03  Anbindung
------------------------------------------------------------------------------

EG:OnLoad("tooltip", function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            EG:Try("tooltip", Tooltip.OnItem, tooltip, data)
        end)
        EG:HookResult("tooltip", true)
    else
        EG:HookResult("tooltip", false, "TooltipDataProcessor fehlt")
    end
end)
