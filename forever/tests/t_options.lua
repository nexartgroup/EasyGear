-- Options.lua: settings page and addon compartment
return function(T)
    local F = require("fixtures")

    local function world(setup, opts)
        return T.world(F.arms(opts), function(W)
            W.I = F.armsWarrior(W)
            W.I.better = F.gear(W, 9001, "Better Chestplate", "INVTYPE_CHEST", 40, { STR = 30, STA = 40, CRIT = 20 }, { armor = 500 })
            if setup then setup(W) end
        end)
    end
    local function category(W) return W.state.settings[1] end

    T.test("options: one category with checkboxes, sliders, a dropdown and buttons", function()
        local W = world()
        local cat = category(W)
        T.ok(cat, "category registered") T.eq(cat.name, "EasyGear") T.eq(cat.registered, true)
        local kinds = {}
        for _, c in ipairs(cat.controls) do kinds[c.kind] = (kinds[c.kind] or 0) + 1 end
        T.eq(kinds.checkbox, 10) T.eq(kinds.slider, 2) T.eq(kinds.dropdown, 1)
        local headers, buttons = 0, 0
        for _, init in ipairs(cat.initializers) do
            if init.kind == "header" then headers = headers + 1 end
            if init.kind == "button" then buttons = buttons + 1 end
        end
        T.eq(headers, 4) T.eq(buttons, 1, "just the reset button")
        T.eq(W.EG.hookStatus.settings.ok, true)
    end)

    T.test("options: every control has a name and a tooltip from the language file", function()
        local W = world()
        for _, c in ipairs(category(W).controls) do
            if c.kind ~= "dropdown" or c.tooltip then
                T.ok(c.tooltip and c.tooltip ~= "", "tooltip of " .. tostring(c.setting.variable))
            end
            T.ok(W.EG:LocaleHas((c.setting.name and "x") and "TITLE" or "TITLE"))
            T.ok(not c.setting.name:match("^OPT_"), "name resolved: " .. c.setting.name)
        end
    end)

    T.test("options: the settings write into EasyGearDB and take effect immediately", function()
        local W = world()
        local b = W.bagButton(0, 1)
        W.env.SetItemButtonQuality(b, 3, W.I.better)
        T.eq(b.EasyGearArrow:IsShown(), true)
        local s = W.state.settingByVariable.EasyGear_showBagIcons
        T.eq(s:GetValue(), true)
        s:SetValue(false)
        T.eq(W.env.EasyGearDB.showBagIcons, false)
        W.flush()
        T.eq(b.EasyGearArrow:IsShown(), false, "marker follows the setting")

        local slider = W.state.settingByVariable.EasyGear_ilvlWeight
        T.eq(slider:GetValue(), 0.5)
        local before = W.EG.Score.OfLink(W.I.chest)
        slider:SetValue(1.0)
        T.eq(W.EG:Get("ilvlWeight"), 1.0)
        T.near(W.EG.Score.OfLink(W.I.chest) - before, 15)
    end)

    T.test("options: the slider ranges and labels", function()
        local W = world()
        local sliders = {}
        for _, c in ipairs(category(W).controls) do if c.kind == "slider" then sliders[#sliders + 1] = c end end
        T.eq(sliders[1].options.minValue, 0) T.eq(sliders[1].options.maxValue, 2) T.near(sliders[1].options.steps, 40)
        T.eq(sliders[1].options.formatter(0.55), "0.55")
        T.eq(sliders[2].options.formatter(1), "1.0 %")
    end)

    T.test("options: the profile dropdown lists automatic plus every profile and sets the character profile", function()
        local W = world()
        local dd
        for _, c in ipairs(category(W).controls) do if c.kind == "dropdown" then dd = c end end
        local opts = dd.getOptions()
        T.eq(opts[1].value, "AUTO") T.has(opts[1].label, "Automatic")
        T.eq(#opts, 1 + 5 + 2)
        T.eq(dd.setting:GetValue(), "AUTO")
        dd.setting:SetValue("WARRIOR_FURY")
        T.eq(W.EG.Profiles.ActiveID(), "WARRIOR_FURY")
        W.state.settingsOpen = true
        W.EG.Profiles.SetActive("AUTO")
        T.ok((W.state.settingByVariable.EasyGear_PROFILE.notified or 0) >= 1, "the page is told when the profile changes elsewhere")
    end)

    T.test("options: the reset button asks first, resets the settings and keeps own profiles", function()
        local W = world()
        local reset
        for _, init in ipairs(category(W).initializers) do if init.kind == "button" then reset = init end end
        W.EG:Set("tooltipDiff", false)
        local id = W.EG.Profiles.CreateCustom("Keep Me", "WARRIOR_ARMS")
        reset.onClick()
        local dlg = W.state.popups[#W.state.popups]
        T.eq(dlg.which, "GENERIC_CONFIRMATION")
        T.eq(W.env.EasyGearDB.tooltipDiff, false, "nothing happens before confirming")
        dlg.data.callback()
        T.eq(W.env.EasyGearDB.tooltipDiff, true)
        T.ok(W.EG.Profiles.Get(id), "own profiles survive a reset")
    end)

    T.test("options: Open goes to the category", function()
        local W = world()
        T.eq(W.EG.Options.Open(), true)
        T.eq(W.state.opened[#W.state.opened], category(W):GetID())
    end)

    T.test("options: the addon compartment functions", function()
        local W = world()
        local env = W.env
        env.EasyGear_OnAddonCompartmentClick("EasyGear", "LeftButton")
        T.eq(W.EG.Window.IsShown(), true)
        env.EasyGear_OnAddonCompartmentClick("EasyGear", "LeftButton")
        T.eq(W.EG.Window.IsShown(), false, "toggles")
        env.EasyGear_OnAddonCompartmentClick("EasyGear", "RightButton")
        T.eq(#W.state.opened, 1)
        local owner = W.env.CreateFrame("Frame")
        env.EasyGear_OnAddonCompartmentEnter("EasyGear", owner)
        local tip = env.GameTooltip
        T.eq(tip:GetOwner(), owner)
        T.has(tip:Dump(), "EasyGear 4.0.0-test") T.has(tip:Dump(), "Left click") T.has(tip:Dump(), "Profile: Arms")
        env.EasyGear_OnAddonCompartmentLeave()
        T.eq(tip.__shown, false)
    end)

    T.test("options: the TOC names exist as functions", function()
        local toc = io.open(T.dir .. "/EasyGear.toc"):read("*a")
        local W = world()
        for field, fname in toc:gmatch("## (AddonCompartmentFunc[%w]*):%s*([%w_]+)") do
            T.eq(type(W.env[fname]), "function", field)
        end
        T.has(toc, "## SavedVariables: EasyGearDB")
        T.has(toc, "## SavedVariablesPerCharacter: EasyGearCharDB")
    end)

    T.test("options: without a settings interface the addon still starts and says so", function()
        local W = world(nil, { noSettings = true })
        T.eq(W.EG.hookStatus.settings.ok, false)
        W.clearChat()
        T.eq(W.EG.Options.Open(), false)
        T.has(W.chatText(), "settings page is not available")
    end)

    T.test("options: only values that changed elsewhere reach an open page - without a loop or a click for every setting", function()
        local W = world()
        W.state.settingsOpen = true
        local s = W.state.settingByVariable
        local function told()
            local names = {}
            for var, st in pairs(s) do if (st.notified or 0) > 0 then names[#names + 1] = var .. "=" .. st.notified end end
            table.sort(names)
            return table.concat(names, " ")
        end
        local calls = 0
        W.EG:Listen("INVALIDATED", function() calls = calls + 1 end)

        W.slash("ilvl 0.9")
        T.eq(calls, 1, "one invalidation - the notification of the page started no second one")
        T.eq(told(), "EasyGear_ilvlWeight=1", "only the changed setting is told (a checkbox would click)")
        T.eq(s.EasyGear_ilvlWeight:GetValue(), 0.9)

        -- a change on the page itself tells nobody: the control shows it already
        calls = 0
        s.EasyGear_showBagIcons:SetValue(false)
        T.eq(calls, 1)
        T.eq(W.env.EasyGearDB.showBagIcons, false)
        T.eq(told(), "EasyGear_ilvlWeight=1", "no one was told about the page's own change")
        W.slash("icons on")
        T.eq(told(), "EasyGear_ilvlWeight=1 EasyGear_showBagIcons=1", "but a chat command is")

        -- the reset tells exactly those that differ from what the page shows
        W.slash("tooltip off")
        W.slash("reset")
        T.eq(s.EasyGear_showTooltip:GetValue(), true) T.eq(s.EasyGear_ilvlWeight:GetValue(), 0.5)
        T.eq(s.EasyGear_showTooltip.notified, 2, "off by command, back by reset") T.eq(s.EasyGear_ilvlWeight.notified, 2)
        T.eq(s.EasyGear_showBagIcons.notified, 1, "already back on: the reset did not touch it")
        T.eq(s.EasyGear_tooltipDiff.notified, nil, "unchanged settings stay untouched")
    end)

    T.test("options: the profile follows changes made elsewhere, not the page's own choice", function()
        local W = world()
        W.state.settingsOpen = true
        local p = W.state.settingByVariable.EasyGear_PROFILE
        p:SetValue("WARRIOR_FURY")
        T.eq(W.EG.Profiles.ActiveID(), "WARRIOR_FURY") T.eq(p.notified, nil, "own choice")
        W.slash("profile warrior_prot")
        T.eq(p.notified, 1) T.eq(p:GetValue(), "WARRIOR_PROT")
        W.slash("profile warrior_prot")
        T.eq(p.notified, 1, "nothing changed, nobody is told")
    end)

    T.test("options: a control that adjusts the value (a slider snapping to its step) is taken over and evaluated", function()
        local W = world()
        W.state.settingsOpen = true
        local slider = W.state.settingByVariable.EasyGear_ilvlWeight
        slider:SetValueChangedCallback(function(setting, v)
            local snapped = math.floor(v / 0.05 + 0.5) * 0.05
            if math.abs(snapped - v) > 1e-9 then setting:SetValue(snapped) end
        end)
        local calls = 0
        W.EG:Listen("INVALIDATED", function() calls = calls + 1 end)
        W.slash("ilvl 0.73")
        T.near(W.EG:Get("ilvlWeight"), 0.75, 1e-9, "the control's value stands")
        T.eq(calls, 2, "evaluated once more with the adjusted value")
        -- ilvl 30 x 0.75 + 20 STR x 1 + 20 STA x 0.1 + 300 armor x 0.025 = 22.5 + 20 + 2 + 7.5
        T.near(W.EG.Score.OfLink(W.I.chest), 52, 1e-9)
    end)

    T.test("options: the slider ranges are the ranges of the chat commands", function()
        local W = world()
        local ranges = W.EG.RANGES
        local sliders = {}
        for _, c in ipairs(category(W).controls) do if c.kind == "slider" then sliders[#sliders + 1] = c end end
        T.eq(sliders[1].options.minValue, ranges.ilvlWeight[1]) T.eq(sliders[1].options.maxValue, ranges.ilvlWeight[2])
        T.eq(sliders[2].options.minValue, ranges.minDeltaPercent[1]) T.eq(sliders[2].options.maxValue, ranges.minDeltaPercent[2])
        for _, cmd in ipairs({ { "ilvl", "ilvlWeight" }, { "mindeltapct", "minDeltaPercent" } }) do
            local hi = ranges[cmd[2]][2]
            W.slash(cmd[1] .. " " .. hi)
            T.eq(W.EG:Get(cmd[2]), hi, cmd[1] .. " accepts the slider maximum")
            W.slash(cmd[1] .. " " .. (hi + 0.5))
            T.eq(W.EG:Get(cmd[2]), hi, cmd[1] .. " refuses more than the slider can show")
        end
    end)

    T.test("options: a closed settings window is not bothered", function()
        local W = world()
        W.state.settingsOpen = false
        W.slash("ilvl 0.9")
        W.slash("tooltip off")
        for var, st in pairs(W.state.settingByVariable) do T.eq(st.notified or 0, 0, var) end
    end)
end
