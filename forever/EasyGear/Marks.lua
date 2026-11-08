--[[---------------------------------------------------------------------------
    Marks.lua - Markierungen auf Gegenstandssymbolen

    Eine Markierung ist eine kleine Textur oben links auf dem Symbol (wie der gruene Pfeil, den die
    Taschen der Standard-Oberflaeche selbst mitbringen):

        gruener Pfeil   echte Verbesserung gegenueber dem Angelegten
        gelber Pfeil    waere eine, aber die Charakterstufe reicht noch nicht
        Haken (rechts)  beste Wahl unter den Questbelohnungen

    Die Engine kennt kein Fenster. Contexts.lua meldet ihr "dieser Knopf zeigt jetzt diesen Link"
    (Marks.Set); sie merkt sich den Knopf und frischt ihn auf, wenn sich Ausruestung, Profil oder
    Einstellungen aendern (Ereignisse INVALIDATED / REFRESH).
-----------------------------------------------------------------------------]]

local _, EG = ...
local Marks = {}
EG.Marks = Marks

local Score = EG.Score

local pairs, pcall = pairs, pcall

-- Atlas-Namen stehen im Client (die Taschen der Standard-Oberflaeche benutzen "bags-greenarrow");
-- fehlt einer, faellt die Markierung auf eine feste Textur zurueck.
local ARROW_ATLAS, CHECK_ATLAS = "bags-greenarrow", "common-icon-checkmark"
local ARROW_FILE, CHECK_FILE = "Interface\\Buttons\\UI-CheckBox-Check", "Interface\\Buttons\\UI-CheckBox-Check"
local ARROW_SIZE, CHECK_SIZE = 18, 20

local registry = setmetatable({}, { __mode = "k" })     -- Knopf -> Daten
Marks.registry = registry

local function AtlasExists(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end

local function Ensure(button, key, layerLevel)
    local tex = button[key]
    if tex then return tex end
    tex = button:CreateTexture(nil, "OVERLAY", nil, layerLevel or 7)
    button[key] = tex
    tex:Hide()
    return tex
end

local function ShowArrow(button, state)
    local tex = Ensure(button, "EasyGearArrow", 7)
    tex:ClearAllPoints()
    -- Wie der eigene Pfeil der Taschen oben links; zeigt der Haendler dort den Restbestand (Stock), geht er nach rechts
    local corner = "TOPLEFT"
    local stock = button.Stock
    if type(stock) == "table" and stock.IsShown and stock:IsShown() then corner = "TOPRIGHT" end
    tex:SetPoint(corner, button, corner, 0, 0)
    tex:SetSize(ARROW_SIZE, ARROW_SIZE)
    if AtlasExists(ARROW_ATLAS) then
        tex:SetAtlas(ARROW_ATLAS)
        tex:SetSize(ARROW_SIZE, ARROW_SIZE)
    else
        tex:SetTexture(ARROW_FILE)
    end
    if state == "LEVEL" then
        tex:SetDesaturated(true)
        tex:SetVertexColor(1.0, 0.82, 0.0)
    else
        tex:SetDesaturated(false)
        tex:SetVertexColor(1, 1, 1)
    end
    tex:Show()
end

local function ShowCheck(button)
    local tex = Ensure(button, "EasyGearCheck", 7)
    tex:ClearAllPoints()
    -- Questbelohnungen sind breite Knoepfe (Symbol links, Name rechts): der Haken gehoert ans Symbol
    local icon = button.Icon or button.icon
    if type(icon) ~= "table" or not icon.GetObjectType then icon = button end
    tex:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 2, 2)
    tex:SetSize(CHECK_SIZE, CHECK_SIZE)
    if AtlasExists(CHECK_ATLAS) then
        tex:SetAtlas(CHECK_ATLAS)
        tex:SetSize(CHECK_SIZE, CHECK_SIZE)
    else
        tex:SetTexture(CHECK_FILE)
    end
    tex:SetVertexColor(0.25, 1.0, 0.25)
    tex:Show()
end

local function HideAll(button)
    if button.EasyGearArrow then button.EasyGearArrow:Hide() end
    if button.EasyGearCheck then button.EasyGearCheck:Hide() end
end

-- Welche Gruppe von Einstellungen schaltet diese Art von Knopf?
local SETTING_FOR = {
    bag = "showBagIcons", bank = "showBagIcons",
    merchant = "showItemIcons", loot = "showItemIcons", roll = "showItemIcons",
    trade = "showItemIcons", mail = "showItemIcons",
    quest = "showQuestIcons", char = "showCharIcons",
}
Marks.SETTING_FOR = SETTING_FOR

function Marks.Enabled(ctx)
    local key = SETTING_FOR[ctx]
    return key == nil or EG:Get(key) ~= false
end

--[[ Zustand eines Knopfes neu bestimmen und zeichnen.
     data = { ctx, link, best, hintSlot }                                                      ]]
function Marks.Update(button)
    local data = registry[button]
    if not data then return end

    local state, show = nil, false
    if Marks.Enabled(data.ctx) then
        if data.ctx == "char" then
            local hint = data.hint and data.hint() or nil
            state = hint and "UPGRADE" or nil
        elseif data.link then
            state = Score.UpgradeState(data.link)
        end
        if data.best and Marks.Enabled(data.ctx) then show = true end
    end

    if state or show then
        if state then ShowArrow(button, state) elseif button.EasyGearArrow then button.EasyGearArrow:Hide() end
        if show then ShowCheck(button) elseif button.EasyGearCheck then button.EasyGearCheck:Hide() end
    else
        HideAll(button)
    end
end

--[[ Ein Knopf zeigt jetzt diesen Link (nil = leer).
     opts: ctx (Pflicht), best (beste Questwahl), hint (Funktion -> Eintrag; nur fuer das Charakterfenster)

     Beim Aufruf aus Contexts.lua wird die Questwahl bewusst zurueckgesetzt: Blizzard setzt den Knopf neu,
     wenn sich die Belohnungen aendern, und die beste Wahl wird danach neu bestimmt.                         ]]
function Marks.Set(button, link, opts)
    if not button then return end
    local data = registry[button]
    if not data then
        data = {}
        registry[button] = data
    end
    data.ctx = opts and opts.ctx or data.ctx
    data.link = link
    data.best = opts and opts.best or false
    data.bestKind = nil
    data.hint = opts and opts.hint or data.hint
    Marks.Update(button)
end

-- Beste Questwahl; kind = "UPGRADE" (groesster Zugewinn) oder "VENDOR" (hoechster Verkaufswert)
function Marks.SetBest(button, best, kind)
    local data = registry[button]
    if not data then return end
    data.best = best and true or false
    data.bestKind = data.best and kind or nil
    Marks.Update(button)
end

function Marks.Clear(button)
    local data = registry[button]
    if data then
        data.link, data.best, data.bestKind = nil, false, nil
    end
    HideAll(button)
end

-- Alle sichtbaren Knoepfe auffrischen
function Marks.RefreshAll()
    for button, data in pairs(registry) do
        if button.IsVisible and button:IsVisible() then
            EG:Try("mark", Marks.Update, button)
        elseif data.ctx and not Marks.Enabled(data.ctx) then
            HideAll(button)
        end
    end
end

local function Schedule()
    EG:Debounce("marks", 0.15, Marks.RefreshAll)
end
EG:Listen("INVALIDATED", Schedule)
EG:Listen("REFRESH", Schedule)
