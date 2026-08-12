local addonName = "EasyGear"

local PU = {}

EasyGear = PU

PU.loaded = false
PU.elvHooked = false
PU.defaultHooked = false
PU.bagnonHooked = false
PU.questHooked = false

------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local EGUP_BAG_ITEM_ID = 51809
local EGUP_BAG_COUNT = 4

------------------------------------------------------------
-- Quest indicator textures
------------------------------------------------------------

local QUEST_UPGRADE_ICON =
    "Interface\\Buttons\\UI-CheckBox-Check"

local QUEST_VENDOR_ICON =
    "Interface\\MoneyFrame\\UI-GoldIcon"

------------------------------------------------------------
-- EGUP session tracking
------------------------------------------------------------

PU.EGUPSession = {
    targetName = nil,
    targetGUID = nil,
    class = nil,
    items = {},
    active = false
}

------------------------------------------------------------
-- Utility: add an item to an EGUP package
------------------------------------------------------------

local function AddPackageItem(
    package,
    id,
    count,
    name
)

    if not id then
        return
    end

    table.insert(
        package,
        {
            id = id,
            count = count or 1,
            name = name or ("Item " .. tostring(id))
        }
    )

end

------------------------------------------------------------
-- Small delayed callback helper
------------------------------------------------------------

local timerFrame =
    CreateFrame("Frame")

function PU:After(delay, callback)

    if not callback then
        return
    end

    local elapsed = 0

    timerFrame:SetScript(
        "OnUpdate",
        function(self, delta)

            elapsed =
                elapsed + delta

            if elapsed >= delay then

                self:SetScript(
                    "OnUpdate",
                    nil
                )

                callback()

            end

        end
    )

end

------------------------------------------------------------
-- Class stat weights
------------------------------------------------------------

function PU:GetStatWeights()

    local class =
        select(
            2,
            UnitClass("player")
        )

    local weights = {

        WARRIOR = {
            ITEM_MOD_STRENGTH_SHORT = 10,
            ITEM_MOD_STAMINA_SHORT = 5,
            ITEM_MOD_CRIT_RATING_SHORT = 3,
            ITEM_MOD_HASTE_RATING_SHORT = 2,
            ITEM_MOD_HIT_RATING_SHORT = 3,
            ITEM_MOD_EXPERTISE_RATING_SHORT = 4,
            ITEM_MOD_ATTACK_POWER_SHORT = 5,
        },

        PALADIN = {
            ITEM_MOD_STRENGTH_SHORT = 10,
            ITEM_MOD_STAMINA_SHORT = 5,
            ITEM_MOD_INTELLECT_SHORT = 3,
            ITEM_MOD_CRIT_RATING_SHORT = 3,
            ITEM_MOD_HASTE_RATING_SHORT = 2,
            ITEM_MOD_SPELL_POWER_SHORT = 5,
        },

        HUNTER = {
            ITEM_MOD_AGILITY_SHORT = 10,
            ITEM_MOD_STAMINA_SHORT = 5,
            ITEM_MOD_CRIT_RATING_SHORT = 3,
            ITEM_MOD_HASTE_RATING_SHORT = 2,
            ITEM_MOD_ATTACK_POWER_SHORT = 5,
            ITEM_MOD_HIT_RATING_SHORT = 3,
        },

        ROGUE = {
            ITEM_MOD_AGILITY_SHORT = 10,
            ITEM_MOD_STAMINA_SHORT = 5,
            ITEM_MOD_CRIT_RATING_SHORT = 3,
            ITEM_MOD_HASTE_RATING_SHORT = 2,
            ITEM_MOD_ATTACK_POWER_SHORT = 5,
            ITEM_MOD_HIT_RATING_SHORT = 3,
            ITEM_MOD_EXPERTISE_RATING_SHORT = 4,
        },

        PRIEST = {
            ITEM_MOD_INTELLECT_SHORT = 10,
            ITEM_MOD_SPIRIT_SHORT = 5,
            ITEM_MOD_STAMINA_SHORT = 4,
            ITEM_MOD_HASTE_RATING_SHORT = 3,
            ITEM_MOD_SPELL_POWER_SHORT = 8,
            ITEM_MOD_MP5_SHORT = 4,
        },

        MAGE = {
            ITEM_MOD_INTELLECT_SHORT = 10,
            ITEM_MOD_STAMINA_SHORT = 4,
            ITEM_MOD_HASTE_RATING_SHORT = 3,
            ITEM_MOD_CRIT_RATING_SHORT = 3,
            ITEM_MOD_SPELL_POWER_SHORT = 8,
            ITEM_MOD_HIT_RATING_SHORT = 5,
        },

        WARLOCK = {
            ITEM_MOD_INTELLECT_SHORT = 10,
            ITEM_MOD_STAMINA_SHORT = 5,
            ITEM_MOD_HASTE_RATING_SHORT = 3,
            ITEM_MOD_CRIT_RATING_SHORT = 3,
            ITEM_MOD_SPELL_POWER_SHORT = 8,
            ITEM_MOD_HIT_RATING_SHORT = 5,
        },

        DRUID = {
            ITEM_MOD_AGILITY_SHORT = 8,
            ITEM_MOD_INTELLECT_SHORT = 8,
            ITEM_MOD_STRENGTH_SHORT = 5,
            ITEM_MOD_STAMINA_SHORT = 5,
            ITEM_MOD_SPELL_POWER_SHORT = 7,
        },

        SHAMAN = {
            ITEM_MOD_AGILITY_SHORT = 8,
            ITEM_MOD_INTELLECT_SHORT = 8,
            ITEM_MOD_STAMINA_SHORT = 5,
            ITEM_MOD_HASTE_RATING_SHORT = 3,
            ITEM_MOD_SPELL_POWER_SHORT = 7,
        },

    }

    local result =
        weights[class]
        or {
            ITEM_MOD_STAMINA_SHORT = 5
        }

    if UnitLevel("player") <= 80 then
        result.RESISTANCE0_NAME = 5
    end

    return result

end

------------------------------------------------------------
-- Item data
--
-- IMPORTANT:
-- GetItemInfo() return #11 is the vendor sell price.
------------------------------------------------------------

function PU:GetItemData(itemLink)

    if not itemLink then
        return nil
    end

    local itemName,
          itemLink2,
          quality,
          itemLevel,
          itemMinLevel,
          itemType,
          itemSubType,
          itemStackCount,
          equipLoc,
          texture,
          sellPrice =
        GetItemInfo(itemLink)

    if not itemLevel then
        return nil
    end

    local data = {

        name = itemName,

        link =
            itemLink2
            or itemLink,

        level =
            itemLevel,

        minLevel =
            itemMinLevel,

        quality =
            quality or 0,

        equipLoc =
            equipLoc,

        itemType =
            itemType,

        itemSubType =
            itemSubType,

        texture =
            texture,

        stackCount =
            itemStackCount or 1,

        sellPrice =
            tonumber(sellPrice) or 0,

        stats = {}

    }

    local stats =
        GetItemStats(itemLink)

    if stats then

        for stat, value in pairs(stats) do

            data.stats[stat] =
                value

        end

    end
    if quality == 7 then
        local playerLevel = 
        UnitLevel("player") or 0
        data.level = playerLevel
    end
    return data

end

------------------------------------------------------------
-- Item score
------------------------------------------------------------

function PU:GetItemScore(item)

    if not item then
        return 0
    end

    local score =
        (item.level or 0) * 2

    local weights =
        self:GetStatWeights()

    for stat, value in pairs(
        item.stats or {}
    ) do

        local weight =
            weights[stat]

        if weight then

            score =
                score
                + value * weight

        end

    end

    return score

end

------------------------------------------------------------
-- Heirloom detection
--
-- Quality 7 = Heirloom.
--
-- Below level 80 an equipped heirloom is protected.
------------------------------------------------------------

function PU:IsHeirloom(item)

    if not item then
        return false
    end

    if UnitLevel("player") >= 80 then
        return false
    end

    return item.quality == 7

end

------------------------------------------------------------
-- Equipment slot names
------------------------------------------------------------

local EQUIPMENT_SLOT_NAMES = {

    [1] = "Kopf",
    [2] = "Hals",
    [3] = "Schultern",
    [4] = "Hemd",
    [5] = "Brust",
    [6] = "Taille",
    [7] = "Beine",
    [8] = "Füße",
    [9] = "Handgelenke",
    [10] = "Hände",

    [11] = "Finger 1",
    [12] = "Finger 2",

    [13] = "Trinket 1",
    [14] = "Trinket 2",

    [15] = "Rücken",

    [16] = "Waffe Mainhand",
    [17] = "Waffe Offhand",

    [18] = "Ranged",

    [19] = "Tabard",

}

------------------------------------------------------------
-- Get human-readable slot name
------------------------------------------------------------

function PU:GetSlotName(
    slot,
    item
)

    if type(slot) == "table" then

        local names = {}

        for _, slotID in ipairs(slot) do

            table.insert(
                names,
                EQUIPMENT_SLOT_NAMES[slotID]
                    or tostring(slotID)
            )

        end

        return table.concat(
            names,
            " / "
        )

    end

    if slot then

        return
            EQUIPMENT_SLOT_NAMES[slot]
            or tostring(slot)

    end

    if item and item.equipLoc then
        return item.equipLoc
    end

    return "Unknown"

end

------------------------------------------------------------
-- Equipment slot detection
------------------------------------------------------------

function PU:GetEquipSlot(itemLink)

    if not itemLink then
        return nil
    end

    local _, _, _, _, _, _, _, _, equipLoc =
        GetItemInfo(itemLink)

    if not equipLoc then
        return nil
    end

    local slots = {

        INVTYPE_HEAD = 1,
        INVTYPE_NECK = 2,
        INVTYPE_SHOULDER = 3,
        INVTYPE_BODY = 4,

        INVTYPE_CHEST = 5,
        INVTYPE_ROBE = 5,

        INVTYPE_WAIST = 6,
        INVTYPE_LEGS = 7,
        INVTYPE_FEET = 8,
        INVTYPE_WRIST = 9,
        INVTYPE_HAND = 10,

        INVTYPE_FINGER = {
            11,
            12
        },

        INVTYPE_TRINKET = {
            13,
            14
        },

        INVTYPE_CLOAK = 15,

        INVTYPE_WEAPON = {
            16,
            17
        },

        INVTYPE_2HWEAPON = 16,

        INVTYPE_WEAPONMAINHAND = 16,

        INVTYPE_WEAPONOFFHAND = 17,

        INVTYPE_SHIELD = 17,

        INVTYPE_HOLDABLE = 17,

        INVTYPE_RANGED = 18,

        INVTYPE_THROWN = 18,

        INVTYPE_RELIC = 18,

    }

    return slots[equipLoc]

end

------------------------------------------------------------
-- Find equipped heirloom in relevant slot(s)
------------------------------------------------------------

function PU:GetEquippedHeirloom(
    slot,
    item
)

    if UnitLevel("player") >= 80 then
        return nil
    end

    if not slot then
        return nil
    end

    local function CheckSlot(slotID)

        local link =
            GetInventoryItemLink(
                "player",
                slotID
            )

        if not link then
            return nil
        end

        local equipped =
            self:GetItemData(link)

        if equipped
            and equipped.quality == 7
        then
            return equipped
        end

        return nil

    end

    if type(slot) == "table" then

        for _, slotID in ipairs(slot) do

            local equipped =
                CheckSlot(slotID)

            if equipped then
                return equipped
            end

        end

    else

        return CheckSlot(slot)

    end

    return nil

end


function PU:GetEquippedItems(slot)

    local result = {}

    if not slot then
        return result
    end

    local function AddEquipped(slotID)

        local link =
            GetInventoryItemLink(
                "player",
                slotID
            )

        if not link then
            return
        end

        local item =
            self:GetItemData(link)

        if not item then
            return
        end

        item.slotID =
            slotID

        item.score =
            self:GetItemScore(item)

        table.insert(
            result,
            item
        )

    end

    if type(slot) == "table" then

        for _, slotID in ipairs(slot) do

            AddEquipped(slotID)

        end

    else

        AddEquipped(slot)

    end

    return result
end

------------------------------------------------------------
-- Check item level requirement
------------------------------------------------------------

function PU:IsItemLevelTooHigh(itemLink)

    if not itemLink then
        return false
    end

    local item =
        self:GetItemData(itemLink)

    if not item then
        return false
    end

    if not item.minLevel then
        return false
    end

    return
        UnitLevel("player")
        < item.minLevel

end

------------------------------------------------------------
-- Equipment compatibility
------------------------------------------------------------

function PU:CanEquipItem(itemLink)

    if not itemLink then
        return false
    end

    local _, _, _, _, _, itemType, itemSubType =
        GetItemInfo(itemLink)

    if not itemType
        or not itemSubType
    then
        return false
    end

    local _, class =
        UnitClass("player")

    if not class then
        return false
    end

    --------------------------------------------------------
    -- Localized Blizzard strings
    --------------------------------------------------------

    local function GetLocalizedString(
        globalName,
        english,
        german
    )

        local value =
            _G[globalName]

        if value then
            return value
        end

        if GetLocale() == "deDE" then
            return german
        end

        return english

    end

    --------------------------------------------------------
    -- Armor
    --------------------------------------------------------

    local CLOTH =
        GetLocalizedString(
            "ITEM_SUBCLASS_ARMOR_CLOTH",
            "Cloth",
            "Stoff"
        )

    local LEATHER =
        GetLocalizedString(
            "ITEM_SUBCLASS_ARMOR_LEATHER",
            "Leather",
            "Leder"
        )

    local MAIL =
        GetLocalizedString(
            "ITEM_SUBCLASS_ARMOR_MAIL",
            "Mail",
            "Schwere Rüstung"
        )

    local PLATE =
        GetLocalizedString(
            "ITEM_SUBCLASS_ARMOR_PLATE",
            "Plate",
            "Platte"
        )

    --------------------------------------------------------
    -- Weapons
    --------------------------------------------------------

    local DAGGER =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_DAGGER",
            "Daggers",
            "Dolche"
        )

    local FIST =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_FIST",
            "Fist Weapons",
            "Faustwaffen"
        )

    local AXE_1H =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_AXE",
            "One-Handed Axes",
            "Äxte"
        )

    local AXE_2H =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_AXE2",
            "Two-Handed Axes",
            "Zweihandäxte"
        )

    local MACE_1H =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_MACE",
            "One-Handed Maces",
            "Einhandstreitkolben"
        )

    local MACE_2H =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_MACE2",
            "Two-Handed Maces",
            "Zweihandstreitkolben"
        )

    local SWORD_1H =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_SWORD",
            "One-Handed Swords",
            "Einhandschwerter"
        )

    local SWORD_2H =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_SWORD2",
            "Two-Handed Swords",
            "Zweihandschwerter"
        )

    local POLEARM =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_POLEARM",
            "Polearms",
            "Stangenwaffen"
        )

    local STAFF =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_STAFF",
            "Staves",
            "Stäbe"
        )

    local BOW =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_BOW",
            "Bows",
            "Bogen"
        )

    local GUN =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_GUN",
            "Guns",
            "Schusswaffen"
        )

    local CROSSBOW =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_CROSSBOW",
            "Crossbows",
            "Armbrüste"
        )

    local WAND =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_WAND",
            "Wands",
            "Zauberstäbe"
        )

    local THROWN =
        GetLocalizedString(
            "ITEM_SUBCLASS_WEAPON_THROWN",
            "Thrown",
            "Wurfwaffen"
        )

    --------------------------------------------------------
    -- Miscellaneous
    --------------------------------------------------------

    local MISC =
        GetLocalizedString(
            "ITEM_SUBCLASS_MISC",
            "Miscellaneous",
            "Verschiedenes"
        )

    --------------------------------------------------------
    -- Allowed subtypes per class
    --------------------------------------------------------

    local allowed = {

        WARRIOR = {

            [CLOTH] = true,
            [LEATHER] = true,
            [MAIL] = true,
            [PLATE] = true,

            [DAGGER] = true,
            [FIST] = true,

            [AXE_1H] = true,
            [AXE_2H] = true,

            [MACE_1H] = true,
            [MACE_2H] = true,

            [SWORD_1H] = true,
            [SWORD_2H] = true,

            [POLEARM] = true,
            [STAFF] = true,

            [GUN] = true,
            [BOW] = true,
            [CROSSBOW] = true,
            [THROWN] = true,

            [MISC] = true,
        },

        PALADIN = {

            [CLOTH] = true,
            [LEATHER] = true,
            [MAIL] = true,
            [PLATE] = true,

            [AXE_1H] = true,
            [AXE_2H] = true,

            [MACE_1H] = true,
            [MACE_2H] = true,

            [SWORD_1H] = true,
            [SWORD_2H] = true,

            [POLEARM] = true,

            [MISC] = true,
        },

        HUNTER = {

            [CLOTH] = true,
            [LEATHER] = true,

            [DAGGER] = true,
            [FIST] = true,

            [AXE_1H] = true,
            [AXE_2H] = true,

            [SWORD_1H] = true,
            [SWORD_2H] = true,

            [POLEARM] = true,
            [STAFF] = true,

            [BOW] = true,
            [CROSSBOW] = true,
            [GUN] = true,
            [THROWN] = true,

            [MISC] = true,
        },

        ROGUE = {

            [CLOTH] = true,
            [LEATHER] = true,

            [DAGGER] = true,
            [FIST] = true,

            [AXE_1H] = true,
            [MACE_1H] = true,
            [SWORD_1H] = true,

            [BOW] = true,
            [CROSSBOW] = true,
            [GUN] = true,
            [THROWN] = true,

            [MISC] = true,
        },

        DRUID = {

            [CLOTH] = true,
            [LEATHER] = true,

            [DAGGER] = true,
            [FIST] = true,

            [MACE_1H] = true,
            [MACE_2H] = true,

            [POLEARM] = true,
            [STAFF] = true,

            [MISC] = true,
        },

        SHAMAN = {

            [CLOTH] = true,
            [LEATHER] = true,

            [DAGGER] = true,
            [FIST] = true,

            [AXE_1H] = true,
            [AXE_2H] = true,

            [MACE_1H] = true,
            [MACE_2H] = true,

            [STAFF] = true,

            [MISC] = true,
        },

        PRIEST = {

            [CLOTH] = true,

            [DAGGER] = true,
            [MACE_1H] = true,
            [STAFF] = true,
            [WAND] = true,

            [MISC] = true,
        },

        MAGE = {

            [CLOTH] = true,

            [DAGGER] = true,
            [SWORD_1H] = true,
            [STAFF] = true,
            [WAND] = true,

            [MISC] = true,
        },

        WARLOCK = {

            [CLOTH] = true,

            [DAGGER] = true,
            [SWORD_1H] = true,
            [STAFF] = true,
            [WAND] = true,

            [MISC] = true,
        },

    }
    -- Mail becomes available to Hunter and Shaman at level 40
    local playerLevel =
        UnitLevel("player")
        
    if playerLevel >= 40 then
        allowed.HUNTER[MAIL] = true
        allowed.SHAMAN[MAIL] = true
    end
    
    if not allowed[class] then
        return false
    end

    return
        allowed[class][itemSubType] == true

end

------------------------------------------------------------
-- Upgrade comparison
--
-- This is the central comparison used by both bags and
-- quest rewards.
--
-- For dual-slot equipment:
--   The candidate is compared against the weaker equipped
--   slot.
--
-- For heirlooms:
--   An equipped Quality 7 heirloom below level 80 is
--   protected and cannot be replaced.
------------------------------------------------------------

function PU:IsUpgrade(itemLink)

    if not self:CanEquipItem(itemLink) then
        return false, 0, 0, nil
    end

    if self:IsItemLevelTooHigh(itemLink) then
        return false, 0, 0, nil
    end

    local newItem =
        self:GetItemData(itemLink)

    if not newItem then
        return false, 0, 0, nil
    end

    local slot =
        self:GetEquipSlot(itemLink)

    if not slot then
        return false, 0, 0, nil
    end

    local newScore =
        self:GetItemScore(newItem)

    local function GetOldScore(oldLink)

        if not oldLink then
            return 0
        end

        local oldItem =
            self:GetItemData(oldLink)

        if not oldItem then
            return 0
        end

        if self:IsHeirloom(oldItem) then
            return math.huge
        end

        return self:GetItemScore(oldItem)

    end

    --------------------------------------------------------
    -- Dual-slot item
    --
    -- IMPORTANT:
    -- If ANY relevant slot contains a Quality 7 heirloom,
    -- the item is protected until level 80.
    --------------------------------------------------------
    
    if type(slot) == "table" then
    
        local worstOld = math.huge
        local heirloomEquipped = false
    
        for _, slotID in ipairs(slot) do
    
            local oldLink =
                GetInventoryItemLink(
                    "player",
                    slotID
                )
    
            if oldLink then
    
                local oldItem =
                    self:GetItemData(oldLink)
    
                if oldItem then
    
                    ------------------------------------------------
                    -- Heirloom protection
                    ------------------------------------------------
    
                    if self:IsHeirloom(oldItem) then
    
                        heirloomEquipped = true
    
                    else
    
                        local oldScore =
                            self:GetItemScore(oldItem)
    
                        if oldScore < worstOld then
                            worstOld = oldScore
                        end
    
                    end
    
                end
    
            else
    
                ------------------------------------------------
                -- Empty slot.
                --
                -- Only use this as the comparison target if
                -- there is no protected heirloom.
                ------------------------------------------------
    
                if not heirloomEquipped
                    and worstOld > 0
                then
                    worstOld = 0
                end
    
            end
    
        end
    
        --------------------------------------------------------
        -- ANY equipped heirloom protects the dual-slot item.
        --------------------------------------------------------
    
        if heirloomEquipped then
    
            return
                false,
                newScore,
                math.huge,
                slot
    
        end
    
        --------------------------------------------------------
        -- No heirloom:
        -- Compare against the weakest relevant slot.
        --------------------------------------------------------
    
        if worstOld == math.huge then
    
            worstOld = 0
    
        end
    
        return
            newScore > worstOld,
            newScore,
            worstOld,
            slot
    
    end
    --------------------------------------------------------
    -- Single-slot item
    --------------------------------------------------------

    local oldLink =
        GetInventoryItemLink(
            "player",
            slot
        )

    local oldScore =
        GetOldScore(oldLink)

    if oldLink
        and oldScore == math.huge
    then

        return
            false,
            newScore,
            oldScore,
            slot

    end

    return
        newScore > oldScore,
        newScore,
        oldScore,
        slot

end

------------------------------------------------------------
-- Quest reward scoring
------------------------------------------------------------

function PU:GetQuestRewardScore(itemLink)

    if not itemLink then
        return 0
    end

    local item =
        self:GetItemData(itemLink)

    if not item then
        return 0
    end

    return self:GetItemScore(item)

end

------------------------------------------------------------
-- Get quest reward item ID
------------------------------------------------------------

function PU:GetQuestRewardItemID(index)

    if not index then
        return nil
    end

    local link =
        self:GetQuestRewardLink(index)

    if not link then
        return nil
    end

    return
        self:GetItemIDFromLink(link)

end

------------------------------------------------------------
-- Get quest reward link
------------------------------------------------------------

function PU:GetQuestRewardLink(index)

    if not index then
        return nil
    end

    if not GetQuestItemLink then
        return nil
    end

    return
        GetQuestItemLink(
            "choice",
            index
        )

end

------------------------------------------------------------
-- Check whether quest reward is usable
--
-- Blizzard's usable flag is used when available.
-- CanEquipItem() remains the fallback.
------------------------------------------------------------

function PU:IsQuestRewardUsable(index)

    if not index then
        return false
    end

    local link =
        self:GetQuestRewardLink(index)

    if not link then
        return false
    end

    --------------------------------------------------------
    -- Character level requirement
    --------------------------------------------------------

    if self:IsItemLevelTooHigh(link) then
        return false
    end

    --------------------------------------------------------
    -- Blizzard usability result
    --------------------------------------------------------

    if GetQuestItemInfo then

        local _, _, _, _, isUsable =
            GetQuestItemInfo(
                "choice",
                index
            )

        if isUsable ~= nil then

            if isUsable then
                return true
            end

            return false

        end

    end

    --------------------------------------------------------
    -- Fallback
    --------------------------------------------------------

    return
        self:CanEquipItem(link)

end

------------------------------------------------------------
-- Get best quest reward
--
-- IMPORTANT:
--
-- We intentionally do NOT simply choose the item with the
-- highest score.
--
-- Priority:
--
--   1. Find all actual upgrades.
--   2. If upgrades exist, select the highest-scoring upgrade.
--   3. If no upgrade exists, select the most valuable item.
--
-- This means:
--
--   Reward A = score 900, NOT an upgrade
--   Reward B = score 850, IS an upgrade
--
-- => Reward B is selected.
--
-- If:
--
--   Reward A = score 900, NOT an upgrade, value 5g
--   Reward B = score 850, NOT an upgrade, value 12g
--
-- => Reward B is selected with the coin icon.
------------------------------------------------------------

function PU:GetBestQuestReward()

    local numChoices =
        GetNumQuestChoices()

    if not numChoices
        or numChoices <= 0
    then

        return nil,
            0,
            false,
            0,
            nil

    end

    local bestUpgradeButton =
        nil

    local bestUpgradeScore =
        -math.huge

    local bestUpgradeValue =
        0

    local bestVendorButton =
        nil

    local bestVendorValue =
        -math.huge

    local bestVendorScore =
        0

    --------------------------------------------------------
    -- Evaluate every reward.
    --------------------------------------------------------

    for i = 1, numChoices do

        local link =
            self:GetQuestRewardLink(i)
            
        

        if link then

            local item =
                self:GetItemData(link)

            if item then

                local value =
                    tonumber(item.sellPrice)
                    or 0

                local score =
                    self:GetItemScore(item)
                    
                    print(
                        "Quest reward",
                        i,
                        link,
                        "value =", item.sellPrice,
                        "score =", score
                    )

                ------------------------------------------------
                -- FALLBACK:
                -- Always remember the most valuable reward.
                --
                -- We deliberately do not require the item to
                -- be an upgrade here. If there is no upgrade,
                -- the player should still be offered the most
                -- valuable reward.
                ------------------------------------------------

                if value > bestVendorValue then

                    bestVendorValue =
                        value

                    bestVendorButton =
                        i

                    bestVendorScore =
                        score

                end

                ------------------------------------------------
                -- PRIMARY:
                -- Check for a real upgrade.
                ------------------------------------------------

                local isUsable =
                    self:IsQuestRewardUsable(i)

                if isUsable then

                    local upgrade,
                          newScore =
                        self:IsUpgrade(link)

                    if upgrade
                        and newScore
                    then

                        if newScore
                            > bestUpgradeScore
                        then

                            bestUpgradeScore =
                                newScore

                            bestUpgradeButton =
                                i

                            bestUpgradeValue =
                                value

                        elseif newScore
                            == bestUpgradeScore
                            and value
                            > bestUpgradeValue
                        then

                            ------------------------------------------------
                            -- Tie-breaker:
                            -- If two upgrades have exactly the same
                            -- score, prefer the one with the higher
                            -- vendor value.
                            ------------------------------------------------

                            bestUpgradeButton =
                                i

                            bestUpgradeValue =
                                value

                        end

                    end

                end

            end

        end

    end

    --------------------------------------------------------
    -- PRIMARY RESULT:
    -- An actual upgrade always wins.
    --------------------------------------------------------

    if bestUpgradeButton then

        return
            bestUpgradeButton,
            bestUpgradeScore,
            true,
            bestUpgradeValue,
            "UPGRADE"

    end

    --------------------------------------------------------
    -- FALLBACK:
    -- No upgrade exists.
    --
    -- Select the item worth the most gold.
    --------------------------------------------------------

    if bestVendorButton then

        return
            bestVendorButton,
            bestVendorScore,
            false,
            bestVendorValue,
            "VENDOR"

    end

    return
        nil,
        0,
        false,
        0,
        nil

end

------------------------------------------------------------
-- Create quest indicator
------------------------------------------------------------

function PU:CreateQuestIndicator(button)

    if not button then
        return
    end

    if button.PUQuestIcon then
        return
    end

    local icon =
        button:CreateTexture(
            nil,
            "OVERLAY",
            nil,
            7
        )

    icon:SetPoint(
        "TOPRIGHT",
        button,
        "TOPRIGHT",
        -4,
        -4
    )

    icon:SetSize(
        20,
        20
    )

    button.PUQuestIcon =
        icon

end

------------------------------------------------------------
-- Configure quest indicator
------------------------------------------------------------

function PU:SetQuestIndicator(
    button,
    mode
)

    if not button then
        return
    end

    self:CreateQuestIndicator(
        button
    )

    local icon =
        button.PUQuestIcon

    if not icon then
        return
    end

    --------------------------------------------------------
    -- Actual upgrade
    --------------------------------------------------------

    if mode == "UPGRADE" then

        icon:SetTexture(
            QUEST_UPGRADE_ICON
        )

        icon:SetVertexColor(
            0,
            1,
            0,
            1
        )

        icon:Show()

        return

    end

    --------------------------------------------------------
    -- Vendor fallback
    --------------------------------------------------------

    if mode == "VENDOR" then

        icon:SetTexture(
            QUEST_VENDOR_ICON
        )

        icon:SetVertexColor(
            1,
            1,
            1,
            1
        )

        icon:Show()

        return

    end

    icon:Hide()

end

------------------------------------------------------------
-- Update quest rewards
------------------------------------------------------------

function PU:UpdateQuestRewards()

    local numChoices =
        GetNumQuestChoices()

    if not numChoices
        or numChoices <= 0
    then
        return
    end

    local bestButton,
          bestScore,
          isUpgrade,
          value,
          mode =
        self:GetBestQuestReward()

    --------------------------------------------------------
    -- Clear indicators first.
    --------------------------------------------------------

    for i = 1, numChoices do

        local button =
            _G[
                "QuestInfoItem" .. i
            ]

        if button then

            self:CreateQuestIndicator(
                button
            )

            button.PUQuestIcon:Hide()

        end

    end

    if not bestButton then

        self.selectedQuestReward =
            nil

        return

    end

    --------------------------------------------------------
    -- Save selected reward.
    --------------------------------------------------------

    local link =
        self:GetQuestRewardLink(
            bestButton
        )

    local item =
        link
        and self:GetItemData(link)
        or nil

    self.selectedQuestReward = {

        index =
            bestButton,

        link =
            link,

        item =
            item,

        score =
            bestScore,

        value =
            value,

        isUpgrade =
            isUpgrade,

        mode =
            mode,

    }

    --------------------------------------------------------
    -- Display selected indicator.
    --------------------------------------------------------

    local selectedButton =
        _G[
            "QuestInfoItem"
            .. bestButton
        ]

    if selectedButton then

        self:SetQuestIndicator(
            selectedButton,
            mode
        )

    end

end

------------------------------------------------------------
-- Delayed quest reward update
------------------------------------------------------------

function PU:HookQuestRewards()

    if self.questHooked then
        return
    end

    if not QuestInfo_Display then
        return
    end

    hooksecurefunc(
        "QuestInfo_Display",
        function()

            self:After(
                0.2,
                function()

                    self:UpdateQuestRewards()

                    ------------------------------------------------
                    -- Second pass because item information may
                    -- still be loading.
                    ------------------------------------------------

                    self:After(
                        0.5,
                        function()

                            self:UpdateQuestRewards()

                        end
                    )

                end
            )

        end
    )

    self.questHooked =
        true

end

------------------------------------------------------------
-- Bag upgrade indicator
------------------------------------------------------------

function PU:CreateUpgradeIndicator(button)

    if not button then
        return
    end

    if button.PUUpgradeIcon then
        return
    end

    local icon =
        button:CreateTexture(
            nil,
            "OVERLAY",
            nil,
            7
        )

    icon:SetTexture(
        QUEST_UPGRADE_ICON
    )

    icon:SetVertexColor(
        0,
        1,
        0
    )

    icon:SetPoint(
        "TOPRIGHT",
        button,
        "TOPRIGHT",
        -4,
        -4
    )

    icon:SetSize(
        20,
        20
    )

    button.PUUpgradeIcon =
        icon

end

------------------------------------------------------------
-- Update bag button
------------------------------------------------------------

function PU:UpdateBagButton(
    button,
    bagID,
    slotID
)

    if not button then
        return
    end

    self:CreateUpgradeIndicator(
        button
    )

    local link =
        GetContainerItemLink(
            bagID,
            slotID
        )

    if not link then

        button.PUUpgradeIcon:Hide()

        return

    end

    --------------------------------------------------------
    -- Item requires a higher level.
    --------------------------------------------------------

    if self:IsItemLevelTooHigh(link) then

        button.PUUpgradeIcon:SetVertexColor(
            1,
            1,
            0
        )

        button.PUUpgradeIcon:Show()

        return

    end

    --------------------------------------------------------
    -- Normal upgrade.
    --------------------------------------------------------

    local upgrade =
        self:IsUpgrade(link)

    if upgrade then

        button.PUUpgradeIcon:SetTexture(
            QUEST_UPGRADE_ICON
        )

        button.PUUpgradeIcon:SetVertexColor(
            0,
            1,
            0
        )

        button.PUUpgradeIcon:Show()

    else

        button.PUUpgradeIcon:Hide()

    end

end

------------------------------------------------------------
-- Blizzard Bags
------------------------------------------------------------

function PU:HookDefaultBags()

    if self.defaultHooked then
        return
    end

    if not ContainerFrame_Update then
        return
    end

    hooksecurefunc(
        "ContainerFrame_Update",
        function(frame)

            if not frame then
                return
            end

            local bagID =
                frame:GetID()

            for i = 1, MAX_CONTAINER_ITEMS do

                local button =
                    _G[
                        frame:GetName()
                        .. "Item"
                        .. i
                    ]

                if button then

                    self:UpdateBagButton(
                        button,
                        bagID,
                        i
                    )

                end

            end

        end
    )

    self.defaultHooked =
        true

end

------------------------------------------------------------
-- ElvUI
------------------------------------------------------------

function PU:HookElvUI()

    if self.elvHooked then
        return
    end

    if not ElvUI then
        return
    end

    local E =
        unpack(ElvUI)

    if not E then
        return
    end

    local Bags =
        E:GetModule(
            "Bags",
            true
        )

    if not Bags then
        return
    end

    if Bags.UpdateSlot then

        hooksecurefunc(
            Bags,
            "UpdateSlot",
            function(
                _,
                frame,
                bagID,
                slotID
            )

                local button

                if frame
                    and frame.Bags
                    and frame.Bags[bagID]
                then

                    button =
                        frame.Bags[bagID][slotID]

                end

                if button then

                    self:UpdateBagButton(
                        button,
                        bagID,
                        slotID
                    )

                end

            end
        )

    end

    self.elvHooked =
        true

    print(
        "|cff00ff00EasyGear:|r ElvUI bag support enabled."
    )

end

------------------------------------------------------------
-- Bagnon
------------------------------------------------------------

function PU:HookBagnon()

    if self.bagnonHooked then
        return
    end

    if not Bagnon then
        return
    end

    if not Bagnon.ItemSlot then
        return
    end

    if not Bagnon.ItemSlot.Update then
        return
    end

    hooksecurefunc(
        Bagnon.ItemSlot,
        "Update",
        function(button)

            local bag =
                button:GetBag()

            local slot =
                button:GetID()

            if bag and slot then

                self:UpdateBagButton(
                    button,
                    bag,
                    slot
                )

            end

        end
    )

    self.bagnonHooked =
        true

    print(
        "|cff00ff00EasyGear:|r Bagnon support enabled."
    )

end

------------------------------------------------------------
-- EGUP ITEM DATABASE
------------------------------------------------------------

local EGUP_ITEMS = {

    --------------------------------------------------------
    -- Trinkets
    --------------------------------------------------------

    TRINKETS = {

        {
            id = 42991,
            count = 2,
            name = "Swift Hand of Justice"
        },

        {
            id = 42992,
            count = 2,
            name = "Discerning Eye of the Beast"
        },

    },

    --------------------------------------------------------
    -- Ring
    --------------------------------------------------------

    RING = {

        id = 50255,
        count = 1,
        name = "Dread Pirate Ring"

    },

    --------------------------------------------------------
    -- Portable Holes
    --------------------------------------------------------

    BAGS = {

        {
            id = EGUP_BAG_ITEM_ID,
            count = EGUP_BAG_COUNT,
            name = "Portable Hole"
        },

    },

    --------------------------------------------------------
    -- Cloth
    --------------------------------------------------------

    CLOTH = {

        CHEST = {

            id = 48691,
            count = 1,
            name = "Tattered Dreadmist Robe"

        },

        SHOULDERS = {

            id = 42985,
            count = 1,
            name = "Tattered Dreadmist Mantle"

        },

        WEAPON = {

            id = 42947,
            count = 1,
            name = "Dignified Headmaster's Charge"

        },

    },

    --------------------------------------------------------
    -- Leather Agility
    --------------------------------------------------------

    LEATHER_AGI = {

        CHEST = {

            id = 48689,
            count = 1,
            name = "Stained Shadowcraft Tunic"

        },

        SHOULDERS = {

            id = 42952,
            count = 1,
            name = "Stained Shadowcraft Spaulders"

        },

        DAGGER = {

            id = 42944,
            count = 1,
            name = "Balanced Heartseeker"

        },

        SWORD = {

            id = 42945,
            count = 1,
            name = "Venerable Dal'Rend's Sacred Charge"

        },

        THRASH_BLADE = {

            id = 44096,
            count = 1,
            name = "Battleworn Thrash Blade"

        },

        OFFHAND_DAGGER = {

            id = 44091,
            count = 1,
            name = "Sharpened Scarlet Kris"

        },

    },

    --------------------------------------------------------
    -- Leather Caster
    --------------------------------------------------------

    LEATHER_INT = {

        CHEST = {

            id = 48687,
            count = 1,
            name = "Preened Ironfeather Breastplate"

        },

        SHOULDERS = {

            id = 42984,
            count = 1,
            name = "Preened Ironfeather Shoulders"

        },

        WEAPON = {

            id = 42947,
            count = 1,
            name = "Dignified Headmaster's Charge"

        },

    },

    --------------------------------------------------------
    -- Mail Agility
    --------------------------------------------------------

    MAIL_AGI = {

        CHEST = {

            id = 48677,
            count = 1,
            name = "Champion's Deathdealer Breastplate"

        },

        SHOULDERS = {

            id = 42950,
            count = 1,
            name = "Champion Herod's Shoulder"

        },

        MACE = {

            id = 48716,
            count = 1,
            name = "Venerable Mass of McGowan"

        },

        BOW = {

            id = 42946,
            count = 1,
            name = "Charmed Ancient Bone Bow"

        },

    },

    --------------------------------------------------------
    -- Mail Caster
    --------------------------------------------------------

    MAIL_INT = {

        CHEST = {

            id = 48683,
            count = 1,
            name = "Mystical Vest of Elements"

        },

        SHOULDERS = {

            id = 42951,
            count = 1,
            name = "Mystical Pauldrons of Elements"

        },

        WEAPON = {

            id = 42948,
            count = 1,
            name = "Devout Aurastone Hammer"

        },

    },

    --------------------------------------------------------
    -- Plate
    --------------------------------------------------------

    PLATE = {

        CHEST = {

            id = 48685,
            count = 1,
            name = "Polished Breastplate of Valor"

        },

        SHOULDERS = {

            id = 42949,
            count = 1,
            name = "Polished Spaulders of Valor"

        },

        WEAPON = {

            id = 44092,
            count = 1,
            name = "Reforged Truesilver Champion"

        },

    },

}

------------------------------------------------------------
-- Build class package
------------------------------------------------------------

function PU:GetEGUPPackage(class)

    local package = {}

    local function Add(item)

        if not item then
            return
        end

        AddPackageItem(
            package,
            item.id,
            item.count,
            item.name
        )

    end

    --------------------------------------------------------
    -- Universal items
    --------------------------------------------------------

    for _, item in ipairs(
        EGUP_ITEMS.TRINKETS
    ) do

        Add(item)

    end

    Add(
        EGUP_ITEMS.RING
    )

    --------------------------------------------------------
    -- Portable Holes
    --------------------------------------------------------

    for _, item in ipairs(
        EGUP_ITEMS.BAGS
    ) do

        Add(item)

    end

    --------------------------------------------------------
    -- Rogue
    --------------------------------------------------------

    if class == "ROGUE" then

        Add(
            EGUP_ITEMS.LEATHER_AGI.CHEST
        )

        Add(
            EGUP_ITEMS.LEATHER_AGI.SHOULDERS
        )

        Add(
            EGUP_ITEMS.LEATHER_AGI.DAGGER
        )

        Add(
            EGUP_ITEMS.LEATHER_AGI.SWORD
        )

        Add(
            EGUP_ITEMS.LEATHER_AGI.THRASH_BLADE
        )

        Add(
            EGUP_ITEMS.LEATHER_AGI.OFFHAND_DAGGER
        )

    --------------------------------------------------------
    -- Druid
    --------------------------------------------------------

    elseif class == "DRUID" then

        Add(
            EGUP_ITEMS.LEATHER_INT.CHEST
        )

        Add(
            EGUP_ITEMS.LEATHER_INT.SHOULDERS
        )

        Add(
            EGUP_ITEMS.LEATHER_INT.WEAPON
        )

    --------------------------------------------------------
    -- Hunter
    --------------------------------------------------------

    elseif class == "HUNTER" then

        Add(
            EGUP_ITEMS.MAIL_AGI.CHEST
        )

        Add(
            EGUP_ITEMS.MAIL_AGI.SHOULDERS
        )

        Add(
            EGUP_ITEMS.MAIL_AGI.BOW
        )

    --------------------------------------------------------
    -- Shaman
    --------------------------------------------------------

    elseif class == "SHAMAN" then

        Add(
            EGUP_ITEMS.MAIL_AGI.CHEST
        )

        Add(
            EGUP_ITEMS.MAIL_AGI.SHOULDERS
        )

        Add(
            EGUP_ITEMS.MAIL_AGI.MACE
        )

        Add(
            EGUP_ITEMS.MAIL_INT.WEAPON
        )

    --------------------------------------------------------
    -- Warrior
    --------------------------------------------------------

    elseif class == "WARRIOR" then

        Add(
            EGUP_ITEMS.PLATE.CHEST
        )

        Add(
            EGUP_ITEMS.PLATE.SHOULDERS
        )

        Add(
            EGUP_ITEMS.PLATE.WEAPON
        )

        Add(
            EGUP_ITEMS.LEATHER_AGI.SWORD
        )

        Add(
            EGUP_ITEMS.MAIL_AGI.MACE
        )

    --------------------------------------------------------
    -- Paladin
    --------------------------------------------------------

    elseif class == "PALADIN" then

        Add(
            EGUP_ITEMS.PLATE.CHEST
        )

        Add(
            EGUP_ITEMS.PLATE.SHOULDERS
        )

        Add(
            EGUP_ITEMS.PLATE.WEAPON
        )

        Add(
            EGUP_ITEMS.MAIL_INT.WEAPON
        )

    --------------------------------------------------------
    -- Priest
    --------------------------------------------------------

    elseif class == "PRIEST" then

        Add(
            EGUP_ITEMS.CLOTH.CHEST
        )

        Add(
            EGUP_ITEMS.CLOTH.SHOULDERS
        )

        Add(
            EGUP_ITEMS.CLOTH.WEAPON
        )

    --------------------------------------------------------
    -- Mage
    --------------------------------------------------------

    elseif class == "MAGE" then

        Add(
            EGUP_ITEMS.CLOTH.CHEST
        )

        Add(
            EGUP_ITEMS.CLOTH.SHOULDERS
        )

        Add(
            EGUP_ITEMS.CLOTH.WEAPON
        )

    --------------------------------------------------------
    -- Warlock
    --------------------------------------------------------

    elseif class == "WARLOCK" then

        Add(
            EGUP_ITEMS.CLOTH.CHEST
        )

        Add(
            EGUP_ITEMS.CLOTH.SHOULDERS
        )

        Add(
            EGUP_ITEMS.CLOTH.WEAPON
        )

    end

    return package

end

------------------------------------------------------------
-- Record EGUP item
------------------------------------------------------------

function PU:RecordEGUPItem(item)

    if not item then
        return
    end

    local id =
        tonumber(item.id)

    if not id then
        return
    end

    if not self.EGUPSession.items[id] then

        self.EGUPSession.items[id] = {

            id = id,

            name =
                item.name,

            count = 0

        }

    end

    self.EGUPSession.items[id].count =
        self.EGUPSession.items[id].count
        + (item.count or 1)

end

------------------------------------------------------------
-- Clear EGUP session
------------------------------------------------------------

function PU:ClearEGUPSession()

    self.EGUPSession = {

        targetName = nil,

        targetGUID = nil,

        class = nil,

        items = {},

        active = false

    }

end

------------------------------------------------------------
-- Send GM command
------------------------------------------------------------

function PU:SendEGUPCommand(command)

    SendChatMessage(
        command,
        "SAY"
    )

end

------------------------------------------------------------
-- EGUP command queue
------------------------------------------------------------

PU.EGUPQueue = {}
PU.EGUPRunning = false

function PU:ProcessEGUPQueue()

    if self.EGUPRunning then
        return
    end

    if #self.EGUPQueue == 0 then
        return
    end

    self.EGUPRunning =
        true

    local index = 1

    local function SendNext()

        if index > #self.EGUPQueue then

            self.EGUPQueue =
                {}

            self.EGUPRunning =
                false

            print(
                "|cff00ff00EasyGear:|r EGUP completed."
            )

            return

        end

        local command =
            self.EGUPQueue[index]

        index =
            index + 1

        self:SendEGUPCommand(
            command
        )

        self:After(
            0.35,
            SendNext
        )

    end

    SendNext()

end

------------------------------------------------------------
-- Run EGUP
------------------------------------------------------------

function PU:RunEGUP()

    if not UnitExists("target") then

        print(
            "|cffff0000EasyGear EGUP:|r Target a player first."
        )

        return

    end

    if not UnitIsPlayer("target") then

        print(
            "|cffff0000EasyGear EGUP:|r Target is not a player."
        )

        return

    end

    local targetName =
        UnitName("target")

    if not targetName then

        print(
            "|cffff0000EasyGear EGUP:|r Could not determine target."
        )

        return

    end

    local _, class =
        UnitClass("target")

    if not class then

        print(
            "|cffff0000EasyGear EGUP:|r Could not determine target class."
        )

        return

    end

    local package =
        self:GetEGUPPackage(class)

    if not package
        or #package == 0
    then

        print(
            "|cffff0000EasyGear EGUP:|r No package configured for",
            class
        )

        return

    end

    self:ClearEGUPSession()

    self.EGUPSession.targetName =
        targetName

    self.EGUPSession.targetGUID =
        UnitGUID("target")

    self.EGUPSession.class =
        class

    self.EGUPSession.active =
        true

    self.EGUPQueue = {}

    for _, item in ipairs(package) do

        self:RecordEGUPItem(
            item
        )

        local command =
            ".additem "
            .. targetName
            .. " "
            .. item.id
            .. " "
            .. item.count

        table.insert(
            self.EGUPQueue,
            command
        )

    end

    print(
        "|cff00ff00EasyGear EGUP|r"
    )

    print(
        "Giving WotLK leveling package to:",
        "|cffffff00"
        .. targetName
        .. "|r"
    )

    print(
        "Class:",
        "|cffffff00"
        .. class
        .. "|r"
    )

    print(
        "Portable Holes:",
        "|cffffff00"
        .. EGUP_BAG_COUNT
        .. "|r"
    )

    print(
        "Package entries:",
        "|cffffff00"
        .. #package
        .. "|r"
    )

    print(
        "After equipping the desired items, use:",
        "|cffffff00/EGUPCLEAN|r"
    )

    self:ProcessEGUPQueue()

end

------------------------------------------------------------
-- EGUP CLEANUP
------------------------------------------------------------

function PU:IsItemIDEquipped(itemID)

    itemID =
        tonumber(itemID)

    if not itemID then
        return false
    end

    for slot = 1, 19 do

        local link =
            GetInventoryItemLink(
                "player",
                slot
            )

        if link then

            local equippedID =
                tonumber(
                    string.match(
                        link,
                        "item:(%d+)"
                    )
                )

            if equippedID == itemID then
                return true
            end

        end

    end

    return false

end

------------------------------------------------------------
-- Extract item ID
------------------------------------------------------------

function PU:GetItemIDFromLink(link)

    if not link then
        return nil
    end

    local id =
        string.match(
            link,
            "item:(%d+)"
        )

    return tonumber(id)

end

------------------------------------------------------------
-- Find bag item locations
------------------------------------------------------------

function PU:GetBagItemLocations(itemID)

    local locations = {}

    itemID =
        tonumber(itemID)

    if not itemID then
        return locations
    end

    for bagID = 0, 4 do

        local numSlots =
            GetContainerNumSlots(
                bagID
            )

        if numSlots then

            for slotID = 1, numSlots do

                local link =
                    GetContainerItemLink(
                        bagID,
                        slotID
                    )

                if link then

                    local foundID =
                        self:GetItemIDFromLink(
                            link
                        )

                    if foundID == itemID then

                        local _, count =
                            GetContainerItemInfo(
                                bagID,
                                slotID
                            )

                        table.insert(
                            locations,
                            {
                                bag = bagID,
                                slot = slotID,
                                count = count or 1,
                                link = link
                            }
                        )

                    end

                end

            end

        end

    end

    return locations

end

------------------------------------------------------------
-- Delete bag slot
------------------------------------------------------------

function PU:DeleteBagSlot(
    bagID,
    slotID
)

    if CursorHasItem() then
        ClearCursor()
    end

    PickupContainerItem(
        bagID,
        slotID
    )

    if CursorHasItem() then
        DeleteCursorItem()
    end

end

------------------------------------------------------------
-- Cleanup item
------------------------------------------------------------

function PU:CleanupEGUPItem(
    itemID,
    requestedCount,
    callback
)

    local locations =
        self:GetBagItemLocations(
            itemID
        )

    if #locations == 0 then

        if callback then
            callback()
        end

        return

    end

    local remaining =
        requestedCount

    local index = 1

    local function DeleteNext()

        if remaining <= 0 then

            if callback then
                callback()
            end

            return

        end

        if index > #locations then

            if callback then
                callback()
            end

            return

        end

        local location =
            locations[index]

        index =
            index + 1

        local equipped =
            self:IsItemIDEquipped(
                itemID
            )

        local deleteCount =
            location.count

        if equipped then

            if deleteCount > 1 then

                deleteCount =
                    deleteCount - 1

            else

                deleteCount = 0

            end

        end

        if deleteCount <= 0 then

            self:After(
                0.05,
                DeleteNext
            )

            return

        end

        if deleteCount > remaining then
            deleteCount = remaining
        end

        ----------------------------------------------------
        -- Do not partially destroy a stack.
        ----------------------------------------------------

        if deleteCount >= location.count then

            self:DeleteBagSlot(
                location.bag,
                location.slot
            )

            remaining =
                remaining
                - location.count

        else

            remaining = 0

        end

        self:After(
            0.10,
            DeleteNext
        )

    end

    DeleteNext()

end

------------------------------------------------------------
-- Run cleanup
------------------------------------------------------------

function PU:RunEGUPClean()

    if not self.EGUPSession.active then

        print(
            "|cffff0000EasyGear:|r No EGUP session is available to clean."
        )

        return

    end

    local targetGUID =
        self.EGUPSession.targetGUID

    local playerGUID =
        UnitGUID("player")

    if targetGUID
        and playerGUID
        and targetGUID ~= playerGUID
    then

        print(
            "|cffff0000EasyGear:|r EGUPCLEAN must be run by the player who received the EGUP package."
        )

        print(
            "EGUP target:",
            self.EGUPSession.targetName
                or "Unknown"
        )

        return

    end

    print(
        "|cff00ff00EasyGear EGUPCLEAN|r"
    )

    print(
        "Scanning bags for items supplied by the last EGUP session..."
    )

    local itemList = {}

    for _, data in pairs(
        self.EGUPSession.items
    ) do

        table.insert(
            itemList,
            data
        )

    end

    if #itemList == 0 then

        print(
            "Nothing to clean."
        )

        return

    end

    local index = 1

    local function CleanNext()

        if index > #itemList then

            print(
                "|cff00ff00EasyGear:|r EGUPCLEAN completed."
            )

            return

        end

        local data =
            itemList[index]

        index =
            index + 1

        self:CleanupEGUPItem(
            data.id,
            data.count,
            function()

                self:After(
                    0.10,
                    CleanNext
                )

            end
        )

    end

    CleanNext()

end

------------------------------------------------------------
-- Localized stat name
------------------------------------------------------------

function PU:GetLocalizedStatName(stat)

    return
        _G[stat]
        or stat

end

------------------------------------------------------------
-- /EG
--
-- Detailed item upgrade information.
------------------------------------------------------------

SLASH_EasyGear1 = "/EG"

SlashCmdList["EasyGear"] =
function(msg)

    if not msg
        or msg == ""
    then

        print(
            "|cff00ccffEasyGear|r"
        )

        print(
            "Usage:",
            "|cffffff00/EG itemlink|r"
        )

        print(
            "Example:",
            "|cffffff00/EG [item]|r"
        )

        return

    end

    --------------------------------------------------------
    -- Make sure item information is available.
    --------------------------------------------------------

    local item =
        PU:GetItemData(msg)

    if not item then

        print(
            "|cffff0000EasyGear:|r Could not read item information."
        )

        print(
            "Make sure you supplied a valid item link."
        )

        return

    end

    --------------------------------------------------------
    -- Check whether the item can be used.
    --------------------------------------------------------

    if not PU:CanEquipItem(msg) then

        print(
            "|cff00ccffEasyGear|r"
        )

        print(
            "Item:",
            item.link or msg
        )

        print(
            "|cffff0000✗ NOT USABLE|r",
            "This item is not compatible with your class/armor type."
        )

        print(
            "Item type:",
            item.itemType or "Unknown"
        )

        print(
            "Item subtype:",
            item.itemSubType or "Unknown"
        )

        return

    end

    --------------------------------------------------------
    -- Perform upgrade comparison.
    --------------------------------------------------------

    local upgrade,
          newScore,
          oldScore,
          slot =
        PU:IsUpgrade(msg)

    local slotName =
        PU:GetSlotName(
            slot,
            item
        )
    --------------------------------------------------------
    -- Get currently equipped item(s).
    --------------------------------------------------------
    
    local equippedItems =
        PU:GetEquippedItems(slot)

    local difference

    if oldScore == math.huge then

        difference =
            -math.huge

    else

        difference =
            newScore - oldScore

    end

    --------------------------------------------------------
    -- Header
    --------------------------------------------------------

    print(
        "|cff00ccff========================================|r"
    )

    print(
        "|cff00ccffEasyGear Item Evaluation|r"
    )

    print(
        "|cff00ccff========================================|r"
    )

    --------------------------------------------------------
    -- Item information
    --------------------------------------------------------

    print(
        "Item:",
        item.link or msg
    )

    print(
        "Slot:",
        "|cffffff00"
        .. tostring(slotName)
        .. "|r"
    )

    print(
        "Item Level:",
        "|cffffff00"
        .. tostring(item.level or 0)
        .. "|r"
    )

    if item.stats then

        print(
            "Stats:"
        )

        for stat, value in pairs(
            item.stats
        ) do

            print(
                "  " .. tostring(
                    PU:GetLocalizedStatName(stat)
                ) .. ":",
                "|cffffff00+"
                .. tostring(value)
                .. "|r"
            )

        end

    end

    print(
        "Quality:",
        "|cffffff00"
        .. tostring(item.quality or 0)
        .. "|r"
    )

    if item.itemType then

        print(
            "Type:",
            "|cffffff00"
            .. tostring(item.itemType)
            .. "|r"
        )

    end

    if item.itemSubType then

        print(
            "Subtype:",
            "|cffffff00"
            .. tostring(item.itemSubType)
            .. "|r"
        )

    end

    if item.minLevel then

        print(
            "minLevel:",
            "|cffffff00"
            .. tostring(item.minLevel)
            .. "|r"
        )

    end

    if item.sellPrice then

        print(
            "Price:",
            "|cffffff00"
            .. GetCoinTextureString(
                item.sellPrice
            )
            .. "|r"
        )

    end
    
    
    --------------------------------------------------------
    -- Equipped item information
    --------------------------------------------------------
    
    print(
        "|cffaaaaaa----------------------------------------|r"
    )
    
    print(
        "|cff00ccffCurrently Equipped|r"
    )
    
    if #equippedItems == 0 then
    
        print(
            "Equipped:",
            "|cffffcc00Nothing equipped|r"
        )
    
    else
    
        for _, equipped in ipairs(
            equippedItems
        ) do
            
            if equipped.link then
                print(
                    "Equipped:",
                    equipped.link
                )
            end
            
            if equipped.level then
                print(
                    "  Item Level:",
                    "|cffffff00"
                    .. tostring(
                        equipped.level or 0
                    )
                    .. "|r"
                )
            end
            
            if equipped.stats then
        
                print(
                    "  Stats:"
                )
        
                for eqstat, eqvalue in pairs(
                    equipped.stats
                ) do
        
                    print(
                        "   " .. tostring(
                            PU:GetLocalizedStatName(eqstat)
                        ) .. ":",
                        "|cffffff00+"
                        .. tostring(eqvalue)
                        .. "|r"
                    )
        
                end
        
            end

                
                
            print(
                "  Score:",
                "|cffffff00"
                .. string.format(
                    "%.0f",
                    equipped.score or 0
                )
                .. "|r"
            )
    
            if equipped.quality == 7 then
    
                print(
                    "  Quality:",
                    "|cffffcc00Heirloom|r"
                )
    
            end
    
        end
    
    end
    
    --------------------------------------------------------
    -- Character information
    --------------------------------------------------------

    local playerClassName,
          playerClass =
        UnitClass("player")

    local playerLevel =
        UnitLevel("player")

    print(
        "Character:",
        "|cffffff00"
        .. tostring(
            playerClassName
                or "Unknown"
        )
        .. "|r",
        "Level",
        "|cffffff00"
        .. tostring(
            playerLevel
                or 0
        )
        .. "|r"
    )

    --------------------------------------------------------
    -- Score information
    --------------------------------------------------------

    print(
        "|cffaaaaaa----------------------------------------|r"
    )

    print(
        "New Item Score:",
        "|cff00ff00"
        .. string.format(
            "%.0f",
            newScore
        )
        .. "|r"
    )

    if oldScore == math.huge then

        print(
            "Current Item Score:",
            "|cffffcc00HEIRLOOM / PROTECTED|r"
        )

        print(
            "Score Difference:",
            "|cffffcc00N/A|r"
        )

    else

        print(
            "Current Item Score:",
            "|cffffff00"
            .. string.format(
                "%.0f",
                oldScore
            )
            .. "|r"
        )

        if difference > 0 then

            print(
                "Score Difference:",
                "|cff00ff00+"
                .. string.format(
                    "%.0f",
                    difference
                )
                .. "|r"
            )

        elseif difference < 0 then

            print(
                "Score Difference:",
                "|cffff0000"
                .. string.format(
                    "%.0f",
                    difference
                )
                .. "|r"
            )

        else

            print(
                "Score Difference:",
                "|cffffff00±0|r"
            )

        end

    end

    --------------------------------------------------------
    -- Heirloom information
    --------------------------------------------------------

    local equippedHeirloom =
        PU:GetEquippedHeirloom(
            slot,
            item
        )

    if equippedHeirloom then

        print(
            "|cffaaaaaa----------------------------------------|r"
        )

        print(
            "|cffffcc00Heirloom Protection Active|r"
        )

        print(
            "Equipped:",
            equippedHeirloom.link
        )

        print(
            "Quality:",
            "|cffffcc007 (Heirloom)|r"
        )

        print(
            "Character Level:",
            "|cffffff00"
            .. tostring(playerLevel)
            .. " / 80|r"
        )

        print(
            "Rule:",
            "Equipped Quality 7 heirlooms are treated as best until level 80."
        )

    end

    --------------------------------------------------------
    -- Final result
    --------------------------------------------------------

    print(
        "|cffaaaaaa----------------------------------------|r"
    )

    if upgrade then

        print(
            "|cff00ff00✓ UPGRADE|r"
        )

        print(
            "This item scores higher than the current equipment."
        )

        if oldScore ~= math.huge then

            print(
                "Improvement:",
                "|cff00ff00+"
                .. string.format(
                    "%.0f",
                    difference
                )
                .. " score|r"
            )

        end

    else

        print(
            "|cffff0000✗ NOT AN UPGRADE|r"
        )

        if equippedHeirloom then

            print(
                "|cffffcc00Reason:|r",
                "An equipped Quality 7 heirloom is protected until level 80."
            )

        elseif oldScore == newScore then

            print(
                "Reason:",
                "The item has the same score as the current equipment."
            )

        elseif oldScore > newScore then

            print(
                "Reason:",
                "The current equipment has a higher calculated score."
            )

        else

            print(
                "Reason:",
                "The item does not qualify as an upgrade."
            )

        end

    end

    print(
        "|cff00ccff========================================|r"
    )

end

------------------------------------------------------------
-- /EGUP
------------------------------------------------------------

SLASH_EGUP1 = "/EGUP"

SlashCmdList["EGUP"] =
function(msg)

    PU:RunEGUP()

end

------------------------------------------------------------
-- /EGUPCLEAN
------------------------------------------------------------

SLASH_EGUPCLEAN1 = "/EGUPCLEAN"

SlashCmdList["EGUPCLEAN"] =
function(msg)

    PU:RunEGUPClean()

end

------------------------------------------------------------
-- Initialization
------------------------------------------------------------

local eventFrame =
    CreateFrame("Frame")

eventFrame:RegisterEvent(
    "PLAYER_ENTERING_WORLD"
)

eventFrame:RegisterEvent(
    "ADDON_LOADED"
)

eventFrame:SetScript(
    "OnEvent",
    function(_, event)

        if event == "PLAYER_ENTERING_WORLD" then

            if PU.loaded then
                return
            end

            PU.loaded =
                true

            print(
                "|cff00ff00EasyGear loaded.|r"
            )

            print(
                "Commands:"
            )

            print(
                "  |cffffff00/EG itemlink|r - Detailed item evaluation"
            )

            print(
                "  |cffffff00/EGUP|r - Give targeted player the class-specific leveling package"
            )

            print(
                "  |cffffff00/EGUPCLEAN|r - Clean recorded EGUP items from bags"
            )

            ------------------------------------------------
            -- Bag integrations
            ------------------------------------------------

            if IsAddOnLoaded("ElvUI") then

                PU:HookElvUI()

            elseif IsAddOnLoaded("Bagnon") then

                PU:HookBagnon()

            else

                PU:HookDefaultBags()

            end

            ------------------------------------------------
            -- Quest integration
            ------------------------------------------------

            PU:HookQuestRewards()

        end

    end
)
