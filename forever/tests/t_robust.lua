-- Missing pieces of the client, events, saved variables and error containment
return function(T)
    local F = require("fixtures")

    T.test("robust: without the tooltip processor the rest works and the status says so", function()
        local W = T.world(F.arms({ noTooltipProcessor = true }), function(w) w.I = F.armsWarrior(w) end)
        T.eq(W.EG.hookStatus.tooltip.ok, false)
        T.has(W.EG.hookStatus.tooltip.note, "TooltipDataProcessor")
        local b = W.bagButton(0, 1)
        local better = F.gear(W, 9801, "Better", "INVTYPE_CHEST", 40, { STR = 30 }, { armor = 500 })
        W.env.SetItemButtonQuality(b, 3, better)
        T.eq(b.EasyGearArrow:IsShown(), true)
    end)

    T.test("robust: a missing Blizzard function is reported, not fatal", function()
        local W = T.Mock.new(F.arms())
        W.load(T.dir)
        W.env.MerchantFrameItem_UpdateQuality = nil
        W.boot()
        T.eq(W.EG.hookStatus.merchant.ok, false)
        T.has(W.EG.hookStatus.merchant.note, "MerchantFrameItem_UpdateQuality")
        T.eq(W.EG.hookStatus.itembuttons.ok, true)
    end)

    T.test("robust: a missing part of the interface is announced at login, a complete one is not", function()
        local W = T.Mock.new(F.arms())
        W.load(T.dir)
        W.env.GroupLootFrame_SetupItemDisplay = nil
        W.boot()
        T.has(W.chatText(), "Some parts of the game interface were not found")
        local ok = T.world()
        T.hasnt(ok.chatText(), "were not found")
    end)

    T.test("robust: another client is announced once at login", function()
        local W = T.Mock.new(F.arms({ notForever = true }))
        W.load(T.dir)
        W.boot()
        T.has(W.chatText(), "does not look like the WoW Forever client")
        T.eq(W.EG.isForever, false)
        local ok = T.world()
        T.hasnt(ok.chatText(), "WoW Forever client")
    end)

    T.test("robust: without tooltip data the API values still score an item", function()
        local W = T.world(F.arms(), function(w) w.I = F.armsWarrior(w) end)
        W.env.C_TooltipInfo = nil
        W.EG.Items.Wipe()
        local item = W.EG.Items.Get(W.I.chest)
        T.eq(item.stats.STR, 20)
        T.near(W.EG.Score.OfLink(W.I.chest), 44.5)
    end)

    T.test("robust: item data errors do not escape", function()
        local W = T.world(F.arms(), function(w) w.I = F.armsWarrior(w) end)
        W.env.C_Item.GetItemStats = function() error("client hiccup") end
        W.EG.Items.Wipe()
        local item = W.EG.Items.Get(W.I.chest)
        T.ok(item, "still produces an item from the tooltip lines")
    end)

    T.test("robust: events are debounced into one recalculation", function()
        local W = T.world(F.arms(), function(w) w.I = F.armsWarrior(w) end)
        local count = 0
        W.EG:Listen("INVALIDATED", function() count = count + 1 end)
        for _ = 1, 10 do W.fire("PLAYER_EQUIPMENT_CHANGED", 5) end
        W.flush()
        T.eq(count, 1)
    end)

    T.test("robust: Debounce waits for quiet - a repeated call pushes the run back", function()
        local W = T.world(F.arms())
        local runs = 0
        W.EG:Debounce("probe", 0.2, function() runs = runs + 1 end)
        W.advance(0.1)
        W.EG:Debounce("probe", 0.2, function() runs = runs + 1 end)
        W.advance(0.15)
        T.eq(runs, 0, "0.25 s in: the second call restarted the wait")
        W.advance(0.2)
        T.eq(runs, 1, "one run for both calls")
        W.EG:Debounce("probe", 0.2, function() runs = runs + 1 end)
        W.flush()
        T.eq(runs, 2, "a later call starts a new cycle")
    end)

    T.test("robust: leveling up switches the profile and refreshes the data", function()
        local W = T.world(F.arms({ level = 59 }), function(w) w.I = F.armsWarrior(w) end)
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_LEVELING")
        W.setLevel(60)
        W.flush()
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_ARMS")
    end)

    T.test("robust: saved variables from an older run are completed, not replaced", function()
        local W = T.world(F.arms(), function(w)
            w.env.EasyGearDB = { showTooltip = false, custom = { X = { id = "X", custom = true, weights = {} } }, legacy = 1 }
            w.env.EasyGearCharDB = { profile = "WARRIOR_PROT" }
        end)
        T.eq(W.EG:Get("showTooltip"), false)
        T.eq(W.EG:Get("showBagIcons"), true, "missing keys get their defaults")
        T.eq(W.env.EasyGearDB.legacy, 1)
        T.ok(W.env.EasyGearDB.custom.X)
        T.eq(W.env.EasyGearCharDB.profile, "WARRIOR_PROT")
        T.eq(W.env.EasyGearCharDB.gui.point, "CENTER")
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_PROT")
    end)

    T.test("robust: broken saved variables are replaced by clean tables", function()
        local W = T.world(F.arms(), function(w) w.env.EasyGearDB = "garbage" w.env.EasyGearCharDB = 5 end)
        T.eq(type(W.env.EasyGearDB), "table") T.eq(type(W.env.EasyGearCharDB), "table")
        T.eq(W.EG:Get("showTooltip"), true)
    end)

    T.test("robust: errors in event handlers and timers are contained and reported once", function()
        local W = T.world(F.arms())
        local calls = 0
        W.EG:On("BAG_UPDATE", function() calls = calls + 1 error("handler bug") end)
        W.fire("BAG_UPDATE") W.fire("BAG_UPDATE")
        T.eq(calls, 2)
        T.has(tostring(W.EG.lastError.err), "handler bug")
        W.EG:After(0.1, function() error("timer bug") end)
        W.flush()
        T.has(tostring(W.EG.lastError.err), "timer bug")
        W.EG:Fire("NOBODY_LISTENS")
    end)

    T.test("robust: a contained error is printed once per distinct message, then only remembered", function()
        local W = T.world(F.arms())
        W.clearChat()
        for _ = 1, 3 do W.EG:Try("probe", function() error("noisy") end) end
        local _, count = W.chatText():gsub("noisy", "")
        T.eq(count, 1, "printed once")
        T.has(W.chatText(), "EasyGear[probe]")
        W.EG:Try("probe", function() error("another") end)
        T.has(W.chatText(), "another")
        T.has(tostring(W.EG.lastError.err), "another")
        W.clearChat()
        W.EG:Try("probe", function() error(string.rep("x", 1000)) end)
        T.ok(#W.chatText() < 600, "long messages are cut")
    end)

    T.test("robust: formatting helpers", function()
        local W = T.world()
        local EG = W.EG
        T.eq(EG.FmtScore(81.5), "81.5") T.eq(EG.FmtScore(120.4), "120") T.eq(EG.FmtScore(7), "7") T.eq(EG.FmtScore(nil), "0")
        T.eq(EG.FmtSigned(5), "+5") T.eq(EG.FmtSigned(-2.5), "-2.5") T.eq(EG.FmtSigned(0), "+0")
        T.eq(EG.FmtPct(12.34), "+12.3%") T.eq(EG.FmtPct(-1), "-1.0%")
        T.eq(EG.FmtWeight(0.025), "0.025") T.eq(EG.FmtWeight(1), "1") T.eq(EG.FmtWeight(10), "10")
        T.eq(EG.FmtWeight(0.5), "0.5") T.eq(EG.FmtWeight(nil), "0") T.eq(EG.FmtWeight(1.2), "1.2")
        T.eq(EG.Trim("  a b  "), "a b") T.eq(EG.Trim(nil), "")
    end)

    T.test("robust: nothing in the addon touches Blizzard globals it should not set", function()
        local allowed = { EasyGear = true, EasyGearDB = true, EasyGearCharDB = true, EasyGearLocales = true,
                          SLASH_EASYGEAR1 = true, SLASH_EASYGEAR2 = true, SLASH_EASYGEARGUI1 = true,
                          SLASH_EASYGEARPROFILE1 = true, SLASH_EASYGEARPROFILE2 = true,
                          EasyGear_OnAddonCompartmentClick = true, EasyGear_OnAddonCompartmentEnter = true,
                          EasyGear_OnAddonCompartmentLeave = true, EasyGearWindow = true, EasyGearProfileWindow = true }
        local fresh = T.Mock.new(F.arms())
        local before = {}
        for k in pairs(fresh.env) do before[k] = true end
        fresh.load(T.dir) fresh.boot()
        fresh.EG.Window.Open() fresh.EG.ProfileWindow.Open()
        local extra = {}
        for k in pairs(fresh.env) do
            if not before[k] and not allowed[k] then extra[#extra + 1] = tostring(k) end
        end
        table.sort(extra)
        T.eq(table.concat(extra, ","), "", "unexpected new globals")
    end)
end
