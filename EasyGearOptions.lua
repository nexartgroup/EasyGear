--[[---------------------------------------------------------------------------
    EasyGear 3.1.0 - Einstellungsfenster

    Seite "EasyGear" unter Interface > AddOns (oder /eg options): ein Haken je
    Markierung und je Tooltip-Zeile. Dieselben Schalter gibt es als Befehle
    (/eg icons, /eg items, /eg quest, /eg tooltip, /eg diff, /eg marks ...);
    beide Wege aendern dieselben Werte in EasyGearDB.
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

local L = EG.L

local Options = {}
EG.Options = Options

local ROW_H  = 26
local LEFT   = 16
local ICON   = 18

-- Zeilen: key = Einstellung in EasyGearDB, label = Schluessel des Anzeigetexts,
-- tex = Symbol (wie am Item), coords = Ausschnitt; header = Ueberschrift,
-- spacer = Luecke.
local function BuildRows()
    local rows = {
        { key = "showBagIcons",   label = "OPT_BAGS",        default = true,
          tex = EG.TEX_UPGRADE, vertex = { 0, 1, 0 } },
        { key = "showItemIcons",  label = "OPT_ITEMS",       default = true,
          tex = EG.TEX_UPGRADE, vertex = { 0, 1, 0 } },
        { key = "showQuestIcons", label = "OPT_QUESTREWARD", default = true,
          tex = EG.TEX_UPGRADE, vertex = { 1, 0.85, 0 } },
        { header = "MARKS_HEADER" },
    }
    for _, spec in ipairs(EG.MARKS or {}) do
        rows[#rows + 1] = { key = spec.setting, label = spec.name, default = spec.default,
                            tex = spec.tex, coords = spec.coords }
    end
    rows[#rows + 1] = { spacer = true }
    rows[#rows + 1] = { key = "showTooltip", label = "OPT_TOOLTIP", default = true }
    rows[#rows + 1] = { key = "tooltipDiff", label = "OPT_DIFF",    default = true }
    return rows
end

local function RowValue(row)
    local v = EG.db and EG.db[row.key]
    if v == nil then v = row.default end
    return v and true or false
end

-- Haken aus den gespeicherten Werten neu setzen (Befehle aendern sie ebenfalls)
function Options:Refresh()
    for _, row in ipairs(self.rows or {}) do
        if row.box then row.box:SetChecked(RowValue(row)) end
    end
end

function Options:Build()
    if self.panel then return self.panel end
    if not InterfaceOptions_AddCategory then return nil end

    local panel = CreateFrame("Frame", "EasyGearOptionsPanel", UIParent)
    panel.name = "EasyGear"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", LEFT, -16)
    title:SetText("EasyGear")

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    hint:SetText(L.OPT_HINT)

    local rows = BuildRows()
    local y = -64
    for i, row in ipairs(rows) do
        if row.spacer then
            y = y - ROW_H / 2
        elseif row.header then
            local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            fs:SetPoint("TOPLEFT", LEFT, y - 6)
            fs:SetText(L[row.header])
            row.fs = fs
            y = y - ROW_H
        else
            local name = "EasyGearOption" .. i
            local box = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
            box:SetPoint("TOPLEFT", LEFT, y)

            local anchor = box
            if row.tex then
                local icon = panel:CreateTexture(nil, "ARTWORK")
                icon:SetTexture(row.tex)
                local c = row.coords or { 0, 1, 0, 1 }
                icon:SetTexCoord(c[1], c[2], c[3], c[4])
                local v = row.vertex or { 1, 1, 1 }
                icon:SetVertexColor(v[1], v[2], v[3])
                icon:SetWidth(ICON)
                icon:SetHeight(ICON)
                icon:SetPoint("LEFT", box, "RIGHT", 4, 0)
                row.icon = icon
                anchor = icon
            end

            local text = _G[name .. "Text"] or box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            text:ClearAllPoints()
            text:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
            text:SetText(L[row.label])
            row.text = text

            box:SetScript("OnClick", function(button)
                EG.db[row.key] = button:GetChecked() and true or false
                EG.ApplySettingChange(false)
            end)
            row.box = box
            y = y - ROW_H
        end
    end

    panel.refresh = function() Options:Refresh() end
    panel:SetScript("OnShow", function() Options:Refresh() end)

    self.rows  = rows
    self.panel = panel
    InterfaceOptions_AddCategory(panel)
    return panel
end

function EG:OpenOptions()
    local panel = Options:Build()
    if not panel or not InterfaceOptionsFrame_OpenToCategory then
        self:PrintMarkList()
        return
    end
    Options:Refresh()
    -- Der 3.3.5-Client oeffnet beim ersten Aufruf oft nur das Fenster, nicht die Seite.
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end

Options:Build()
