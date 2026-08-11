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
------------------------------------------------------------

PU.EGUPSession = {
    targetName = nil,
    targetGUID = nil,
    class = nil,
    items = {},
    active = false
}

------------------------------------------------------------
-- Add package item
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
-- Delayed callback helper
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
            ITEM_MOD_RESISTANCE0 = 0.5,
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
    
    

    local result = weights[class] or {
        ITEM_MOD_STAMINA_SHORT = 5
    }
    
    if UnitLevel("player") <= 80 then
        result.RESISTANCE0_NAME = 5
    end

    return result
    
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
        ((item.level or 0) * 2)

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
-- Quality 7 = Heirloom.
--
-- Below level 80, an equipped Quality 7 heirloom is treated
-- as the best item for that equipment slot.
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

    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulder",
    [4] = "Shirt",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [11] = "Finger 1",
    [12] = "Finger 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [18] = "Ranged",
    [19] = "Tabard",

}

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
-- Get human-readable slot name
------------------------------------------------------------

function PU:GetSlotName(slot, item)

    if type(slot) == "number" then

        return EQUIPMENT_SLOT_NAMES[slot]
            or "Unknown slot"

    end

    if type(slot) == "table" then

        if item then

            if item.equipLoc == "INVTYPE_FINGER" then
                return "Finger"
            end

            if item.equipLoc == "INVTYPE_TRINKET" then
                return "Trinket"
            end

            if item.equipLoc == "INVTYPE_WEAPON"
            or item.equipLoc == "INVTYPE_2HWEAPON"
            or item.equipLoc == "INVTYPE_WEAPONMAINHAND"
            or item.equipLoc == "INVTYPE_WEAPONOFFHAND" then

                return "Weapon"

            end

        end

        return "Multiple slots"

    end

    return "Unknown slot"

end

------------------------------------------------------------
-- Upgrade comparison
------------------------------------------------------------

function PU:IsUpgrade(itemLink)

    if not self:CanEquipItem(itemLink) then
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
                math.huge,
                slot

        end

        return
            newScore > worstOld,
            newScore,
            worstOld,
            slot

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
-- Find equipped heirloom in relevant slot(s)
------------------------------------------------------------

function PU:GetEquippedHeirloom(itemSlot, item)

    if UnitLevel("player") >= 80 then
        return nil
    end

    if type(itemSlot) == "number" then

        local link =
            GetInventoryItemLink(
                "player",
                itemSlot
            )

        if link then

            local equipped =
                self:GetItemData(link)

            if equipped
            and equipped.quality == 7 then

                return equipped

            end

        end

    elseif type(itemSlot) == "table" then

        for _, slot in ipairs(itemSlot) do

            local link =
                GetInventoryItemLink(
                    "player",
                    slot
                )

            if link then

                local equipped =
                    self:GetItemData(link)

                if equipped
                and equipped.quality == 7 then

                    return equipped

                end

            end

        end

    end

    return nil

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
        -- Rüstung
        ["Stoff"] = true,
        ["Leder"] = true,
        ["Schwere Rüstung"] = true,
        ["Plattenrüstung"] = true,

        -- Waffen
        ["Dolche"] = true,
        ["Faustwaffen"] = true,
        ["Einhandäxte"] = true,
        ["Zweihandäxte"] = true,
        ["Einhandstreitkolben"] = true,
        ["Zweihandstreitkolben"] = true,
        ["Einhandschwerter"] = true,
        ["Zweihandschwerter"] = true,
        ["Stangenwaffen"] = true,
        ["Stäbe"] = true,
        ["Schusswaffen"] = true,
        ["Bogen"] = true,
        ["Armbrüste"] = true,
        ["Wurfwaffen"] = true,

        -- Sonstiges
        ["Verschiedenes"] = true,
    },

    PALADIN = {
        -- Rüstung
        ["Stoff"] = true,
        ["Leder"] = true,
        ["Schwere Rüstung"] = true,
        ["Plattenrüstung"] = true,

        -- Waffen
        ["Einhandäxte"] = true,
        ["Zweihandäxte"] = true,
        ["Einhandstreitkolben"] = true,
        ["Zweihandstreitkolben"] = true,
        ["Einhandschwerter"] = true,
        ["Zweihandschwerter"] = true,
        ["Stangenwaffen"] = true,

        -- Sonstiges
        ["Verschiedenes"] = true,
    },

    HUNTER = {
        -- Rüstung
        ["Stoff"] = true,
        ["Leder"] = true,
        ["Schwere Rüstung"] = true,

        -- Waffen
        ["Dolche"] = true,
        ["Einhandäxte"] = true,
        ["Zweihandäxte"] = true,
        ["Einhandschwerter"] = true,
        ["Zweihandschwerter"] = true,
        ["Stangenwaffen"] = true,
        ["Stäbe"] = true,
        ["Bogen"] = true,
        ["Armbrüste"] = true,
        ["Schusswaffen"] = true,
        ["Wurfwaffen"] = true,

        -- Sonstiges
        ["Verschiedenes"] = true,
    },

    ROGUE = {
        -- Rüstung
        ["Stoff"] = true,
        ["Leder"] = true,

        -- Waffen
        ["Dolche"] = true,
        ["Faustwaffen"] = true,
        ["Einhandäxte"] = true,
        ["Einhandstreitkolben"] = true,
        ["Einhandschwerter"] = true,
        ["Bogen"] = true,
        ["Armbrüste"] = true,
        ["Schusswaffen"] = true,
        ["Wurfwaffen"] = true,

        -- Sonstiges
        ["Verschiedenes"] = true,
    },

    DRUID = {
        -- Rüstung
        ["Stoff"] = true,
        ["Leder"] = true,

        -- Waffen
        ["Dolche"] = true,
        ["Faustwaffen"] = true,
        ["Einhandstreitkolben"] = true,
        ["Zweihandstreitkolben"] = true,
        ["Stangenwaffen"] = true,
        ["Stäbe"] = true,

        -- Sonstiges
        ["Verschiedenes"] = true,
    },

    SHAMAN = {
        -- Rüstung
        ["Stoff"] = true,
        ["Leder"] = true,
        ["Schwere Rüstung"] = true,

        -- Waffen
        ["Dolche"] = true,
        ["Faustwaffen"] = true,
        ["Einhandäxte"] = true,
        ["Zweihandäxte"] = true,
        ["Einhandstreitkolben"] = true,
        ["Zweihandstreitkolben"] = true,
        ["Stäbe"] = true,

        -- Sonstiges
        ["Verschiedenes"] = true,
    },

    PRIEST = {
        -- Rüstung
        ["Stoff"] = true,

        -- Waffen
        ["Dolche"] = true,
        ["Einhandstreitkolben"] = true,
        ["Stäbe"] = true,
        ["Zauberstäbe"] = true,

        -- Sonstiges
        ["Verschiedenes"] = true,
    },

    MAGE = {
        -- Rüstung
        ["Stoff"] = true,

        -- Waffen
        ["Dolche"] = true,
        ["Einhandschwerter"] = true,
        ["Stäbe"] = true,
        ["Zauberstäbe"] = true,

        -- Sonstiges
        ["Verschiedenes"] = true,
    },

    WARLOCK = {
        -- Rüstung
        ["Stoff"] = true,

        -- Waffen
        ["Dolche"] = true,
        ["Einhandschwerter"] = true,
        ["Stäbe"] = true,
        ["Zauberstäbe"] = true,

        -- Sonstiges
        ["Verschiedenes"] = true,
    },
}

    if not allowed[class] then
        return false
    end

    return allowed[class][itemSubType] == true

end

--------------------------------------------------------
-- Quest reward scoring
--------------------------------------------------------

function PU:GetQuestRewardScore(itemLink)

    if not itemLink then
        return 0
    end

    local item = self:GetItemData(itemLink)

    if not item then
        return 0
    end

    return self:GetItemScore(item)

end


--------------------------------------------------------
-- Get quest reward item ID
--------------------------------------------------------

function PU:GetQuestRewardItemID(index)

    if not index then
        return nil
    end

    -- Modern clients provide itemID directly.
    if GetQuestItemInfo then

        local _, _, _, _, _, itemID =
            GetQuestItemInfo(
                "choice",
                index
            )

        if itemID then
            return tonumber(itemID)
        end

    end

    -- Fallback: extract ID from item link.
    local link =
        GetQuestItemLink(
            "choice",
            index
        )

    if not link then
        return nil
    end

    return self:GetItemIDFromLink(link)

end


--------------------------------------------------------
-- Get quest reward link
--------------------------------------------------------

function PU:GetQuestRewardLink(index)

    if not index then
        return nil
    end

    return GetQuestItemLink(
        "choice",
        index
    )

end


--------------------------------------------------------
-- Check whether quest reward is usable
--------------------------------------------------------

function PU:IsQuestRewardUsable(index)

    if not index then
        return false
    end

    if GetQuestItemInfo then

        local _, _, _, _, isUsable =
            GetQuestItemInfo(
                "choice",
                index
            )

        if isUsable ~= nil then
            return isUsable
        end

    end

    local link =
        self:GetQuestRewardLink(index)

    if not link then
        return false
    end

    return self:CanEquipItem(link)

end


--------------------------------------------------------
-- Get best quest reward
--------------------------------------------------------

function PU:GetBestQuestReward()

    local bestButton = nil
    local bestScore = -math.huge

    local numChoices =
        GetNumQuestChoices()

    if not numChoices
    or numChoices <= 0 then
        return nil, 0
    end

    for i = 1, numChoices do

        local link =
            self:GetQuestRewardLink(i)

        if link then

            local score = 0

            ------------------------------------------------
            -- Prefer Blizzard's quest usability result.
            ------------------------------------------------

            if self:IsQuestRewardUsable(i) then

                local item =
                    self:GetItemData(link)

                if item then

                    score =
                        self:GetItemScore(item)

                end

            end

            ------------------------------------------------
            -- Keep non-zero results only.
            ------------------------------------------------

            if score > bestScore then

                bestScore = score
                bestButton = i

            end

        end

    end

    if not bestButton then
        return nil, 0
    end

    return bestButton, bestScore

end


--------------------------------------------------------
-- Create quest indicator
--------------------------------------------------------

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


--------------------------------------------------------
-- Update quest rewards
--------------------------------------------------------

function PU:UpdateQuestRewards()

    local numChoices =
        GetNumQuestChoices()

    if not numChoices
    or numChoices <= 0 then
        return
    end

    local best =
        self:GetBestQuestReward()

    if not best then
        return
    end

    for i = 1, numChoices do

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


--------------------------------------------------------
-- Delayed quest reward update
--------------------------------------------------------

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

            ------------------------------------------------
            -- Quest reward item data may not be available
            -- immediately when QuestInfo_Display fires.
            ------------------------------------------------

            self:After(
                0.2,
                function()

                    self:UpdateQuestRewards()

                    ------------------------------------------------
                    -- Second pass in case GetItemInfo() was
                    -- still waiting for item data.
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
-- EGUP ITEM DATABASE
-- ==========================================================
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

    for _, item in ipairs(EGUP_ITEMS.TRINKETS) do
        Add(item)
    end

    Add(EGUP_ITEMS.RING)

    --------------------------------------------------------
    -- Portable Holes
    --------------------------------------------------------

    for _, item in ipairs(EGUP_ITEMS.BAGS) do
        Add(item)
    end

    --------------------------------------------------------
    -- Rogue
    --------------------------------------------------------

    if class == "ROGUE" then

        Add(EGUP_ITEMS.LEATHER_AGI.CHEST)
        Add(EGUP_ITEMS.LEATHER_AGI.SHOULDERS)
        Add(EGUP_ITEMS.LEATHER_AGI.DAGGER)
        Add(EGUP_ITEMS.LEATHER_AGI.SWORD)
        Add(EGUP_ITEMS.LEATHER_AGI.THRASH_BLADE)
        Add(EGUP_ITEMS.LEATHER_AGI.OFFHAND_DAGGER)

    --------------------------------------------------------
    -- Druid
    --------------------------------------------------------

    elseif class == "DRUID" then

        Add(EGUP_ITEMS.LEATHER_INT.CHEST)
        Add(EGUP_ITEMS.LEATHER_INT.SHOULDERS)
        Add(EGUP_ITEMS.LEATHER_INT.WEAPON)

    --------------------------------------------------------
    -- Hunter
    --------------------------------------------------------

    elseif class == "HUNTER" then

        Add(EGUP_ITEMS.MAIL_AGI.CHEST)
        Add(EGUP_ITEMS.MAIL_AGI.SHOULDERS)
        Add(EGUP_ITEMS.MAIL_AGI.BOW)

    --------------------------------------------------------
    -- Shaman
    --------------------------------------------------------

    elseif class == "SHAMAN" then

        Add(EGUP_ITEMS.MAIL_AGI.CHEST)
        Add(EGUP_ITEMS.MAIL_AGI.SHOULDERS)
        Add(EGUP_ITEMS.MAIL_AGI.MACE)
        Add(EGUP_ITEMS.MAIL_INT.WEAPON)

    --------------------------------------------------------
    -- Warrior
    --------------------------------------------------------

    elseif class == "WARRIOR" then

        Add(EGUP_ITEMS.PLATE.CHEST)
        Add(EGUP_ITEMS.PLATE.SHOULDERS)
        Add(EGUP_ITEMS.PLATE.WEAPON)
        Add(EGUP_ITEMS.LEATHER_AGI.SWORD)
        Add(EGUP_ITEMS.MAIL_AGI.MACE)

    --------------------------------------------------------
    -- Paladin
    --------------------------------------------------------

    elseif class == "PALADIN" then

        Add(EGUP_ITEMS.PLATE.CHEST)
        Add(EGUP_ITEMS.PLATE.SHOULDERS)
        Add(EGUP_ITEMS.PLATE.WEAPON)
        Add(EGUP_ITEMS.MAIL_INT.WEAPON)

    --------------------------------------------------------
    -- Priest
    --------------------------------------------------------

    elseif class == "PRIEST" then

        Add(EGUP_ITEMS.CLOTH.CHEST)
        Add(EGUP_ITEMS.CLOTH.SHOULDERS)
        Add(EGUP_ITEMS.CLOTH.WEAPON)

    --------------------------------------------------------
    -- Mage
    --------------------------------------------------------

    elseif class == "MAGE" then

        Add(EGUP_ITEMS.CLOTH.CHEST)
        Add(EGUP_ITEMS.CLOTH.SHOULDERS)
        Add(EGUP_ITEMS.CLOTH.WEAPON)

    --------------------------------------------------------
    -- Warlock
    --------------------------------------------------------

    elseif class == "WARLOCK" then

        Add(EGUP_ITEMS.CLOTH.CHEST)
        Add(EGUP_ITEMS.CLOTH.SHOULDERS)
        Add(EGUP_ITEMS.CLOTH.WEAPON)

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
    or #package == 0 then

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

    print(
        "|cff00ff00EasyGear EGUP|r"
    )

    print(
        "Giving WotLK leveling package to:",
        "|cffffff00" .. targetName .. "|r"
    )

    print(
        "Class:",
        "|cffffff00" .. class .. "|r"
    )

    print(
        "Portable Holes:",
        "|cffffff00" .. EGUP_BAG_COUNT .. "|r"
    )

    print(
        "Package entries:",
        "|cffffff00" .. #package .. "|r"
    )

    print(
        "After equipping the desired items, use:",
        "|cffffff00/EGUPCLEAN|r"
    )

    self:ProcessEGUPQueue()

end

------------------------------------------------------------
-- ==========================================================
-- EGUP CLEANUP
-- ==========================================================
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

        index = index + 1

        local equipped =
            self:IsItemIDEquipped(
                itemID
            )

        local deleteCount =
            location.count

        if equipped then

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

        if deleteCount > remaining then
            deleteCount = remaining
        end

        ----------------------------------------------------
        -- Do not partially destroy a stack.
        --
        -- If the requested amount is smaller than the stack,
        -- leave the stack intact.
        ----------------------------------------------------

        if deleteCount >= location.count then

            self:DeleteBagSlot(
                location.bag,
                location.slot
            )

            remaining =
                remaining - location.count

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
    and targetGUID ~= playerGUID then

        print(
            "|cffff0000EasyGear:|r EGUPCLEAN must be run by the player who received the EGUP package."
        )

        print(
            "EGUP target:",
            self.EGUPSession.targetName or "Unknown"
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

        index = index + 1

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
-- ==========================================================
-- /EG
-- ==========================================================
--
-- Detailed item upgrade information.
------------------------------------------------------------

SLASH_EasyGear1 = "/EG"

SlashCmdList["EasyGear"] =
function(msg)

    if not msg or msg == "" then

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
    -- Check whether the item can be used by this class.
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

    local difference

    --------------------------------------------------------
    -- math.huge is used when a Quality 7 heirloom is
    -- equipped below level 80.
    --------------------------------------------------------

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
        "|cffffff00" .. slotName .. "|r"
    )

    print(
        "Item Level:",
        "|cffffff00" .. tostring(item.level or 0) .. "|r"
    )
    
    local stats = GetItemStats(item.link)

    for stat, value in pairs(stats or {}) do
        print(
            tostring(stat) .. ":",
            "|cffffff00" .. tostring(value) .. "|r"
        )
    end

    print(
        "Quality:",
        "|cffffff00" .. tostring(item.quality or 0) .. "|r"
    )

    if item.itemType then

        print(
            "Type:",
            "|cffffff00" .. tostring(item.itemType) .. "|r"
        )

    end

    if item.itemSubType then

        print(
            "Subtype:",
            "|cffffff00" .. tostring(item.itemSubType) .. "|r"
        )
        
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
        .. tostring(playerClassName or "Unknown")
        .. "|r",
        "Level",
        "|cffffff00"
        .. tostring(playerLevel or 0)
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

            PU.loaded = true

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