--[[---------------------------------------------------------------------------
    EasyGear 2.2.0 - Vergleichsfenster  (/eggui)

    Links:  das abgelegte Item mit allen Berechnungsgrundlagen
    Rechts: das aktuell angelegte Gegenstueck mit derselben Aufschluesselung
    Unten:  Ergebnis, Differenz und Hinweise

    Reines Lua, keine XML-Datei, kompatibel mit 3.3.5a.
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

local L     = EG.L
local COLOR = EG.COLOR

local GUI = {}
EG.GUI = GUI

local sformat = string.format
local tonumber, tostring, ipairs, pairs = tonumber, tostring, ipairs, pairs

------------------------------------------------------------------------------
-- Layout-Konstanten
------------------------------------------------------------------------------

local FRAME_W, FRAME_H = 660, 530
local PANEL_W, PANEL_H = 310, 376
local MAX_ROWS         = 14
local ROW_H            = 15

local BACKDROP_MAIN = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local BACKDROP_PANEL = {
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

------------------------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------------------------

local function Num(v, d)
    if not v then return "0" end
    if v == math.huge then return "-" end
    if d and d > 0 then return sformat("%." .. d .. "f", v) end
    return sformat("%d", v + (v >= 0 and 0.5 or -0.5))
end

-- Nachkommastellen nach Groessenordnung (niedrige Stufen -> kleine Wertungen)
local function FmtScore(v)   return EG:FmtScore(v)  end
local function FmtWeight(v)  return EG:FmtWeight(v) end

local function MakeText(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function MakePanel(parent, name)
    local p = CreateFrame("Frame", name, parent)
    p:SetWidth(PANEL_W)
    p:SetHeight(PANEL_H)
    p:SetBackdrop(BACKDROP_PANEL)
    p:SetBackdropColor(0, 0, 0, 0.55)
    p:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    return p
end

local function QualityColor(quality)
    if not quality or not GetItemQualityColor then return 1, 1, 1 end
    local r, g, b = GetItemQualityColor(quality)
    return r or 1, g or 1, b or 1
end

------------------------------------------------------------------------------
-- Eine Seite (links = Kandidat, rechts = angelegt)
------------------------------------------------------------------------------

local function BuildSide(parent, name, withItemSlot)
    local side = {}
    side.panel = MakePanel(parent, name)

    side.header = MakeText(side.panel, "GameFontNormal")
    side.header:SetPoint("TOPLEFT", side.panel, "TOPLEFT", 10, -8)

    local textLeft = 12
    if withItemSlot then
        local slot = CreateFrame("Button", name .. "Slot", side.panel, "ItemButtonTemplate")
        slot:SetPoint("TOPLEFT", side.panel, "TOPLEFT", 10, -26)
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        side.slot = slot
        textLeft = 58
    else
        side.icon = side.panel:CreateTexture(nil, "ARTWORK")
        side.icon:SetWidth(37)
        side.icon:SetHeight(37)
        side.icon:SetPoint("TOPLEFT", side.panel, "TOPLEFT", 12, -28)
        side.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        side.icon:Hide()
        textLeft = 58
    end

    local textWidth = PANEL_W - textLeft - 12

    side.itemName = MakeText(side.panel, "GameFontNormalSmall")
    side.itemName:SetPoint("TOPLEFT", side.panel, "TOPLEFT", textLeft, -26)
    side.itemName:SetWidth(textWidth)
    side.itemName:SetHeight(26)
    side.itemName:SetJustifyV("TOP")

    --[[ Zwei feste Metazeilen statt einer umbrechenden.
         Bei langen Angaben ("Gegenstandsstufe 8 | Einhandstreitkolben |
         Waffenhand | Erbstueck") lief die einzelne Zeile sonst ueber die
         Trennlinie hinaus.                                               ]]
    side.itemMeta = MakeText(side.panel, "GameFontDisableSmall")
    side.itemMeta:SetPoint("TOPLEFT", side.panel, "TOPLEFT", textLeft, -55)
    side.itemMeta:SetWidth(textWidth)
    side.itemMeta:SetHeight(12)
    side.itemMeta:SetJustifyV("TOP")

    side.itemMeta2 = MakeText(side.panel, "GameFontDisableSmall")
    side.itemMeta2:SetPoint("TOPLEFT", side.panel, "TOPLEFT", textLeft, -69)
    side.itemMeta2:SetWidth(textWidth)
    side.itemMeta2:SetHeight(12)
    side.itemMeta2:SetJustifyV("TOP")

    -- Trennlinie
    local sep = side.panel:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    sep:SetVertexColor(0.4, 0.4, 0.4, 0.6)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", side.panel, "TOPLEFT", 10, -86)
    sep:SetPoint("TOPRIGHT", side.panel, "TOPRIGHT", -10, -86)

    -- Spaltenkopf
    local hy = -92
    side.colStat   = MakeText(side.panel, "GameFontNormalSmall", "LEFT")
    side.colStat:SetPoint("TOPLEFT", side.panel, "TOPLEFT", 10, hy)
    side.colStat:SetText(L.STAT)

    side.colValue  = MakeText(side.panel, "GameFontNormalSmall", "RIGHT")
    side.colValue:SetPoint("TOPRIGHT", side.panel, "TOPLEFT", 190, hy)
    side.colValue:SetText(L.VALUE)

    side.colWeight = MakeText(side.panel, "GameFontNormalSmall", "RIGHT")
    side.colWeight:SetPoint("TOPRIGHT", side.panel, "TOPLEFT", 245, hy)
    side.colWeight:SetText(L.WEIGHT)

    side.colPoints = MakeText(side.panel, "GameFontNormalSmall", "RIGHT")
    side.colPoints:SetPoint("TOPRIGHT", side.panel, "TOPRIGHT", -10, hy)
    side.colPoints:SetText(L.POINTS)

    -- Zeilen
    side.rows = {}
    for i = 1, MAX_ROWS do
        local y = -108 - (i - 1) * ROW_H
        local row = {}
        row.label = MakeText(side.panel, "GameFontHighlightSmall", "LEFT")
        row.label:SetPoint("TOPLEFT", side.panel, "TOPLEFT", 10, y)
        row.label:SetWidth(125)
        row.label:SetHeight(ROW_H)

        row.value = MakeText(side.panel, "GameFontHighlightSmall", "RIGHT")
        row.value:SetPoint("TOPRIGHT", side.panel, "TOPLEFT", 190, y)
        row.value:SetHeight(ROW_H)

        row.weight = MakeText(side.panel, "GameFontDisableSmall", "RIGHT")
        row.weight:SetPoint("TOPRIGHT", side.panel, "TOPLEFT", 245, y)
        row.weight:SetHeight(ROW_H)

        row.points = MakeText(side.panel, "GameFontHighlightSmall", "RIGHT")
        row.points:SetPoint("TOPRIGHT", side.panel, "TOPRIGHT", -10, y)
        row.points:SetHeight(ROW_H)

        side.rows[i] = row
    end

    -- Summe
    local ty = -114 - MAX_ROWS * ROW_H
    local sep2 = side.panel:CreateTexture(nil, "ARTWORK")
    sep2:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    sep2:SetVertexColor(0.4, 0.4, 0.4, 0.6)
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT", side.panel, "TOPLEFT", 10, ty + 4)
    sep2:SetPoint("TOPRIGHT", side.panel, "TOPRIGHT", -10, ty + 4)

    side.totalLabel = MakeText(side.panel, "GameFontNormal", "LEFT")
    side.totalLabel:SetPoint("TOPLEFT", side.panel, "TOPLEFT", 10, ty - 4)
    side.totalLabel:SetText(L.TOTAL)

    side.totalValue = MakeText(side.panel, "GameFontNormalLarge", "RIGHT")
    side.totalValue:SetPoint("TOPRIGHT", side.panel, "TOPRIGHT", -10, ty - 4)

    side.empty = MakeText(side.panel, "GameFontDisableSmall", "CENTER")
    side.empty:SetPoint("CENTER", side.panel, "CENTER", 0, -10)
    side.empty:SetWidth(PANEL_W - 40)
    side.empty:Hide()

    return side
end

------------------------------------------------------------------------------
-- Seite befuellen
------------------------------------------------------------------------------

local function FillSide(side, item, rows, total, link, extraMeta)
    -- Zuruecksetzen
    for i = 1, MAX_ROWS do
        local r = side.rows[i]
        r.label:SetText(""); r.value:SetText("")
        r.weight:SetText(""); r.points:SetText("")
    end

    if not item then
        side.itemName:SetText("")
        side.itemMeta:SetText("")
        side.itemMeta2:SetText("")
        side.totalValue:SetText("")
        if side.icon then side.icon:Hide() end
        if side.slot then
            local tex = _G[side.slot:GetName() .. "IconTexture"]
            if tex then tex:SetTexture(nil) end
        end
        side.empty:Show()
        return
    end

    side.empty:Hide()

    local r, g, b = QualityColor(item.quality)
    side.itemName:SetText(item.name or "?")
    side.itemName:SetTextColor(r, g, b)

    side.itemMeta:SetText(sformat("%s %s  |  %s", L.ILVL, tostring(item.level or 0),
        tostring(item.itemSubType or item.itemType or "")))
    side.itemMeta2:SetText(extraMeta or "")

    if side.icon then
        side.icon:SetTexture(item.texture)
        side.icon:Show()
    end
    if side.slot then
        local tex = _G[side.slot:GetName() .. "IconTexture"]
        if tex then tex:SetTexture(item.texture) end
    end

    local shown = 0
    for i = 1, #rows do
        if shown >= MAX_ROWS then break end
        shown = shown + 1
        local row  = side.rows[shown]
        local data = rows[i]
        row.label:SetText(tostring(data.label))
        row.value:SetText(Num(data.value, (data.value % 1 ~= 0) and 1 or 0))
        row.weight:SetText("x " .. FmtWeight(data.weight))
        row.points:SetText(FmtScore(data.points))
        if data.points >= 0 then
            row.points:SetTextColor(0.4, 1, 0.4)
        else
            row.points:SetTextColor(1, 0.4, 0.4)
        end
    end

    if #rows > MAX_ROWS then
        local row = side.rows[MAX_ROWS]
        row.label:SetText("...")
        row.value:SetText(""); row.weight:SetText(""); row.points:SetText("")
    end

    side.totalValue:SetText(FmtScore(total))
    side.totalValue:SetTextColor(1, 0.82, 0)
end

------------------------------------------------------------------------------
-- Fenster aufbauen
------------------------------------------------------------------------------

function GUI:Create()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "EasyGearGUIFrame", UIParent)
    f:SetWidth(FRAME_W)
    f:SetHeight(FRAME_H)
    f:SetBackdrop(BACKDROP_MAIN)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self_) self_:StartMoving() end)
    f:SetScript("OnDragStop", function(self_)
        self_:StopMovingOrSizing()
        local point, _, _, x, y = self_:GetPoint()
        local g = EG.charDB and EG.charDB.gui
        if g then g.point, g.x, g.y = point, x, y end
    end)
    f:Hide()

    -- ESC schliesst das Fenster
    tinsert(UISpecialFrames, "EasyGearGUIFrame")

    -- Titel
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -16)
    title:SetText(L.TITLE)
    f.title = title

    -- Profilzeile
    local profile = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profile:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -40)
    f.profileText = profile

    -- Rollen-Schalter
    local roleBtn = CreateFrame("Button", "EasyGearGUIRoleButton", f, "UIPanelButtonTemplate")
    roleBtn:SetWidth(120)
    roleBtn:SetHeight(20)
    roleBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -38)
    roleBtn:SetWidth(190)
    roleBtn:SetScript("OnClick", function()
        if EG.ProfileGUI then EG.ProfileGUI:Toggle() else EG:PrintProfileList() end
    end)
    roleBtn:SetScript("OnEnter", function(s_)
        GameTooltip:SetOwner(s_, "ANCHOR_LEFT")
        GameTooltip:SetText(L.PROFILE, 1, 0.82, 0)
        local spec = EG:GetActiveSpec()
        if spec then
            GameTooltip:AddLine(EG:GetProfileDesc(spec), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    roleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.roleBtn = roleBtn

    -- Schliessen
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

    -- Seiten
    self.left = BuildSide(f, "EasyGearGUILeft", true)
    self.left.panel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -64)
    self.left.header:SetText(L.CANDIDATE)

    self.right = BuildSide(f, "EasyGearGUIRight", false)
    self.right.panel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -64)
    self.right.header:SetText(L.EQUIPPED)

    -- Slot-Umschalter (Ringe / Schmuck / Waffen)
    self.slotTabs = {}
    for i = 1, 2 do
        local b = CreateFrame("Button", "EasyGearGUISlotTab" .. i,
            self.right.panel, "UIPanelButtonTemplate")
        b:SetWidth(64)
        b:SetHeight(18)
        b:SetPoint("TOPRIGHT", self.right.panel, "TOPRIGHT", -10 - (2 - i) * 68, -6)
        b:SetText(i == 1 and L.GUI_SLOT1 or L.GUI_SLOT2)
        b.index = i
        b:SetScript("OnClick", function(self_)
            GUI.selectedSlot = self_.index
            GUI:Refresh()
        end)
        b:Hide()
        self.slotTabs[i] = b
    end

    -- Ergebniszeile
    local verdict = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    verdict:SetPoint("TOP", f, "TOP", 0, -456)
    verdict:SetWidth(FRAME_W - 60)
    f.verdict = verdict

    local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOP", f, "TOP", 0, -478)
    note:SetWidth(FRAME_W - 60)
    note:SetJustifyH("CENTER")
    f.note = note

    -- Buttons unten
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetWidth(110); clearBtn:SetHeight(22)
    clearBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 16)
    clearBtn:SetText(L.BTN_CLEAR)
    clearBtn:SetScript("OnClick", function() GUI:Clear() end)

    local chatBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    chatBtn:SetWidth(140); chatBtn:SetHeight(22)
    chatBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
    chatBtn:SetText(L.BTN_CHAT)
    chatBtn:SetScript("OnClick", function()
        if GUI.currentLink then EG:PrintReport(GUI.currentLink) end
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetWidth(110); closeBtn:SetHeight(22)
    closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
    closeBtn:SetText(L.BTN_CLOSE)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Ablagefeld
    local slot = self.left.slot
    slot:SetScript("OnReceiveDrag", function() GUI:AcceptCursor() end)
    slot:SetScript("OnClick", function(_, button)
        if CursorHasItem() then
            GUI:AcceptCursor()
        elseif button == "RightButton" then
            GUI:Clear()
        end
    end)
    slot:SetScript("OnEnter", function(self_)
        if GUI.currentLink then
            GameTooltip:SetOwner(self_, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(GUI.currentLink)
            GameTooltip:Show()
        else
            GameTooltip:SetOwner(self_, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.DROP_HINT, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.left.empty:SetText(L.DROP_HINT)
    self.right.empty:SetText(L.NOTHING_EQUIPPED)

    -- Position wiederherstellen
    local g = EG.charDB and EG.charDB.gui
    f:ClearAllPoints()
    if g and g.point then
        f:SetPoint(g.point, UIParent, g.point, g.x or 0, g.y or 0)
    else
        f:SetPoint("CENTER")
    end
    f:SetScale((g and g.scale) or 1.0)

    self.frame = f
    return f
end

------------------------------------------------------------------------------
-- Steuerung
------------------------------------------------------------------------------

function GUI:AcceptCursor()
    local kind, a, b = GetCursorInfo()
    ClearCursor()
    if kind ~= "item" then return end
    local link = b
    if type(link) ~= "string" then
        local _, l = GetItemInfo(a)
        link = l
    end
    if link then self:SetItem(link) end
end

function GUI:SetItem(link, dontShow)
    if not link then return end
    self.currentLink  = link
    self.selectedSlot = nil
    self.retries      = nil
    if not dontShow then self:Show() end
    self:Refresh()
end

function GUI:Clear()
    self.currentLink  = nil
    self.selectedSlot = nil
    self:Refresh()
end

function GUI:Show()
    self:Create()
    self.frame:Show()
    self:Refresh()
end

function GUI:Hide()
    if self.frame then self.frame:Hide() end
end

function GUI:Toggle()
    self:Create()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Show()
    end
end

------------------------------------------------------------------------------
-- Aktualisierung
------------------------------------------------------------------------------

function GUI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    if not EG.db or not EG.charDB then return end
    local f = self.frame

    -- Profil / Rolle
    local _, profileName = EG:GetProfile()
    f.profileText:SetText(sformat("%s: %s%s%s", L.PROFILE,
        COLOR.value, tostring(profileName), COLOR.reset))
    local spec = EG:GetActiveSpec()
    f.roleBtn:SetText(spec and EG:GetProfileName(spec) or L.ROLE_AUTO)

    for i = 1, 2 do self.slotTabs[i]:Hide() end

    if not self.currentLink then
        FillSide(self.left, nil)
        FillSide(self.right, nil)
        f.verdict:SetText("")
        f.note:SetText("")
        return
    end

    local result = EG:Compare(self.currentLink)
    if not result then
        FillSide(self.left, nil)
        FillSide(self.right, nil)
        f.verdict:SetText(COLOR.warn .. L.ITEM_LOADING .. COLOR.reset)
        f.note:SetText("")
        -- Itemdaten koennen noch nachladen - hoechstens fuenf Versuche
        self.retries = (self.retries or 0) + 1
        if self.retries <= 5 then
            EG:After(0.5, function() GUI:Refresh() end)
        end
        return
    end

    self.retries = nil
    if EG.ProfileGUI and EG.ProfileGUI.frame and EG.ProfileGUI.frame:IsShown() then
        EG.ProfileGUI:Refresh()
    end

    -- Linke Seite
    FillSide(self.left, result.item, result.breakdown, result.score,
        self.currentLink, result.slotName)

    -- Rechte Seite: welchen Slot zeigen?
    local entries = result.equipped or {}
    if #entries > 1 then
        for i = 1, math.min(2, #entries) do
            local b = self.slotTabs[i]
            b:SetText(EG:GetSlotName(entries[i].slotID))
            b:Show()
        end
    end

    local index = self.selectedSlot
    if not index or not entries[index] then
        index = 1
        if result.target then
            for i, e in ipairs(entries) do
                if e == result.target then index = i break end
            end
        end
    end

    local entry = entries[index]
    if entry and not entry.empty then
        local extra = EG:GetSlotName(entry.slotID)
        if entry.isHeirloom then
            extra = extra .. "  |  " .. COLOR.warn .. L.HEIRLOOM .. COLOR.reset
        end
        FillSide(self.right, entry.item, entry.breakdown, entry.score, entry.link, extra)
    else
        FillSide(self.right, nil)
        self.right.empty:SetText(entry and
            (EG:GetSlotName(entry.slotID) .. ": " .. L.NOTHING_EQUIPPED) or L.NOTHING_EQUIPPED)
        self.right.empty:Show()
    end

    -- Ergebnis
    if result.usable ~= true then
        f.verdict:SetText(COLOR.bad .. L.NOT_USABLE .. COLOR.reset)
        f.note:SetText(tostring(result.reason or ""))
    elseif result.protected then
        f.verdict:SetText(COLOR.warn .. L.NO_UPGRADE .. COLOR.reset)
        f.note:SetText(tostring(result.reason or ""))
    else
        local delta = result.delta or 0
        local sign  = delta > 0 and "+" or ""
        local col   = result.isUpgrade and COLOR.good or (delta > 0 and COLOR.warn or COLOR.bad)
        local head  = result.isUpgrade and L.UPGRADE or L.NO_UPGRADE

        -- Bei Zweihandwaffen wird gegen die Summe beider Haende verglichen
        local against = FmtScore(result.targetScore)
        if result.combined then
            against = against .. " (" .. EG:GetSlotName(16) .. " + " .. EG:GetSlotName(17) .. ")"
        end

        f.verdict:SetText(sformat("%s%s%s     %s: %s%s%s     (%s %s)",
            col, head, COLOR.reset,
            L.DIFFERENCE, col, sign .. FmtScore(delta), COLOR.reset,
            L.GUI_COMPARED, against))

        local note = result.note or result.reason or ""
        f.note:SetText(note)
    end
end

------------------------------------------------------------------------------
-- Initialisierung
------------------------------------------------------------------------------

function GUI:OnInit()
    -- Shift-Klick auf ein Item laedt es ins offene Fenster
    if HandleModifiedItemClick then
        hooksecurefunc("HandleModifiedItemClick", function(link)
            if link and GUI.frame and GUI.frame:IsShown() and IsShiftKeyDown() then
                GUI:SetItem(link, true)
            end
        end)
    end
end
