-- Random gear, profiles and levels: nothing may raise, and the invariants of the comparison must hold
return function(T)
    local F = require("fixtures")

    -- small deterministic generator (the tests must be repeatable)
    local seed = tonumber(os.getenv("FUZZ_SEED")) or 12345
    local RUNS = tonumber(os.getenv("FUZZ_RUNS")) or 12
    local function rnd(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed % n + 1
    end
    local function pick(list) return list[rnd(#list)] end

    local LOCS = { "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WAIST",
                   "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET",
                   "INVTYPE_CLOAK", "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND",
                   "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_BODY",
                   "INVTYPE_TABARD" }
    local SLOT_OF = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
                      INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
                      INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16,
                      INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17,
                      INVTYPE_SHIELD = 17, INVTYPE_HOLDABLE = 17, INVTYPE_RANGED = 18 }
    local STATS = { "STR", "AGI", "STA", "INT", "SPI", "AP", "SP", "CRIT", "HIT", "HASTE", "EXP", "ARP", "DEF", "DODGE", "PARRY", "MP5" }
    local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

    local nextId = 100000
    local function randomItem(W)
        nextId = nextId + 1
        local loc = pick(LOCS)
        local stats = {}
        for _ = 1, rnd(5) do stats[pick(STATS)] = rnd(60) end
        local extra = { armor = (rnd(3) == 1) and rnd(800) or nil, sockets = (rnd(4) == 1) and rnd(2) or nil,
                        minLevel = (rnd(3) == 1) and rnd(70) or 0, unique = (rnd(10) == 1) and true or nil,
                        badType = (rnd(8) == 1) and true or nil, sellPrice = rnd(5000) }
        if loc:find("WEAPON") or loc == "INVTYPE_RANGED" then extra.dps = rnd(400) / 10 end
        return F.gear(W, nextId, "Item" .. nextId, loc, rnd(120), stats, extra), loc
    end

    T.test("fuzz: random characters and gear never raise and keep the invariants", function()
        local checked = 0
        for run = 1, RUNS do
            local class = pick(CLASSES)
            local level = pick({ 10, 30, 59, 60 })
            local pts = { rnd(41) - 1, rnd(41) - 1, rnd(41) - 1 }
            local W = T.world({ class = class, level = level, talents = { mode = "specinfo", points = pts } }, function(w)
                -- random worn set
                for slot = 1, 18 do
                    if rnd(3) > 1 then
                        local link, loc = randomItem(w)
                        local fits = SLOT_OF[loc]
                        if fits then w.equip(fits == 11 and (rnd(2) == 1 and 11 or 12) or fits, link) end
                    end
                end
            end)
            for _, spec in ipairs(W.EG.Profiles.List(class)) do
                if rnd(3) == 1 then W.EG.Profiles.SetActive(spec.id) end
                for _ = 1, 12 do
                    local link = randomItem(W)
                    local ok, r = pcall(W.EG.Score.Compare, link, true)
                    T.ok(ok, "Compare raised: " .. tostring(r))
                    if r then
                        checked = checked + 1
                        T.ok(r.score == r.score and r.score > -1e9 and r.score < 1e9, "finite score")
                        if not r.noCompare then
                            T.near(r.delta, r.score - r.targetScore, 1e-9, "delta = score - worn score")
                            if r.isUpgrade then
                                T.ok(r.usable and not r.levelTooLow and r.delta > 0 and r.delta >= r.threshold, "upgrade invariants")
                            end
                            T.ok(r.target, "a target slot")
                        end
                        local sum = 0
                        for _, row in ipairs(r.breakdown or {}) do sum = sum + row.points end
                        if r.breakdown then T.near(sum, r.score, 1e-6, "breakdown adds up to the score") end
                        local state = W.EG.Score.UpgradeState(link)
                        T.ok(state == nil or state == "UPGRADE" or state == "LEVEL")
                        local tip = W.tooltipFor(W.bagButton(0, 1), link)
                        T.ok(tip.__shown)
                    end
                end
                W.EG.Slash.PrintUpgrades()
            end
            T.eq(W.EG.lastError, nil, "no internal error in run " .. run .. ": " .. tostring(W.EG.lastError and W.EG.lastError.err))
        end
        T.ok(checked > 40 * RUNS, "enough comparisons: " .. checked)
    end)

    T.test("fuzz: a copy of the worn item in a single-slot position never gains", function()
        local W = T.world(F.arms(), function(w) w.I = F.armsWarrior(w) end)
        local r = W.EG.Score.Compare(W.I.chest)
        T.near(r.delta, 0, 1e-9)
        T.eq(r.isUpgrade, false)
        -- for a ring or trinket the second slot decides: a copy would fill the empty one
        r = W.EG.Score.Compare(W.I.trinket)
        T.eq(r.target.empty, true) T.near(r.delta, r.score)
    end)

    T.test("fuzz: every profile of every class resolves and scores a plain item", function()
        for _, class in ipairs(CLASSES) do
            local W = T.world({ class = class, level = 60, talents = { mode = "specinfo", points = { 20, 10, 5 } } })
            local link = F.gear(W, 200000 + #class, "Plain", "INVTYPE_CHEST", 50, { STR = 20, INT = 20, SP = 20 }, { armor = 300 })
            for _, spec in ipairs(W.EG.Profiles.List(class)) do
                T.eq(W.EG.Profiles.SetActive(spec.id), true)
                local s = W.EG.Score.OfLink(link)
                T.ok(s and s > 0, class .. " " .. spec.id)
            end
        end
    end)
end
