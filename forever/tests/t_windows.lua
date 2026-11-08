-- Window.lua / ProfileWindow.lua: the comparison window and the profile window
return function(T)
    local F = require("fixtures")

    local function world(setup, opts)
        return T.world(F.arms(opts), function(W)
            W.I = F.armsWarrior(W)
            W.I.better = F.gear(W, 8001, "Better Chestplate", "INVTYPE_CHEST", 40, { STR = 30, STA = 40, CRIT = 20 }, { armor = 500, minLevel = 35 })
            W.I.ring = F.gear(W, 8002, "Good Ring", "INVTYPE_FINGER", 40, { STR = 20, HIT = 15 }, { typeText = "" })
            if setup then setup(W) end
        end)
    end

    ------------------------------------------------------------------ comparison window
    T.test("window: opening builds the frame from the Forever templates", function()
        local W = world()
        W.EG.Window.Open()
        local f = W.env.EasyGearWindow
        T.ok(f, "frame") T.eq(f:IsShown(), true) T.eq(f.__template, "ButtonFrameTemplate")
        T.eq(f.__title, W.EG.L.TITLE)
        T.eq(f.cand.button.__kind, "ItemButton", "item buttons are ItemButton frames")
        T.ok(W.env.UISpecialFrames[1] == "EasyGearWindow", "closes with Escape")
        W.EG.Window.Toggle()
        T.eq(f:IsShown(), false)
    end)

    T.test("window: an item shows score, rows, verdict and the worn item", function()
        local W = world()
        W.EG.Window.SetItem(W.I.better)
        local f = W.env.EasyGearWindow
        T.eq(f.cand.name:GetText(), "Better Chestplate")
        T.has(f.cand.score:GetText(), "81.5")
        T.eq(f.eq.name:GetText(), "Worn Chestplate")
        T.has(f.eq.score:GetText(), "44.5")
        T.has(f.verdict:GetText(), "UPGRADE") T.has(f.verdict:GetText(), "+37")
        T.eq(f.cand.rows[1].label:GetText(), W.EG.L.BASE_ILVL)
        T.eq(f.cand.rows[2].label:GetText(), "Strength")
        T.eq(f.tab1:IsShown(), false)
        T.has(f.profileText:GetText(), "Arms")
    end)

    T.test("window: rings offer both slots on tabs", function()
        local W = world()
        W.EG.Window.SetItem(W.I.ring)
        local f = W.env.EasyGearWindow
        T.eq(f.tab1:IsShown(), true) T.eq(f.tab2:IsShown(), true)
        T.eq(f.tab1:GetText(), "Finger 1") T.eq(f.tab2:GetText(), "Finger 2")
        T.eq(f.eq.name:GetText(), "Copper Band")
        f.tab2.__scripts.OnClick(f.tab2)
        T.eq(f.eq.name:GetText(), "Plain Ring")
    end)

    T.test("window: unusable and level-limited items say so", function()
        local W = world()
        local robe = F.gear(W, 8003, "Robe", "INVTYPE_CHEST", 90, { INT = 100 }, { badType = true, typeText = "Cloth" })
        W.EG.Window.SetItem(robe)
        local f = W.env.EasyGearWindow
        T.has(f.verdict:GetText(), "NOT USABLE")
        local late = F.gear(W, 8004, "Late", "INVTYPE_CHEST", 90, { STR = 100 }, { minLevel = 65 })
        W.EG.Window.SetItem(late)
        T.has(f.verdict:GetText(), "UPGRADE from level 65")
    end)

    T.test("window: items that are not compared and empty states", function()
        local W = world()
        local tabard = F.gear(W, 8005, "Tabard", "INVTYPE_TABARD", 1, {})
        W.EG.Window.SetItem(tabard)
        local f = W.env.EasyGearWindow
        T.has(f.verdict:GetText(), "not compared")
        W.EG.Window.Clear()
        T.eq(f.cand.name:GetText(), W.EG.L.DROP_HINT) T.eq(f.verdict:GetText(), "")
        T.eq(W.EG.Window.SetItem(nil), false)
        W.EG.Window.SetItem(F.gear(W, 8006, "Slow", "INVTYPE_CHEST", 40, { STR = 1 }, { uncached = true }))
        T.eq(f.cand.name:GetText(), W.EG.L.ITEM_LOADING)
    end)

    T.test("window: dropping an item from the cursor and shift-clicking an item", function()
        local W = world()
        W.EG.Window.Open()
        local f = W.env.EasyGearWindow
        W.state.cursor = { id = 8001, link = W.I.better }
        f.cand.button.__scripts.OnReceiveDrag(f.cand.button)
        T.eq(f.cand.name:GetText(), "Better Chestplate") T.eq(W.state.cursor, nil)

        W.EG.Window.Clear()
        W.state.shift = false
        W.env.HandleModifiedItemClick(W.I.better)
        T.eq(f.cand.name:GetText(), W.EG.L.DROP_HINT, "only with shift")
        W.state.shift = true
        W.env.HandleModifiedItemClick(W.I.better)
        T.eq(f.cand.name:GetText(), "Better Chestplate")
        f:Hide()
        W.EG.Window.Clear()
        W.env.HandleModifiedItemClick(W.I.ring)
        T.eq(f:IsShown(), false, "a closed window stays closed")
    end)

    T.test("window: refresh follows profile changes, position and scale are stored", function()
        local W = world()
        W.EG.Window.SetItem(W.I.better)
        local f = W.env.EasyGearWindow
        W.EG.Profiles.SetActive("WARRIOR_PROT")
        T.has(f.profileText:GetText(), "Protection")
        f.__scripts.OnDragStop(f)
        T.eq(W.env.EasyGearCharDB.gui.point, "CENTER")
        W.slash("scale 1.5")
        T.eq(f.__scale, 1.5)
        W.slash("reset")
        T.eq(f.__scale, 1)
    end)

    T.test("window: buttons print to chat, clear and open the profile window", function()
        local W = world()
        W.EG.Window.SetItem(W.I.better)
        local f = W.env.EasyGearWindow
        W.clearChat()
        f.btnChat.__scripts.OnClick(f.btnChat)
        T.has(W.chatText(), "Better Chestplate") T.has(W.chatText(), "UPGRADE")
        f.btnProfiles.__scripts.OnClick(f.btnProfiles)
        T.eq(W.EG.ProfileWindow.IsShown(), true)
        f.btnClear.__scripts.OnClick(f.btnClear)
        T.eq(W.EG.Window.Link(), nil)
    end)

    ------------------------------------------------------------------ profile window
    local function profileWindow(W)
        W.EG.ProfileWindow.Open()
        return W.env.EasyGearProfileWindow
    end
    local function radios(dd)
        local out = {}
        for _, e in ipairs(dd.__menu.entries) do if e.kind == "radio" then out[#out + 1] = e.text end end
        return out
    end

    T.test("profile window: builds with menus for class and profile", function()
        local W = world()
        local f = profileWindow(W)
        T.eq(f.__template, "ButtonFrameTemplate")
        T.eq(f.classDD.__kind, "DropdownButton")
        local classes = radios(f.classDD)
        T.eq(#classes, 9) T.eq(classes[1], "My class (Warrior)")
        T.eq(f.classDD:SelectedText(), "My class (Warrior)")
        local profiles = radios(f.profDD)
        T.eq(#profiles, 5 + 2, "five warrior profiles plus the two general ones")
        T.eq(f.profDD.__menu.scroll, 320)
        -- the default comparison profile is one other than the active one
        T.ok(f.profDD:SelectedText() ~= "Arms (two-hand)")
    end)

    T.test("profile window: both sides share their rows, totals and verdict", function()
        local W = world()
        local f = profileWindow(W)
        W.EG.ProfileWindow.Select("WARRIOR_PROT")
        T.eq(f.left.title:GetText(), "Protection (tank)")
        T.eq(f.right.title:GetText(), "Arms (two-hand) (Automatic)")
        T.eq(f.left.rows[1].label:GetText(), W.EG.L.BASE_ILVL)
        T.eq(f.left.rows[1].label:GetText(), f.right.rows[1].label:GetText(), "rows line up")
        T.eq(f.left.rows[1].value:GetText(), f.right.rows[1].value:GetText(), "same gear on both sides")
        T.eq(f.right.totalValue:GetText(), "302", "301.5 is shown rounded, as scores of 100 and more are")
        T.ok(f.left.totalValue:GetText() ~= "302")
        T.has(f.verdict:GetText(), "Difference")
        T.eq(f.btnActivate:IsEnabled(), true)
        T.eq(f.btnAuto:IsEnabled(), false, "already automatic")
        T.eq(f.btnDelete:IsEnabled(), false, "built-in profiles cannot be deleted")
        T.eq(f.btnSave:IsEnabled(), false)
    end)

    T.test("profile window: choosing the active profile says so", function()
        local W = world()
        local f = profileWindow(W)
        W.EG.ProfileWindow.Select("WARRIOR_ARMS")
        T.has(f.verdict:GetText(), "already the active profile")
        T.eq(f.btnActivate:IsEnabled(), false)
    end)

    T.test("profile window: picking from the menus", function()
        local W = world()
        local f = profileWindow(W)
        T.eq(f.classDD:ChooseRadio("Mage"), true)
        T.eq(f.profDD:SelectedText() ~= nil, true)
        local list = radios(f.profDD)
        T.ok(list[1]:find("Arcane", 1, true), "mage profiles after the class change")
        T.eq(f.profDD:ChooseRadio("Fire"), true)
        T.eq(f.left.title:GetText(), "Fire")
        T.eq(f.profDD:SelectedText(), "Fire")
    end)

    T.test("profile window: activate and automatic", function()
        local W = world()
        local f = profileWindow(W)
        W.EG.ProfileWindow.Select("WARRIOR_PROT")
        W.clearChat()
        f.btnActivate.__scripts.OnClick(f.btnActivate)
        T.eq(W.EG.Profiles.ActiveID(), "WARRIOR_PROT")
        T.has(W.chatText(), "Active profile: Protection (tank)")
        T.eq(f.btnAuto:IsEnabled(), true)
        f.btnAuto.__scripts.OnClick(f.btnAuto)
        T.eq(W.EG.Profiles.ActiveID(), "AUTO")
    end)

    T.test("profile window: edit, save as a new profile, overwrite, rename, delete", function()
        local W = world()
        local PW, P = W.EG.ProfileWindow, W.EG.Profiles
        local f = profileWindow(W)
        PW.Select("WARRIOR_FURY")
        f.btnEdit.__scripts.OnClick(f.btnEdit)
        T.eq(f.btnEdit:GetText(), W.EG.L.BTN_CANCEL)
        T.eq(f.btnSaveNew:IsEnabled(), true) T.eq(f.btnSave:IsEnabled(), false, "built-in cannot be overwritten")
        -- every attribute row is editable, the item level row is fixed
        local str
        for _, row in ipairs(f.left.rows) do
            if row.label:GetText() == "Strength" then str = row end
        end
        T.ok(str and str.edit:IsShown(), "edit box for Strength")
        str.edit:SetText("2,5")
        str.edit.__scripts.OnEditFocusLost(str.edit)
        T.ok(f.left.totalValue:GetText() ~= f.right.totalValue:GetText())

        local before = f.left.totalValue:GetText()
        f.btnSaveNew.__scripts.OnClick(f.btnSaveNew)
        local dlg = W.state.popups[#W.state.popups]
        T.eq(dlg.which, "GENERIC_INPUT_BOX")
        T.eq(dlg.data.text, W.EG.L.P_NEW_PROMPT)
        T.eq(dlg.GetEditBox(dlg):GetText(), "Fury (dual wield) 2", "suggested name")
        dlg.data.callback("Hard Hitter")
        local id = "CUSTOM_HardHitter"
        T.ok(P.Get(id), "created")
        T.eq(P.Get(id).weights.STR, 2.5) T.eq(P.Get(id).weights.HIT, 1.2, "copied from Fury")
        T.eq(f.left.title:GetText(), "Hard Hitter")
        T.eq(f.btnDelete:IsEnabled(), true)
        T.eq(f.btnEdit:GetText(), W.EG.L.P_EDIT, "edit mode ended")

        -- overwrite
        f.btnEdit.__scripts.OnClick(f.btnEdit)
        T.eq(f.btnSave:IsEnabled(), true)
        T.eq(f.nameBox:IsShown(), true) T.eq(f.nameBox:GetText(), "Hard Hitter")
        f.nameBox:SetText("Harder Hitter")
        for _, row in ipairs(f.left.rows) do
            if row.label:GetText() == "Strength" then row.edit:SetText("3") row.edit.__scripts.OnEditFocusLost(row.edit) end
        end
        f.btnSave.__scripts.OnClick(f.btnSave)
        T.eq(P.Get(id).weights.STR, 3) T.eq(P.Name(P.Get(id)), "Harder Hitter")
        T.eq(f.btnEdit:GetText(), W.EG.L.P_EDIT)

        -- delete with confirmation
        f.btnDelete.__scripts.OnClick(f.btnDelete)
        dlg = W.state.popups[#W.state.popups]
        T.eq(dlg.which, "GENERIC_CONFIRMATION")
        T.eq(dlg.data.text, W.EG.L.P_DELETE_PROMPT, "the client formats this text with the argument")
        T.eq(dlg.data.text_arg1, "Harder Hitter")
        T.ok(P.Get(id), "still there until confirmed")
        dlg.data.callback()
        T.eq(P.Get(id), nil)
    end)

    T.test("profile window: saving a built-in profile in place is refused politely", function()
        local W = world()
        local PW = W.EG.ProfileWindow
        profileWindow(W)
        PW.Select("WARRIOR_FURY")
        W.clearChat()
        PW.SaveOver()
        T.has(W.chatText(), "Only your own profiles can be edited")
        PW.ToggleEdit()
        PW.ApplyEdit("STR", "7")
        W.clearChat()
        PW.SaveOver()
        T.has(W.chatText(), "Only your own profiles can be edited", "also while editing")
        T.eq(next(W.env.EasyGearDB.custom), nil, "nothing was created or changed")
    end)

    T.test("profile window: cancelling an edit drops the draft", function()
        local W = world()
        local f = profileWindow(W)
        W.EG.ProfileWindow.Select("WARRIOR_FURY")
        f.btnEdit.__scripts.OnClick(f.btnEdit)
        W.EG.ProfileWindow.ApplyEdit("STR", "9")
        f.btnEdit.__scripts.OnClick(f.btnEdit)
        T.eq(f.btnEdit:GetText(), W.EG.L.P_EDIT)
        T.eq(W.EG.Specs.BY_ID.WARRIOR_FURY.w.STR, 1.0, "built-in weights are untouched")
    end)

    T.test("profile window: active custom profile changes show up right away", function()
        local W = world()
        local PW, P = W.EG.ProfileWindow, W.EG.Profiles
        local f = profileWindow(W)
        local id = P.CreateCustom("Mine", "WARRIOR_ARMS")
        P.SetActive(id)
        PW.Rebuild()
        local before = f.right.totalValue:GetText()
        P.SetCustomWeight(id, "STR", 5)
        T.ok(f.right.totalValue:GetText() ~= before, "total follows the weights")
    end)

    T.test("profile window: scrolling the rows", function()
        local W = world()
        local PW = W.EG.ProfileWindow
        local f = profileWindow(W)
        PW.Select("WARRIOR_FURY")
        PW.ToggleEdit()
        local first = f.left.rows[1].label:GetText()
        PW.Scroll(3)
        T.eq(f.left.rows[1].label:GetText() ~= first, true)
        PW.Scroll(-100)
        T.eq(f.left.rows[1].label:GetText(), first)
        PW.Scroll(1000)
        T.ok(f.left.rows[1].label:GetText() ~= first)
        T.ok(f.left.rows[18].label:GetText() ~= "", "scrolling stops when the last row is in view")
    end)

    T.test("profile window: without the menu template buttons cycle through the choices", function()
        local W = world(nil, { noDropdown = true })
        local f = profileWindow(W)
        T.eq(f.classDD.__kind, "Button")
        local before = f.left.title:GetText()
        f.profDD.__scripts.OnClick(f.profDD, "LeftButton")
        T.ok(f.left.title:GetText() ~= before, "next profile")
        f.classDD.__scripts.OnClick(f.classDD, "LeftButton")
        T.eq(f.classDD:GetText(), "Paladin")
        f.classDD.__scripts.OnClick(f.classDD, "RightButton")
        T.eq(f.classDD:GetText(), "Warrior")
    end)

    T.test("profile window: without popups the actions happen directly", function()
        local W = world()
        local f = profileWindow(W)
        W.env.StaticPopup_Show = nil
        W.env.StaticPopup_ShowCustomGenericConfirmation = nil
        W.EG.ProfileWindow.Select("WARRIOR_FURY")
        f.btnSaveNew.__scripts.OnClick(f.btnSaveNew)
        local custom
        for id in pairs(W.env.EasyGearDB.custom) do custom = id end
        T.ok(custom, "created without asking")
        f.btnDelete.__scripts.OnClick(f.btnDelete)
        T.eq(W.env.EasyGearDB.custom[custom], nil, "deleted without asking")
    end)

    T.test("profile window: the item of the comparison window is scored under both profiles", function()
        local W = world()
        local f = profileWindow(W)
        W.EG.Window.SetItem(W.I.better)
        W.EG.ProfileWindow.Select("WARRIOR_PROT")
        T.has(f.note:GetText(), W.EG.L.P_ITEM_LINE)
    end)

    T.test("window: an item whose worn counterpart is still loading shows the loading text, not an error", function()
        local W = world()
        W.state.items[2001].uncached = true                 -- the worn chestplate
        W.EG.Items.Wipe()
        W.EG.Window.SetItem(W.I.better)
        local f = W.env.EasyGearWindow
        T.eq(f.cand.name:GetText(), W.EG.L.ITEM_LOADING)
        T.eq(f.verdict:GetText(), "")
        T.eq(W.EG.lastError, nil, "no error")
        W.state.items[2001].uncached = nil
        W.fire("GET_ITEM_INFO_RECEIVED", 2001, true)
        W.flush()
        T.eq(f.cand.name:GetText(), "Better Chestplate", "the next refresh fills it in")
        T.eq(W.EG.lastError, nil)
    end)

    T.test("window: an item the client does not know says so after the client gave up", function()
        local W = world()
        W.EG.Window.SetItem(88888)
        local f = W.env.EasyGearWindow
        T.eq(f.cand.name:GetText(), W.EG.L.ITEM_LOADING)
        W.fire("GET_ITEM_INFO_RECEIVED", 88888, false)
        W.flush()
        T.eq(f.cand.name:GetText(), W.EG.L.INVALID_ITEM, "the window follows without being touched")
    end)

    T.test("window: only items are accepted - numbers, item strings and links, not spells or junk", function()
        local W = world()
        local Wd = W.EG.Window
        T.eq(Wd.SetItem("garbage"), false) T.eq(Wd.SetItem(0), false) T.eq(Wd.SetItem(-3), false)
        T.eq(Wd.SetItem({}), false) T.eq(Wd.SetItem("|cff71d5ff|Hspell:133|h[Fireball]|h|r"), false)
        T.eq(Wd.Link(), nil)
        T.eq(Wd.SetItem("item:8001"), true)
        T.eq(W.env.EasyGearWindow.cand.name:GetText(), "Better Chestplate")
        T.eq(Wd.SetItem(8001), true) T.eq(Wd.SetItem(W.I.better), true)
        -- shift-clicking other kinds of links leaves the window alone
        Wd.Clear()
        W.state.shift = true
        W.env.HandleModifiedItemClick("|cff71d5ff|Hspell:133|h[Fireball]|h|r")
        W.env.HandleModifiedItemClick("|cffffff00|Hquest:1234:80|h[A Quest]|h|r")
        W.env.HandleModifiedItemClick(nil)
        T.eq(W.env.EasyGearWindow.cand.name:GetText(), W.EG.L.DROP_HINT)
        T.eq(W.EG.lastError, nil)
    end)

    T.test("window: script errors are caught and reported once", function()
        local W = world()
        W.EG.Window.SetItem(W.I.better)
        local f = W.env.EasyGearWindow
        W.env.GameTooltip.SetHyperlink = function() error("boom") end
        W.clearChat()
        T.eq(pcall(f.cand.button.__scripts.OnEnter, f.cand.button), true, "the script itself does not raise")
        T.eq(W.EG.lastError.label, "window")
        T.has(W.chatText(), "boom")
        W.clearChat()
        pcall(f.cand.button.__scripts.OnEnter, f.cand.button)
        T.eq(W.chatText(), "", "the same message is not repeated")
    end)

    T.test("window: item names stay on one line, hints may wrap", function()
        local W = world()
        W.EG.Window.SetItem(W.I.better)
        local f = W.env.EasyGearWindow
        T.eq(f.cand.name.__wordWrap, false, "an item name") T.eq(f.eq.name.__wordWrap, false)
        T.eq(f.cand.info.__wordWrap, false)
        W.EG.Window.Clear()
        T.eq(f.cand.name.__wordWrap, true, "the hint")
    end)

    T.test("profile window: a profile name with a percent sign cannot break the delete prompt", function()
        local W = world()
        local PW, P = W.EG.ProfileWindow, W.EG.Profiles
        local f = profileWindow(W)
        local id = P.CreateCustom("50% Crit", "WARRIOR_ARMS")
        PW.Select(id)
        f.btnDelete.__scripts.OnClick(f.btnDelete)
        local dlg = W.state.popups[#W.state.popups]
        local ok, text = pcall(string.format, dlg.data.text, dlg.data.text_arg1, dlg.data.text_arg2)
        T.eq(ok, true, "the client formats the text with the arguments")
        T.has(text, "50% Crit")
        dlg.data.callback()
        T.eq(P.Get(id), nil)
    end)

    T.test("profile window: weight input ignores nonsense, empty clears", function()
        local W = world()
        local PW, P = W.EG.ProfileWindow, W.EG.Profiles
        profileWindow(W)
        local id = P.CreateCustom("Mine", "WARRIOR_ARMS")
        PW.Select(id)
        local before = P.Get(id).weights.STR
        T.ok(before and before > 0)
        PW.ToggleEdit()
        for _, junk in ipairs({ "abc", "nan", "inf", "-inf", "1..2" }) do PW.ApplyEdit("STR", junk) end
        PW.SaveOver()
        T.eq(P.Get(id).weights.STR, before, "nonsense keeps the old weight")
        PW.ToggleEdit()
        PW.ApplyEdit("STR", "  ")
        PW.SaveOver()
        T.eq(P.Get(id).weights.STR, nil, "empty removes the weight")
        PW.ToggleEdit()
        PW.ApplyEdit("STR", "1,25")
        PW.SaveOver()
        T.eq(P.Get(id).weights.STR, 1.25)
    end)
end
