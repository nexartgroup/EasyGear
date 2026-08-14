--[[---------------------------------------------------------------------------
    EasyGear 2.4.0 - Profilvergleich  (/egprofile)

    Aufbau wie der Item-Vergleich:

      links   das gewaehlte Vergleichsprofil (z. B. Tank)
      rechts  das aktuell aktive Profil (z. B. DD)
      Zeilen  Attribut | Wert deiner Ausruestung | Gewicht | Punkte
      unten   Differenz der Ausruestungswertung, aktivieren, bearbeiten,
              als neues Profil speichern

    Die Wertespalte ist auf beiden Seiten identisch - es sind die Summen
    deiner angelegten Ausruestung. Unterschiedlich sind Gewicht und Punkte.
    Damit sieht man unmittelbar, was die aktuelle Ausruestung unter einem
    anderen Build wert waere.
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

local L     = EG.L
local COLOR = EG.COLOR

local PGUI = {}
EG.ProfileGUI = PGUI

local sformat, tonumber, tostring = string.format, tonumber, tostring
local ipairs, pairs, tinsert = ipairs, pairs, table.insert

------------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------------

local FRAME_W, FRAME_H = 700, 590
local PANEL_W, PANEL_H = 330, 400
local MAX_ROWS         = 18
local ROW_H            = 15

local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "DEATHKNIGHT", "HUNTER", "ROGUE",
    "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

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

local function MakeText(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function ClassName(token)
    local t = LOCALIZED_CLASS_NAMES_MALE or LOCALIZED_CLASS_NAMES
    return (t and t[token]) or token
end

------------------------------------------------------------------------------
-- Eine Seite
------------------------------------------------------------------------------

local function BuildSide(parent, name, editable)
    local side = {}

    local p = CreateFrame("Frame", name, parent)
    p:SetWidth(PANEL_W); p:SetHeight(PANEL_H)
    p:SetBackdrop(BACKDROP_PANEL)
    p:SetBackdropColor(0, 0, 0, 0.55)
    p:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta) PGUI:Scroll(delta > 0 and -3 or 3) end)
    side.panel = p

    side.caption = MakeText(p, "GameFontNormalSmall")
    side.caption:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -8)

    side.title = MakeText(p, "GameFontNormalLarge")
    side.title:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -24)
    side.title:SetWidth(PANEL_W - 20)
    side.title:SetHeight(18)

    side.desc = MakeText(p, "GameFontDisableSmall")
    side.desc:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -46)
    side.desc:SetWidth(PANEL_W - 20)
    side.desc:SetHeight(24)
    side.desc:SetJustifyV("TOP")

    local sep = p:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    sep:SetVertexColor(0.4, 0.4, 0.4, 0.6)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -74)
    sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -74)

    local hy = -80
    local h1 = MakeText(p, "GameFontNormalSmall", "LEFT")
    h1:SetPoint("TOPLEFT", p, "TOPLEFT", 10, hy); h1:SetText(L.STAT)
    local h2 = MakeText(p, "GameFontNormalSmall", "RIGHT")
    h2:SetPoint("TOPRIGHT", p, "TOPLEFT", 205, hy); h2:SetText(L.VALUE)
    local h3 = MakeText(p, "GameFontNormalSmall", "RIGHT")
    h3:SetPoint("TOPRIGHT", p, "TOPLEFT", 268, hy); h3:SetText(L.WEIGHT)
    local h4 = MakeText(p, "GameFontNormalSmall", "RIGHT")
    h4:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, hy); h4:SetText(L.POINTS)

    side.rows = {}
    for i = 1, MAX_ROWS do
        local y = -96 - (i - 1) * ROW_H
        local row = {}

        row.label = MakeText(p, "GameFontHighlightSmall", "LEFT")
        row.label:SetPoint("TOPLEFT", p, "TOPLEFT", 10, y)
        row.label:SetWidth(130); row.label:SetHeight(ROW_H)

        row.value = MakeText(p, "GameFontHighlightSmall", "RIGHT")
        row.value:SetPoint("TOPRIGHT", p, "TOPLEFT", 205, y)
        row.value:SetHeight(ROW_H)

        row.weight = MakeText(p, "GameFontDisableSmall", "RIGHT")
        row.weight:SetPoint("TOPRIGHT", p, "TOPLEFT", 268, y)
        row.weight:SetHeight(ROW_H)

        row.points = MakeText(p, "GameFontHighlightSmall", "RIGHT")
        row.points:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, y)
        row.points:SetHeight(ROW_H)

        if editable then
            local eb = CreateFrame("EditBox", nil, p)
            eb:SetWidth(52); eb:SetHeight(ROW_H + 2)
            eb:SetPoint("TOPRIGHT", p, "TOPLEFT", 270, y + 1)
            eb:SetAutoFocus(false)
            eb:SetFontObject("GameFontHighlightSmall")
            eb:SetJustifyH("RIGHT")
            eb:SetMaxLetters(6)
            eb:SetTextInsets(3, 3, 0, 0)
            eb:SetBackdrop(BACKDROP_PANEL)
            eb:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
            eb:SetBackdropBorderColor(0.5, 0.5, 0.3, 0.9)
            eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
            eb:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
            eb:SetScript("OnTabPressed", function(s) s:ClearFocus() end)
            eb:SetScript("OnEditFocusLost", function(s)
                PGUI:ApplyEdit(s.statKey, s:GetText())
            end)
            eb:Hide()
            row.edit = eb
        end

        side.rows[i] = row
    end

    local ty = -102 - MAX_ROWS * ROW_H
    local sep2 = p:CreateTexture(nil, "ARTWORK")
    sep2:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    sep2:SetVertexColor(0.4, 0.4, 0.4, 0.6)
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT", p, "TOPLEFT", 10, ty + 4)
    sep2:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, ty + 4)

    side.totalLabel = MakeText(p, "GameFontNormal", "LEFT")
    side.totalLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 10, ty - 4)
    side.totalLabel:SetText(L.P_GEAR_SCORE)

    side.totalValue = MakeText(p, "GameFontNormalLarge", "RIGHT")
    side.totalValue:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, ty - 4)

    return side
end

------------------------------------------------------------------------------
-- Fenster
------------------------------------------------------------------------------

function PGUI:Create()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "EasyGearProfileFrame", UIParent)
    f:SetWidth(FRAME_W); f:SetHeight(FRAME_H)
    f:SetBackdrop(BACKDROP_MAIN)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) s:StartMoving() end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, _, _, x, y = s:GetPoint()
        local g = EG.charDB and EG.charDB.profileGui
        if g then g.point, g.x, g.y = point, x, y end
    end)
    f:Hide()
    tinsert(UISpecialFrames, "EasyGearProfileFrame")

    local title = MakeText(f, "GameFontNormalLarge", "CENTER")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText(L.P_TITLE)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

    ------------------------------------------------------------- Auswahl ---
    local classLabel = MakeText(f, "GameFontDisableSmall")
    classLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -38)
    classLabel:SetText(L.P_CLASS)

    local classDD = CreateFrame("Frame", "EasyGearProfileClassDD", f, "UIDropDownMenuTemplate")
    classDD:SetPoint("TOPLEFT", f, "TOPLEFT", 46, -50)
    self.classDD = classDD

    local profDD = CreateFrame("Frame", "EasyGearProfileDD", f, "UIDropDownMenuTemplate")
    profDD:SetPoint("LEFT", classDD, "RIGHT", 6, 0)
    self.profDD = profDD

    if UIDropDownMenu_SetWidth then
        pcall(UIDropDownMenu_SetWidth, classDD, 115)
        pcall(UIDropDownMenu_SetWidth, profDD, 185)
    end

    UIDropDownMenu_Initialize(classDD, function() PGUI:InitClassMenu() end)
    UIDropDownMenu_Initialize(profDD,  function() PGUI:InitProfileMenu() end)

    local pvp = CreateFrame("CheckButton", "EasyGearProfilePvP", f, "UICheckButtonTemplate")
    pvp:SetWidth(22); pvp:SetHeight(22)
    pvp:SetPoint("TOPRIGHT", f, "TOPRIGHT", -250, -46)
    local pvpText = MakeText(f, "GameFontHighlightSmall")
    pvpText:SetPoint("LEFT", pvp, "RIGHT", 2, 0)
    pvpText:SetText(L.P_PVP)
    pvp:SetScript("OnClick", function(s) EG:SetPvPMode(s:GetChecked() and true or false) end)
    self.pvpCheck = pvp

    -------------------------------------------------------------- Seiten ---
    self.left = BuildSide(f, "EasyGearProfileLeft", true)
    self.left.panel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -80)
    self.left.caption:SetText(L.P_CANDIDATE)

    self.right = BuildSide(f, "EasyGearProfileRight", false)
    self.right.panel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -80)
    self.right.caption:SetText(L.P_ACTIVEPROF)

    local nameBox = CreateFrame("EditBox", nil, f)
    nameBox:SetWidth(200); nameBox:SetHeight(20)
    nameBox:SetPoint("TOPLEFT", self.left.panel, "TOPLEFT", 10, -22)
    nameBox:SetAutoFocus(false)
    nameBox:SetFontObject("GameFontNormal")
    nameBox:SetMaxLetters(32)
    nameBox:SetTextInsets(4, 4, 0, 0)
    nameBox:SetBackdrop(BACKDROP_PANEL)
    nameBox:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    nameBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    nameBox:Hide()
    self.nameBox = nameBox

    ------------------------------------------------------------ Ergebnis ---
    local verdict = MakeText(f, "GameFontNormalLarge", "CENTER")
    verdict:SetPoint("TOP", f, "TOP", 0, -490)
    verdict:SetWidth(FRAME_W - 40)
    self.verdict = verdict

    local note = MakeText(f, "GameFontDisableSmall", "CENTER")
    note:SetPoint("TOP", f, "TOP", 0, -512)
    note:SetWidth(FRAME_W - 40)
    self.note = note

    local caveat = MakeText(f, "GameFontDisableSmall", "CENTER")
    caveat:SetPoint("TOP", f, "TOP", 0, -528)
    caveat:SetWidth(FRAME_W - 40)
    caveat:SetTextColor(0.5, 0.5, 0.5)
    self.caveat = caveat

    ------------------------------------------------------------- Knoepfe ---
    local function Btn(text, width, anchor, xOff)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetWidth(width); b:SetHeight(22)
        if anchor then
            b:SetPoint("LEFT", anchor, "RIGHT", xOff, 0)
        else
            b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", xOff, 14)
        end
        b:SetText(text)
        return b
    end

    self.btnActivate = Btn(L.P_ACTIVATE, 104, nil, 16)
    self.btnActivate:SetScript("OnClick", function()
        if not PGUI.spec then return end
        EG:SetActiveProfile(PGUI.spec.id)
        EG:Print(L.SET_PROFILE:format(EG:GetProfileName(PGUI.spec)))
    end)

    self.btnEdit = Btn(L.P_EDIT, 94, self.btnActivate, 5)
    self.btnEdit:SetScript("OnClick", function()
        PGUI.editMode = not PGUI.editMode
        PGUI.offset   = 0
        if PGUI.editMode then PGUI:StartDraft() else PGUI.draft = nil end
        PGUI:Refresh()
    end)

    self.btnSave = Btn(L.P_OVERWRITE, 94, self.btnEdit, 5)
    self.btnSave:SetScript("OnClick", function() PGUI:SaveOver() end)

    self.btnSaveNew = Btn(L.P_SAVE_NEW, 170, self.btnSave, 5)
    self.btnSaveNew:SetScript("OnClick", function()
        StaticPopup_Show("EASYGEAR_PROFILE_NEW", L.P_NEW_PROMPT)
    end)

    self.btnDelete = Btn(L.P_DELETE, 90, self.btnSaveNew, 5)
    self.btnDelete:SetScript("OnClick", function()
        if not (PGUI.spec and PGUI.spec.custom) then return end
        local d = StaticPopup_Show("EASYGEAR_PROFILE_DELETE", EG:GetProfileName(PGUI.spec))
        if d then d.data = PGUI.spec.id end
    end)

    local btnClose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnClose:SetWidth(86); btnClose:SetHeight(22)
    btnClose:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    btnClose:SetText(L.BTN_CLOSE)
    btnClose:SetScript("OnClick", function() f:Hide() end)

    EG.charDB.profileGui = EG.charDB.profileGui or { point = "CENTER", x = 0, y = 0 }
    local g = EG.charDB.profileGui
    f:ClearAllPoints()
    f:SetPoint(g.point or "CENTER", UIParent, g.point or "CENTER", g.x or 0, g.y or 0)
    f:SetScale((EG.charDB.gui and EG.charDB.gui.scale) or 1.0)

    self.frame = f
    return f
end

------------------------------------------------------------------------------
-- Auswahlmenues
------------------------------------------------------------------------------

function PGUI:InitClassMenu()
    local mine = EG:GetPlayerClass()

    local info = UIDropDownMenu_CreateInfo()
    info.text    = L.P_MYCLASS .. " (" .. ClassName(mine) .. ")"
    info.value   = mine
    info.checked = (self.class == mine)
    info.func    = function() PGUI:SetClass(mine) end
    UIDropDownMenu_AddButton(info, 1)

    for _, token in ipairs(CLASS_ORDER) do
        if token ~= mine then
            local i2 = UIDropDownMenu_CreateInfo()
            i2.text    = ClassName(token)
            i2.value   = token
            i2.checked = (self.class == token)
            i2.func    = function() PGUI:SetClass(token) end
            UIDropDownMenu_AddButton(i2, 1)
        end
    end
end

function PGUI:InitProfileMenu()
    for _, spec in ipairs(EG:GetProfilesForClass(self.class)) do
        local id   = spec.id
        local info = UIDropDownMenu_CreateInfo()
        local name = EG:GetProfileName(spec)
        if spec.custom then name = "* " .. name end
        info.text    = name
        info.value   = id
        info.checked = (self.spec and self.spec.id == id)
        info.func    = function() PGUI:SelectProfile(id) end
        UIDropDownMenu_AddButton(info, 1)
    end
end

local function SetDropText(dd, text)
    local fs = _G[dd:GetName() .. "Text"]
    if fs then fs:SetText(text) end
end

function PGUI:SetClass(class)
    self.class    = class
    self.spec     = nil
    self.editMode = false
    self.draft    = nil
    self.offset   = 0
    CloseDropDownMenus()
    self:Refresh()
end

function PGUI:SelectProfile(id)
    self.spec     = EG:GetProfileByID(id)
    self.editMode = false
    self.draft    = nil
    self.offset   = 0
    CloseDropDownMenus()
    self:Refresh()
end

------------------------------------------------------------------------------
-- Bearbeiten
------------------------------------------------------------------------------

function PGUI:AllKeys()
    local keys = {}
    for _, k in ipairs(EG.STAT_ORDER) do keys[#keys + 1] = k end
    keys[#keys + 1] = EG.PSEUDO_DPS
    return keys
end

function PGUI:StartDraft()
    self.draft = {}
    local w = self.spec and self.spec.weights or {}
    for k, v in pairs(w) do self.draft[k] = v end
end

function PGUI:ApplyEdit(statKey, text)
    if not (self.editMode and self.draft and statKey) then return end
    local v = tonumber((string.gsub(text or "", ",", ".")))
    if not v or v == 0 then
        self.draft[statKey] = nil
    else
        self.draft[statKey] = v
    end
    self:Refresh()
end

function PGUI:SaveOver()
    if not (self.editMode and self.draft and self.spec and self.spec.custom) then
        EG:Print(COLOR.warn .. L.P_ONLY_CUSTOM .. COLOR.reset)
        return
    end
    local id = self.spec.id
    for _, key in ipairs(self:AllKeys()) do
        EG:SetCustomWeight(id, key, self.draft[key] or 0)
    end
    local newName = self.nameBox:GetText()
    if newName and newName ~= "" then EG:RenameCustomProfile(id, newName) end

    self.editMode = false
    self.draft    = nil
    self.spec     = EG:GetProfileByID(id)
    EG:Print(L.SET_PROFILE:format(EG:GetProfileName(self.spec)))
    self:Refresh()
end

function PGUI:SaveAsNew(name)
    local weights = self.draft
    if not weights then
        weights = {}
        local w = self.spec and self.spec.weights or {}
        for k, v in pairs(w) do weights[k] = v end
    end

    local id = EG:CreateCustomProfile(name, self.spec and self.spec.id, self.class)
    if not id then return end
    for _, key in ipairs(self:AllKeys()) do
        EG:SetCustomWeight(id, key, weights[key] or 0)
    end

    self.spec     = EG:GetProfileByID(id)
    self.editMode = false
    self.draft    = nil
    EG:Print(L.SET_PROFILE:format(EG:GetProfileName(self.spec)))
    self:Refresh()
end

------------------------------------------------------------------------------
-- Popups
------------------------------------------------------------------------------

StaticPopupDialogs["EASYGEAR_PROFILE_NEW"] = {
    text = "%s",
    button1 = ACCEPT or "OK",
    button2 = CANCEL or "Abbrechen",
    hasEditBox = 1, maxLetters = 32,
    OnShow = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        if eb then
            local base = EasyGear.ProfileGUI.spec
            eb:SetText(base and (EasyGear:GetProfileName(base) .. " 2") or "")
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    OnAccept = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        EasyGear.ProfileGUI:SaveAsNew(eb and eb:GetText() or "")
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        EasyGear.ProfileGUI:SaveAsNew(self:GetText() or "")
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["EASYGEAR_PROFILE_DELETE"] = {
    text = "%s",
    button1 = YES or "Ja",
    button2 = NO or "Nein",
    OnAccept = function(self)
        local id = self.data
        if id then
            EasyGear:DeleteCustomProfile(id)
            EasyGear.ProfileGUI.spec     = nil
            EasyGear.ProfileGUI.editMode = false
            EasyGear.ProfileGUI.draft    = nil
            EasyGear.ProfileGUI:Refresh()
        end
    end,
    timeout = 30, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

------------------------------------------------------------------------------
-- Steuerung
------------------------------------------------------------------------------

function PGUI:Show()
    self:Create()
    self.frame:Show()
    self:Refresh()
end

function PGUI:Hide() if self.frame then self.frame:Hide() end end

function PGUI:Toggle()
    self:Create()
    if self.frame:IsShown() then self.frame:Hide() else self:Show() end
end

------------------------------------------------------------------------------
-- Darstellung
------------------------------------------------------------------------------

--[[ Gemeinsame Zeilenliste fuer beide Seiten.

     Wichtig: die Zeilen muessen auf beiden Seiten fluchten, sonst steht
     "Ausdauer" links in Zeile 3 und rechts in Zeile 9 und der Vergleich
     ist unlesbar. Deshalb wird die Vereinigung beider Gewichtssaetze
     gebildet und in fester Reihenfolge ausgegeben - fehlt ein Attribut in
     einem Profil, steht dort Gewicht 0.                                   ]]
function PGUI:BuildRows(totals, wA, wB, showAll)
    local rows  = {}
    local ilvlW = EG:GetEffectiveIlvlWeight()

    rows[#rows + 1] = {
        key = "__ILVL", label = L.BASE_ILVL, fixed = true,
        value = totals.__ILVL or 0,
        wa = ilvlW, pa = (totals.__ILVL or 0) * ilvlW,
        wb = ilvlW, pb = (totals.__ILVL or 0) * ilvlW,
    }

    local keys = {}
    for _, k in ipairs(EG.STAT_ORDER) do keys[#keys + 1] = k end
    keys[#keys + 1] = EG.PSEUDO_DPS
    keys[#keys + 1] = EG.PSEUDO_SOCKET

    for _, key in ipairs(keys) do
        local a = (wA and wA[key]) or 0
        local b = (wB and wB[key]) or 0
        if key == EG.PSEUDO_SOCKET then
            a = tonumber(EG.db and EG.db.socketValue) or 0
            b = a
            if (totals.__SOCKET or 0) == 0 then a, b = 0, 0 end
        end
        if showAll or a ~= 0 or b ~= 0 then
            local v
            if key == EG.PSEUDO_DPS then
                v = totals.__DPS or 0
            elseif key == EG.PSEUDO_SOCKET then
                v = totals.__SOCKET or 0
            else
                v = totals[key] or 0
            end
            rows[#rows + 1] = {
                key = key, label = EG:GetLocalizedStatName(key),
                value = v, wa = a, pa = v * a, wb = b, pb = v * b,
            }
        end
    end

    local ta, tb = 0, 0
    for _, r in ipairs(rows) do ta = ta + r.pa; tb = tb + r.pb end
    return rows, ta, tb
end

--[[ which = "a" (linke Seite) oder "b" (rechte Seite)                     ]]
local function FillSide(side, rows, total, which, offset, editable)
    for i = 1, MAX_ROWS do
        local r = side.rows[i]
        r.label:SetText(""); r.value:SetText("")
        r.weight:SetText(""); r.points:SetText("")
        if r.edit then r.edit:Hide() end
    end

    for i = 1, MAX_ROWS do
        local data = rows[i + offset]
        local r    = side.rows[i]
        if data then
            local w = (which == "a") and data.wa or data.wb
            local pt = (which == "a") and data.pa or data.pb

            r.label:SetText(data.label)
            r.value:SetText(EG:FmtScore(data.value))

            if editable and r.edit and not data.fixed then
                r.edit.statKey = data.key
                r.edit:SetText(w ~= 0 and EG:FmtWeight(w) or "")
                r.edit:Show()
                r.weight:SetText("")
            else
                r.weight:SetText("x " .. EG:FmtWeight(w))
            end

            r.points:SetText(EG:FmtScore(pt))

            -- Abweichung zur Gegenseite einfaerben
            local other = (which == "a") and data.pb or data.pa
            if pt > other + 0.001 then
                r.points:SetTextColor(0.4, 1, 0.4)
            elseif pt < other - 0.001 then
                r.points:SetTextColor(1, 0.5, 0.4)
            else
                r.points:SetTextColor(0.85, 0.85, 0.85)
            end
        end
    end

    side.totalValue:SetText(EG:FmtScore(total))
    side.totalValue:SetTextColor(1, 0.82, 0)
end

function PGUI:Scroll(delta)
    local total = self.rowCount or 0
    local maxOffset = total - MAX_ROWS
    if maxOffset < 0 then maxOffset = 0 end
    self.offset = (self.offset or 0) + delta
    if self.offset < 0 then self.offset = 0 end
    if self.offset > maxOffset then self.offset = maxOffset end
    self:Refresh()
end

function PGUI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    if not EG.db or not EG.charDB then return end

    self.class = self.class or EG:GetPlayerClass()

    local activeSpec = EG:GetActiveSpec()

    -- Standard: ein anderes Profil als das aktive, damit sofort ein echter
    -- Vergleich zu sehen ist
    if not self.spec then
        for _, s in ipairs(EG:GetProfilesForClass(self.class)) do
            if not activeSpec or s.id ~= activeSpec.id then
                self.spec = s
                break
            end
        end
        self.spec = self.spec or activeSpec
    end

    self.pvpCheck:SetChecked(EG:IsPvPMode())
    SetDropText(self.classDD, ClassName(self.class))
    SetDropText(self.profDD, self.spec and EG:GetProfileName(self.spec) or "-")

    local pvp    = EG:IsPvPMode()
    local totals = EG:GetEquippedTotals()

    local edit = (self.editMode and self.draft) and true or false

    local wActive = EG:GetWeightsFor(activeSpec, pvp)
    local wLeft
    if edit then
        wLeft = EG:GetWeightsFor({ weights = self.draft }, pvp)
    else
        wLeft = EG:GetWeightsFor(self.spec, pvp)
    end

    -- eine gemeinsame Zeilenliste, damit beide Seiten fluchten
    local rows, totalL, totalR = self:BuildRows(totals, wLeft, wActive, edit)
    self.rowCount = #rows

    local maxOffset = #rows - MAX_ROWS
    if maxOffset < 0 then maxOffset = 0 end
    self.offset = self.offset or 0
    if self.offset > maxOffset then self.offset = maxOffset end

    ------------------------------------------------- rechts: aktives Profil --
    self.right.title:SetText(activeSpec and EG:GetProfileName(activeSpec) or "-")
    self.right.desc:SetText(activeSpec and EG:GetProfileDesc(activeSpec) or "")
    FillSide(self.right, rows, totalR, "b", self.offset, false)

    ------------------------------------------------ links: Vergleichsprofil --
    if edit then
        self.nameBox:Show()
        if self.nameBox:GetText() == "" then
            self.nameBox:SetText(self.spec and EG:GetProfileName(self.spec) or "")
        end
        self.left.title:SetText("")
        self.left.desc:SetText(L.P_EDIT_HINT)
    else
        self.nameBox:Hide()
        self.nameBox:SetText("")
        self.left.title:SetText(self.spec and EG:GetProfileName(self.spec) or "-")
        self.left.desc:SetText(self.spec and EG:GetProfileDesc(self.spec) or "")
    end
    FillSide(self.left, rows, totalL, "a", self.offset, edit)

    ------------------------------------------------------------- Ergebnis --
    local isActive = (activeSpec and self.spec and activeSpec.id == self.spec.id
                      and not edit) and true or false
    local delta = totalL - totalR

    self.caveat:SetText(isActive and "" or L.P_CAVEAT)

    if (totals.__COUNT or 0) == 0 then
        self.verdict:SetText(COLOR.warn .. L.P_NOGEAR .. COLOR.reset)
        self.note:SetText("")
        self.caveat:SetText("")
    elseif isActive then
        self.verdict:SetText(COLOR.grey .. L.P_IS_ACTIVE .. COLOR.reset)
        self.note:SetText(sformat("%s: %s  (%s)", L.P_GEAR, EG:FmtScore(totalR),
            L.P_ITEMS:format(totals.__COUNT or 0)))
    else
        local col  = (delta > 0) and COLOR.good or ((delta < 0) and COLOR.bad or COLOR.grey)
        local sign = (delta > 0) and "+" or ""
        self.verdict:SetText(sformat("%s %s %s     %s: %s%s%s",
            EG:FmtScore(totalR), COLOR.grey .. "->" .. COLOR.reset, EG:FmtScore(totalL),
            L.DIFFERENCE, col, sign .. EG:FmtScore(delta), COLOR.reset))

        local msg = (delta > 0) and L.P_BETTER or ((delta < 0) and L.P_WORSE or L.P_SAME)

        local link = EG.GUI and EG.GUI.currentLink
        if link then
            local item = EG:GetItemData(link)
            if item then
                msg = msg .. "   |   " .. sformat("%s: %s / %s", L.P_ITEM_LINE,
                    EG:FmtScore(EG:GetItemScoreUnder(item, wLeft)),
                    EG:FmtScore(EG:GetItemScoreUnder(item, wActive)))
            end
        end
        self.note:SetText(msg)
    end

    -------------------------------------------------------------- Knoepfe --
    self.btnEdit:SetText(edit and L.BTN_CLEAR or L.P_EDIT)

    if self.spec and not isActive then
        self.btnActivate:Enable()
    else
        self.btnActivate:Disable()
    end

    if edit and self.spec and self.spec.custom then
        self.btnSave:Enable()
    else
        self.btnSave:Disable()
    end

    if self.spec and self.spec.custom then
        self.btnDelete:Enable()
    else
        self.btnDelete:Disable()
    end
end

function PGUI:OnInit() end
