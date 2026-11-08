-- Tooltip.lua: lines in item tooltips
return function(T)
    local F = require("fixtures")
    local LINE, COLOR = T.Mock.LINE, T.Mock.COLOR

    local function world(setup)
        return T.world(F.ARMS, function(W)
            W.I = F.armsWarrior(W)
            W.I.better = F.gear(W, 6001, "Better Chestplate", "INVTYPE_CHEST", 40, { STR = 30, STA = 40, CRIT = 20 }, { armor = 500, minLevel = 35 })
            if setup then setup(W) end
        end)
    end

    T.test("tooltip: full comparison for an item in the bags", function()
        local W = world()
        local tip = W.tooltipFor(W.bagButton(0, 1), W.I.better)
        local text = tip:Dump()
        T.has(text, "EasyGear | Score: 81.5")
        T.has(text, "Chest | 44.5", "slot and worn score")
        T.has(text, "UPGRADE | +37  (+83.1%)")
        T.has(text, "+20 Critical Strike") T.has(text, "+10 Strength") T.has(text, "+200 Armor") T.has(text, "+20 Stamina")
        T.eq(tip.__shown, true)
    end)

    T.test("tooltip: the worn item shows only its score, also for rings and trinkets", function()
        local W = world()
        for _, def in ipairs({ { "CharacterChestSlot", 5, W.I.chest, "44.5" }, { "CharacterFinger0Slot", 11, W.I.ring1, "32.5" },
                               { "CharacterTrinket0Slot", 13, W.I.trinket, "35" } }) do
            local tip = W.tooltipFor(W.namedButton(def[1], def[2]), def[3])
            T.has(tip:Dump(), "EasyGear | Score: " .. def[4], def[1])
            T.hasnt(tip:Dump(), "UPGRADE", def[1])
            T.hasnt(tip:Dump(), "Chest |", def[1])
        end
    end)

    T.test("tooltip: compare tooltips only show the score", function()
        local W = world()
        local tip = W.env.ShoppingTooltip1
        tip:SetOwner(W.env.GameTooltip, "ANCHOR_NONE")
        W.env.__showItem(tip, W.I.chest)
        T.has(tip:Dump(), "EasyGear | Score: 44.5")
        T.hasnt(tip:Dump(), "UPGRADE")
    end)

    T.test("tooltip: compare tooltips are recognised by their name too", function()
        local W = world()
        local tip = W.env.ShoppingTooltip1
        tip.isShopping = nil
        tip:SetOwner(W.env.GameTooltip, "ANCHOR_NONE")
        W.env.__showItem(tip, W.I.chest)
        T.has(tip:Dump(), "EasyGear | Score: 44.5")
        T.hasnt(tip:Dump(), "UPGRADE", "named ShoppingTooltip1: score only")
    end)

    T.test("tooltip: the addon's own windows do not decorate their tooltips", function()
        local W = world()
        W.EG.Window.SetItem(W.I.better)
        local f = W.env.EasyGearWindow
        local tip = W.env.GameTooltip
        f.cand.button.__scripts.OnEnter(f.cand.button)
        T.hasnt(tip:Dump(), "EasyGear", "owner is a window button")
        T.eq(tip:GetOwner(), f.cand.button)
    end)

    T.test("tooltip: verdicts for no upgrade, unusable, level and empty slot", function()
        local W = world()
        local weak = F.gear(W, 6002, "Weak", "INVTYPE_CHEST", 10, { STR = 1 })
        local tip = W.tooltipFor(W.bagButton(0, 1), weak)
        T.has(tip:Dump(), "NO UPGRADE")
        local robe = F.gear(W, 6003, "Robe", "INVTYPE_CHEST", 90, { INT = 100 }, { badType = true, typeText = "Cloth" })
        tip = W.tooltipFor(W.bagButton(0, 1), robe)
        T.has(tip:Dump(), "NOT USABLE") T.has(tip:Dump(), "Not usable by your class")
        local late = F.gear(W, 6004, "Late", "INVTYPE_CHEST", 90, { STR = 100 }, { minLevel = 65 })
        tip = W.tooltipFor(W.bagButton(0, 1), late)
        T.has(tip:Dump(), "UPGRADE from level 65")
        W.equip(12, nil)
        local ring = F.gear(W, 6005, "Ring", "INVTYPE_FINGER", 10, { STA = 1 }, { typeText = "" })
        tip = W.tooltipFor(W.bagButton(0, 1), ring)
        T.has(tip:Dump(), "UPGRADE (slot empty)")
        T.has(tip:Dump(), "Finger 2 | Slot is empty")
    end)

    T.test("tooltip: settings switch parts off", function()
        local W = world()
        W.EG:Set("tooltipDiff", false)
        local text = W.tooltipFor(W.bagButton(0, 1), W.I.better):Dump()
        T.has(text, "UPGRADE") T.hasnt(text, "+20 Critical Strike")
        W.EG:Set("showTooltipStats", false)
        text = W.tooltipFor(W.bagButton(0, 1), W.I.better):Dump()
        T.hasnt(text, "Chest |")
        W.EG:Set("showTooltip", false)
        text = W.tooltipFor(W.bagButton(0, 1), W.I.better):Dump()
        T.hasnt(text, "EasyGear")
    end)

    T.test("tooltip: items that are not gear get nothing", function()
        local W = world()
        local potion = F.gear(W, 6006, "Potion", "", 1, {})
        T.hasnt(W.tooltipFor(W.bagButton(0, 1), potion):Dump(), "EasyGear")
    end)

    T.test("tooltip: items still loading are skipped without an error", function()
        local W = world()
        local slow = F.gear(W, 6007, "Slow", "INVTYPE_CHEST", 40, { STR = 1 }, { uncached = true })
        local tip = W.tooltipFor(W.bagButton(0, 1), slow, { hyperlink = slow })
        T.hasnt(tip:Dump(), "EasyGear")
    end)

    T.test("tooltip: the link comes from the guid when there is no hyperlink", function()
        local W = world()
        W.env.C_Item.GetItemLinkByGUID = function(guid) return guid == "G1" and W.I.better or nil end
        local tip = W.env.GameTooltip
        tip:SetOwner(W.bagButton(0, 1), "ANCHOR_RIGHT")
        local data = { guid = "G1" }
        for _, pc in ipairs(W.state.postCalls) do pc.fn(tip, data) end
        T.has(tip:Dump(), "UPGRADE")
    end)

    T.test("tooltip: the recommended quest reward carries a line, for gear and for other items", function()
        local W = world()
        local btn = W.namedButton("QuestInfoRewardsFrameQuestInfoItem1", 1)
        W.EG.Marks.Set(btn, W.I.better, { ctx = "quest" })
        W.EG.Marks.SetBest(btn, true, "UPGRADE")
        local text = W.tooltipFor(btn, W.I.better):Dump()
        T.has(text, W.EG.L.QUEST_PICK)
        local potion = F.gear(W, 6008, "Potion", "", 1, {})
        W.EG.Marks.SetBest(btn, true, "VENDOR")
        text = W.tooltipFor(btn, potion):Dump()
        T.has(text, W.EG.L.QUEST_PICK_VENDOR)
        W.EG.Marks.SetBest(btn, false)
        T.hasnt(W.tooltipFor(btn, W.I.better):Dump(), "best choice")
    end)

    T.test("tooltip: a worn slot says when something better waits in the bags", function()
        local W = world(function(w) w.bag(0, 8, { [2] = w.I.better }) end)
        local tip = W.tooltipFor(W.namedButton("CharacterChestSlot", 5), W.I.chest)
        T.has(tip:Dump(), "Better in your bags +37")
        T.has(tip:Dump(), "Better Chestplate")
        local other = W.tooltipFor(W.namedButton("CharacterFinger0Slot", 11), W.I.ring1)
        T.hasnt(other:Dump(), "Better in your bags")
    end)

    T.test("tooltip: gains are green, losses red, no change grey", function()
        local W = world()
        local B = W.EG.Tooltip.BuildLines
        local function verdictColor(link)
            local item = W.EG.Items.Get(link)
            local lines = B(item, W.EG.Score.Compare(item), "FULL")
            for _, l in ipairs(lines) do if l.left == "UPGRADE" or l.left == "NO UPGRADE" then return l.rightColor, l.color end end
        end
        local up = verdictColor(W.I.better)
        T.ok(up[2] > up[1], "green")
        local weak = F.gear(W, 6010, "Weak", "INVTYPE_CHEST", 10, { STR = 1 })
        local down, text = verdictColor(weak)
        T.ok(down[1] > down[2], "red") T.ok(text[1] > text[2], "red text")
        local twin = F.gear(W, 6011, "Twin", "INVTYPE_CHEST", 30, { STR = 20, STA = 20 }, { armor = 300 })
        local same = verdictColor(twin)
        T.near(same[1], same[2], 0.2, "grey")
    end)

    T.test("tooltip: BuildLines is pure and tolerates missing parts", function()
        local W = world()
        local B = W.EG.Tooltip.BuildLines
        T.eq(#B(nil, nil, "FULL"), 0)
        local item = W.EG.Items.Get(W.I.better)
        local lines = B(item, nil, "SCORE")
        T.eq(#lines, 1) T.eq(lines[1].left, "EasyGear")
        local potion = W.EG.Items.Get(F.gear(W, 6009, "P", "", 1, {}))
        T.eq(#B(potion, nil, "FULL"), 0)
        T.eq(#B(potion, nil, "FULL", { pick = "UPGRADE" }), 1)
    end)

    T.test("tooltip: an error inside the handler never reaches the tooltip", function()
        local W = world()
        W.EG.Score.Compare = function() error("boom") end
        local tip = W.tooltipFor(W.bagButton(0, 1), W.I.better)
        T.eq(tip.__shown, true)
        T.ok(W.EG.lastError and tostring(W.EG.lastError.err):find("boom", 1, true))
    end)
end
