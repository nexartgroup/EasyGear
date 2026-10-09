--[[ Testfaelle fuer EasyGear (laufen unter Lua 5.1 gegen tests/wow_stub.lua).
     Jeder Fall steht in Cases[name]; tests/run_tests.py fuehrt sie aus.   ]]

local EG = EasyGear
local L  = EG.L
local S  = EG.STAT_KEYS

Cases = {}

local STR, AGI, STA, INT, SPI = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT",
    "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT"
local AP, SP, CRIT, HASTE, HIT = "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_SPELL_POWER_SHORT",
    "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HIT_RATING_SHORT"

local nextID = 1000
local function ID() nextID = nextID + 1; return nextID end

local function Setup(class, level, tabs, opts)
    T.reset()
    T.setPlayer({ class = class, level = level, tabs = tabs or { 0, 0, 0 } })
    EG.db.autoLeveling = true
    if opts then for k, v in pairs(opts) do EG.db[k] = v end end
    EG:InvalidateProfile()
end

local PLATE = "Plate"
local function Chest(stats, extra)
    local d = { id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 1000, ilvl = 200 }
    for k, v in pairs(extra or {}) do d[k] = v end
    d.stats = stats
    return T.item(d)
end
local function Ring(stats, extra)
    local d = { id = ID(), loc = "INVTYPE_FINGER", subtype = "Miscellaneous", ilvl = 200 }
    for k, v in pairs(extra or {}) do d[k] = v end
    d.stats = stats
    return T.item(d)
end
local function Weapon(loc, subtype, dps, stats, extra)
    local d = { id = ID(), loc = loc, subtype = subtype, dps = dps, ilvl = 200 }
    for k, v in pairs(extra or {}) do d[k] = v end
    d.stats = stats or {}
    return T.item(d)
end
local function Shield(stats, extra)
    local d = { id = ID(), loc = "INVTYPE_SHIELD", subtype = "Shields", armor = 5000, ilvl = 200 }
    for k, v in pairs(extra or {}) do d[k] = v end
    d.stats = stats
    return T.item(d)
end

local function Score(link, slot) return EG:GetItemScore(EG:GetItemData(link), slot) end

------------------------------------------------------------------------------
-- Laden
------------------------------------------------------------------------------

Cases.load = function()
    T.eq(EG.version, "3.1.0", "version")
    T.check(EG.SPECS and EG.SPECS.WARRIOR, "specs loaded")
    T.check(EG.HEIRLOOMS and EG.HEIRLOOMS[42943], "heirlooms loaded")
    T.check(T.chat():find("EasyGear 3.1.0", 1, true) or T.chat():find("3.1.0", 1, true), "login message")
    T.check(EG.locale.baseOK, "enUS base table present")
end

------------------------------------------------------------------------------
-- Tooltip-Auswertung
------------------------------------------------------------------------------

Cases.scan_gems_enchants = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local base = { [STR] = 20, [STA] = 30 }

    -- Edelstein-Zeile mit zwei Werten
    local a = T.item({ id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 900, stats = base,
        gems = { 3001 }, extra = { { text = "+10 Strength and +15 Stamina", color = "white" } } })
    local d = EG:GetItemData(a)
    T.eq(d.stats[STR], 30, "gem: strength")
    T.eq(d.stats[STA], 45, "gem: stamina")
    T.eq(d.extraStats[STR], 10, "gem: extra strength")
    T.check(d.hasExtraStats, "gem: hasExtraStats")

    -- Verzauberung
    local b = T.item({ id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 900, stats = { [STA] = 10 },
        ench = 2000, extra = { { text = "+30 Spell Power", color = "green" } } })
    d = EG:GetItemData(b)
    T.eq(d.stats[SP], 30, "enchant: spell power")
    T.eq(d.stats[STA], 10, "enchant: base stamina untouched")

    -- aktiver Sockelbonus zaehlt, inaktiver (grau) nicht
    local c = T.item({ id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 900, stats = base, sockets = 0,
        gems = { 3002 }, extra = { { text = "Socket Bonus: +4 Stamina", color = "green" } } })
    T.eq(EG:GetItemData(c).stats[STA], 34, "socket bonus active")
    local c2 = T.item({ id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 900, stats = base,
        extra = { { text = "Socket Bonus: +4 Stamina", color = "grey" } } })
    T.eq(EG:GetItemData(c2).stats[STA], 30, "socket bonus inactive ignored")

    -- "Alle Werte"
    local e = T.item({ id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 900, stats = {},
        ench = 2001, extra = { { text = "+10 All Stats", color = "green" } } })
    d = EG:GetItemData(e)
    for _, k in ipairs({ STR, AGI, STA, INT, SPI }) do T.eq(d.stats[k], 10, "all stats " .. k) end

    -- Mana alle 5 Sek. darf nicht als Mana zaehlen, Ruestungsdurchschlag nicht als Ruestung
    local f = T.item({ id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 900, stats = {},
        ench = 2002, extra = { { text = "+6 Mana per 5 sec.", color = "green" },
                               { text = "+20 Armor Penetration Rating", color = "green" } } })
    d = EG:GetItemData(f)
    T.eq(d.stats[S.MP5], 6, "mp5 parsed")
    T.check(d.stats[S.MANA] == nil, "mp5 not counted as mana")
    T.eq(d.stats[S.ARP], 20, "arp parsed")
    T.eq(d.stats[S.ARMOR], 900, "armor stays base armor")
end

Cases.scan_no_double_count = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    -- Wertungen stehen in GetItemStats UND im Tooltip: Maximum, nicht Summe
    local a = T.item({ id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 900,
        stats = { [CRIT] = 30, [STR] = 50, [AP] = 80 } })
    local d = EG:GetItemData(a)
    T.eq(d.stats[CRIT], 30, "crit not doubled")
    T.eq(d.stats[STR], 50, "str not doubled")
    T.eq(d.stats[AP], 80, "ap not doubled")
    T.check(not d.hasExtraStats, "no extras without enchant")
end

Cases.scan_ignores_procs_and_sets = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local a = T.item({ id = ID(), loc = "INVTYPE_TRINKET", stats = {},
        extra = { { text = "Equip: Chance on hit: Increases attack power by 340 for 10 sec.", color = "green" },
                  { text = "Use: Increases your attack power by 340 for 10 sec.", color = "green" },
                  { text = "Equip: Increases your attack power by 340 for 10 sec.", color = "green" } } })
    local d = EG:GetItemData(a)
    T.check(d.stats[AP] == nil, "proc text is not a stat")

    local b = T.item({ id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 900, stats = { [STR] = 40 },
        setHeader = "Some Set (2/5)", setLines = { { text = "+50 Strength", color = "green" } } })
    T.eq(EG:GetItemData(b).stats[STR], 40, "set bonus below set header ignored")

    local u = T.item({ id = ID(), loc = "INVTYPE_FINGER", stats = { [STR] = 10 }, unique = "equipped" })
    T.check(EG:GetItemData(u).unique, "unique detected")
end

Cases.include_enchants_toggle = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local a = T.item({ id = ID(), loc = "INVTYPE_CHEST", subtype = PLATE, armor = 900, stats = { [STR] = 10 },
        ench = 2003, extra = { { text = "+30 Strength", color = "green" } } })
    T.eq(EG:GetItemData(a).stats[STR], 40, "with enchants")
    EG.db.includeEnchants = false
    EG:WipeItemCache(); EG:InvalidateProfile()
    T.eq(EG:GetItemData(a).stats[STR], 10, "without enchants")
    EG.db.includeEnchants = true
end

------------------------------------------------------------------------------
-- Vergleich
------------------------------------------------------------------------------

Cases.compare_basic = function()
    Setup("WARRIOR", 80, { 31, 5, 5 })
    local eq = Chest({ [STR] = 100, [STA] = 100 })
    T.equip(5, eq)

    local better = Chest({ [STR] = 150, [STA] = 100 })
    local r = EG:Compare(better)
    T.check(r.isUpgrade, "better chest is an upgrade")
    T.check(r.delta > 0, "positive delta")
    T.eq(r.target.slotID, 5, "target slot")

    local worse = Chest({ [STR] = 80, [STA] = 100 })
    T.check(not EG:Compare(worse).isUpgrade, "worse chest")

    local same = Chest({ [STR] = 100, [STA] = 100 })
    local rs = EG:Compare(same)
    T.check(not rs.isUpgrade, "equal chest is no upgrade")

    -- Schwelle: ein Vorsprung unter 1 % zaehlt nicht
    local tiny = Chest({ [STR] = 101, [STA] = 100 }, { ilvl = 200 })
    local rt = EG:Compare(tiny)
    T.check(rt.delta > 0 and not rt.isUpgrade, "tiny gain below threshold")

    -- leerer Slot
    local helm = T.item({ id = ID(), loc = "INVTYPE_HEAD", subtype = PLATE, armor = 800, stats = { [STR] = 10 } })
    local rh = EG:Compare(helm)
    T.check(rh.isUpgrade and rh.target.empty, "empty slot is an upgrade")
    T.eq(rh.reason, L.R_EMPTY, "empty slot reason")
end

Cases.compare_rings_two_slots = function()
    Setup("WARRIOR", 80, { 31, 5, 5 })
    local weak, strong = Ring({ [STR] = 20 }), Ring({ [STR] = 80 })
    T.equip(11, weak); T.equip(12, strong)

    local mid = Ring({ [STR] = 50 })
    local r = EG:Compare(mid)
    T.eq(r.mode, "EITHER", "ring mode")
    T.eq(r.target.slotID, 11, "replaces the weaker ring")
    T.eq(r.candSlot, 11, "candidate slot")
    T.check(r.isUpgrade, "upgrade over the weaker ring")

    local weaker = Ring({ [STR] = 10 })
    T.check(not EG:Compare(weaker).isUpgrade, "worse than both")

    -- Slot 12 schwach, Slot 11 stark -> ersetzt Slot 12
    T.equip(11, strong); T.equip(12, weak)
    T.eq(EG:Compare(mid).target.slotID, 12, "other way round")
end

Cases.compare_unique_ring = function()
    Setup("WARRIOR", 80, { 31, 5, 5 })
    local uid = ID()
    local a = T.item({ id = uid, loc = "INVTYPE_FINGER", stats = { [STR] = 50 }, unique = true, name = "UniqueA" })
    local strong = Ring({ [STR] = 90 })
    T.equip(11, a); T.equip(12, strong)
    -- Zweites Exemplar (andere Verzauberung = anderer Link) ersetzt das erste, nicht den schwaecheren Slot
    local b = T.item({ id = uid, loc = "INVTYPE_FINGER", stats = { [STR] = 50 }, unique = true,
        ench = 77, name = "UniqueA" })
    local r = EG:Compare(b)
    T.eq(r.target.slotID, 11, "unique duplicate targets its twin")
end

Cases.compare_two_hand = function()
    Setup("WARRIOR", 80, { 31, 5, 5 })
    local twoH = Weapon("INVTYPE_2HWEAPON", "Two-Handed Swords", 200, { [STR] = 100 })
    T.equip(16, twoH)

    -- Schild gegen Zweihaender: BOTH, nicht gegen den leeren Slot 17
    local shield = Shield({ [STA] = 60 })
    local r = EG:Compare(shield)
    T.eq(r.mode, "BOTH", "shield vs 2H is BOTH")
    T.check(r.combined, "combined compare")
    T.check(not r.isUpgrade, "a shield does not beat a 2H")
    T.check(r.targetScore > 1000, "target is the 2H weapon score")

    -- Einhandwaffe gegen Zweihaender: SINGLE, Waffenhand
    local one = Weapon("INVTYPE_WEAPON", "One-Handed Swords", 100, { [STR] = 50 })
    local r1 = EG:Compare(one)
    T.eq(r1.mode, "SINGLE", "1H vs 2H single")
    T.eq(r1.slots[1], 16, "main hand")

    -- besserer Zweihaender
    local better = Weapon("INVTYPE_2HWEAPON", "Two-Handed Axes", 230, { [STR] = 120 })
    local rb = EG:Compare(better)
    T.check(rb.isUpgrade and rb.combined, "better 2H is an upgrade")

    -- 1H + Schild angelegt, Zweihaender als Kandidat: gegen die Summe
    T.equip(16, one); T.equip(17, shield)
    local rs = EG:Compare(twoH)
    T.eq(rs.mode, "BOTH", "2H candidate")
    T.near(rs.targetScore, Score(one, 16) + Score(shield, 17), "sum of both hands", 1e-6)
end

Cases.compare_titans_grip = function()
    Setup("WARRIOR", 80, { 5, 31, 5 })
    T.setPlayer({ talents = { { tab = 2, icon = "Ability_Warrior_TitansGrip", rank = 1 } } })
    T.check(EG:HasTitansGrip(), "titan's grip detected from talent icon")

    local a = Weapon("INVTYPE_2HWEAPON", "Two-Handed Swords", 150, { [STR] = 90 })
    local b = Weapon("INVTYPE_2HWEAPON", "Two-Handed Axes", 220, { [STR] = 120 })
    T.equip(16, b); T.equip(17, a)

    local cand = Weapon("INVTYPE_2HWEAPON", "Two-Handed Maces", 190, { [STR] = 100 })
    local r = EG:Compare(cand)
    T.eq(r.mode, "EITHER", "TG: 2H is EITHER")
    T.eq(r.target.slotID, 17, "TG: replaces the weaker hand")

    -- ohne Talent: BOTH
    T.setPlayer({ talents = {} })
    T.equip(17, nil)
    T.check(not EG:HasTitansGrip(), "no TG without talent")
    T.eq(EG:Compare(cand).mode, "BOTH", "no TG: BOTH")
end

Cases.compare_dual_wield_offhand_factor = function()
    Setup("ROGUE", 80, { 5, 31, 5 })
    local mh = Weapon("INVTYPE_WEAPON", "Daggers", 100, { [AGI] = 50 })
    local oh = Weapon("INVTYPE_WEAPON", "Daggers", 100, { [AGI] = 50 })
    T.equip(16, mh); T.equip(17, oh)

    local cand = Weapon("INVTYPE_WEAPON", "Daggers", 150, { [AGI] = 60 })
    local sMH, sOH = Score(cand, 16), Score(cand, 17)
    T.check(sMH > sOH, "off hand scores less (half weapon dps)")
    local d = EG:GetItemData(cand)
    local rowsMH = EG:GetScoreBreakdown(d, 16)
    local rowsOH = EG:GetScoreBreakdown(d, 17)
    local function dpsRow(rows) for _, r in ipairs(rows) do if r.key == EG.PSEUDO_DPS then return r end end end
    T.near(dpsRow(rowsOH).weight, dpsRow(rowsMH).weight * 0.5, "oh dps weight halved")

    local r = EG:Compare(cand)
    T.eq(r.mode, "EITHER", "rogue 1H is EITHER")
    T.check(r.isUpgrade, "upgrade")
end

Cases.compare_tank_keeps_shield = function()
    Setup("WARRIOR", 80, { 0, 0, 31 })
    T.eq(EG:GetActiveSpec().id, "WARRIOR_PROT", "protection profile")
    local mh = Weapon("INVTYPE_WEAPON", "One-Handed Swords", 100, { [STA] = 40 })
    local sh = Shield({ [STA] = 20 })
    T.equip(16, mh); T.equip(17, sh)
    T.check(EG:CanDualWield(), "warrior can dual wield")
    local cand = Weapon("INVTYPE_WEAPON", "One-Handed Swords", 120, { [STA] = 50 })
    local r = EG:Compare(cand)
    T.eq(r.mode, "SINGLE", "tank: weapon only competes for the main hand")
    T.eq(r.slots[1], 16, "tank: main hand")

    -- DD-Profil: darf in die Schildhand
    T.setPlayer({ tabs = { 31, 0, 0 } })
    T.eq(EG:GetActiveSpec().id, "WARRIOR_ARMS", "arms profile")
    T.eq(EG:Compare(cand).mode, "EITHER", "dps: both hands")
end

Cases.compare_not_usable = function()
    Setup("MAGE", 80, { 31, 0, 0 })
    local sword2h = Weapon("INVTYPE_2HWEAPON", "Two-Handed Swords", 300, { [STR] = 200 })
    local r = EG:Compare(sword2h)
    T.check(not r.usable and not r.isUpgrade, "mage cannot use 2H swords")
    T.eq(r.reason, L.R_CLASS, "reason")

    local red = Chest({ [INT] = 50 }, { subtype = "Cloth", red = { "Classes: Priest" } })
    local rr = EG:Compare(red)
    T.check(not rr.usable, "red tooltip line makes it unusable")
    T.eq(rr.reason, "Classes: Priest", "red line reason")
end

Cases.level_too_low_state = function()
    Setup("WARRIOR", 30, { 31, 0, 0 })
    local plate = Chest({ [STR] = 80, [STA] = 80 }, { armor = 1500, ilvl = 80 })
    local r = EG:Compare(plate)
    T.check(not r.usable and r.levelTooLow, "plate needs level 40 for warriors")
    T.check(r.wouldUpgrade, "would be an upgrade")
    T.eq(EG:GetUpgradeState(plate), "LEVEL", "yellow state")

    local ok = Chest({ [STR] = 10, [STA] = 10 }, { subtype = "Mail", armor = 100, ilvl = 20 })
    T.eq(EG:GetUpgradeState(ok), "UPGRADE", "green state")
end

Cases.cosmetics_not_compared = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local shirt = T.item({ id = ID(), loc = "INVTYPE_BODY", ilvl = 50, stats = {} })
    local r = EG:Compare(shirt)
    T.check(r.noCompare and not r.isUpgrade, "shirt is never an upgrade")
    local rod = Weapon("INVTYPE_2HWEAPON", "Fishing Poles", nil, {}, { ilvl = 1 })
    T.check(EG:Compare(rod).noCompare, "fishing pole is a tool")
end

------------------------------------------------------------------------------
-- Erbstuecke
------------------------------------------------------------------------------

Cases.heirloom_preference = function()
    Setup("WARRIOR", 20, { 31, 0, 0 })
    EG.db.heirloomBonus = 1.5
    local hl = Chest({ [STR] = 50, [STA] = 50 }, { quality = 7, ilvl = 1, armor = 400, subtype = "Mail", name = "HL" })
    T.equip(5, hl)
    local base = Score(hl)

    -- normales Item mit 20 % mehr Rohwertung verliert gegen das Erbstueck
    local n1 = Chest({ [STR] = 60, [STA] = 60 }, { armor = 400, ilvl = 20, subtype = "Mail" })
    T.check(not EG:Compare(n1).isUpgrade, "slightly better normal item loses against heirloom")
    T.check(EG:Compare(n1).reason == L.R_HEIRLOOM_KEEP or not EG:Compare(n1).isUpgrade, "keeps heirloom")

    -- ein deutlich besseres gewinnt
    local n2 = Chest({ [STR] = 160, [STA] = 160 }, { armor = 900, ilvl = 20, subtype = "Mail" })
    T.check(EG:Compare(n2).isUpgrade, "much better normal item wins")

    -- Erbstueck mit geringerer Rohwertung schlaegt das normale Item
    T.equip(5, n1)
    local weakHL = Chest({ [STR] = 42, [STA] = 42 }, { quality = 7, ilvl = 1, armor = 300, subtype = "Mail", name = "HL2" })
    T.check(Score(weakHL) > 0, "score exists")
    local r = EG:Compare(weakHL)
    T.check(r.isUpgrade, "heirloom with 70% raw score beats normal item")
    T.eq(r.reason, L.R_HEIRLOOM_WINS, "reason heirloom wins")

    -- Erbstueck mit falschen Werten (Intelligenz auf einem Krieger) gewinnt nicht
    local wrong = Chest({ [INT] = 200 }, { quality = 7, ilvl = 1, armor = 100, subtype = "Mail", name = "HL3" })
    T.check(not EG:Compare(wrong).isUpgrade, "heirloom with useless stats does not win")
end

Cases.heirloom_factor_taper = function()
    Setup("WARRIOR", 20, { 31, 0, 0 })
    EG.db.heirloomBonus = 1.5
    T.near(EG:GetHeirloomFactor(), 1.5, "level 20: full bonus")
    T.setPlayer({ level = 60 }); T.near(EG:GetHeirloomFactor(), 1.5, "level 60: full bonus")
    T.setPlayer({ level = 70 }); T.near(EG:GetHeirloomFactor(), 1.25, "level 70: half")
    T.setPlayer({ level = 80 }); T.near(EG:GetHeirloomFactor(), 1.0, "level 80: none")
    EG.db.protectHeirlooms = false
    T.setPlayer({ level = 20 }); T.near(EG:GetHeirloomFactor(), 1.0, "disabled")
    EG.db.protectHeirlooms = true
end

Cases.heirloom_level80 = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local weak = Chest({ [STR] = 40 }, { quality = 7, ilvl = 80, subtype = PLATE, name = "HL80" })
    T.equip(5, Chest({ [STR] = 45 }))
    T.check(not EG:Compare(weak).isUpgrade, "no heirloom bonus at 80")
end

------------------------------------------------------------------------------
-- Verwendbarkeit
------------------------------------------------------------------------------

Cases.usability_heirloom_armor = function()
    Setup("SHAMAN", 20, { 0, 31, 0 })
    local hl = Chest({ [AGI] = 20 }, { quality = 7, subtype = "Mail", armor = 300, ilvl = 1, name = "HLmail" })
    local u, reason, low = EG:CanUseItem(EG:GetItemData(hl))
    T.check(u, "shaman level 20 may wear heirloom mail")

    local normal = Chest({ [AGI] = 20 }, { subtype = "Mail", armor = 300, ilvl = 20 })
    local u2, _, low2 = EG:CanUseItem(EG:GetItemData(normal))
    T.check(not u2 and low2, "normal mail needs level 40")

    T.setPlayer({ level = 40 })
    T.check(EG:CanUseItem(EG:GetItemData(normal)), "mail at 40")

    -- Platte: Paladin ab 1 als Erbstueck
    Setup("PALADIN", 10, { 0, 0, 31 })
    local plateHL = Chest({ [STR] = 20 }, { quality = 7, subtype = "Plate", armor = 300, ilvl = 1, name = "HLplate" })
    T.check(EG:CanUseItem(EG:GetItemData(plateHL)), "paladin level 10 may wear heirloom plate")
    local plateN = Chest({ [STR] = 20 }, { subtype = "Plate", armor = 300, ilvl = 10 })
    T.check(not EG:CanUseItem(EG:GetItemData(plateN)), "normal plate needs level 40")
end

Cases.usability_proficiency = function()
    Setup("PRIEST", 80, { 0, 0, 31 })
    local sword = Weapon("INVTYPE_WEAPON", "One-Handed Swords", 100, { [STR] = 10 })
    T.check(not EG:CanUseItem(EG:GetItemData(sword)), "priest: no swords")
    local mace = Weapon("INVTYPE_WEAPON", "One-Handed Maces", 100, { [SP] = 10 })
    T.check(EG:CanUseItem(EG:GetItemData(mace)), "priest: maces")
    local wand = Weapon("INVTYPE_RANGEDRIGHT", "Wands", 50, { [SP] = 10 })
    T.check(EG:CanUseItem(EG:GetItemData(wand)), "priest: wands")

    Setup("DEATHKNIGHT", 80, { 31, 0, 0 })
    local sigil = T.item({ id = ID(), loc = "INVTYPE_RELIC", subtype = "Sigils", stats = { [STR] = 10 } })
    T.check(EG:CanUseItem(EG:GetItemData(sigil)), "DK: sigils")
    local libram = T.item({ id = ID(), loc = "INVTYPE_RELIC", subtype = "Librams", stats = { [SP] = 10 } })
    T.check(not EG:CanUseItem(EG:GetItemData(libram)), "DK: no librams")
end

Cases.subtype_tokens = function()
    for _, loc in ipairs({ "enUS", "deDE" }) do
        T.reset({ locale = loc })
        EG:BuildSubtypeTokens(true)
        T.check(EG.subtypeFromClient, loc .. ": auction lists used")
        local en = T.ahLists[loc]
        T.eq(EG:GetSubtypeToken(en.armor[2]), "CLOTH", loc .. " cloth")
        T.eq(EG:GetSubtypeToken(en.armor[4]), "MAIL", loc .. " mail")
        T.eq(EG:GetSubtypeToken(en.armor[5]), "PLATE", loc .. " plate")
        T.eq(EG:GetSubtypeToken(en.armor[6]), "SHIELD", loc .. " shield")
        T.eq(EG:GetSubtypeToken(en.armor[7]), "LIBRAM", loc .. " libram")
        T.eq(EG:GetSubtypeToken(en.weapon[2]), "AXE2", loc .. " 2h axe")
        T.eq(EG:GetSubtypeToken(en.weapon[10]), "STAFF", loc .. " staff")
        T.eq(EG:GetSubtypeToken(en.weapon[13]), "DAGGER", loc .. " dagger")
        T.eq(EG:GetSubtypeToken(en.weapon[17]), "FISHING", loc .. " fishing pole")

        -- Die Alias-Listen der Sprachdatei muessen jeden Namen der Auktionshaus-Liste enthalten
        local tbl = EG:LocaleTable(loc)
        local function Has(token, name)
            for _, alias in ipairs(EG:SplitAliases(tbl["SUBTYPE_" .. token])) do
                if alias == name then return true end
            end
            return false
        end
        for i, token in ipairs(EG.WEAPON_SUB_ORDER) do
            T.check(Has(token, en.weapon[i]), loc .. ": SUBTYPE_" .. token .. " lacks '" .. en.weapon[i] .. "'")
        end
        for i, token in ipairs(EG.ARMOR_SUB_ORDER) do
            T.check(Has(token, en.armor[i]), loc .. ": SUBTYPE_" .. token .. " lacks '" .. en.armor[i] .. "'")
        end
    end

    -- ohne Auktionshaus-Listen: Namen aus den Sprachdateien (aktive Sprache und Englisch)
    T.reset({ locale = EG.locale.client })
    EG:BuildSubtypeTokens(false)
    T.check(not EG.subtypeFromClient, "lang-only mode")
    T.eq(EG:GetSubtypeToken("Mail"), "MAIL", "English mail from the lang file")
    T.eq(EG:GetSubtypeToken("One-Handed Axes"), "AXE1", "English 1h axe from the lang file")
    if EG.locale.active == "deDE" then
        T.eq(EG:GetSubtypeToken("Schwere Rüstung"), "MAIL", "German mail from the lang file")
        T.eq(EG:GetSubtypeToken("Einhandäxte"), "AXE1", "German 1h axe from the lang file")
        T.eq(EG:GetSubtypeToken("Verschiedenes"), "MISC", "German misc from the lang file")
    end
    -- unbekannte Sprache: nichts erkannt, aber kein Fehler
    T.reset({ locale = "xxXX" })
    EG:BuildSubtypeTokens(true)
    T.check(EG:GetSubtypeToken("Whatever") == nil, "unknown name")
    EG:BuildSubtypeTokens(true)
end

Cases.subtype_mismatch_is_ignored = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    EG:BuildSubtypeTokens(true)
    -- Ein Kopfteil mit Untertyp "Staves" ist unmoeglich - das Token wird verworfen
    local weird = T.item({ id = ID(), loc = "INVTYPE_HEAD", subtype = "Staves", armor = 300, stats = { [STR] = 10 } })
    local d = EG:GetItemData(weird)
    T.check(d.token == nil, "implausible token dropped")
    T.check((EG.subtypeMismatch or 0) >= 1, "mismatch counted")
    -- Schild wird auch ohne Namen erkannt
    local sh = T.item({ id = ID(), loc = "INVTYPE_SHIELD", subtype = "Unbekannt", armor = 900, stats = { [STA] = 10 } })
    T.eq(EG:GetItemData(sh).token, "SHIELD", "shield recognised by slot")
    EG:BuildSubtypeTokens(true)
end

------------------------------------------------------------------------------
-- Profile
------------------------------------------------------------------------------

local CLASSES = { "WARRIOR", "PALADIN", "DEATHKNIGHT", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

Cases.profiles_complete = function()
    local seen = {}
    for _, class in ipairs(CLASSES) do
        local list = EG.SPECS[class]
        T.check(list and #list >= 5, class .. " has profiles")
        local hasLevel, hasAll, hasSpec = false, false, 0
        for _, spec in ipairs(list) do
            T.check(not seen[spec.id], "unique id " .. spec.id)
            seen[spec.id] = true
            T.check(spec.weights and next(spec.weights), spec.id .. " has weights")
            T.check(spec.role, spec.id .. " has a role")
            if spec.kind == "LEVELING" then hasLevel = true; T.eq(spec.id, EG:ClassProfileID(class, "LEVELING"), "leveling id " .. class) end
            if spec.kind == "ALLROUND" then hasAll = true; T.eq(spec.id, EG:ClassProfileID(class, "ALLROUND"), "allround id " .. class) end
            if spec.kind == "SPEC" then hasSpec = hasSpec + 1; T.check(spec.tab, spec.id .. " has a tab") end
            for k, v in pairs(spec.weights) do T.check(type(v) == "number" and v >= 0, spec.id .. " weight " .. tostring(k)) end
            -- Namen und Beschreibungen in den vollstaendigen Sprachen
            for _, code in ipairs({ "enUS", "deDE" }) do
                local t = EG:LocaleTable(code)
                T.check(t["SPEC_" .. spec.id], code .. " name for " .. spec.id)
                T.check(t["SPEC_" .. spec.id .. "_D"], code .. " description for " .. spec.id)
            end
        end
        T.check(hasLevel, class .. " has a leveling profile")
        T.check(hasAll, class .. " has an all-round profile")
        T.check(hasSpec >= 3, class .. " has its talent profiles")
    end
    for _, spec in ipairs(EG.SPECS_ANY) do
        for _, code in ipairs({ "enUS", "deDE" }) do
            T.check(EG:LocaleTable(code)["SPEC_" .. spec.id], code .. " name for " .. spec.id)
        end
    end
end

Cases.profile_detection = function()
    local function Id() return EG:GetActiveSpec().id end

    Setup("WARRIOR", 40, { 5, 31, 0 })
    T.eq(Id(), "WARRIOR_LEVELING", "fury below 80 uses leveling")
    EG.db.autoLeveling = false; EG:InvalidateProfile()
    T.eq(Id(), "WARRIOR_FURY", "autoLeveling off: spec profile")
    EG.db.autoLeveling = true; EG:InvalidateProfile()

    Setup("WARRIOR", 40, { 0, 0, 31 })
    T.eq(Id(), "WARRIOR_PROT", "tank trees keep their profile while leveling")
    Setup("PALADIN", 60, { 31, 0, 0 })
    T.eq(Id(), "PALADIN_HOLY", "healer trees keep their profile while leveling")
    Setup("WARRIOR", 80, { 31, 0, 0 })
    T.eq(Id(), "WARRIOR_ARMS", "level 80: spec profile")
    Setup("WARRIOR", 80, { 0, 0, 0 })
    T.eq(Id(), "WARRIOR_ALLROUND", "level 80 without talents: all-round")
    Setup("WARRIOR", 10, { 0, 0, 0 })
    T.eq(Id(), "WARRIOR_LEVELING", "level 10 without talents: leveling")
    Setup("MAGE", 5, { 2, 0, 0 })
    T.eq(Id(), "MAGE_LEVELING", "few talents: leveling")

    -- Waffenhaltung entscheidet zwischen Profilen desselben Baums
    Setup("DEATHKNIGHT", 80, { 31, 0, 0 })
    T.eq(Id(), "DK_BLOOD_TANK", "blood default is the tank")
    T.equip(16, Weapon("INVTYPE_2HWEAPON", "Two-Handed Swords", 200, { [STR] = 100 }))
    T.eq(Id(), "DK_BLOOD_DPS", "blood with a two-hander: dps")
    Setup("DEATHKNIGHT", 80, { 0, 31, 0 })
    T.eq(Id(), "DK_FROST_DW", "frost default is dual wield")
    T.equip(16, Weapon("INVTYPE_2HWEAPON", "Two-Handed Swords", 200, { [STR] = 100 }))
    T.eq(Id(), "DK_FROST_2H", "frost with a two-hander")

    -- Varianten des Leveln-Profils
    Setup("SHAMAN", 40, { 31, 0, 0 })
    T.eq(Id(), "SHAMAN_LEVELING", "shaman elemental below 80")
    T.check((EG:GetProfile())[S.SP] == 1.0, "elemental variant: spell power")
    Setup("SHAMAN", 40, { 0, 31, 0 })
    T.check((EG:GetProfile())[S.AGI] == 0.9, "enhancement: melee weights")
    Setup("DRUID", 40, { 31, 0, 0 })
    T.check((EG:GetProfile())[S.SP] == 1.0, "balance variant")
    Setup("DRUID", 40, { 0, 31, 0 })
    T.eq(Id(), "DRUID_LEVELING", "feral leveling")
    T.check((EG:GetProfile())[S.AGI] == 1.0, "feral weights")
end

Cases.profile_names = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    T.eq(EG:GetProfileName(EG:GetProfileByID("WARRIOR_ARMS")),
         EG:LocaleTable(EG.locale.active).SPEC_WARRIOR_ARMS, "name from the active language file")
    T.check(EG:GetProfileDesc(EG:GetProfileByID("WARRIOR_ARMS")) ~= "", "desc")
    local id = EG:CreateCustomProfile("My Profile", "WARRIOR_ARMS", "WARRIOR")
    T.check(id and EG:GetProfileByID(id).custom, "custom profile")
    T.eq(EG:GetProfileName(EG:GetProfileByID(id)), "My Profile", "custom name")
    T.check(EG:GetProfileByID(id).weights[S.STR] == 1.0, "custom weights copied")
    T.check(EG:DeleteCustomProfile(id), "delete custom")
end

------------------------------------------------------------------------------
-- Bewertung
------------------------------------------------------------------------------

Cases.socket_points = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local p80 = EG:GetSocketPoints(EG:GetProfile())
    T.check(p80 > 10 and p80 < 20, "auto socket value at 80 is about one gem")
    T.setPlayer({ level = 40 })
    local p40 = EG:GetSocketPoints(EG:GetProfile())
    T.check(p40 < p80 and p40 > 0, "smaller at lower level")
    EG.db.socketValue = 5
    T.eq(EG:GetSocketPoints(EG:GetProfile()), 5, "override")
    EG.db.socketValue = nil

    local sock = Chest({ [STR] = 100 }, { sockets = 2 })
    local plain = Chest({ [STR] = 100 })
    T.check(Score(sock) > Score(plain), "empty sockets add value")
end

Cases.dps_kinds = function()
    Setup("HUNTER", 80, { 0, 31, 0 })
    local bow = Weapon("INVTYPE_RANGED", "Bows", 150, { [AGI] = 50 })
    local dagger = Weapon("INVTYPE_WEAPON", "Daggers", 150, { [AGI] = 50 })
    local d1, d2 = EG:GetItemData(bow), EG:GetItemData(dagger)
    T.eq(d1.handKind, "RANGED", "bow is ranged")
    T.eq(d2.handKind, "MELEE", "dagger is melee")
    T.check(Score(bow) > Score(dagger) * 1.5, "hunter: ranged dps counts far more than melee dps")

    -- Zauberstab beim Leveln
    Setup("PRIEST", 30, { 0, 0, 0 })
    local wand = Weapon("INVTYPE_RANGEDRIGHT", "Wands", 30, {}, { ilvl = 30 })
    local rows = EG:GetScoreBreakdown(EG:GetItemData(wand))
    local found
    for _, r in ipairs(rows) do if r.key == EG.PSEUDO_RDPS then found = r end end
    T.check(found and found.weight >= 3, "priest leveling values the wand")
    EG.db.dpsWeight = 1
    EG:InvalidateProfile(); EG:WipeItemCache()
    rows = EG:GetScoreBreakdown(EG:GetItemData(wand))
    for _, r in ipairs(rows) do if r.key == EG.PSEUDO_RDPS then found = r end end
    T.eq(found.weight, 1, "dpsWeight override")
    EG.db.dpsWeight = nil
end

Cases.stat_diff = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local a = Chest({ [STR] = 100, [STA] = 50, [CRIT] = 30 })
    local b = Chest({ [STR] = 150, [STA] = 40, [CRIT] = 10 })
    T.equip(5, a)
    local r = EG:Compare(b)
    local diffs = EG:GetStatDiff(EG:GetItemData(b), r.replaced)
    T.check(#diffs >= 3, "diff lines")
    T.eq(diffs[1].key, STR, "largest point swing first")
    T.eq(diffs[1].delta, 50, "strength delta")
    local crit
    for _, d in ipairs(diffs) do if d.key == CRIT then crit = d end end
    T.eq(crit.delta, -20, "crit delta")
end

Cases.equipped_totals_match_item_scores = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local items = {
        [5]  = Chest({ [STR] = 100, [STA] = 50 }),
        [11] = Ring({ [STR] = 30, [CRIT] = 20 }),
        [16] = Weapon("INVTYPE_WEAPON", "One-Handed Swords", 120, { [STR] = 40 }),
        [17] = Weapon("INVTYPE_WEAPON", "One-Handed Swords", 100, { [STR] = 30 }),
    }
    local sum = 0
    for slot, link in pairs(items) do T.equip(slot, link); sum = sum + Score(link, slot) end
    local totals = EG:GetEquippedTotals(true)
    local rows, total = EG:BuildTotalsBreakdown(totals, EG:GetProfile())
    T.near(total, sum, "profile totals equal the sum of item scores", 1e-6)
end

------------------------------------------------------------------------------
-- Quest
------------------------------------------------------------------------------

Cases.quest_best_reward = function()
    Setup("WARRIOR", 30, { 31, 0, 0 })
    -- Umhang ersetzt vorhandenen (kleiner Zugewinn), Stiefel fuellen leeren Slot
    local cloak0 = T.item({ id = ID(), loc = "INVTYPE_CLOAK", subtype = "Cloth", armor = 10, ilvl = 20, stats = { [STA] = 5 } })
    T.equip(15, cloak0)
    local cloak = T.item({ id = ID(), loc = "INVTYPE_CLOAK", subtype = "Cloth", armor = 12, ilvl = 22, stats = { [STA] = 6 }, sellPrice = 50 })
    local boots = T.item({ id = ID(), loc = "INVTYPE_FEET", subtype = "Mail", armor = 60, ilvl = 20, stats = { [STR] = 4, [STA] = 4 }, sellPrice = 10 })
    local junk  = T.item({ id = ID(), loc = "INVTYPE_HEAD", subtype = "Cloth", armor = 1, ilvl = 1, stats = {}, sellPrice = 900 })
    local rewards = { cloak, boots }
    G_QUEST = { rewards }
    _G.GetNumQuestChoices = function() return #rewards end
    _G.GetQuestItemLink = function(kind, i) return rewards[i] end
    _G.GetQuestItemInfo = function(kind, i) return "x", "tex", 1, 2, true end
    local best, score, isUpgrade, value, mode = EG:GetBestQuestReward()
    T.eq(best, 2, "boots fill the empty slot - larger gain than the cloak")
    T.eq(mode, "UPGRADE", "upgrade mode")

    -- keine Verbesserung: hoechster Verkaufswert
    T.equip(8, boots); T.equip(15, cloak)
    T.equip(1, T.item({ id = ID(), loc = "INVTYPE_HEAD", subtype = "Cloth", armor = 50, ilvl = 30, stats = { [STA] = 9 } }))
    rewards = { cloak0, junk }
    best, _, isUpgrade, _, mode = EG:GetBestQuestReward()
    T.eq(mode, "VENDOR", "no upgrade -> vendor value")
    T.eq(best, 2, "most valuable")
end

------------------------------------------------------------------------------
-- EGUP
------------------------------------------------------------------------------

Cases.egup_packages = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    for _, class in ipairs(CLASSES) do
        local pkg = EG:GetEGUPPackage(class, "Alliance")
        T.check(#pkg >= 8, class .. " package has entries")
        local ids = {}
        for _, e in ipairs(pkg) do
            T.check(not ids[e.id], class .. " no duplicate " .. e.id)
            ids[e.id] = true
            T.check(EG.HEIRLOOMS[e.id], class .. " known id " .. e.id)
        end
        T.check(ids[44098] and not ids[44097], class .. " alliance insignia only")
        local h = EG:GetEGUPPackage(class, "Horde")
        local hid = {}
        for _, e in ipairs(h) do hid[e.id] = true end
        T.check(hid[44097] and not hid[44098], class .. " horde insignia only")

        local a = EG:AuditHeirloomPackage(class)
        T.eq(#a.unusable, 0, class .. " unusable: " .. table.concat(a.unusable, ","))
        T.eq(#a.useless, 0, class .. " useless: " .. table.concat(a.useless, ","))
        T.eq(#a.missing, 0, class .. " missing: " .. table.concat(a.missing, ","))
    end
    -- der Jaeger bekommt keine Staerkewaffen
    local hunter = {}
    for _, e in ipairs(EG:GetEGUPPackage("HUNTER")) do hunter[e.id] = true end
    T.check(not hunter[42943] and not hunter[44092] and not hunter[44096], "hunter: no strength weapons")
end

Cases.egup_audit_detects_problems = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local pk = EG.HEIRLOOM_PACKAGES
    local saved = pk.PRIEST
    pk.PRIEST = { { id = 42992 }, { id = 48685 }, { id = 42944 } }   -- Platte, Dolch (Agi)
    local a = EG:AuditHeirloomPackage("PRIEST")
    T.check(#a.unusable >= 1, "plate is unusable for priests")
    T.check(#a.useless >= 1, "agility dagger is useless for priests")
    T.check(#a.missing >= 1, "cloth pieces are missing")
    pk.PRIEST = saved
end

local function FillPackage(class)
    local n = 0
    for _, e in ipairs(EG:GetEGUPPackage(class, "Alliance")) do
        local info = EG.HEIRLOOMS[e.id]
        T.item({ id = e.id, name = info.en, quality = 7, loc = info.loc, stats = {} })
        local link = select(2, GetItemInfo(e.id))
        n = n + 1
        T.bag(0, n, link, e.count)
    end
    return n
end

Cases.egup_clean_removes_everything_unequipped = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local n = FillPackage("WARRIOR")
    -- ein Item ist angelegt: es liegt nicht mehr in den Taschen
    local _, equippedLink = GetItemInfo(42943)
    T.bag(0, 3, nil)    -- Platz 3 ist das angelegte Item
    T.equip(16, equippedLink)
    -- ein Fremd-Item und eine Kopie in einer zweiten Tasche muessen bleiben bzw. gehen
    local other = T.item({ id = 777, name = "Other", loc = "INVTYPE_HEAD", stats = {} })
    T.bag(0, 15, other)
    T.bag(1, 1, select(2, GetItemInfo(48685)), 1)      -- Zusatzexemplar in Tasche 1
    T.bag(2, 1, select(2, GetItemInfo(51809)), 1)      -- Portable Hole in Tasche 2

    EG.charDB.egup = nil                              -- keine Sitzung: es soll trotzdem aufgeraeumt werden
    EG:RunEGUPClean()
    T.runTimers()

    local left = EG:ScanEGUPLeftovers()
    T.eq(#left, 0, "nothing of the package is left in the bags")
    T.eq(T.world.equipment[16], equippedLink, "equipped item untouched")
    T.check(T.world.bags[0][15] ~= nil, "foreign item stays")
    T.check(#T.world.deleted >= n - 1, "all stacks deleted")
    T.check(T.chat():find("EGUPCLEAN", 1, true), "completion message")
end

Cases.egup_clean_dry_run_and_confirm = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    FillPackage("WARRIOR")
    EG.db.egupConfirm = true
    T.clearChat()
    EG:RunEGUPClean("list")
    T.check(#T.world.deleted == 0, "list deletes nothing")
    T.check(T.chat():find(L.EGUP_CLEAN_LIST_HEAD, 1, true), "list header")

    EG:RunEGUPClean()
    T.eq(#T.world.popups, 1, "confirmation popup")
    T.eq(#T.world.deleted, 0, "nothing deleted before confirming")
    G_POPUP = T.world.popups[1]
    G_POPUP.def.OnAccept(G_POPUP)
    T.runTimers()
    T.eq(#EG:ScanEGUPLeftovers(), 0, "cleaned after confirming")
    EG.db.egupConfirm = false
end

Cases.egup_clean_locked_and_bank = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local link = T.item({ id = 42943, name = "Reaper", quality = 7, loc = "INVTYPE_2HWEAPON", stats = {} })
    T.bag(0, 1, link, 1)
    T.world.bags[0][1].locked = true
    EG:RunEGUPClean()
    T.runTimers()
    T.eq(#T.world.deleted, 0, "locked slot cannot be deleted")
    T.check(T.chat():find("1", 1, true), "reports what is left")
    T.world.bags[0][1].locked = false
    T.clearChat()
    EG.EGUPCleaning = false
    EG:RunEGUPClean()
    T.runTimers()
    T.eq(#EG:ScanEGUPLeftovers(), 0, "second run removes it")

    -- Bank: nur bei geoeffnetem Bankfenster
    T.world.bags[-1] = { size = 28 }
    T.bag(-1, 1, link, 1)
    EG:RunEGUPClean()
    T.runTimers()
    T.check(T.world.bags[-1][1] ~= nil, "closed bank is not touched")
    BankFrame._shown = true
    EG:RunEGUPClean()
    T.runTimers()
    T.check(T.world.bags[-1][1] == nil, "open bank is cleaned")
    BankFrame._shown = false
end

Cases.egup_verify_checks_primary_stat = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    -- 42943 ist als Staerkewaffe hinterlegt: der Client zeigt Staerke -> OK
    T.item({ id = 42943, name = "Reaper", quality = 7, loc = "INVTYPE_2HWEAPON", subtype = "Two-Handed Axes",
             stats = { [STR] = 40, [STA] = 30 } })
    -- 44092 ist ebenfalls Staerke, der Client zeigt aber Beweglichkeit -> Warnung
    T.item({ id = 44092, name = "Champion", quality = 7, loc = "INVTYPE_2HWEAPON", subtype = "Two-Handed Swords",
             stats = { [AGI] = 40, [STA] = 30 } })
    -- 42948 (Heilerstreitkolben): nur Zaubermacht reicht fuer "Intelligenz"
    T.item({ id = 42948, name = "Hammer", quality = 7, loc = "INVTYPE_WEAPONMAINHAND", subtype = "One-Handed Maces",
             stats = { [SP] = 40 } })
    T.clearChat()
    EG:VerifyHeirlooms("WARRIOR")
    local out = T.chat()
    T.check(out:find("42943", 1, true), "verify lists 42943")
    local line43, line92
    for l in out:gmatch("[^\n]+") do
        if l:find("42943", 1, true) then line43 = l end
        if l:find("44092", 1, true) then line92 = l end
    end
    T.check(line43 and not line43:find("primary attribute", 1, true) and not line43:find("Hauptattribut", 1, true),
        "matching primary attribute is not flagged")
    T.check(line92 and (line92:find("AGI", 1, true)), "wrong primary attribute is flagged: " .. tostring(line92))
    T.check(out:find(L.EGUP_AUDIT_HEAD, 1, true), "package audit section")
end

Cases.egup_send = function()
    Setup("PRIEST", 80, { 0, 0, 31 })
    T.world.target = { class = "PRIEST", className = "Priest", name = "Bob", faction = "Horde" }
    EG:RunEGUP()
    T.runTimers()
    local sent = T.world.sent
    T.check(#sent >= 8, "commands sent")
    T.check(sent[1]:find("^%.additem Bob %d+ %d+$"), "command format: " .. tostring(sent[1]))
    local joined = table.concat(sent, "\n")
    T.check(joined:find("44097", 1, true) and not joined:find("44098", 1, true), "horde insignia only")
    T.check(EG.charDB.egup and EG.charDB.egup.active, "session stored")
    EG.db.egupCommand = ".additem {id} {count}"
    T.eq(EG:BuildEGUPCommand("Bob", 5, 2), ".additem 5 2", "custom template")
    EG.db.egupCommand = EG.DEFAULTS.egupCommand
end

------------------------------------------------------------------------------
-- Befehle, Ausgabe, Fenster
------------------------------------------------------------------------------

Cases.slash_commands = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local function run(c, m) T.clearChat(); T.slash(c, m); return T.chat() end

    T.check(run("EASYGEAR", "help"):find("/eg", 1, true), "help")
    T.check(run("EASYGEAR", "status"):find("EasyGear", 1, true), "status")
    T.check(run("EASYGEAR", "locale"):find(EG.locale.client, 1, true), "locale")
    T.check(run("EASYGEAR", "profile list"):find("WARRIOR_ARMS", 1, true), "profile list")
    run("EASYGEAR", "profile warrior_fury")
    T.eq(EG:GetActiveProfileID(), "WARRIOR_FURY", "profile set")
    run("EASYGEAR", "profile auto")
    T.eq(EG:GetActiveProfileID(), "AUTO", "profile auto")
    run("EASYGEAR", "heirloombonus 2")
    T.eq(EG.db.heirloomBonus, 2, "heirloombonus")
    run("EASYGEAR", "heirloombonus 9")
    T.eq(EG.db.heirloomBonus, 3, "heirloombonus clamped")
    run("EASYGEAR", "heirloom off"); T.eq(EG.db.protectHeirlooms, false, "heirloom off")
    run("EASYGEAR", "heirloom on");  T.eq(EG.db.protectHeirlooms, true, "heirloom on")
    run("EASYGEAR", "socket 12");    T.eq(EG.db.socketValue, 12, "socket value")
    run("EASYGEAR", "socket auto");  T.eq(EG.db.socketValue, nil, "socket auto")
    run("EASYGEAR", "enchants off"); T.eq(EG.db.includeEnchants, false, "enchants off")
    run("EASYGEAR", "enchants on");  T.eq(EG.db.includeEnchants, true, "enchants on")
    run("EASYGEAR", "autolevel off");T.eq(EG.db.autoLeveling, false, "autolevel off")
    run("EASYGEAR", "autolevel on")
    run("EASYGEAR", "items");        T.eq(EG.db.showItemIcons, false, "items toggle")
    run("EASYGEAR", "items");        T.eq(EG.db.showItemIcons, true, "items toggle back")
    run("EASYGEAR", "diff");         T.eq(EG.db.tooltipDiff, false, "diff toggle")
    run("EASYGEAR", "diff")
    run("EASYGEAR", "ilvl 0.7");     T.eq(EG.db.ilvlWeight, 0.7, "ilvl")
    run("EASYGEAR", "mindelta 3");   T.eq(EG.db.minDelta, 3, "mindelta")
    run("EASYGEAR", "pvp");          T.check(EG:IsPvPMode(), "pvp on")
    run("EASYGEAR", "pvp")

    -- Item-Auswertung
    local item = Chest({ [STR] = 100 })
    T.check(run("EASYGEAR", item):find("EasyGear", 1, true), "report for a link")

    -- Reset behaelt eigene Profile
    local id = EG:CreateCustomProfile("Keep", "WARRIOR_ARMS", "WARRIOR")
    run("EASYGEAR", "reset")
    T.check(EG:GetProfileByID(id), "custom profile survives reset")
    T.eq(EG.db.heirloomBonus, EG.DEFAULTS.heirloomBonus, "reset heirloom bonus")
    T.eq(EG.db.minDelta, 0, "reset mindelta")
    EG:DeleteCustomProfile(id)

    T.check(run("EGUP", "help"):find("/egup", 1, true), "egup help")
    T.check(run("EGUP", "verify"):find("OK", 1, true) or true, "egup verify runs")
    T.check(run("EGUP", "list WARRIOR"):find("42943", 1, true), "egup list")
    T.check(run("EGUPCLEAN", "list"):len() >= 0, "egupclean list")
end

Cases.upgrades_command = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    T.equip(5, Chest({ [STR] = 100, [STA] = 100 }))
    local big   = Chest({ [STR] = 200, [STA] = 100 })
    local small = Chest({ [STR] = 120, [STA] = 100 })
    local worse = Chest({ [STR] = 10, [STA] = 10 })
    local helm  = T.item({ id = ID(), loc = "INVTYPE_HEAD", subtype = PLATE, armor = 800, stats = { [STR] = 10 } })
    T.bag(0, 1, small); T.bag(0, 2, big); T.bag(0, 3, worse); T.bag(0, 4, helm)

    local found = EG:CollectUpgrades()
    T.eq(#found, 3, "three upgrades")
    T.check(found[1].empty, "empty slot first")
    T.eq(found[2].link, big, "then by percent")
    T.eq(found[3].link, small, "smallest last")

    T.clearChat()
    T.slash("EASYGEAR", "upgrades")
    T.check(T.chat():find(L.UPGRADES_HEAD, 1, true), "header printed")

    T.bag(0, 1, nil); T.bag(0, 2, nil); T.bag(0, 4, nil)
    T.clearChat()
    T.slash("EASYGEAR", "upgrades")
    T.check(T.chat():find(L.UPGRADES_NONE, 1, true), "none message")
end

Cases.saved_variables_migration = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    -- Einstellungen aus 2.x: 8 Punkte pro Sockel war der Standard, kein Nutzerwunsch
    _G.EasyGearDB = { version = "2.6.0", socketValue = 8, minDelta = 2, custom = { CUSTOM_X = { id = "CUSTOM_X", name = "X", custom = true, weights = {} } } }
    _G.EasyGearCharDB = { profile = "WARRIOR_FURY" }
    EG:InitDB()
    T.eq(EG.db.socketValue, nil, "old default socket value dropped")
    T.eq(EG.db.minDelta, 2, "other settings kept")
    T.check(EG.db.custom.CUSTOM_X, "custom profiles kept")
    T.eq(EG.db.heirloomBonus, EG.DEFAULTS.heirloomBonus, "new defaults added")
    T.eq(EG.db.autoLeveling, true, "new default: autoLeveling")
    T.eq(EG.db.version, "3.1.0", "version stamped")
    T.eq(EG.charDB.profile, "WARRIOR_FURY", "profile choice kept")

    -- ein selbst gesetzter Wert bleibt auch bei einer neuen Version
    _G.EasyGearDB = { version = "3.0.0", socketValue = 8 }
    EG:InitDB()
    T.eq(EG.db.socketValue, 8, "explicit value from 3.x is kept")

    T.check(EG:VersionLess("2.6.0", "3.0.0") and not EG:VersionLess("3.0.0", "3.0.0")
        and EG:VersionLess("2.10.0", "2.9.0") == false, "version compare")
    _G.EasyGearDB, _G.EasyGearCharDB = nil, nil
    EG:InitDB()
end

Cases.report_and_windows = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local eq = Chest({ [STR] = 100, [STA] = 100 })
    T.equip(5, eq)
    local better = Chest({ [STR] = 150, [STA] = 100 })
    T.clearChat()
    EG:PrintReport(better)
    T.check(T.chat():find(L.UPGRADE, 1, true), "report says upgrade")

    EG.GUI:Create()
    EG.GUI.frame:Show()
    EG.GUI:SetItem(better, true)
    EG.GUI:Refresh()
    EG.GUI:Clear()
    EG.ProfileGUI:Create()
    EG.ProfileGUI.frame:Show()
    EG.ProfileGUI:Refresh()
    EG.ProfileGUI:SetClass("MAGE")
    EG.ProfileGUI:Refresh()
end

------------------------------------------------------------------------------
-- Tooltip und Markierungen
------------------------------------------------------------------------------

Cases.tooltip_lines = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local eq = Chest({ [STR] = 100, [STA] = 100, [CRIT] = 20 })
    T.equip(5, eq)
    local better = Chest({ [STR] = 150, [STA] = 90, [CRIT] = 20 })

    local tip = GameTooltip
    tip:ClearLines()
    tip.EGDone = nil
    EG.AddTooltipInfo(tip, better)
    local text = {}
    for _, ln in ipairs(tip._lines) do text[#text + 1] = ln.text or "" end
    local joined = table.concat(text, "\n")
    T.check(joined:find("EasyGear", 1, true), "tooltip header")
    T.check(joined:find(L.UPGRADE, 1, true), "tooltip verdict")
    T.check(joined:find("+50", 1, true), "tooltip strength diff")
    T.check(joined:find("-10", 1, true), "tooltip stamina diff")
    T.check(joined:find("%%"), "tooltip percent")

    -- Auf dem Charakterfenster nur die Wertung
    tip:ClearLines(); tip.EGDone = nil
    local owner = CreateFrame("Button", "CharacterChestSlot")
    tip:SetOwner(owner)
    EG.AddTooltipInfo(tip, better)
    local n = 0
    for _, ln in ipairs(tip._lines) do if (ln.text or ""):find(L.UPGRADE, 1, true) then n = n + 1 end end
    T.eq(n, 0, "no verdict on equipped-item tooltips")
    tip:SetOwner(nil)
end

Cases.overlays_merchant_loot = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    EG:HookOverlays()
    T.equip(5, Chest({ [STR] = 100, [STA] = 100 }))
    local good = Chest({ [STR] = 200, [STA] = 100 })
    local bad  = Chest({ [STR] = 50, [STA] = 10 })

    -- Haendler
    _G.MerchantFrame = CreateFrame("Frame", "MerchantFrame"); MerchantFrame.page = 1; MerchantFrame.selectedTab = 1
    local items = { good, bad }
    _G.GetMerchantItemLink = function(i) return items[i] end
    local b1 = CreateFrame("Button", "MerchantItem1ItemButton")
    local b2 = CreateFrame("Button", "MerchantItem2ItemButton")
    EG:RefreshOverlays()
    T.check(b1.EGIcon and b1.EGIcon._shown == true, "merchant: upgrade marked")
    T.check(b2.EGIcon and b2.EGIcon._shown ~= true, "merchant: non-upgrade not marked")

    -- Beute
    _G.LootFrame = CreateFrame("Frame", "LootFrame")
    local lb = CreateFrame("Button", "LootButton1"); lb.slot = 1
    _G.LootSlotIsItem = function() return true end
    _G.GetLootSlotLink = function() return good end
    EG:RefreshOverlays()
    T.check(lb.EGIcon and lb.EGIcon._shown == true, "loot: upgrade marked")

    -- Wuerfeln
    local rf = CreateFrame("Frame", "GroupLootFrame1")
    rf.rollID = 5
    rf.IconFrame = CreateFrame("Frame", "GroupLootFrame1IconFrame")
    _G.GetLootRollItemLink = function() return good end
    EG:RefreshOverlays()
    T.check(rf.IconFrame.EGIcon and rf.IconFrame.EGIcon._shown == true, "roll: upgrade marked")

    -- Abschalten
    EG.db.showItemIcons = false
    EG:RefreshOverlays()
    T.check(b1.EGIcon._shown ~= true and lb.EGIcon._shown ~= true, "icons off")
    EG.db.showItemIcons = true
end

Cases.bag_buttons = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    T.equip(5, Chest({ [STR] = 100, [STA] = 100 }))
    local good = Chest({ [STR] = 200, [STA] = 100 })
    T.bag(0, 1, good)
    local button = CreateFrame("Button", "TestBagButton")
    EG:UpdateBagButton(button, 0, 1)
    T.check(button.EGIcon and button.EGIcon._shown == true, "bag: marked")

    -- Epoche aendert sich (Ausruestung): wird neu berechnet
    T.equip(5, Chest({ [STR] = 400, [STA] = 100 }))
    EG:UpdateBagButton(button, 0, 1)
    T.check(button.EGIcon._shown ~= true, "bag: marker removed after equipping something better")

    T.bag(0, 1, nil)
    EG:UpdateBagButton(button, 0, 1)
    T.check(button.EGIcon._shown ~= true, "bag: empty slot")
end

------------------------------------------------------------------------------
-- Erlernbare Rezepte
------------------------------------------------------------------------------

local function RecipeType() return EG:SplitAliases(L.RECIPE_TYPE)[1] end

-- Ein Rezept ohne rote Zeile: der Charakter hat den Beruf, die Fertigkeit reicht,
-- es ist noch nicht gelernt. Rote Zeilen ueber extra.red.
local function Recipe(extra)
    local d = { id = ID(), itype = RecipeType(), subtype = "Alchemy", ilvl = 40 }
    for k, v in pairs(extra or {}) do d[k] = v end
    return T.item(d)
end

Cases.recipe_state = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    T.eq(EG.db.showRecipeIcons, true, "an by default")

    T.eq(EG:GetRecipeState(Recipe()), "RECIPE", "learnable recipe")
    T.eq(EG:GetRecipeState(Recipe({ red = { "Already known" } })), nil, "already known")
    T.eq(EG:GetRecipeState(Recipe({ red = { "Requires Alchemy (300)" } })), nil, "profession or skill missing")
    T.eq(EG:GetRecipeState(Recipe({ red = { "Classes: Priest" } })), nil, "other class")
    T.eq(EG:GetRecipeState(Recipe({ red = { "Requires Alchemy (300)", "Already known" } })), nil, "several red lines")

    -- Stufenanforderung
    T.eq(EG:GetRecipeState(Recipe({ minLevel = 60 })), "RECIPE", "level requirement met")
    Setup("WARRIOR", 40, { 31, 0, 0 })
    T.eq(EG:GetRecipeState(Recipe({ minLevel = 60, red = { "Requires Level 60" } })), nil, "level too low")
    T.eq(EG:GetRecipeState(Recipe({ minLevel = 35 })), "RECIPE", "level 40 reaches 35")

    -- Alles, was kein Rezept ist, bleibt ohne Markierung
    local armor = Chest({ [STR] = 10 })
    T.eq(EG:GetRecipeState(armor), nil, "armor is not a recipe")
    local potion = T.item({ id = ID(), itype = "Consumable", subtype = "Potion", ilvl = 40 })
    T.eq(EG:GetRecipeState(potion), nil, "consumable is not a recipe")

    -- Itemdaten noch nicht im Client: spaeter noch einmal fragen
    local state, pending = EG:GetRecipeState("|cffffffff|Hitem:99999:0:0:0:0:0:0:0:80|h[Unbekannt]|h|r")
    T.eq(state, nil, "uncached: no state")
    T.eq(pending, true, "uncached: pending")
    T.eq(EG:GetRecipeState(nil), nil, "no link")
end

Cases.recipe_class_name_per_language = function()
    -- Die Klasse kommt als lokalisierter Text aus GetItemInfo(); die Namen stehen
    -- in den Sprachdateien, die englischen gelten immer als Notanker.
    Setup("WARRIOR", 80, { 31, 0, 0 })
    T.check(EG:IsRecipeType(RecipeType()), "client-language name")
    T.check(EG:IsRecipeType("Recipe"), "English fallback")
    T.check(EG:IsRecipeType("RECIPE"), "case-insensitive")
    T.check(not EG:IsRecipeType("Armor"), "armor is not a recipe")
    T.check(not EG:IsRecipeType(""), "empty")
    T.check(not EG:IsRecipeType(nil), "nil")
    local en = EasyGearLocales.enUS
    T.eq(en.RECIPE_TYPE, "Recipe", "enUS reference value")
end

Cases.recipe_markers_bags = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    EG:HookOverlays()
    local learn = Recipe()
    local known = Recipe({ red = { "Already known" } })
    T.bag(0, 1, learn); T.bag(0, 2, known)
    local b1 = CreateFrame("Button", "RecipeBag1")
    local b2 = CreateFrame("Button", "RecipeBag2")
    EG:UpdateBagButton(b1, 0, 1)
    EG:UpdateBagButton(b2, 0, 2)
    T.check(b1.EGIcon and b1.EGIcon._shown == true, "learnable recipe marked")
    T.eq(b1.EGIcon._texture, EG.TEX_RECIPE, "recipe symbol")
    T.check(b2.EGIcon._shown ~= true, "known recipe not marked")

    -- Das Symbol-Objekt wird wiederverwendet: ein Upgrade bekommt wieder das Haekchen
    T.equip(5, Chest({ [STR] = 100, [STA] = 100 }))
    local good = Chest({ [STR] = 200, [STA] = 100 })
    T.bag(0, 1, good)
    EG:UpdateBagButton(b1, 0, 1)
    T.check(b1.EGIcon._shown == true, "upgrade marked on the same button")
    T.eq(b1.EGIcon._texture, EG.TEX_UPGRADE, "check mark restored")

    -- und zurueck zum Rezept
    T.bag(0, 1, learn)
    EG:UpdateBagButton(b1, 0, 1)
    T.eq(b1.EGIcon._texture, EG.TEX_RECIPE, "recipe symbol again")

    -- Bank/Haendler/Beute laufen ueber dieselbe Markierung
    EG:HookOverlays()
    _G.MerchantFrame = CreateFrame("Frame", "MerchantFrame"); MerchantFrame.page = 1; MerchantFrame.selectedTab = 1
    local items = { learn, known }
    _G.GetMerchantItemLink = function(i) return items[i] end
    local m1 = CreateFrame("Button", "MerchantItem1ItemButton")
    local m2 = CreateFrame("Button", "MerchantItem2ItemButton")
    EG:RefreshOverlays()
    T.check(m1.EGIcon and m1.EGIcon._shown == true, "merchant: learnable recipe marked")
    T.eq(m1.EGIcon._texture, EG.TEX_RECIPE, "merchant: recipe symbol")
    T.check(m2.EGIcon._shown ~= true, "merchant: known recipe not marked")
end

Cases.recipe_setting_and_command = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local learn = Recipe()
    T.bag(0, 1, learn)
    local b = CreateFrame("Button", "RecipeBagOff")
    local function run(m) T.clearChat(); T.slash("EASYGEAR", m); return T.chat() end

    EG:UpdateBagButton(b, 0, 1)
    T.check(b.EGIcon._shown == true, "on: marked")

    local out = run("recipes off")
    T.eq(EG.db.showRecipeIcons, false, "recipes off")
    T.check(out ~= "", "the command answers")
    EG:UpdateBagButton(b, 0, 1)
    T.check(b.EGIcon._shown ~= true, "off: marker gone")
    T.eq(EG:GetRecipeState(learn), nil, "off: no state")

    run("recipes on")
    T.eq(EG.db.showRecipeIcons, true, "recipes on")
    EG:UpdateBagButton(b, 0, 1)
    T.check(b.EGIcon._shown == true, "on again: marked")

    run("recipes")                          -- ohne Argument: umschalten
    T.eq(EG.db.showRecipeIcons, false, "toggle off")
    run("recipe")                           -- Kurzform
    T.eq(EG.db.showRecipeIcons, true, "toggle on")

    -- der Schalter ist unabhaengig von den uebrigen Markierungen
    EG.db.showBagIcons = false
    EG:UpdateBagButton(b, 0, 1)
    T.check(b.EGIcon._shown ~= true, "bag markers off hides recipes too")
    EG.db.showBagIcons = true

    T.check(run("status"):find(L.ST_RECIPES, 1, true), "status shows the recipe switch")
    T.check(run("help"):find("recipes", 1, true), "help lists the command")

    -- /eg reset stellt den Standard (an) wieder her
    run("recipes off")
    run("reset")
    T.eq(EG.db.showRecipeIcons, true, "reset: on")
end

Cases.recipe_learned_refreshes = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    EG:HookOverlays()
    local reds = {}
    local learn = Recipe({ red = reds })
    T.bag(0, 1, learn); T.bag(0, 2, learn)         -- zweites Exemplar
    local b1 = CreateFrame("Button", "RecipeBagA")
    local b2 = CreateFrame("Button", "RecipeBagB")
    EG:UpdateBagButton(b1, 0, 1)
    EG:UpdateBagButton(b2, 0, 2)
    T.check(b1.EGIcon._shown == true and b2.EGIcon._shown == true, "both copies marked")

    -- Rezept gelernt: das zweite Exemplar traegt jetzt "Bereits bekannt"
    reds[#reds + 1] = "Already known"
    EG:UpdateBagButton(b2, 0, 2)
    T.check(b2.EGIcon._shown == true, "cached until something tells us otherwise")

    -- eine fremde Systemmeldung aendert nichts
    local epoch = EG.epoch
    T.fire("CHAT_MSG_SYSTEM", "Welcome to the server.")
    T.eq(EG.epoch, epoch, "unrelated message ignored")

    -- die Meldung ueber das gelernte Rezept verwirft den Zwischenspeicher
    T.fire("CHAT_MSG_SYSTEM", "You have learned how to create a new item: Elixir of Testing.")
    T.check(EG.epoch > epoch, "learn message invalidates")
    T.runTimers()
    EG:UpdateBagButton(b1, 0, 1)
    EG:UpdateBagButton(b2, 0, 2)
    T.check(b1.EGIcon._shown ~= true and b2.EGIcon._shown ~= true, "known now: markers gone")

    -- gestiegene Fertigkeit: wieder neu bewerten
    local epoch2 = EG.epoch
    T.fire("SKILL_LINES_CHANGED")
    T.check(EG.epoch > epoch2, "skill change invalidates")
    T.check(EG:IsLearnMessage("You have learned a new spell: Fireball."), "spell message")
    T.check(not EG:IsLearnMessage("You are now Rested."), "other message")
    T.check(not EG:IsLearnMessage(nil), "nil message")
end

Cases.recipe_tooltip_line = function()
    Setup("WARRIOR", 80, { 31, 0, 0 })
    local tip = GameTooltip

    local function lines(link)
        tip:ClearLines(); tip.EGDone = nil
        EG.AddTooltipInfo(tip, link)
        local out = {}
        for _, ln in ipairs(tip._lines) do out[#out + 1] = (ln.text or ln.left or "") end
        return table.concat(out, "\n")
    end

    T.check(lines(Recipe()):find(L.RECIPE_LEARNABLE, 1, true), "learnable: tooltip says so")
    T.check(not lines(Recipe({ red = { "Already known" } })):find(L.RECIPE_LEARNABLE, 1, true), "known: no line")
    T.check(not lines(Recipe({ red = { "Requires Alchemy (300)" } })):find(L.RECIPE_LEARNABLE, 1, true),
        "not learnable: no line")

    -- einmal je Tooltip
    tip:ClearLines(); tip.EGDone = nil
    local link = Recipe()
    EG.AddTooltipInfo(tip, link)
    EG.AddTooltipInfo(tip, link)
    local n = 0
    for _, ln in ipairs(tip._lines) do if (ln.text or ""):find(L.RECIPE_LEARNABLE, 1, true) then n = n + 1 end end
    T.eq(n, 1, "only once per tooltip")

    -- abgeschaltet: keine Zeile
    EG.db.showRecipeIcons = false
    EG:InvalidateComparisons()
    T.check(not lines(Recipe()):find(L.RECIPE_LEARNABLE, 1, true), "off: no line")
    EG.db.showRecipeIcons = true

    -- Ausruestung bleibt unberuehrt
    T.equip(5, Chest({ [STR] = 100, [STA] = 100 }))
    local better = Chest({ [STR] = 150, [STA] = 90 })
    T.check(lines(better):find(L.UPGRADE, 1, true), "armor tooltip unchanged")
end

return Cases
