local addonName = "EasyGear"

local PU = {}
EasyGear = PU

PU.loaded = false
PU.elvHooked = false


------------------------------------------------------------
-- Class stat weights
------------------------------------------------------------

function PU:GetStatWeights()

    local class = select(2, UnitClass("player"))

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

    local result = weights[class] or {
        ITEM_MOD_STAMINA_SHORT = 5
    }

    if UnitLevel("player") <= 80 then
        result.RESISTANCE0_NAME = 5
    end

    return result

end


------------------------------------------------------------
-- Small delayed callback helper
------------------------------------------------------------

local timerFrame = CreateFrame("Frame")

function PU:After(delay, callback)

    local elapsed = 0

    timerFrame:SetScript("OnUpdate", function(self, delta)

        elapsed = elapsed + delta

        if elapsed >= delay then

            self:SetScript("OnUpdate", nil)

            callback()

        end

    end)

end


------------------------------------------------------------
-- Item data
------------------------------------------------------------

function PU:GetItemData(itemLink)

    if not itemLink then
        return nil
    end

    local _, _, quality, itemLevel, _, _, _, _, equipLoc =
        GetItemInfo(itemLink)

    if not itemLevel then
        return nil
    end

    local data = {
        level = itemLevel,
        quality = quality or 0,
        equipLoc = equipLoc,
        stats = {}
    }

    local stats = GetItemStats(itemLink)

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

    local score = item.level * 2

    local weights = self:GetStatWeights()

    for stat, value in pairs(item.stats) do

        local weight = weights[stat]

        if weight then
            score = score + value * weight
        end

    end

    return score

end


------------------------------------------------------------
-- Heirloom detection
--
-- WotLK Quality 7 = Heirloom.
--
-- Equipped heirlooms are considered best while the player
-- is below level 80.
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

    local item = self:GetItemData(itemLink)

    if not item then

        print("EasyGear: Invalid item.")

        return

    end

    print("==============================")
    print("EasyGear Item Debug")
    print("==============================")

    print("Item:", itemLink)
    print("Level:", item.level)
    print("Quality:", item.quality)
    print("Equip:", item.equipLoc)

    print("Stats:")

    local keys = {}

    for stat in pairs(item.stats) do
        table.insert(keys, stat)
    end

    table.sort(keys)

    for _, stat in ipairs(keys) do

        print(
            " ",
            stat,
            "=",
            item.stats[stat]
        )

    end

    print("==============================")

end


------------------------------------------------------------
-- Class equipment compatibility
------------------------------------------------------------

function PU:CanEquipItem(itemLink)

    if not itemLink then
        return false
    end

    local itemName,
          _,
          _,
          _,
          _,
          itemType,
          itemSubType =
        GetItemInfo(itemLink)

    if not itemType then
        return false
    end

    local class =
        select(2, UnitClass("player"))

    local allowed = {

        WARRIOR = {

            ["Stoff"] = true,
            ["Leder"] = true,
            ["Schwere Rüstung"] = true,
            ["Plattenrüstung"] = true,
            ["Verschiedenes"] = true,

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
        },

        PALADIN = {

            ["Stoff"] = true,
            ["Leder"] = true,
            ["Schwere Rüstung"] = true,
            ["Plattenrüstung"] = true,

            ["Einhandstreitkolben"] = true,
            ["Zweihandstreitkolben"] = true,

            ["Einhandschwerter"] = true,
            ["Zweihandschwerter"] = true,

            ["Stangenwaffen"] = true,
        },

        HUNTER = {

            ["Stoff"] = true,
            ["Leder"] = true,
            ["Schwere Rüstung"] = true,
            ["Verschiedenes"] = true,

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
        },

        ROGUE = {

            ["Stoff"] = true,
            ["Leder"] = true,
            ["Verschiedenes"] = true,

            ["Dolche"] = true,
            ["Faustwaffen"] = true,

            ["Einhandäxte"] = true,
            ["Einhandstreitkolben"] = true,

            ["Einhandschwerter"] = true,

            ["Bogen"] = true,
            ["Armbrüste"] = true,
            ["Schusswaffen"] = true,
            ["Wurfwaffen"] = true,
        },

        DRUID = {

            ["Stoff"] = true,
            ["Leder"] = true,
            ["Verschiedenes"] = true,

            ["Dolche"] = true,
            ["Faustwaffen"] = true,

            ["Einhandstreitkolben"] = true,
            ["Zweihandstreitkolben"] = true,

            ["Stangenwaffen"] = true,
            ["Stäbe"] = true,
        },

        SHAMAN = {

            ["Stoff"] = true,
            ["Leder"] = true,
            ["Schwere Rüstung"] = true,
            ["Verschiedenes"] = true,

            ["Dolche"] = true,
            ["Faustwaffen"] = true,

            ["Einhandäxte"] = true,
            ["Zweihandäxte"] = true,

            ["Einhandstreitkolben"] = true,
            ["Zweihandstreitkolben"] = true,

            ["Stäbe"] = true,
        },

        PRIEST = {

            ["Stoff"] = true,
            ["Verschiedenes"] = true,

            ["Dolche"] = true,
            ["Einhandstreitkolben"] = true,

            ["Stäbe"] = true,
            ["Zauberstäbe"] = true,
        },

        MAGE = {

            ["Stoff"] = true,
            ["Verschiedenes"] = true,

            ["Dolche"] = true,
            ["Einhandschwerter"] = true,

            ["Stäbe"] = true,
            ["Zauberstäbe"] = true,
        },

        WARLOCK = {

            ["Stoff"] = true,
            ["Verschiedenes"] = true,

            ["Dolche"] = true,
            ["Einhandschwerter"] = true,

            ["Stäbe"] = true,
            ["Zauberstäbe"] = true,
        },

    }

    return
        allowed[class]
        and allowed[class][itemSubType]
        or false

end


------------------------------------------------------------
-- Equipment slot detection
------------------------------------------------------------

function PU:GetEquipSlot(itemLink)

    local _,_,_,_,_,_,_,_,equipLoc =
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
-- Quest indicator
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
            _G["QuestInfoItem" .. i]

        if button then

            self:CreateQuestIndicator(button)

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

    local function Compare(oldLink)

        if not oldLink then
            return true, 0, 0
        end

        local oldItem =
            self:GetItemData(oldLink)

        if not oldItem then
            return false, 0, 0
        end

        local newValue =
            self:GetItemScore(newItem)

        local oldValue =
            self:GetItemScore(oldItem)

        ----------------------------------------------------
        -- Equipped Quality 7 heirloom is considered best
        -- until the character reaches level 80.
        ----------------------------------------------------

        if self:IsHeirloom(oldItem) then

            return false,
                newValue,
                math.huge

        end

        return
            newValue > oldValue,
            newValue,
            oldValue

    end

    --------------------------------------------------------
    -- Multi-slot item
    --------------------------------------------------------

    if type(slot) == "table" then

        local worstOld = math.huge

        for _, s in ipairs(slot) do

            local oldLink =
                GetInventoryItemLink(
                    "player",
                    s
                )

            if not oldLink then

                worstOld = 0
                break

            end

            local old =
                self:GetItemData(oldLink)

            if old then

                local value

                if self:IsHeirloom(old) then
                    value = math.huge
                else
                    value = self:GetItemScore(old)
                end

                if value < worstOld then
                    worstOld = value
                end

            end

        end

        if worstOld == math.huge then
            worstOld = 0
        end

        local newValue =
            self:GetItemScore(newItem)

        return
            newValue > worstOld,
            newValue,
            worstOld

    end

    --------------------------------------------------------
    -- Single slot
    --------------------------------------------------------

    return Compare(
        GetInventoryItemLink(
            "player",
            slot
        )
    )

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
        1,
        1,
        1,
        1
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

    icon:SetTexCoord(
        0,
        1,
        0,
        1
    )

    icon:SetBlendMode(
        "BLEND"
    )

    button.PUUpgradeIcon = icon

end


function PU:UpdateBagButton(button, bagID, slotID)

    if not button then
        return
    end

    self:CreateUpgradeIndicator(button)

    local link

    if button.GetItem then

        link =
            button:GetItem()

    else

        link =
            GetContainerItemLink(
                bagID,
                slotID
            )

    end

    if not link then

        button.PUUpgradeIcon:Hide()

        return

    end

    local upgrade =
        self:IsUpgrade(link)

    if upgrade then

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

    hooksecurefunc(
        Bags,
        "UpdateSlot",
        function(_, frame, bagID, slotID)

            local button

            if frame.Bags
            and frame.Bags[bagID] then

                button =
                    frame.Bags[bagID][slotID]

            end

            if button then

                PU:UpdateBagButton(
                    button,
                    bagID,
                    slotID
                )

            end

        end
    )

    self.elvHooked = true

    print(
        "|cff00ff00EasyGear:|r ElvUI bag support enabled."
    )

end


------------------------------------------------------------
-- ==========================================================
-- EGUP - EASY GEAR UPGRADE PACKAGE
-- ==========================================================
--
-- /EGUP
--
-- Target a player and run /EGUP.
--
-- EasyGear checks the TARGET'S class and sends the
-- appropriate WotLK 3.3.5a heirloom .additem commands.
--
-- IMPORTANT:
--
-- This is intended for GM/private-server environments.
--
-- The addon itself cannot directly call the server's
-- AddItem API. It sends normal GM commands through chat.
--
-- If the server does not execute addon-generated GM
-- commands, EasyGear prints the commands instead.
------------------------------------------------------------


------------------------------------------------------------
-- WotLK 3.3.5a Heirloom item IDs
------------------------------------------------------------

local EGUP_ITEMS = {

    --------------------------------------------------------
    -- Universal leveling trinkets
    --
    -- Two copies of each because a character has two
    -- trinket slots.
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
    -- Dread Pirate Ring
    --
    -- Only one can be equipped because it is unique-equipped.
    --------------------------------------------------------

    RING = {

        id = 50255,
        count = 1,
        name = "Dread Pirate Ring"

    },


    --------------------------------------------------------
    -- CLOTH
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
    -- LEATHER - AGILITY
    --
    -- Rogue / physical leather leveling package.
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
    -- LEATHER - CASTER / RESTORATION
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
    -- MAIL - PHYSICAL
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

        WEAPON = {
            id = 42945,
            count = 1,
            name = "Venerable Dal'Rend's Sacred Charge"
        },

        MACE = {
            id = 48716,
            count = 1,
            name = "Venerable Mass of McGowan"
        },

        AXE = {
            id = 42946,
            count = 1,
            name = "Charmed Ancient Bone Bow"
        },

    },


    --------------------------------------------------------
    -- MAIL - CASTER
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
    -- PLATE
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
-- Build a list of items for the selected class
------------------------------------------------------------

function PU:GetEGUPPackage(class)

    local package = {}


    --------------------------------------------------------
    -- Add helper
    --------------------------------------------------------

    local function Add(item)

        if not item then
            return
        end

        table.insert(
            package,
            {
                id = item.id,
                count = item.count or 1,
                name = item.name
            }
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
    -- Class-specific items
    --------------------------------------------------------

    if class == "ROGUE" then

        ----------------------------------------------------
        -- Leather only.
        --
        -- No mail.
        -- No plate.
        -- No heavy armor.
        ----------------------------------------------------

        Add(EGUP_ITEMS.LEATHER_AGI.CHEST)
        Add(EGUP_ITEMS.LEATHER_AGI.SHOULDERS)

        Add(EGUP_ITEMS.LEATHER_AGI.DAGGER)
        Add(EGUP_ITEMS.LEATHER_AGI.SWORD)
        Add(EGUP_ITEMS.LEATHER_AGI.THRASH_BLADE)
        Add(EGUP_ITEMS.LEATHER_AGI.OFFHAND_DAGGER)


    elseif class == "DRUID" then

        ----------------------------------------------------
        -- Leather only.
        ----------------------------------------------------

        Add(EGUP_ITEMS.LEATHER_INT.CHEST)
        Add(EGUP_ITEMS.LEATHER_INT.SHOULDERS)

        Add(EGUP_ITEMS.LEATHER_AGI.CHEST)
        Add(EGUP_ITEMS.LEATHER_AGI.SHOULDERS)

        Add(EGUP_ITEMS.LEATHER_INT.WEAPON)


    elseif class == "HUNTER" then

        ----------------------------------------------------
        -- Mail physical.
        ----------------------------------------------------

        Add(EGUP_ITEMS.MAIL_AGI.CHEST)
        Add(EGUP_ITEMS.MAIL_AGI.SHOULDERS)

        Add(EGUP_ITEMS.MAIL_AGI.AXE)


    elseif class == "SHAMAN" then

        ----------------------------------------------------
        -- Enhancement / physical leveling package.
        ----------------------------------------------------

        Add(EGUP_ITEMS.MAIL_AGI.CHEST)
        Add(EGUP_ITEMS.MAIL_AGI.SHOULDERS)

        Add(EGUP_ITEMS.MAIL_AGI.MACE)

        ----------------------------------------------------
        -- Also provide the caster weapon.
        ----------------------------------------------------

        Add(EGUP_ITEMS.MAIL_INT.WEAPON)


    elseif class == "WARRIOR" then

        Add(EGUP_ITEMS.PLATE.CHEST)
        Add(EGUP_ITEMS.PLATE.SHOULDERS)

        Add(EGUP_ITEMS.PLATE.WEAPON)

        ----------------------------------------------------
        -- One-hand weapon option.
        ----------------------------------------------------

        Add(EGUP_ITEMS.LEATHER_AGI.SWORD)
        Add(EGUP_ITEMS.MAIL_AGI.MACE)


    elseif class == "PALADIN" then

        Add(EGUP_ITEMS.PLATE.CHEST)
        Add(EGUP_ITEMS.PLATE.SHOULDERS)

        Add(EGUP_ITEMS.PLATE.WEAPON)

        Add(EGUP_ITEMS.MAIL_INT.WEAPON)


    elseif class == "PRIEST" then

        Add(EGUP_ITEMS.CLOTH.CHEST)
        Add(EGUP_ITEMS.CLOTH.SHOULDERS)

        Add(EGUP_ITEMS.CLOTH.WEAPON)


    elseif class == "MAGE" then

        Add(EGUP_ITEMS.CLOTH.CHEST)
        Add(EGUP_ITEMS.CLOTH.SHOULDERS)

        Add(EGUP_ITEMS.CLOTH.WEAPON)


    elseif class == "WARLOCK" then

        Add(EGUP_ITEMS.CLOTH.CHEST)
        Add(EGUP_ITEMS.CLOTH.SHOULDERS)

        Add(EGUP_ITEMS.CLOTH.WEAPON)

    end


    return package

end


------------------------------------------------------------
-- Print EGUP package
------------------------------------------------------------

function PU:PrintEGUPPackage(class, targetName)

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
            item.id,
            item.count,
            "--",
            item.name
        )

    end

end


------------------------------------------------------------
-- EGUP command sender
------------------------------------------------------------

PU.EGUPQueue = {}
PU.EGUPRunning = false


------------------------------------------------------------
-- Send one GM command
------------------------------------------------------------

function PU:SendEGUPCommand(command)

    --------------------------------------------------------
    -- Send the GM command as normal chat.
    --
    -- AzerothCore/Trinity-style servers can process
    -- .additem as an in-game GM command.
    --------------------------------------------------------

    SendChatMessage(
        command,
        "SAY"
    )

end


------------------------------------------------------------
-- Process the EGUP queue
------------------------------------------------------------

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

        self:SendEGUPCommand(command)

        ----------------------------------------------------
        -- Small delay between commands.
        --
        -- This avoids dumping a large number of GM commands
        -- into the server connection at once.
        ----------------------------------------------------

        self:After(
            0.35,
            SendNext
        )

    end

    SendNext()

end


------------------------------------------------------------
-- Execute EGUP
------------------------------------------------------------

function PU:RunEGUP()

    --------------------------------------------------------
    -- We need a selected player.
    --------------------------------------------------------

    if not UnitExists("target") then

        print(
            "|cffff0000EasyGear EGUP:|r Target a player first."
        )

        return

    end


    if not UnitIsPlayer("target") then

        print(
            "|cffff0000EasyGear EGUP:|r Your target is not a player."
        )

        return

    end


    local targetName =
        UnitName("target")

    if not targetName then

        print(
            "|cffff0000EasyGear EGUP:|r Could not determine target name."
        )

        return

    end


    --------------------------------------------------------
    -- IMPORTANT:
    --
    -- UnitClass("target") returns the selected player's
    -- class, not the GM's class.
    --------------------------------------------------------

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
            "|cffff0000EasyGear EGUP:|r No heirloom package configured for",
            class
        )

        return

    end


    --------------------------------------------------------
    -- Clear old queue.
    --------------------------------------------------------

    self.EGUPQueue = {}


    --------------------------------------------------------
    -- Build commands.
    --
    -- We explicitly specify the player name so that the
    -- command targets the selected character even if the
    -- server command parser does not use the current target.
    --------------------------------------------------------

    for _, item in ipairs(package) do

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
    -- Display summary.
    --------------------------------------------------------

    print(
        "|cff00ff00EasyGear EGUP|r"
    )

    print(
        "Giving WotLK heirlooms to:",
        targetName
    )

    print(
        "Class:",
        class
    )

    print(
        "Items:",
        #package
    )


    --------------------------------------------------------
    -- Start sending.
    --------------------------------------------------------

    self:ProcessEGUPQueue()

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
-- Existing /eg command
------------------------------------------------------------

SLASH_EasyGear1 = "/eg"

SlashCmdList["EasyGear"] =
function(msg)

    if not msg or msg == "" then

        print(
            "Usage: /eg itemlink"
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
-- Blizzard Bags
------------------------------------------------------------

function PU:HookDefaultBags()

    if self.defaultHooked then
        return
    end

    hooksecurefunc(
        "ContainerFrame_Update",
        function(frame)

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

                    PU:UpdateBagButton(
                        button,
                        bagID,
                        i
                    )

                end

            end

        end
    )

    self.defaultHooked = true

    print(
        "|cff00ff00EasyGear:|r Blizzard bag support enabled."
    )

end


------------------------------------------------------------
-- Bagnon
------------------------------------------------------------

function PU:HookBagnon()

    if self.bagnonHooked then
        return
    end

    if not Bagnon
    or not Bagnon.ItemSlot then

        print(
            "EasyGear: Bagnon.ItemSlot not found"
        )

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

                PU:UpdateBagButton(
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
-- Initialization
------------------------------------------------------------

local eventFrame =
    CreateFrame("Frame")


local function Initialize()

    if PU.loaded then
        return
    end

    PU.loaded = true

    print(
        "|cff00ff00EasyGear loaded.|r"
    )

    print(
        "Use |cffffff00/EGUP|r while targeting a player to give class-appropriate WotLK heirlooms."
    )


    --------------------------------------------------------
    -- Bag integration
    --------------------------------------------------------

    if IsAddOnLoaded("ElvUI") then

        PU:HookElvUI()

    elseif IsAddOnLoaded("Bagnon") then

        PU:HookBagnon()

    else

        PU:HookDefaultBags()

    end


    --------------------------------------------------------
    -- Quest integration
    --------------------------------------------------------

    PU:HookQuestRewards()

end


------------------------------------------------------------
-- Events
------------------------------------------------------------

eventFrame:RegisterEvent(
    "ADDON_LOADED"
)

eventFrame:RegisterEvent(
    "PLAYER_ENTERING_WORLD"
)


eventFrame:SetScript(
    "OnEvent",
    function(_, event)

        if event == "PLAYER_ENTERING_WORLD" then

            Initialize()

        end

    end
)