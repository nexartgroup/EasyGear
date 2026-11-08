-- Stats.lua: reading item values from GetItemStats and tooltip lines
return function(T)
    local LINE, C = T.Mock.LINE, T.Mock.COLOR
    local function stats() return T.world().EG.Stats end

    T.test("stats: GetItemStats keys map to short keys, families take the maximum", function()
        local S = stats()
        local st, unknown, sockets, dps = S.FromItemStats({
            ITEM_MOD_STRENGTH_SHORT = 30, ITEM_MOD_HIT_RATING_SHORT = 10, ITEM_MOD_HIT_MELEE_RATING_SHORT = 12,
            RESISTANCE0_NAME = 400, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 22.5, EMPTY_SOCKET_RED = 1,
            EMPTY_SOCKET_BLUE = 1, ITEM_MOD_SOMETHING_NEW_SHORT = 5,
        })
        T.eq(st.STR, 30)
        T.eq(st.HIT, 12, "hit variants are one value, the larger counts")
        T.eq(st.ARMOR, 400)
        T.eq(dps, 22.5)
        T.eq(sockets, 2)
        T.eq(unknown.ITEM_MOD_SOMETHING_NEW_SHORT, 5)
        T.eq(st.ITEM_MOD_SOMETHING_NEW_SHORT, nil)
    end)

    T.test("stats: FromItemStats tolerates nil and junk", function()
        local S = stats()
        local st, unknown, sockets, dps = S.FromItemStats(nil)
        T.eq(next(st), nil) T.eq(next(unknown), nil) T.eq(sockets, 0) T.eq(dps, nil)
        st = S.FromItemStats({ ITEM_MOD_STRENGTH_SHORT = "x", [5] = 3 })
        T.eq(st.STR, nil)
    end)

    T.test("stats: whole lines, short and long form", function()
        local S = stats()
        local r = S.ScanLines({
            { type = 0, leftText = "+30 Strength", leftColor = C.white },
            { type = 0, leftText = "Equip: Improves critical strike rating by 20.", leftColor = C.green },
            { type = 0, leftText = "Improves haste rating by 15.", leftColor = C.green },
            { type = 0, leftText = "500 Armor", leftColor = C.white },
        })
        T.eq(r.base.STR, 30) T.eq(r.base.CRIT, 20) T.eq(r.base.HASTE, 15) T.eq(r.base.ARMOR, 500)
        T.eq(r.hasStats, true)
    end)

    T.test("stats: enchant, gem and active socket bonus are extras; grey socket bonus is ignored", function()
        local S = stats()
        local r = S.ScanLines({
            { type = 0, leftText = "+20 Strength", leftColor = C.white },
            { type = LINE.ItemEnchantmentPermanent, leftText = "Enchanted: +15 Stamina", leftColor = C.green },
            { type = LINE.GemSocketEnchantment, leftText = "+10 Strength", leftColor = C.white },
            { type = 0, leftText = "Socket Bonus: +4 Stamina", leftColor = C.green },
        })
        T.eq(r.base.STR, 20)
        T.eq(r.extra.STA, 19, "enchant 15 + socket bonus 4")
        T.eq(r.extra.STR, 10)
        local g = S.ScanLines({ { type = 0, leftText = "Socket Bonus: +4 Stamina", leftColor = C.grey } })
        T.eq(g.extra.STA, nil, "inactive bonus")
    end)

    T.test("stats: all stats enchant adds to the five main stats", function()
        local S = stats()
        local r = S.ScanLines({ { type = LINE.ItemEnchantmentPermanent, leftText = "Enchanted: +4 All Stats", leftColor = C.green } })
        for _, k in ipairs({ "STR", "AGI", "STA", "INT", "SPI" }) do T.eq(r.extra[k], 4, k) end
    end)

    T.test("stats: equip slot validity, level requirement and reasons", function()
        local S = stats()
        local r = S.ScanLines({
            { type = LINE.EquipSlot, leftText = "Chest", rightText = "Plate", rightColor = C.red,
              isValidItemType = false, isValidInvSlot = true },
            { type = LINE.UsageRequirement, requirementType = 5, leftText = "Requires Level 45", leftColor = C.red },
            { type = LINE.UsageRequirement, requirementType = 0, leftText = "Requires Warrior", leftColor = C.red },
            { type = LINE.UsageRequirement, requirementType = 4, leftText = "Requires Honored", leftColor = C.red },
        })
        T.eq(r.validType, false) T.eq(r.validSlot, true)
        T.eq(r.slotText, "Chest") T.eq(r.typeText, "Plate")
        T.eq(r.reqLevel, 45)
        T.eq(r.reason, "Requires Warrior", "first red non-level line")
    end)

    T.test("stats: a level line of requirement type Level also works without the text pattern", function()
        local S = stats()
        local r = S.ScanLines({ { type = LINE.UsageRequirement, requirementType = 5, leftText = "Niveau 33 requis", leftColor = C.red } })
        T.eq(r.reqLevel, 33)
    end)

    T.test("stats: colors - red means unmet, grey means inactive, nothing else does", function()
        local S = stats()
        T.eq(S.IsRed(C.red), true) T.eq(S.IsRed(C.white), false) T.eq(S.IsRed(C.green), false)
        T.eq(S.IsRed({ r = 1, g = 0.1, b = 0.9 }), false, "magenta is not red")
        T.eq(S.IsRed({ GetRGB = function() return 1, 0.1, 0.1 end }), true, "color objects work too")
        T.eq(S.IsGrey(C.grey), true) T.eq(S.IsGrey(C.white), false) T.eq(S.IsGrey(nil), false)
    end)

    T.test("stats: without the requirement type enum an untyped red line is only a reason", function()
        local W = T.world()
        W.env.Enum.TooltipDataUsageRequirementType = nil
        local r = W.EG.Stats.ScanLines({ { type = LINE.UsageRequirement, leftText = "Requires 3rd rank", leftColor = C.red } })
        T.eq(r.reqLevel, nil) T.eq(r.reason, "Requires 3rd rank")
    end)

    T.test("stats: requirement lines without a type are not mistaken for level lines", function()
        local S = stats()
        local r = S.ScanLines({ { type = LINE.UsageRequirement, leftText = "Requires something", leftColor = C.red } })
        T.eq(r.reqLevel, nil)
        T.eq(r.reason, "Requires something")
    end)

    T.test("stats: set bonuses after the set header are not counted", function()
        local S = stats()
        local r = S.ScanLines({
            { type = 0, leftText = "+20 Strength", leftColor = C.white },
            { type = 0, leftText = "Battlegear of Might (2/5)", leftColor = C.white },
            { type = 0, leftText = "+50 Strength", leftColor = C.grey },
            { type = 0, leftText = "+60 Stamina", leftColor = C.white },
        })
        T.eq(r.base.STR, 20) T.eq(r.base.STA, nil) T.eq(r.extra.STR, nil)
    end)

    T.test("stats: use and proc effects are not stats", function()
        local S = stats()
        local r = S.ScanLines({
            { type = 0, leftText = "Use: Increases Strength by +100 for 15 sec.", leftColor = C.green },
            { type = LINE.ItemSpellTriggerOnUse, leftText = "Use: +50 Agility", leftColor = C.green },
            { type = 0, leftText = "Chance on hit: +30 Strength", leftColor = C.green },
        })
        T.eq(next(r.base), nil) T.eq(next(r.extra), nil) T.eq(r.hasStats, false)
    end)

    T.test("stats: unique, weapon dps text", function()
        local S = stats()
        local r = S.ScanLines({
            { type = 0, leftText = "Unique-Equipped", leftColor = C.white },
            { type = 0, leftText = "(42.5 damage per second)", leftColor = C.white },
        })
        T.eq(r.unique, true) T.eq(r.dps, 42.5)
    end)

    T.test("stats: Merge takes the larger of API and tooltip base values and adds extras", function()
        local S = stats()
        local scan = { base = { STR = 32, STA = 10 }, extra = { STR = 5 } }
        local st, extra = S.Merge({ STR = 30, AGI = 7 }, scan, true)
        T.eq(st.STR, 37, "max(30,32) + 5") T.eq(st.AGI, 7) T.eq(st.STA, 10) T.eq(extra.STR, 5)
        st, extra = S.Merge({ STR = 30 }, scan, false)
        T.eq(st.STR, 32) T.eq(next(extra), nil)
    end)

    T.test("stats: Label uses the client's own stat names", function()
        local S = stats()
        T.eq(S.Label("STR"), "Strength")
        T.eq(S.Label("ARMOR"), "Armor")
        T.eq(S.Label("DPS"), "Weapon DPS")
        T.eq(S.Label("ITEM_MOD_UNKNOWN_SHORT"), "ITEM_MOD_UNKNOWN_SHORT")
    end)
end
