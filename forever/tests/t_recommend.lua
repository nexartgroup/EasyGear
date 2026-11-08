-- Recommend.lua: upgrades in the bags, best reward
return function(T)
    local F = require("fixtures")

    local function world(setup)
        return T.world(F.ARMS, function(W)
            W.I = F.armsWarrior(W)
            if setup then setup(W) end
        end)
    end

    T.test("recommend: upgrades in the bags, biggest gain first", function()
        local W = world(function(w)
            w.I.better = F.gear(w, 5001, "Better Chest", "INVTYPE_CHEST", 40, { STR = 30, STA = 40, CRIT = 20 }, { armor = 500 })
            w.I.weak = F.gear(w, 5002, "Weak Chest", "INVTYPE_CHEST", 20, { STR = 5 })
            w.I.ring = F.gear(w, 5003, "Good Ring", "INVTYPE_FINGER", 40, { STR = 20, HIT = 15 }, { typeText = "" })
            w.I.potion = F.gear(w, 5004, "Potion", "", 1, {})
            w.I.robe = F.gear(w, 5005, "Robe", "INVTYPE_CHEST", 99, { INT = 200 }, { badType = true })
            w.bag(0, 16, { [1] = w.I.better, [2] = w.I.weak, [4] = w.I.ring, [5] = w.I.potion, [7] = w.I.robe })
        end)
        local list, pending = W.EG.Recommend.Upgrades(false)
        T.eq(pending, false)
        T.eq(#list, 2)
        T.eq(list[1].link, W.I.ring) T.near(list[1].delta, 40.5) T.eq(list[1].slotID, 12) T.eq(list[1].slot, 4)
        T.eq(list[2].link, W.I.better) T.near(list[2].delta, 37) T.eq(list[2].bag, 0)
    end)

    T.test("recommend: bank tabs count only when asked for", function()
        local W = world(function(w)
            w.I.better = F.gear(w, 5010, "Bank Chest", "INVTYPE_CHEST", 40, { STR = 30 }, { armor = 500 })
            w.bag(6, 28, { [3] = w.I.better })
        end)
        T.eq(#W.EG.Recommend.Upgrades(false), 0)
        T.eq(#W.EG.Recommend.Upgrades(true), 1)
        local ids = W.EG.Recommend.ContainerIDs(true)
        T.eq(ids[1], 0) T.eq(ids[6], 5)
    end)

    T.test("recommend: unloaded items are reported as pending", function()
        local W = world(function(w)
            w.I.slow = F.gear(w, 5011, "Slow", "INVTYPE_CHEST", 40, { STR = 30 }, { uncached = true })
            w.bag(0, 4, { [1] = w.I.slow })
        end)
        local list, pending = W.EG.Recommend.Upgrades(false)
        T.eq(#list, 0) T.eq(pending, true)
    end)

    T.test("recommend: best candidate per slot and the hints for the character window", function()
        local W = world(function(w)
            w.I.a = F.gear(w, 5020, "Chest A", "INVTYPE_CHEST", 40, { STR = 30 }, { armor = 500 })
            w.I.b = F.gear(w, 5021, "Chest B", "INVTYPE_CHEST", 50, { STR = 30 }, { armor = 500 })
            w.bag(0, 4, { [1] = w.I.a, [2] = w.I.b })
        end)
        local hints, list = W.EG.Recommend.SlotHints()
        T.eq(#list, 2)
        T.eq(hints[5].link, W.I.b, "the better chest wins slot 5")
        T.eq(hints[1], nil)
        W.state.bags[0].items[2] = nil
        T.eq(W.EG.Recommend.BestPerSlot(W.EG.Recommend.Upgrades(false))[5].link, W.I.a)
    end)

    local function reward(W, id, ilvl, stats, extra)
        return F.gear(W, id, "Reward " .. id, "INVTYPE_CHEST", ilvl, stats, extra)
    end

    T.test("recommend: best reward is the biggest upgrade", function()
        local W = world()
        local a = reward(W, 5030, 36, { STR = 25 }, { armor = 400, sellPrice = 900 })     -- 18+25+10 = 53 -> +8.5
        local b = reward(W, 5031, 40, { STR = 30 }, { armor = 500, sellPrice = 100 })     -- 20+30+12.5 = 62.5 -> +18
        local idx, kind, delta = W.EG.Recommend.BestReward({
            { index = 1, link = a, count = 1 }, { index = 2, link = b, count = 1 },
        })
        T.eq(idx, 2) T.eq(kind, "UPGRADE") T.near(delta, 18)
    end)

    T.test("recommend: without an upgrade the highest vendor value wins (price x count)", function()
        local W = world()
        local a = reward(W, 5032, 10, { STR = 1 }, { sellPrice = 50 })
        local b = reward(W, 5033, 10, { STR = 1 }, { sellPrice = 20 })
        local idx, kind, _, value = W.EG.Recommend.BestReward({
            { index = 1, link = a, count = 1 }, { index = 2, link = b, count = 4 },
        })
        T.eq(idx, 2) T.eq(kind, "VENDOR") T.eq(value, 80)
    end)

    T.test("recommend: equal gain is decided by vendor value", function()
        local W = world()
        local a = reward(W, 5034, 40, { STR = 30 }, { armor = 500, sellPrice = 10 })
        local b = reward(W, 5035, 40, { STR = 30 }, { armor = 500, sellPrice = 99 })
        local idx = W.EG.Recommend.BestReward({ { index = 1, link = a, count = 1 }, { index = 2, link = b, count = 1 } })
        T.eq(idx, 2)
    end)

    T.test("recommend: rewards the client calls unusable are not compared", function()
        local W = world()
        local a = reward(W, 5036, 90, { STR = 90 }, { armor = 900, sellPrice = 1 })
        local b = reward(W, 5037, 40, { STR = 30 }, { armor = 500, sellPrice = 2 })
        local idx, kind = W.EG.Recommend.BestReward({
            { index = 1, link = a, count = 1, apiUsable = false }, { index = 2, link = b, count = 1 },
        })
        T.eq(idx, 2) T.eq(kind, "UPGRADE")
    end)

    T.test("recommend: nothing to choose from", function()
        local W = world()
        local idx = W.EG.Recommend.BestReward({})
        T.eq(idx, nil)
        idx = W.EG.Recommend.BestReward(nil)
        T.eq(idx, nil)
    end)
end
