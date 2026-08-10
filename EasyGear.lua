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


    ------------------------------------------------
    -- Low level armor scaling
    -- GetItemStats() returns this token:
    -- RESISTANCE0_NAME = Armor
    ------------------------------------------------

    if UnitLevel("player") <= 80 then
        result.RESISTANCE0_NAME = 5
    end


    return result

end

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

function PU:GetItemData(itemLink)

    if not itemLink then
        return nil
    end

    local _, _, _, itemLevel, _, _, _, _, equipLoc =
        GetItemInfo(itemLink)

    if not itemLevel then
        return nil
    end

    local data = {
        level = itemLevel,
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

function PU:DebugItem(itemLink)

    local item = self:GetItemData(itemLink)

    if not item then
        print("Invalid item.")
        return
    end

    print("========== ITEM ==========")
    print("Item:", itemLink)
    print("Level:", item.level)
    print("Equip:", item.equipLoc)

    print("Stats:")

    local keys = {}

    for stat in pairs(item.stats) do
        table.insert(keys, stat)
    end

    table.sort(keys)

    for _, stat in ipairs(keys) do
        print(" ", stat, "=", item.stats[stat])
    end

    print("==========================")
end

------------------------------------------------------------
-- check if item can be equipped
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

    -- Everything except armor and weapons is always usable
    -- if itemType ~= "Rüstung"
    -- and itemType ~= "Waffe" then
    --     return true
    -- end
    
    

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
            ["Verschiedenes"] = true,
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

    local result =
        allowed[class]
        and allowed[class][itemSubType]
        or false

    return result
end

------------------------------------------------------------
-- Slot detection
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

        INVTYPE_FINGER = {11,12},
        INVTYPE_TRINKET = {13,14},

        INVTYPE_CLOAK = 15,

        INVTYPE_WEAPON = {16,17},
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
-- Quest reward comparison
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


    return bestButton,bestScore

end

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


    local best,bestScore =
    self:GetBestQuestReward()



    if not best then
        return
    end



    for i=1,GetNumQuestChoices() do


        local button =
            _G["QuestInfoItem"..i]


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

    if PU.questHooked then
        return
    end


    hooksecurefunc(
        "QuestInfo_Display",
        function()

            PU:After(0.2, function()

                    PU:UpdateQuestRewards()

                end
            )

        end
    )


    PU.questHooked=true

end


------------------------------------------------------------
-- Simple upgrade check
------------------------------------------------------------

function PU:IsUpgrade(itemLink)

    if not self:CanEquipItem(itemLink) then
        return false, 0, 0
    end


    local newItem =
        self:GetItemData(itemLink)


    if not newItem then
        return false
    end


    local slot =
        self:GetEquipSlot(itemLink)


    if not slot then
        return false
    end



    local function Compare(oldLink)

        if not oldLink then
            return true, 0, 0
        end


        local oldItem =
            self:GetItemData(oldLink)


        if not oldItem then
            return false
        end


        local newValue = self:GetItemScore(newItem)


        local oldValue = self:GetItemScore(oldItem)


        return newValue > oldValue,
               newValue,
               oldValue

    end



    if type(slot) == "table" then

        local worstOld = math.huge
    
        for _, s in ipairs(slot) do
    
            local oldLink = GetInventoryItemLink("player", s)
    
            -- Empty slot means the new item can be equipped immediately.
            if not oldLink then
                worstOld = 0
                break
            end
    
            local old = self:GetItemData(oldLink)
    
            if old then
                local value = self:GetItemScore(old)
    
                if value < worstOld then
                    worstOld = value
                end
            end
    
        end
    
        if worstOld == math.huge then
            worstOld = 0
        end
    
        local newValue = self:GetItemScore(newItem)
    
        return newValue > worstOld,
               newValue,
               worstOld
    
    end


    return Compare(
        GetInventoryItemLink(
            "player",
            slot
        )
    )

end



------------------------------------------------------------
-- ElvUI indicator
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

	icon:SetTexCoord(0,1,0,1)

	-- Remove ADD blending
	icon:SetBlendMode("BLEND")

	button.PUUpgradeIcon = icon

end


function PU:UpdateBagButton(button, bagID, slotID)

    if not button then
        return
    end

    self:CreateUpgradeIndicator(button)

    local link

    -- Bagnon
    if button.GetItem then
        link = button:GetItem()

    -- Blizzard / ElvUI
    else
        link = GetContainerItemLink(bagID, slotID)
    end

    if not link then
        button.PUUpgradeIcon:Hide()
        return
    end

    local upgrade = self:IsUpgrade(link)

    if upgrade then
        button.PUUpgradeIcon:SetVertexColor(0, 1, 0)
        button.PUUpgradeIcon:Show()
    else
        button.PUUpgradeIcon:Hide()
    end

end



------------------------------------------------------------
-- ElvUI hook
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
        function(_,frame,bagID,slotID)


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


    print("|cff00ff00EasyGear:|r ElvUI bag support enabled.")

end



------------------------------------------------------------
-- Slash command
------------------------------------------------------------

SLASH_EasyGear1="/puc"

SlashCmdList["EasyGear"] =
function(msg)
    
    if not msg or msg == "" then
        print("Usage: /puc itemlink")
        return
    end
    
    local upgrade,newScore,oldScore =
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


function PU:HookDefaultBags()

    if self.defaultHooked then
        return
    end

    hooksecurefunc("ContainerFrame_Update", function(frame)

        local bagID = frame:GetID()

        for i = 1, MAX_CONTAINER_ITEMS do

            local button = _G[frame:GetName() .. "Item" .. i]

            if button then
                PU:UpdateBagButton(button, bagID, i)
            end
        end
    end)

    self.defaultHooked = true

    print("|cff00ff00EasyGear:|r Blizzard bag support enabled.")
end


function PU:HookBagnon()
    if self.bagnonHooked then
        return
    end

    if not Bagnon or not Bagnon.ItemSlot then
        print("EasyGear: Bagnon.ItemSlot not found")
        return
    end

    hooksecurefunc(Bagnon.ItemSlot, "Update", function(button)
        local bag = button:GetBag()
        local slot = button:GetID()

        if bag and slot then
            PU:UpdateBagButton(button, bag, slot)
        end
    end)

    self.bagnonHooked = true
    print("|cff00ff00EasyGear:|r Bagnon support enabled.")
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
        "|cff00ff00EasyGear loaded.|r Basic item comparison."
    )


    if IsAddOnLoaded("ElvUI") then
        PU:HookElvUI()
    elseif IsAddOnLoaded("Bagnon") then
	print("BAGNON DETECTED!")
        PU:HookBagnon()
    else
        PU:HookDefaultBags()
    end

    PU:HookQuestRewards()

end



eventFrame:RegisterEvent(
    "ADDON_LOADED"
)

eventFrame:RegisterEvent(
    "PLAYER_ENTERING_WORLD"
)



eventFrame:SetScript(
"OnEvent",
function(_,event,addon)

    eventFrame:SetScript("OnEvent", function(_, event)

        if event == "PLAYER_ENTERING_WORLD" then
            Initialize()
        end

    end)
end)