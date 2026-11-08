-- Shared test items and characters
local F = {}

local MOD = {
    STR = "ITEM_MOD_STRENGTH_SHORT", AGI = "ITEM_MOD_AGILITY_SHORT", STA = "ITEM_MOD_STAMINA_SHORT",
    INT = "ITEM_MOD_INTELLECT_SHORT", SPI = "ITEM_MOD_SPIRIT_SHORT", AP = "ITEM_MOD_ATTACK_POWER_SHORT",
    SP = "ITEM_MOD_SPELL_POWER_SHORT", CRIT = "ITEM_MOD_CRIT_RATING_SHORT", HIT = "ITEM_MOD_HIT_RATING_SHORT",
    HASTE = "ITEM_MOD_HASTE_RATING_SHORT", EXP = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    ARP = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", DEF = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    DODGE = "ITEM_MOD_DODGE_RATING_SHORT", PARRY = "ITEM_MOD_PARRY_RATING_SHORT",
    RESIL = "ITEM_MOD_RESILIENCE_RATING_SHORT", MP5 = "ITEM_MOD_POWER_REGEN0_SHORT",
    BLOCKV = "ITEM_MOD_BLOCK_VALUE_SHORT",
}
F.MOD = MOD

local SLOT_TEXT = {
    INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_CHEST = "Chest",
    INVTYPE_ROBE = "Chest", INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet",
    INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands", INVTYPE_FINGER = "Finger", INVTYPE_TRINKET = "Trinket",
    INVTYPE_CLOAK = "Back", INVTYPE_WEAPON = "One-Hand", INVTYPE_2HWEAPON = "Two-Hand",
    INVTYPE_WEAPONMAINHAND = "Main Hand", INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_SHIELD = "Off Hand",
    INVTYPE_HOLDABLE = "Held In Off-hand", INVTYPE_RANGED = "Ranged", INVTYPE_BODY = "Shirt",
    INVTYPE_TABARD = "Tabard",
}
local WEAPON = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
                 INVTYPE_WEAPONOFFHAND = true, INVTYPE_RANGED = true }

--[[ F.gear(W, id, name, loc, ilvl, stats, extra) -> link
     stats uses the addon's short keys (STR, STA, ...); extra: armor, dps, minLevel, unique, badType, sockets,
     uncached, cosmetic, sellPrice, lines                                                           ]]
function F.gear(W, id, name, loc, ilvl, stats, extra)
    extra = extra or {}
    local d = {
        id = id, name = name, equipLoc = loc, ilvl = ilvl, quality = extra.quality or 3,
        stats = {}, statOrder = {}, slotText = SLOT_TEXT[loc] or "Chest",
        typeText = extra.typeText or (WEAPON[loc] and "Sword" or (loc == "INVTYPE_SHIELD" and "Shield" or "Plate")),
        type = WEAPON[loc] and "Weapon" or "Armor", classID = WEAPON[loc] and 2 or 4,
    }
    local keys = {}
    for k in pairs(stats or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local mod = assert(MOD[k], "unknown stat " .. k)
        d.stats[mod] = stats[k]
        d.statOrder[#d.statOrder + 1] = mod
    end
    if extra.armor then d.armor = extra.armor d.stats.RESISTANCE0_NAME = extra.armor end
    for _, k in ipairs({ "dps", "minLevel", "unique", "badType", "sockets", "uncached", "cosmetic", "sellPrice",
                         "lines", "effectiveIlvl" }) do
        d[k] = extra[k]
    end
    return (W.item(d))
end

-- Arms warrior, level 60 of 60 (profile WARRIOR_ARMS), with a worn set whose scores are known:
--   chest 44.5   ring1 32.5   ring2 14.5   trinket1 35   main hand 175   (ilvl weight 0.5)
function F.armsWarrior(W)
    local I = {}
    I.chest = F.gear(W, 2001, "Worn Chestplate", "INVTYPE_CHEST", 30, { STR = 20, STA = 20 }, { armor = 300, minLevel = 25 })
    I.ring1 = F.gear(W, 2002, "Copper Band", "INVTYPE_FINGER", 30, { STR = 10, CRIT = 10 }, { typeText = "" })
    I.ring2 = F.gear(W, 2003, "Plain Ring", "INVTYPE_FINGER", 25, { STA = 20 }, { typeText = "" })
    I.trinket = F.gear(W, 2004, "Old Charm", "INVTYPE_TRINKET", 30, { AP = 40 }, { typeText = "" })
    I.sword = F.gear(W, 2005, "Old Sword", "INVTYPE_WEAPON", 30, {}, { dps = 20 })
    W.equip(5, I.chest) W.equip(11, I.ring1) W.equip(12, I.ring2) W.equip(13, I.trinket) W.equip(16, I.sword)
    return I
end

F.ARMS = { class = "WARRIOR", level = 60, talents = { mode = "specinfo", points = { 40, 5, 0 } } }

function F.arms(extra)
    local o = {}
    for k, v in pairs(F.ARMS) do o[k] = v end
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end

return F
