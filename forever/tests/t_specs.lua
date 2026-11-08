-- Specs.lua: structure of the weight tables
return function(T)
    local MAIN = { "STR", "AGI", "STA", "INT", "SP" }

    T.test("specs: weights are known keys with positive numbers", function()
        local W = T.world()
        local S, Stats = W.EG.Specs, W.EG.Stats
        local known = {}
        for _, k in ipairs(Stats.ORDER) do known[k] = true end
        known.DPS, known.RDPS = true, true
        local function check(spec, w)
            for k, v in pairs(w) do
                T.ok(known[k], spec.id .. ": unknown key " .. tostring(k))
                T.ok(type(v) == "number" and v > 0, spec.id .. "." .. k .. " must be a positive number")
            end
        end
        local count = 0
        for _, list in pairs(S.CLASS) do
            for _, spec in ipairs(list) do
                count = count + 1
                check(spec, spec.w)
                for tab, variant in pairs(spec.variants or {}) do check(spec, variant.w) T.ok(tab >= 1 and tab <= 3) end
            end
        end
        for _, spec in ipairs(S.ANY) do check(spec, spec.w) count = count + 1 end
        T.eq(count, 48)
    end)

    T.test("specs: profiles are normalised to a main attribute of 1.00", function()
        local W = T.world()
        for class, list in pairs(W.EG.Specs.CLASS) do
            for _, spec in ipairs(list) do
                if spec.kind == "SPEC" then
                    local top = 0
                    for _, k in ipairs(MAIN) do top = math.max(top, spec.w[k] or 0) end
                    T.eq(top, 1.0, class .. " " .. spec.id .. ": largest main attribute weight")
                end
            end
        end
    end)

    T.test("specs: ids are unique, trees are 1 to 3, roles are known", function()
        local W = T.world()
        local seen = {}
        local roles = { TANK = true, MELEE = true, RANGED = true, CASTER = true, HEAL = true }
        for class, list in pairs(W.EG.Specs.CLASS) do
            for _, spec in ipairs(list) do
                T.ok(not seen[spec.id], "duplicate id " .. spec.id)
                seen[spec.id] = true
                T.ok(spec.id:find("^" .. class .. "_"), spec.id .. " belongs to " .. class)
                T.ok(roles[spec.role], spec.id .. " role")
                if spec.tab then T.ok(spec.tab >= 1 and spec.tab <= 3, spec.id .. " tab") end
                T.eq(spec.class, class)
                T.eq(W.EG.Specs.BY_ID[spec.id], spec)
            end
        end
    end)

    T.test("specs: every tree of every class has a default profile for the automatic choice", function()
        local W = T.world()
        for class, list in pairs(W.EG.Specs.CLASS) do
            for tab = 1, 3 do
                local auto = 0
                for _, spec in ipairs(list) do if spec.tab == tab and spec.auto then auto = auto + 1 end end
                T.eq(auto, 1, class .. " tree " .. tab .. " needs exactly one default profile")
            end
        end
    end)

    T.test("specs: tanks weigh avoidance, healers weigh spell power, casters weigh hit", function()
        local W = T.world()
        for class, list in pairs(W.EG.Specs.CLASS) do
            for _, spec in ipairs(list) do
                if spec.kind == "SPEC" and spec.role == "TANK" then
                    T.ok(spec.w.STA and (spec.w.DODGE or spec.w.PARRY or spec.w.DEF), class .. " " .. spec.id .. " tank stats")
                elseif spec.kind == "SPEC" and spec.role == "HEAL" then
                    T.ok(spec.w.SP and spec.w.INT, class .. " " .. spec.id .. " healer stats")
                elseif spec.kind == "SPEC" and spec.role == "CASTER" then
                    T.ok(spec.w.SP and spec.w.HIT, class .. " " .. spec.id .. " caster stats")
                end
            end
        end
    end)

    T.test("specs: a caster tree carries no feral attack power", function()
        local W = T.world()
        for _, spec in ipairs(W.EG.Specs.CLASS.DRUID) do
            if spec.role == "CASTER" or spec.role == "HEAL" then
                T.eq(spec.w.FAP, nil, spec.id .. " has no use for feral attack power")
            end
        end
    end)
end
