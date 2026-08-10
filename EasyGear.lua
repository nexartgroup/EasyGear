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
-- EGUP session tracking
--
-- This records what the most recent /EGUP operation asked
-- the server to give to the target.
--
-- /EGUPCLEAN uses this information to remove those items
-- from the target's bags if they are not equipped.
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

local function AddPackageItem(package, id, count, name)

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

local timerFrame = CreateFrame("Frame")

function PU:After(delay, callback)

    local elapsed = 0

    timerFrame:SetScript(
        "OnUpdate",
        function(self, delta)

            elapsed = elapsed + delta

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

    local class = select(
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

    return weights[class] or {
        ITEM_MOD_STAMINA_SHORT = 5
    }

end

------------------------------------------------------------
-- Item data
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
          equipLoc =
        GetItemInfo(itemLink)

    if not itemLevel then
        return nil
    end

    local data = {
        name = itemName,
        link = itemLink2 or itemLink,
        level = itemLevel,
        quality = quality or 0,
        equipLoc = equipLoc,
        itemType = itemType,
        itemSubType = itemSubType,
        stats = {}
    }

    local stats =
        GetItemStats(itemLink)

    if stats then

        for stat, value in pairs(stats) do
            data.stats[stat] = value
        end

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

    for stat, value in pairs(item.stats or {}) do

        local weight =
            weights[stat]

        if weight then

            score =
                score + value * weight

        end

    end

    return score

end

------------------------------------------------------------
-- Heirloom detection
--
-- WotLK Quality 7 = Heirloom.
--
-- Below level 80, equipped heirlooms are treated as best.
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
-- Debug item
------------------------------------------------------------

function PU:DebugItem(itemLink)

    local item =
        self:GetItemData(itemLink)

    if not item then

        print(
            "EasyGear: Invalid item."
        )

        return

    end

    print(
        "=============================="
    )

    print(
        "EasyGear Item Debug"
    )

    print(
        "=============================="
    )

    print(
        "Item:",
        item.link
    )

    print(
        "Level:",
        item.level
    )

    print(
        "Quality:",
        item.quality
    )

    print(
        "Equip:",
        item.equipLoc
    )

    print(
        "Type:",
        item.itemType
    )

    print(
        "Subtype:",
        item.itemSubType
    )

    print(
        "Stats:"
    )

    for stat, value in pairs(item.stats) do

        print(
            " ",
            stat,
            "=",
            value
        )

    end

    print(
        "=============================="
    )

end

------------------------------------------------------------
-- Equipment compatibility
--
-- Uses English WoW subtype names. If the server/client is
-- localized differently, adapt this table accordingly.
------------------------------------------------------------

function PU:CanEquipItem(itemLink)

    if not itemLink then
        return false
    end

    local _, _, _, _, _, itemType, itemSubType =
        GetItemInfo(itemLink)

    if not itemType or not itemSubType then
        return false
    end

    local class =
        select(
            2,
            UnitClass("player")
        )

    local allowed = {

        WARRIOR = {
            ["Cloth"] = true,
            ["Leather"] = true,
            ["Mail"] = true,
            ["Plate"] = true,

            ["Daggers"] = true,
            ["Fist Weapons"] = true,

            ["One-Handed Axes"] = true,
            ["Two-Handed Axes"] = true,

            ["One-Handed Maces"] = true,
            ["Two-Handed Maces"] = true,

            ["One-Handed Swords"] = true,
            ["Two-Handed Swords"] = true,

            ["Polearms"] = true,
            ["Staves"] = true,

            ["Guns"] = true,
            ["Bows"] = true,
            ["Crossbows"] = true,
            ["Thrown"] = true,
        },

        PALADIN = {
            ["Cloth"] = true,
            ["Leather"] = true,
            ["Mail"] = true,
            ["Plate"] = true,

            ["One-Handed Maces"] = true,
            ["Two-Handed Maces"] = true,

            ["One-Handed Swords"] = true,
            ["Two-Handed Swords"] = true,

            ["Polearms"] = true,
        },

        HUNTER = {
            ["Cloth"] = true,
            ["Leather"] = true,
            ["Mail"] = true,

            ["Daggers"] = true,

            ["One-Handed Axes"] = true,
            ["Two-Handed Axes"] = true,

            ["One-Handed Swords"] = true,
            ["Two-Handed Swords"] = true,

            ["Polearms"] = true,
            ["Staves"] = true,

            ["Bows"] = true,
            ["Guns"] = true,
            ["Crossbows"] = true,
        },

        ROGUE = {
            ["Cloth"] = true,
            ["Leather"] = true,

            ["Daggers"] = true,
            ["Fist Weapons"] = true,

            ["One-Handed Axes"] = true,
            ["One-Handed Maces"] = true,
            ["One-Handed Swords"] = true,

            ["Bows"] = true,
            ["Guns"] = true,
            ["Crossbows"] = true,
            ["Thrown"] = true,
        },

        DRUID = {
            ["Cloth"] = true,
            ["Leather"] = true,

            ["Daggers"] = true,
            ["Fist Weapons"] = true,

            ["One-Handed Maces"] = true,
            ["Two-Handed Maces"] = true,

            ["Polearms"] = true,
            ["Staves"] = true,
        },

        SHAMAN = {
            ["Cloth"] = true,
            ["Leather"] = true,
            ["Mail"] = true,

            ["Daggers"] = true,
            ["Fist Weapons"] = true,

            ["One-Handed Axes"] = true,
            ["Two-Handed Axes"] = true,

            ["One-Handed Maces"] = true,
            ["Two-Handed Maces"] = true,

            ["Staves"] = true,
        },

        PRIEST = {
            ["Cloth"] = true,

            ["Daggers"] = true,
            ["One-Handed Maces"] = true,

            ["Staves"] = true,
            ["Wands"] = true,
        },

        MAGE = {
            ["Cloth"] = true,

            ["Daggers"] = true,
            ["One-Handed Swords"] = true,

            ["Staves"] = true,
            ["Wands"] = true,
        },

        WARLOCK = {
            ["Cloth"] = true,

            ["Daggers"] = true,
            ["One-Handed Swords"] = true,

            ["Staves"] = true,
            ["Wands"] = true,
        },

    }

    if not allowed[class] then
        return false
    end

    return allowed[class][itemSubType] == true

end

------------------------------------------------------------
-- Equipment slot detection
------------------------------------------------------------

function PU:GetEquipSlot(itemLink)

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
-- Upgrade comparison
------------------------------------------------------------

function PU:IsUpgrade(itemLink)

    if not self:CanEquipItem(itemLink) then
        return false, 0, 0
    end

    local newItem =
        self:GetItemData(itemLink)

    if not newItem then
        return false, 0, 0
    end

    local slot =
        self:GetEquipSlot(itemLink)

    if not slot then
        return false, 0, 0
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

    if type(slot) == "table" then

        local worstOld =
            math.huge

        for _, s in ipairs(slot) do

            local oldLink =
                GetInventoryItemLink(
                    "player",
                    s
                )

            local oldScore =
                GetOldScore(oldLink)

            if oldScore < worstOld then
                worstOld = oldScore
            end

        end

        if worstOld == math.huge then

            return false,
                newScore,
                math.huge

        end

        return
            newScore > worstOld,
            newScore,
            worstOld

    end

    local oldLink =
        GetInventoryItemLink(
            "player",
            slot
        )

    local oldScore =
        GetOldScore(oldLink)

    if oldLink and
       oldScore == math.huge then

        return false,
            newScore,
            oldScore

    end

    return
        newScore > oldScore,
        newScore,
        oldScore

end

------------------------------------------------------------
-- Quest reward scoring
------------------------------------------------------------

function PU:GetQuestRewardScore(itemLink)

    if not self:CanEquipItem(itemLink) then
        return 0
    end

    local item =
        self:GetItemData(itemLink)

    if not item then
        return 0
    end

    return self:GetItemScore(item)

end

function PU:GetBestQuestReward()

    local bestButton
    local bestScore = 0

    for i = 1, GetNumQuestChoices() do

        local link =
            GetQuestItemLink(
                "choice",
                i
            )

        if link then

            local score =
                self:GetQuestRewardScore(link)

            if score > bestScore then

                bestScore = score
                bestButton = i

            end

        end

    end

    return bestButton, bestScore

end

------------------------------------------------------------
-- Quest indicators
------------------------------------------------------------

function PU:CreateQuestIndicator(button)

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

    icon:SetTexture(
        "Interface\\Buttons\\UI-CheckBox-Check"
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

    button.PUQuestIcon = icon

end

function PU:UpdateQuestRewards()

    local best =
        self:GetBestQuestReward()

    if not best then
        return
    end

    for i = 1, GetNumQuestChoices() do

        local button =
            _G[
                "QuestInfoItem" .. i
            ]

        if button then

            self:CreateQuestIndicator(
                button
            )

            if i == best then

                button.PUQuestIcon:Show()

            else

                button.PUQuestIcon:Hide()

            end

        end

    end

end

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
                end
            )

        end
    )

    self.questHooked = true

end

------------------------------------------------------------
-- Bag upgrade indicator
------------------------------------------------------------

function PU:CreateUpgradeIndicator(button)

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
        "Interface\\Buttons\\UI-CheckBox-Check"
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

    button.PUUpgradeIcon = icon

end

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

    local upgrade =
        self:IsUpgrade(link)

    if upgrade then

        button.PUUpgradeIcon:Show()

    else

        button.PUUpgradeIcon:Hide()

    end

end

------------------------------------------------------------
-- Blizzard bags
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

    self.defaultHooked = true

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
            function(_, frame, bagID, slotID)

                local button

                if frame
                and frame.Bags
                and frame.Bags[bagID] then

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

    self.elvHooked = true

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

    self.bagnonHooked = true

    print(
        "|cff00ff00EasyGear:|r Bagnon support enabled."
    )

end

------------------------------------------------------------
-- ==========================================================
-- EGUP
-- EasyGear Upgrade Package
-- ==========================================================
--
-- /EGUP
--
-- Target a player and run /EGUP.
--
-- The addon detects the TARGET player's class and sends
-- the configured WotLK 3.3.5a heirloom package.
--
-- Four Portable Holes are also supplied.
--
-- /EGUPCLEAN
--
-- Removes EGUP-provided items which remain in the bags.
-- Equipped items are never deleted.
----------------------------------------------------------

------------------------------------------------------------
-- WotLK 3.3.5a EGUP item database
------------------------------------------------------------

local EGUP_ITEMS = {

    --------------------------------------------------------
    -- Two copies of each trinket.
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
    -- Dread Pirate Ring.
    --------------------------------------------------------

    RING = {

        id = 50255,
        count = 1,
        name = "Dread Pirate Ring"

    },

    --------------------------------------------------------
    -- Portable Hole
    --
    -- Four copies.
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
    -- Leather agility
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
    -- Leather caster
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
    -- Mail agility
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
    -- Mail caster
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
-- Build package for target class
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
    -- Everyone gets the universal leveling items.
    --------------------------------------------------------

    for _, item in ipairs(EGUP_ITEMS.TRINKETS) do
        Add(item)
    end

    Add(EGUP_ITEMS.RING)

    --------------------------------------------------------
    -- Four Portable Holes.
    --------------------------------------------------------

    for _, item in ipairs(EGUP_ITEMS.BAGS) do
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
-- Record EGUP item quantities
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
            name = item.name,
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
-- Send a GM command
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

    self.EGUPRunning = true

    local index = 1

    local function SendNext()

        if index > #self.EGUPQueue then

            self.EGUPQueue = {}
            self.EGUPRunning = false

            print(
                "|cff00ff00EasyGear:|r EGUP completed."
            )

            return

        end

        local command =
            self.EGUPQueue[index]

        index = index + 1

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
-- Print EGUP package
------------------------------------------------------------

function PU:PrintEGUPPackage(
    class,
    targetName
)

    local package =
        self:GetEGUPPackage(class)

    print(
        "|cff00ff00EasyGear EGUP|r"
    )

    print(
        "Target:",
        targetName or "Unknown"
    )

    print(
        "Class:",
        class or "Unknown"
    )

    print(
        "Items:"
    )

    for _, item in ipairs(package) do

        print(
            " .additem",
            targetName,
            item.id,
            item.count,
            "--",
            item.name
        )

    end

end

------------------------------------------------------------
-- Execute /EGUP
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
    or #package == 0 then

        print(
            "|cffff0000EasyGear EGUP:|r No package configured for",
            class
        )

        return

    end

    --------------------------------------------------------
    -- Reset session tracking.
    --------------------------------------------------------

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

    --------------------------------------------------------
    -- Build commands and record quantities.
    --------------------------------------------------------

    for _, item in ipairs(package) do

        self:RecordEGUPItem(item)

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

    --------------------------------------------------------
    -- Summary.
    --------------------------------------------------------

    print(
        "|cff00ff00EasyGear EGUP|r"
    )

    print(
        "Giving WotLK leveling package to:",
        targetName
    )

    print(
        "Class:",
        class
    )

    print(
        "Portable Hole:",
        EGUP_BAG_COUNT,
        "x"
    )

    print(
        "Package commands:",
        #package
    )

    print(
        "Use /EGUPCLEAN after equipping the items."
    )

    --------------------------------------------------------
    -- Start.
    --------------------------------------------------------

    self:ProcessEGUPQueue()

end

------------------------------------------------------------
-- ==========================================================
-- EGUP CLEANUP
-- ==========================================================
--
-- /EGUPCLEAN
--
-- Scans the bags for items recorded by the most recent
-- /EGUP operation.
--
-- It removes only the recorded quantities.
--
-- Equipped items are never touched.
--
-- This operates on the local client's bags, rather than
-- using .removeitem, because .removeitem would not know
-- which copies are equipped versus sitting in bags.
----------------------------------------------------------

------------------------------------------------------------
-- Check whether a bag item is currently equipped
------------------------------------------------------------

function PU:IsItemIDEquipped(itemID)

    itemID =
        tonumber(itemID)

    if not itemID then
        return false
    end

    --------------------------------------------------------
    -- Inventory slots:
    --
    -- 1  Head
    -- 2  Neck
    -- 3  Shoulder
    -- 4  Shirt
    -- 5  Chest
    -- 6  Waist
    -- 7  Legs
    -- 8  Feet
    -- 9  Wrist
    -- 10 Hands
    -- 11 Finger 1
    -- 12 Finger 2
    -- 13 Trinket 1
    -- 14 Trinket 2
    -- 15 Back
    -- 16 Main Hand
    -- 17 Off Hand
    -- 18 Ranged
    -- 19 Tabard
    --------------------------------------------------------

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
-- Extract item ID from an item link
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
-- Find all copies of an item in bags
------------------------------------------------------------

function PU:GetBagItemLocations(itemID)

    local locations = {}

    itemID =
        tonumber(itemID)

    if not itemID then
        return locations
    end

    --------------------------------------------------------
    -- Bags:
    --
    -- 0 = backpack
    -- 1-4 = equipped bags
    --
    -- Standard WotLK inventory uses 0-4 here.
    --------------------------------------------------------

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
-- Delete one bag slot
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

    --------------------------------------------------------
    -- The cursor now holds the item.
    --
    -- DeleteCursorItem() permanently destroys it.
    --------------------------------------------------------

    if CursorHasItem() then

        DeleteCursorItem()

    end

end

------------------------------------------------------------
-- Cleanup a single item ID
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

    --------------------------------------------------------
    -- We remove only the number of copies recorded by EGUP.
    --------------------------------------------------------

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

        index = index + 1

        ----------------------------------------------------
        -- Never delete an item if that item ID is currently
        -- equipped.
        --
        -- If there are multiple identical copies, this is a
        -- conservative safety check. If any copy of the ID
        -- is equipped, we leave one copy alone and continue
        -- cleaning other copies where possible.
        ----------------------------------------------------

        local equipped =
            self:IsItemIDEquipped(
                itemID
            )

        local deleteCount =
            location.count

        if equipped then

            ------------------------------------------------
            -- Preserve one copy from this stack.
            ------------------------------------------------

            if deleteCount > 1 then
                deleteCount = deleteCount - 1
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

        ----------------------------------------------------
        -- Do not delete more than requested.
        ----------------------------------------------------

        if deleteCount > remaining then
            deleteCount = remaining
        end

        ----------------------------------------------------
        -- If the stack contains more than the requested
        -- amount, splitting is necessary to preserve the
        -- rest of the stack.
        --
        -- WoW's protected bag manipulation can vary between
        -- 3.3.5a cores. We therefore delete the entire stack
        -- only when the whole stack is part of the EGUP count.
        ----------------------------------------------------

        if deleteCount >= location.count then

            self:DeleteBagSlot(
                location.bag,
                location.slot
            )

            remaining =
                remaining - location.count

        else

            ------------------------------------------------
            -- Partial stack:
            --
            -- The standard 3.3.5a API does not provide a
            -- completely safe unattended stack-split API
            -- across all private-server clients.
            --
            -- Leave the partial stack intact rather than
            -- risking deletion of unrelated items.
            ------------------------------------------------

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
-- Run /EGUPCLEAN
------------------------------------------------------------

function PU:RunEGUPClean()

    if not self.EGUPSession.active then

        print(
            "|cffff0000EasyGear:|r No EGUP session is available to clean."
        )

        return

    end

    --------------------------------------------------------
    -- Only clean the player for whom EGUP was run.
    --
    -- Since the addon runs on the player's client, the
    -- target must be that same player.
    --------------------------------------------------------

    local targetGUID =
        self.EGUPSession.targetGUID

    local playerGUID =
        UnitGUID("player")

    if targetGUID
    and playerGUID
    and targetGUID ~= playerGUID then

        print(
            "|cffff0000EasyGear:|r EGUPCLEAN must be run by the player who received the EGUP package."
        )

        print(
            "Target:",
            self.EGUPSession.targetName or "Unknown"
        )

        return

    end

    print(
        "|cff00ff00EasyGear EGUPCLEAN|r"
    )

    print(
        "Cleaning items from the bags that were recorded by EGUP."
    )

    local itemList = {}

    for id, data in pairs(
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

            ------------------------------------------------
            -- The session is deliberately retained.
            --
            -- This allows the user to run cleanup again if
            -- bags were full or a partial stack could not be
            -- safely deleted.
            ------------------------------------------------

            return

        end

        local data =
            itemList[index]

        index = index + 1

        local itemID =
            data.id

        local count =
            data.count

        self:CleanupEGUPItem(
            itemID,
            count,
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
-- /EG
------------------------------------------------------------

SLASH_EasyGear1 = "/EG"

SlashCmdList["EasyGear"] =
function(msg)

    if not msg or msg == "" then

        print(
            "Usage: /EG itemlink"
        )

        return

    end

    local upgrade,
          newScore,
          oldScore =
        PU:IsUpgrade(msg)

    if upgrade then

        print(
            "|cff00ff00Upgrade!|r",
            newScore,
            ">",
            oldScore
        )

    else

        print(
            "|cffff0000Not upgrade.|r",
            newScore,
            oldScore
        )

    end

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

            PU.loaded = true

            print(
                "|cff00ff00EasyGear loaded.|r"
            )

            print(
                "Use |cffffff00/EGUP|r while targeting a player to give the class-specific WotLK heirloom package."
            )

            print(
                "Use |cffffff00/EGUPCLEAN|r after equipping to clean the recorded EGUP items from the bags."
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