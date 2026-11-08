-- Profiles.lua / Specs.lua: profile choice, talent detection, custom profiles
return function(T)
    local F = require("fixtures")

    local function resolve(opts, setup)
        local W = T.world(opts, setup)
        return W, W.EG.Profiles.Resolve()
    end
    local function talents(mode, points, extra)
        local t = { mode = mode, points = points }
        for k, v in pairs(extra or {}) do t[k] = v end
        return t
    end

    T.test("profiles: every class has a profile per tree, leveling and all-round", function()
        local W = T.world(F.ARMS)
        local Specs = W.EG.Specs
        T.eq(#Specs.CLASS_ORDER, 9)
        for _, class in ipairs(Specs.CLASS_ORDER) do
            local list = Specs.CLASS[class]
            T.ok(list, class)
            local tabs, leveling, allround = {}, false, false
            for _, s in ipairs(list) do
                if s.tab then tabs[s.tab] = true end
                if s.kind == "LEVELING" then leveling = true end
                if s.kind == "ALLROUND" then allround = true end
                T.ok(s.w and next(s.w), s.id .. " has weights")
            end
            T.ok(tabs[1] and tabs[2] and tabs[3], class .. " covers three trees")
            T.ok(leveling and allround, class .. " has leveling and all-round")
        end
    end)

    T.test("profiles: detection from SpecializationInfo points", function()
        local cases = { { { 40, 5, 0 }, "WARRIOR_ARMS" }, { { 5, 40, 0 }, "WARRIOR_FURY" }, { { 0, 3, 41 }, "WARRIOR_PROT" } }
        for _, c in ipairs(cases) do
            local _, p = resolve({ class = "WARRIOR", level = 60, talents = talents("specinfo", c[1]) })
            T.eq(p.spec.id, c[2])
            T.eq(p.auto, true)
        end
    end)

    T.test("profiles: detection through the trait tree groups follows the list order of the talent frame", function()
        local _, p = resolve({ class = "WARRIOR", level = 60, talents = talents("traits", { 5, 40, 0 }) })
        T.eq(p.spec.id, "WARRIOR_FURY")
        _, p = resolve({ class = "WARRIOR", level = 60, talents = talents("traits", { 0, 0, 41 }) })
        T.eq(p.spec.id, "WARRIOR_PROT")
    end)

    T.test("profiles: detection through the selected specialization alone", function()
        local _, p = resolve({ class = "MAGE", level = 60, talents = talents("selected", { 0, 0, 0 }, { selected = 2 }) })
        T.eq(p.spec.id, "MAGE_FIRE")
    end)

    T.test("profiles: all-zero points from GetSpecializationInfo do not hide the other sources", function()
        local W = T.world({ class = "DRUID", level = 60, talents = talents("traits", { 0, 41, 0 }, { roles = { "DAMAGER", "TANK", "HEALER" } }) })
        local t = W.EG.Profiles.Talents()
        T.eq(t.source, "traits") T.eq(t.tab, 2) T.eq(t.role, "TANK", "roles come from GetSpecializationInfo")
        T.eq(W.EG.Profiles.Resolve().spec.id, "DRUID_BEAR")
    end)

    T.test("profiles: all three trees are read even if the client counts fewer specializations", function()
        local W = T.world({ class = "WARRIOR", level = 60, talents = talents("specinfo", { 5, 40, 0 }, { numSpecs = 1 }) })
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_FURY")
    end)

    T.test("profiles: an API that raises is skipped, the next source answers", function()
        local W = T.world({ class = "WARRIOR", level = 60, talents = talents("specinfo", { 40, 5, 0 }) }, function(w)
            w.env.C_Traits.GetConfigInfo = function() error("client hiccup") end
            w.env.C_SpecializationInfo.GetSpecialization = function() error("client hiccup") end
        end)
        local t = W.EG.Profiles.Talents()
        T.eq(t.source, "specinfo") T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_ARMS")
    end)

    T.test("profiles: a source that answers with zeros means no talents, not unknown", function()
        local W = T.world({ class = "WARRIOR", level = 60, talents = talents("specinfo", { 0, 0, 0 }) })
        local t = W.EG.Profiles.Talents()
        T.eq(t.total, 0) T.eq(t.tab, nil)
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_ALLROUND")
        T.eq(W.EG.Profiles.DominantTab(), nil)
    end)

    T.test("profiles: talents are read again when the world loads", function()
        local W = T.world({ class = "WARRIOR", level = 60, talents = talents("specinfo", { 0, 0, 0 }) })
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_ALLROUND")
        W.state.talents.points = { 40, 5, 0 }
        W.fire("PLAYER_ENTERING_WORLD")
        W.flush()
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_ARMS")
        W.state.talents.points = { 5, 40, 0 }
        W.fire("TRAIT_CONFIG_UPDATED")
        W.flush()
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_FURY")
    end)

    T.test("profiles: no talent information falls back to all-round at the top level, leveling below", function()
        local _, p = resolve({ class = "ROGUE", level = 60, talents = talents("none", { 0, 0, 0 }) })
        T.eq(p.spec.id, "ROGUE_ALLROUND")
        _, p = resolve({ class = "ROGUE", level = 30, talents = talents("none", { 0, 0, 0 }) })
        T.eq(p.spec.id, "ROGUE_LEVELING")
        _, p = resolve({ class = "ROGUE", level = 60, talents = talents("specinfo", { 2, 1, 0 }) })
        T.eq(p.spec.id, "ROGUE_ALLROUND", "fewer than 5 points count as no talents")
    end)

    T.test("profiles: below the maximum level the leveling profile wins, except tank and healer trees", function()
        local _, p = resolve({ class = "WARRIOR", level = 40, talents = talents("specinfo", { 40, 0, 0 }) })
        T.eq(p.spec.id, "WARRIOR_LEVELING")
        _, p = resolve({ class = "WARRIOR", level = 40, talents = talents("specinfo", { 0, 0, 30 }) })
        T.eq(p.spec.id, "WARRIOR_PROT")
        _, p = resolve({ class = "PRIEST", level = 40, talents = talents("specinfo", { 30, 0, 0 }) })
        T.eq(p.spec.id, "PRIEST_DISC", "healer tree keeps its profile")
    end)

    T.test("profiles: autoLeveling off keeps the tree profile at any level", function()
        local W = T.world({ class = "WARRIOR", level = 40, talents = talents("specinfo", { 40, 0, 0 }) })
        W.EG:Set("autoLeveling", false)
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_ARMS")
    end)

    T.test("profiles: the level cap comes from the client", function()
        local _, p = resolve({ class = "WARRIOR", level = 70, maxLevel = 70, talents = talents("specinfo", { 40, 0, 0 }) })
        T.eq(p.spec.id, "WARRIOR_ARMS")
        _, p = resolve({ class = "WARRIOR", level = 60, maxLevel = 70, talents = talents("specinfo", { 40, 0, 0 }) })
        T.eq(p.spec.id, "WARRIOR_LEVELING")
    end)

    T.test("profiles: druid tree 2 picks bear for a tank tree and cat otherwise", function()
        local _, p = resolve({ class = "DRUID", level = 60, talents = talents("specinfo", { 0, 41, 0 }, { roles = { "DAMAGER", "TANK", "HEALER" } }) })
        T.eq(p.spec.id, "DRUID_BEAR")
        _, p = resolve({ class = "DRUID", level = 60, talents = talents("specinfo", { 0, 41, 0 }, { roles = { "DAMAGER", "DAMAGER", "HEALER" } }) })
        T.eq(p.spec.id, "DRUID_CAT")
    end)

    T.test("profiles: weighting variants of hybrid leveling profiles follow the dominant tree", function()
        local W, p = resolve({ class = "DRUID", level = 40, talents = talents("specinfo", { 40, 0, 0 }) })
        T.eq(p.spec.id, "DRUID_LEVELING")
        T.ok(p.weights.SP, "balance variant weighs spell power")
        T.eq(p.weights.AGI, nil)
        W = T.world({ class = "DRUID", level = 40, talents = talents("specinfo", { 0, 40, 0 }) })
        p = W.EG.Profiles.Resolve()
        T.ok(p.weights.AGI and not p.weights.SP, "feral weights otherwise")
    end)

    T.test("profiles: spell damage and healing are derived from spell power by role", function()
        local W = T.world(F.ARMS)
        local P, S = W.EG.Profiles, W.EG.Specs
        local fire = P.WeightsFor(S.BY_ID.MAGE_FIRE)
        T.eq(fire.SPDMG, fire.SP) T.eq(fire.SPHEAL, 0)
        local holy = P.WeightsFor(S.BY_ID.PRIEST_HOLY)
        T.eq(holy.SPHEAL, holy.SP) T.near(holy.SPDMG, holy.SP * 0.35)
        local ret = P.WeightsFor(S.BY_ID.PALADIN_RET)
        T.eq(ret.SPDMG, ret.SP) T.eq(ret.SPHEAL, ret.SP)
        T.eq(W.EG.Profiles.WeightsFor(nil) ~= nil, true)
    end)

    T.test("profiles: choosing a profile by id and back to automatic", function()
        local W = T.world(F.ARMS)
        local P = W.EG.Profiles
        T.eq(P.ActiveID(), "AUTO")
        T.eq(P.SetActive("WARRIOR_PROT"), true)
        T.eq(P.Resolve().spec.id, "WARRIOR_PROT") T.eq(P.Resolve().auto, false)
        T.eq(P.SetActive("NOPE"), false)
        T.eq(P.ActiveID(), "WARRIOR_PROT")
        P.SetActive("AUTO")
        T.eq(P.Resolve().spec.id, "WARRIOR_ARMS")
        T.eq(W.env.EasyGearCharDB.profile, "AUTO")
    end)

    T.test("profiles: an unknown stored id falls back to detection", function()
        local W = T.world(F.ARMS, function(w) w.env.EasyGearCharDB = { profile = "GONE" } end)
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_ARMS")
    end)

    T.test("profiles: custom profiles - create, edit, rename, list, delete", function()
        local W = T.world(F.ARMS)
        local P = W.EG.Profiles
        local id = P.CreateCustom("My Build", "WARRIOR_ARMS")
        T.eq(id, "CUSTOM_MyBuild")
        local spec = P.Get(id)
        T.eq(spec.custom, true) T.eq(spec.name, "My Build") T.eq(spec.weights.STR, 1.0)
        T.eq(spec.weights.SPDMG, nil, "derived values are not copied")
        T.eq(P.CreateCustom("My Build", "WARRIOR_ARMS"), "CUSTOM_MyBuild2", "unique ids")
        local caster = P.Get(P.CreateCustom("Caster Copy", "MAGE_FIRE", "MAGE"))
        T.ok(caster.weights.SP, "spell power is copied")
        T.eq(caster.weights.SPDMG, nil, "derived spell damage and healing are not stored")
        T.eq(caster.weights.SPHEAL, nil)
        T.eq(caster.class, "MAGE") T.eq(caster.role, "CASTER")
        local derived = P.WeightsFor(caster)
        T.eq(derived.SPDMG, derived.SP) T.eq(derived.SPHEAL, 0, "a clone of a caster tree profile values no healing power")

        P.SetActive(id)
        local sig1 = P.Resolve().sig
        T.eq(P.SetCustomWeight(id, "STR", 2.5), true)
        T.eq(P.Resolve().weights.STR, 2.5)
        T.ok(P.Resolve().sig ~= sig1, "signature changes with the weights")
        P.SetCustomWeight(id, "STR", 0)
        T.eq(P.Get(id).weights.STR, nil, "zero removes the weight")
        local sig2 = P.Resolve().sig
        T.eq(P.SetCustomWeights(id, { CRIT = 3, HIT = 0, AGI = "2" }), true)
        T.ok(P.Resolve().sig ~= sig2, "signature changes when all weights are replaced")
        T.eq(P.Get(id).weights.CRIT, 3) T.eq(P.Get(id).weights.HIT, nil) T.eq(P.Get(id).weights.AGI, 2)
        T.eq(P.RenameCustom(id, "Renamed"), true)
        T.eq(P.Name(P.Get(id)), "Renamed")
        T.eq(P.RenameCustom(id, ""), false)

        local found = false
        for _, s in ipairs(P.List("WARRIOR")) do if s.id == id then found = true end end
        T.ok(found, "listed for its class")
        found = false
        for _, s in ipairs(P.List("MAGE")) do if s.id == id then found = true end end
        T.no(found, "not listed for other classes")

        T.eq(P.DeleteCustom(id), true)
        T.eq(P.ActiveID(), "AUTO", "deleting the active profile returns to automatic")
        T.eq(P.Get(id), nil)
        T.eq(P.DeleteCustom(id), false)
    end)

    T.test("profiles: names and descriptions come from the language files", function()
        local W = T.world(F.ARMS)
        local P, S = W.EG.Profiles, W.EG.Specs
        T.eq(P.Name(S.BY_ID.WARRIOR_ARMS), "Arms (two-hand)")
        T.ok(#P.Desc(S.BY_ID.WARRIOR_ARMS) > 5)
        for id, spec in pairs(S.BY_ID) do
            T.ok(W.EG:LocaleHas("SPEC_" .. id), "name for " .. id)
            T.ok(P.Desc(spec) ~= "", "description for " .. id)
        end
    end)

    T.test("profiles: talent changes re-resolve the profile after a short delay", function()
        local W = T.world(F.ARMS)
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_ARMS")
        W.state.talents.points = { 5, 40, 0 }
        W.fire("PLAYER_TALENT_UPDATE")
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_ARMS", "cached until the debounce fires")
        W.flush()
        T.eq(W.EG.Profiles.Resolve().spec.id, "WARRIOR_FURY")
    end)
end
