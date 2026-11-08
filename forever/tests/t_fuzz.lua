-- Random gear, profiles and levels: nothing may raise, and the invariants of the comparison must hold
return function(T)
    local F = require("fixtures")

    -- small deterministic generator (the tests must be repeatable). Park-Miller: the products stay below 2^53, so
    -- the arithmetic is exact (a 31-bit LCG with a 2^30 multiplier is not, and its low bits degenerate).
    local seed = (tonumber(os.getenv("FUZZ_SEED")) or 12345) % 2147483646 + 1
    local RUNS = tonumber(os.getenv("FUZZ_RUNS")) or 12
    local function rnd(n)
        seed = (seed * 16807) % 2147483647
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

    --[[ A random walk through everything that happens in a session. The caches are warmed first, then one event
         happens, and right after it (no timer has run) every cached answer must equal the answer computed from
         scratch - a stale cache would show as a difference. Nothing may raise on the way.                    ]]
    T.test("fuzz: after random events the cached answers equal fresh ones", function()
        local RUNS_STATE = math.max(4, math.floor(RUNS / 2))
        local COMMANDS = { "ilvl 0.7", "ilvl 0.5", "mindelta 3", "mindelta 0", "mindeltapct 5", "mindeltapct 1", "autolevel off",
                           "autolevel on", "enchants off", "enchants on", "ilvlscale off", "ilvlscale on", "socket 3",
                           "socket auto", "tooltip off", "tooltip on", "icons", "frobnicate", "upgrades", "status",
                           "profile list", "ilvl abc", "scale 9", "parse item:100001" }
        local checks = 0
        for run = 1, RUNS_STATE do
            local class = pick(CLASSES)
            local W = T.world({ class = class, level = pick({ 30, 60 }),
                                talents = { mode = "specinfo", points = { rnd(41) - 1, rnd(41) - 1, rnd(41) - 1 } } })
            local pool, locs = {}, {}
            for i = 1, 10 do pool[i], locs[i] = randomItem(W) end
            local S, C = W.EG.Score, W.EG.Contexts

            --[[ Everything the session may have cached, read as the displays would read it right after the event, and
                 compared with the same answers computed from scratch (hints and totals bypass their caches).    ]]
            local function verify()
                local sample, cached = { pick(pool), pick(pool), pick(pool) }, {}
                for i, link in ipairs(sample) do cached[i] = { S.Compare(link), S.UpgradeState(link) } end
                local cachedHints = {}
                for slot = 1, 19 do
                    local h = C.SlotHint(slot)
                    cachedHints[slot] = h and h.delta
                end
                local cachedTotals = S.EquippedTotals()

                W.EG:InvalidateAll()
                checks = checks + 1

                local freshTotals = S.EquippedTotals(true)
                for _, key in ipairs({ "COUNT", "ILVL", "DPS", "RDPS", "SOCKET" }) do
                    T.near(cachedTotals[key], freshTotals[key], 1e-9, "stale total " .. key .. ", run " .. run)
                end
                local freshHints = W.EG.Recommend.SlotHints()
                for slot = 1, 19 do
                    T.eq(cachedHints[slot], freshHints[slot] and freshHints[slot].delta, "stale hint for slot " .. slot .. ", run " .. run)
                end
                for i, link in ipairs(sample) do
                    local r1, s1 = cached[i][1], cached[i][2]
                    local r2, s2 = S.Compare(link), S.UpgradeState(link)
                    T.eq(r1 == nil, r2 == nil, "availability, run " .. run)
                    if r1 and r2 then
                        T.eq(r1.delta == nil, r2.delta == nil, "delta present, run " .. run)     -- shirts and tabards have none
                        if r1.delta and r2.delta then T.near(r1.delta, r2.delta, 1e-9, "stale delta, run " .. run) end
                        T.eq(r1.isUpgrade, r2.isUpgrade, "stale verdict, run " .. run)
                        T.eq(r1.target and r1.target.slotID, r2.target and r2.target.slotID, "stale target, run " .. run)
                    end
                    T.eq(s1, s2, "stale state, run " .. run)
                end
            end

            for _ = 1, 40 do
                -- warm every cache
                for _, link in ipairs(pool) do S.Compare(link) S.UpgradeState(link) end
                for slot = 1, 19 do C.SlotHint(slot) end
                S.EquippedTotals()

                local action = rnd(11)
                local flush = false
                if action == 1 then
                    local i = rnd(#pool)
                    local slot = SLOT_OF[locs[i]]
                    if slot then W.equip(slot, pool[i]) W.fire("PLAYER_EQUIPMENT_CHANGED", slot) end
                elseif action == 2 then
                    local slot = rnd(18)
                    W.equip(slot, nil)
                    W.fire("PLAYER_EQUIPMENT_CHANGED", slot)
                elseif action == 3 then                          -- an enchant: new link in the same slot, no slot event
                    local link, loc = randomItem(W)
                    local slot = SLOT_OF[loc]
                    if slot then W.equip(slot, link) W.fire("UNIT_INVENTORY_CHANGED", "player") end
                elseif action == 4 then
                    W.put(0, rnd(8), pick(pool))
                    W.fire("BAG_UPDATE_DELAYED")
                elseif action == 5 then
                    W.fire("GET_ITEM_INFO_RECEIVED", 100000 + rnd(40), rnd(2) == 1)
                elseif action == 6 then
                    W.tooltipFor(W.bagButton(0, 1), pick(pool))
                    W.tooltipFor(W.namedButton("CharacterChestSlot", 5), pick(pool))
                    local shop = W.env.ShoppingTooltip1
                    shop:SetOwner(W.env.GameTooltip, "ANCHOR_NONE")
                    W.env.__showItem(shop, pick(pool))
                elseif action == 7 then
                    W.EG.Window.SetItem(pick({ pick(pool), 100000 + rnd(40), "item:" .. (100000 + rnd(40)), "junk", 0 }))
                    W.EG.Window.Refresh()
                elseif action == 8 then
                    W.slash(pick(COMMANDS))
                elseif action == 9 then
                    W.flush()
                elseif action == 10 then
                    W.setLevel(pick({ 30, 45, 60 }))
                    flush = true                                  -- the profile follows the level after a short delay
                else
                    local specs = W.EG.Profiles.List(class)
                    W.EG.Profiles.SetActive(rnd(3) == 1 and "AUTO" or pick(specs).id)
                end
                if flush then W.flush() end

                T.eq(W.EG.lastError, nil, "no internal error, run " .. run .. ": " .. tostring(W.EG.lastError and W.EG.lastError.err))
                verify()
            end
        end
        T.ok(checks >= 40 * RUNS_STATE, "enough checks: " .. checks)
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
