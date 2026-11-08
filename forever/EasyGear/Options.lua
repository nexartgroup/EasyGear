--[[---------------------------------------------------------------------------
    Options.lua - Einstellungsseite (Optionen > AddOns > EasyGear) und Addon-Fach

    Die Seite benutzt die Einstellungs-API der Standard-Oberflaeche (senkrechtes Layout), sieht also aus
    wie die uebrigen Seiten und ist ueber die Suche der Optionen auffindbar. Aenderungen gelten sofort
    und liegen in EasyGearDB. Das Addon-Fach an der Minimap (Eintrag "EasyGear") oeffnet mit Linksklick
    das Vergleichsfenster, mit Rechtsklick diese Seite.
-----------------------------------------------------------------------------]]

local _, EG = ...
local Options = {}
EG.Options = Options

local L = EG.L
local Profiles = EG.Profiles

local ipairs, type, pcall, tostring = ipairs, type, pcall, tostring
local sformat = string.format

local category

------------------------------------------------------------------------------
-- 01  Beschreibung der Seite
------------------------------------------------------------------------------

-- Haken: Schluessel in EasyGearDB, Name und Hinweis (Schluessel der Sprachdateien)
Options.CHECKS = {
    { section = "OPT_SEC_MARKS" },
    { key = "showBagIcons",     name = "OPT_BAGS",         tip = "OPT_BAGS_TIP" },
    { key = "showItemIcons",    name = "OPT_ITEMS",        tip = "OPT_ITEMS_TIP" },
    { key = "showQuestIcons",   name = "OPT_QUESTREWARD",  tip = "OPT_QUESTREWARD_TIP" },
    { key = "showCharIcons",    name = "OPT_CHARHINT",     tip = "OPT_CHARHINT_TIP" },
    { section = "OPT_SEC_TOOLTIP" },
    { key = "showTooltip",      name = "OPT_TOOLTIP",      tip = "OPT_TOOLTIP_TIP" },
    { key = "showTooltipStats", name = "OPT_TOOLTIP_STATS", tip = "OPT_TOOLTIP_STATS_TIP" },
    { key = "tooltipDiff",      name = "OPT_DIFF",         tip = "OPT_DIFF_TIP" },
    { section = "OPT_SEC_SCORE" },
    { key = "includeEnchants",  name = "OPT_ENCHANTS",     tip = "OPT_ENCHANTS_TIP" },
    { key = "autoLeveling",     name = "OPT_AUTOLEVEL",    tip = "OPT_AUTOLEVEL_TIP" },
    { key = "ilvlScaling",      name = "OPT_ILVLSCALE",    tip = "OPT_ILVLSCALE_TIP" },
}

-- Regler: Schluessel, Bereich schrittweise, Anzeigeformat
Options.SLIDERS = {
    { key = "ilvlWeight",      name = "OPT_ILVL",      tip = "OPT_ILVL_TIP",      min = 0, max = 2,  step = 0.05, fmt = "%.2f" },
    { key = "minDeltaPercent", name = "OPT_MINDELTA",  tip = "OPT_MINDELTA_TIP",  min = 0, max = 10, step = 0.5,  fmt = "%.1f %%" },
}

------------------------------------------------------------------------------
-- 02  Seite aufbauen
------------------------------------------------------------------------------

local function Changed()
    EG:InvalidateAll()
end

local function AddCheck(cat, def)
    local default = EG.DEFAULTS[def.key]
    local setting = Settings.RegisterAddOnSetting(cat, "EasyGear_" .. def.key, def.key, EG.db,
        Settings.VarType.Boolean, L[def.name], default)
    setting:SetValueChangedCallback(Changed)
    Settings.CreateCheckbox(cat, setting, L[def.tip])
end

local function AddSlider(cat, def)
    local default = EG.DEFAULTS[def.key]
    local setting = Settings.RegisterAddOnSetting(cat, "EasyGear_" .. def.key, def.key, EG.db,
        Settings.VarType.Number, L[def.name], default)
    setting:SetValueChangedCallback(Changed)
    local options = Settings.CreateSliderOptions(def.min, def.max, def.step)
    if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
            return sformat(def.fmt, v)
        end)
    end
    Settings.CreateSlider(cat, setting, options, L[def.tip])
end

local function AddProfileDropdown(cat)
    local function GetValue() return Profiles.ActiveID() end
    local function SetValue(value) Profiles.SetActive(value) end
    local setting = Settings.RegisterProxySetting(cat, "EasyGear_PROFILE", Settings.VarType.String,
        L.OPT_PROFILE, "AUTO", GetValue, SetValue)
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("AUTO", L.OPT_PROFILE_AUTO)
        for _, spec in ipairs(Profiles.List()) do
            container:Add(spec.id, Profiles.Name(spec))
        end
        return container:GetData()
    end
    Settings.CreateDropdown(cat, setting, GetOptions, L.OPT_PROFILE_TIP)
end

local function Header(layout, key)
    if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L[key]))
    end
end

local function AddButton(layout, name, text, onClick, tip)
    if layout and layout.AddInitializer and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(name, text, onClick, tip, true))
    end
end

local function ConfirmReset()
    local function Do()
        EG:ResetDB()
        EG:Print(L.SET_RESET)
    end
    if type(StaticPopup_ShowCustomGenericConfirmation) == "function" then
        local ok = pcall(StaticPopup_ShowCustomGenericConfirmation, { text = L.OPT_RESET_PROMPT, callback = Do })
        if ok then return end
    end
    Do()
end

function Options.Build()
    if category then return category end
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting
            and Settings.CreateCheckbox and Settings.CreateSlider and Settings.CreateDropdown) then
        EG:HookResult("settings", false, "Settings-API fehlt")
        return nil
    end

    local cat, layout = Settings.RegisterVerticalLayoutCategory("EasyGear")

    for _, def in ipairs(Options.CHECKS) do
        if def.section then
            Header(layout, def.section)
        else
            AddCheck(cat, def)
        end
    end
    for _, def in ipairs(Options.SLIDERS) do AddSlider(cat, def) end

    Header(layout, "OPT_SEC_PROFILE")
    AddProfileDropdown(cat)
    AddButton(layout, L.OPT_RESET, L.OPT_RESET, ConfirmReset, L.H_RESET)

    Settings.RegisterAddOnCategory(cat)
    category = cat
    EG:HookResult("settings", true)
    return category
end

function Options.Open()
    Options.Build()
    if category and Settings and Settings.OpenToCategory then
        local id = category.GetID and category:GetID()
        if id then
            Settings.OpenToCategory(id)
            return true
        end
    end
    EG:Print(EG.COLOR.warn .. L.OPT_UNAVAILABLE .. EG.COLOR.reset)
    return false
end

-- Das Profil kann auch ausserhalb der Seite wechseln: die Auswahl nachziehen
EG:Listen("INVALIDATED", function()
    if category and Settings and Settings.NotifyUpdate then
        pcall(Settings.NotifyUpdate, "EasyGear_PROFILE")
    end
end)

EG:OnLoad("options", function()
    local ok, err = pcall(Options.Build)
    if not ok then
        EG:HookResult("settings", false, tostring(err))
    end
end)

------------------------------------------------------------------------------
-- 03  Addon-Fach (Minimap)
------------------------------------------------------------------------------

-- Die Namen stehen in der .toc (AddonCompartmentFunc, ...Enter, ...Leave); die Oberflaeche ruft sie mit
-- (Addonname, Maustaste) bzw. (Addonname, Knopf) auf.
function _G.EasyGear_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        Options.Open()
    elseif EG.Window then
        EG.Window.Toggle()
    end
end

function _G.EasyGear_OnAddonCompartmentEnter(_, menuButtonFrame)
    if not (GameTooltip and menuButtonFrame) then return end
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:AddLine("EasyGear " .. tostring(EG.version), 0, 0.8, 1)
    GameTooltip:AddLine(L.COMPARTMENT_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.COMPARTMENT_RIGHT, 1, 1, 1)
    local ok, profile = pcall(function() return Profiles.Resolve().name end)
    if ok and profile then GameTooltip:AddLine(L.PROFILE .. ": " .. profile, 0.7, 0.7, 0.7) end
    GameTooltip:Show()
end

function _G.EasyGear_OnAddonCompartmentLeave()
    if GameTooltip then GameTooltip:Hide() end
end
