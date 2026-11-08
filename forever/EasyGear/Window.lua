--[[---------------------------------------------------------------------------
    Window.lua - Vergleichsfenster (/eg, /eggui)

    Einen Gegenstand auf das Feld links ziehen, bei offenem Fenster mit Umschalt anklicken oder
    /eg <Link> eingeben. Links steht die volle Rechnung des Kandidaten (Attribut, Wert, Gewicht,
    Punkte), rechts die des angelegten Gegenstands; bei Ringen, Schmuck und Einhandwaffen schalten
    die Reiter zwischen beiden Plaetzen. Unten stehen Urteil und Hinweise.

    Aufbau mit den Vorlagen der Standard-Oberflaeche (ButtonFrameTemplate, ItemButtonTemplate,
    UIPanelButtonTemplate), damit das Fenster aussieht wie die uebrigen.
-----------------------------------------------------------------------------]]

local _, EG = ...
local Window = {}
EG.Window = Window

local L = EG.L
local Items, Score, Profiles = EG.Items, EG.Score, EG.Profiles

local ipairs, type, pcall, tostring = ipairs, type, pcall, tostring
local sformat = string.format

local WIDTH, HEIGHT = 570, 520
local ROWS = 15
local ROW_H = 16

local frame
local state = { link = nil, pick = 1 }

------------------------------------------------------------------------------
-- 01  Bausteine
------------------------------------------------------------------------------

local function Text(parent, template, ...)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    if ... then fs:SetPoint(...) end
    return fs
end

local function SetTitle(f, text)
    if f.SetTitle then
        f:SetTitle(text)
    else
        f.titleText = f.titleText or Text(f, "GameFontNormal", "TOP", 0, -6)
        f.titleText:SetText(text)
    end
end

-- Eine Spalte (Kandidat oder Angelegtes): Symbol, Name, Wertung und die Rechenzeilen
local function BuildColumn(parent, x)
    local col = { rows = {} }

    local btn = CreateFrame("ItemButton", nil, parent)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -8)
    btn:SetSize(40, 40)
    btn.EasyGearPlain = true            -- deren Tooltip bekommt keine EasyGear-Zeilen (Tooltip.lua)
    col.button = btn

    col.name = Text(parent, "GameFontNormal", "TOPLEFT", x + 48, -10)
    col.name:SetWidth(210)
    col.name:SetJustifyH("LEFT")
    col.info = Text(parent, "GameFontHighlightSmall", "TOPLEFT", x + 48, -28)
    col.info:SetWidth(210)
    col.info:SetJustifyH("LEFT")
    col.score = Text(parent, "GameFontNormalLarge", "TOPLEFT", x, -54)

    local y = -80
    for i = 1, ROWS do
        local row = {}
        row.label = Text(parent, "GameFontHighlightSmall", "TOPLEFT", x, y)
        row.label:SetWidth(112) row.label:SetJustifyH("LEFT")
        row.value = Text(parent, "GameFontHighlightSmall", "TOPLEFT", x + 112, y)
        row.value:SetWidth(40) row.value:SetJustifyH("RIGHT")
        row.weight = Text(parent, "GameFontDisableSmall", "TOPLEFT", x + 156, y)
        row.weight:SetWidth(44) row.weight:SetJustifyH("RIGHT")
        row.points = Text(parent, "GameFontNormalSmall", "TOPLEFT", x + 204, y)
        row.points:SetWidth(52) row.points:SetJustifyH("RIGHT")
        col.rows[i] = row
        y = y - ROW_H
    end
    return col
end

local function FillRows(col, breakdown)
    local n = breakdown and #breakdown or 0
    for i = 1, ROWS do
        local row, data = col.rows[i], breakdown and breakdown[i]
        if data and i <= ROWS then
            row.label:SetText(data.label or "?")
            local v = data.value or 0
            row.value:SetText((data.key == "DPS" or data.key == "RDPS") and sformat("%.1f", v) or EG.FmtScore(v))
            row.weight:SetText("x" .. EG.FmtWeight(data.weight))
            row.points:SetText(EG.FmtScore(data.points or 0))
        else
            row.label:SetText("") row.value:SetText("") row.weight:SetText("") row.points:SetText("")
        end
    end
    if n > ROWS then
        local row = col.rows[ROWS]
        row.label:SetText("...")
        row.value:SetText("") row.weight:SetText("") row.points:SetText("")
    end
end

local function QualityColor(quality)
    local r, g, b = 1, 1, 1
    if C_Item and C_Item.GetItemQualityColor then
        local ok, rr, gg, bb = pcall(C_Item.GetItemQualityColor, quality or 1)
        if ok and rr then r, g, b = rr, gg, bb end
    end
    return r, g, b
end

local function ShowItem(col, item, extraInfo)
    local btn = col.button
    if item then
        if SetItemButtonTexture then SetItemButtonTexture(btn, item.texture) end
        col.name:SetText(item.name or "?")
        col.name:SetTextColor(QualityColor(item.quality))
        col.info:SetText(extraInfo or "")
    else
        if SetItemButtonTexture then SetItemButtonTexture(btn, nil) end
        col.name:SetText(L.NOTHING_EQUIPPED)
        col.name:SetTextColor(0.6, 0.6, 0.6)
        col.info:SetText(extraInfo or "")
    end
    btn.link = item and item.link or nil
end

------------------------------------------------------------------------------
-- 02  Inhalt
------------------------------------------------------------------------------

local function ItemInfo(item)
    local parts = { L.ILVL .. " " .. tostring(item.ilvl or 0) }
    if item.slotText and item.slotText ~= "" then parts[#parts + 1] = item.slotText end
    if item.typeText and item.typeText ~= "" then parts[#parts + 1] = item.typeText end
    return table.concat(parts, " - ")
end

function Window.Refresh()
    if not frame or not frame:IsShown() then return end

    frame.profileText:SetText(L.PROFILE .. ": " .. Profiles.Resolve().name)

    local item = state.link and Items.Get(state.link)
    local result = item and Score.Compare(item, true)

    if not item then
        ShowItem(frame.cand, nil)
        frame.cand.name:SetText(state.link and L.ITEM_LOADING or L.DROP_HINT)
        frame.cand.name:SetTextColor(0.7, 0.7, 0.7)
        frame.cand.score:SetText("")
        FillRows(frame.cand, nil)
        ShowItem(frame.eq, nil)
        frame.eq.name:SetText("")
        frame.eq.score:SetText("")
        FillRows(frame.eq, nil)
        frame.verdict:SetText("")
        frame.notes:SetText("")
        frame.tab1:Hide() frame.tab2:Hide()
        return
    end

    ShowItem(frame.cand, item, ItemInfo(item))
    frame.cand.score:SetText(L.SCORE .. ": " .. EG.FmtScore(result.score or 0))
    FillRows(frame.cand, result.breakdown)

    -- Rechte Seite: der angelegte Gegenstand des gewaehlten Platzes
    local entries = result.equipped or {}
    if #entries > 1 and not result.combined then
        frame.tab1:Show() frame.tab2:Show()
        frame.tab1:SetText(Score.SlotName(entries[1].slotID))
        frame.tab2:SetText(Score.SlotName(entries[2].slotID))
        if state.pick > #entries then state.pick = 1 end
    else
        frame.tab1:Hide() frame.tab2:Hide()
        state.pick = 1
    end
    local entry = entries[state.pick]

    if entry and entry.item then
        ShowItem(frame.eq, entry.item, Score.SlotName(entry.slotID) .. " - " .. ItemInfo(entry.item))
        frame.eq.score:SetText(L.SCORE .. ": " .. EG.FmtScore(result.combined and result.targetScore or entry.score or 0))
        FillRows(frame.eq, entry.breakdown)
    elseif entry then
        ShowItem(frame.eq, nil, Score.SlotName(entry.slotID))
        frame.eq.score:SetText(L.SCORE .. ": 0")
        FillRows(frame.eq, nil)
    else
        ShowItem(frame.eq, nil)
        frame.eq.score:SetText("")
        FillRows(frame.eq, nil)
    end

    -- Urteil
    local text, r, g, b
    if result.noCompare then
        text, r, g, b = L.R_NOCOMPARE, 0.7, 0.7, 0.7
    elseif not result.usable then
        text, r, g, b = L.NOT_USABLE .. " - " .. (result.reason or ""), 1, 0.35, 0.35
    elseif result.levelTooLow and result.wouldUpgrade then
        text, r, g, b = sformat(L.UPGRADE_AT_LEVEL, item.reqLevel or 0), 1, 0.82, 0
    elseif result.isUpgrade then
        text, r, g, b = L.UPGRADE, 0.25, 1, 0.25
    else
        text, r, g, b = L.NO_UPGRADE, 1, 0.35, 0.35
    end
    if not result.noCompare and result.usable and result.delta then
        text = text .. "   " .. EG.FmtSigned(result.delta)
        if result.percent then text = text .. "  (" .. EG.FmtPct(result.percent) .. ")" end
    end
    frame.verdict:SetText(text)
    frame.verdict:SetTextColor(r, g, b)

    local notes = {}
    if result.reason and result.usable and not result.noCompare then notes[#notes + 1] = result.reason end
    for _, n in ipairs(result.notes or {}) do notes[#notes + 1] = n end
    frame.notes:SetText(table.concat(notes, "\n"))
end

function Window.SetItem(link)
    if type(link) ~= "string" and type(link) ~= "number" then return false end
    state.link, state.pick = link, 1
    Window.Open()
    Window.Refresh()
    return true
end

function Window.Clear()
    state.link, state.pick = nil, 1
    Window.Refresh()
end

function Window.Link() return state.link end

------------------------------------------------------------------------------
-- 03  Aufbau
------------------------------------------------------------------------------

local function SavePosition()
    if not (frame and EG.cdb) then return end
    local point, _, _, x, y = frame:GetPoint(1)
    EG.cdb.gui = EG.cdb.gui or {}
    EG.cdb.gui.point, EG.cdb.gui.x, EG.cdb.gui.y = point, x, y
end

local function ReceiveCursorItem()
    if not GetCursorInfo then return end
    local kind, id, link = GetCursorInfo()
    if kind == "item" then
        if ClearCursor then ClearCursor() end
        Window.SetItem(link or id)
    end
end

local function Build()
    if frame then return frame end

    frame = CreateFrame("Frame", "EasyGearWindow", UIParent, "ButtonFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(frame) end
    SetTitle(frame, L.TITLE)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePosition() end)
    frame:Hide()

    local gui = EG.cdb and EG.cdb.gui or {}
    frame:SetPoint(gui.point or "CENTER", UIParent, gui.point or "CENTER", gui.x or 0, gui.y or 0)
    frame:SetScale(gui.scale or 1)

    if UISpecialFrames then table.insert(UISpecialFrames, "EasyGearWindow") end

    local holder = frame.Inset or frame
    frame.holder = holder

    frame.profileText = Text(frame, "GameFontHighlightSmall", "TOPLEFT", 12, -34)

    frame.cand = BuildColumn(holder, 10)
    frame.eq = BuildColumn(holder, 290)
    frame.cand.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.cand.button:SetScript("OnReceiveDrag", ReceiveCursorItem)
    frame.cand.button:SetScript("OnClick", function(_, button)
        if button == "RightButton" then Window.Clear() else ReceiveCursorItem() end
    end)
    frame.cand.name:SetText(L.DROP_HINT)

    for _, col in ipairs({ frame.cand, frame.eq }) do
        local b = col.button
        b:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.link)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Reiter fuer die beiden Plaetze (Ringe, Schmuck, Einhandwaffen)
    frame.tab1 = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
    frame.tab1:SetSize(66, 20)
    frame.tab1:SetPoint("TOPLEFT", holder, "TOPLEFT", 410, -52)
    frame.tab1:SetScript("OnClick", function() state.pick = 1 Window.Refresh() end)
    frame.tab2 = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
    frame.tab2:SetSize(66, 20)
    frame.tab2:SetPoint("TOPLEFT", holder, "TOPLEFT", 480, -52)
    frame.tab2:SetScript("OnClick", function() state.pick = 2 Window.Refresh() end)

    frame.verdict = Text(holder, "GameFontNormalLarge", "BOTTOMLEFT", 12, 84)
    frame.verdict:SetWidth(WIDTH - 40)
    frame.verdict:SetJustifyH("LEFT")
    frame.notes = Text(holder, "GameFontHighlightSmall", "BOTTOMLEFT", 12, 8)
    frame.notes:SetWidth(WIDTH - 40)
    frame.notes:SetJustifyH("LEFT")
    frame.notes:SetJustifyV("TOP")

    -- Schaltflaechen unten
    local function Button(text, x, onClick)
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(130, 22)
        b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 4)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    frame.btnClear = Button(L.BTN_CLEAR, 8, function() Window.Clear() end)
    frame.btnChat = Button(L.BTN_CHAT, 144, function()
        if state.link and EG.Slash then EG.Slash.PrintReport(state.link) end
    end)
    frame.btnProfiles = Button(L.BTN_PROFILES, 280, function()
        if EG.ProfileWindow then EG.ProfileWindow.Toggle() end
    end)

    frame:SetScript("OnShow", function() Window.Refresh() end)
    return frame
end

function Window.Open()
    Build()
    if not frame:IsShown() then frame:Show() end
end

function Window.Toggle()
    Build()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function Window.IsShown() return frame ~= nil and frame:IsShown() end

------------------------------------------------------------------------------
-- 04  Anbindung
------------------------------------------------------------------------------

-- Umschalt + Klick auf einen Gegenstand holt ihn in das offene Fenster
EG:OnLoad("window", function()
    if hooksecurefunc and type(_G.HandleModifiedItemClick) == "function" then
        hooksecurefunc("HandleModifiedItemClick", function(link)
            if frame and frame:IsShown() and IsShiftKeyDown and IsShiftKeyDown() and link then
                EG:Try("window", Window.SetItem, link)
            end
        end)
        EG:HookResult("shiftclick", true)
    else
        EG:HookResult("shiftclick", false, "HandleModifiedItemClick fehlt")
    end
end)

EG:Listen("INVALIDATED", function() Window.Refresh() end)
EG:Listen("REFRESH", function() Window.Refresh() end)

EG:Listen("GUI_SCALE", function()
    if frame then frame:SetScale((EG.cdb and EG.cdb.gui and EG.cdb.gui.scale) or 1) end
end)

EG:Listen("GUI_RESET", function()
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetScale(1)
end)
