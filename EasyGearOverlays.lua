--[[---------------------------------------------------------------------------
    EasyGear 3.1.0 - Markierungen

    Ein gruenes Haekchen am Item bedeutet "besser als das, was du traegst",
    ein gelbes "waere besser, aber deine Stufe reicht noch nicht". Gezeigt wird
    es ueberall, wo ein Item erscheint:

      Taschen    Blizzard, Bank, ElvUI, Bagnon
      Haendler   Angebot und Rueckkauf
      Beute      Beutefenster und Wuerfelfenster (Beduerfnis/Gier)
      Handel     angebotene Items des Handelspartners
      Auktion    Durchsuchen-Reiter
      Post       Postfach (erster Anhang)

    Die Bewertung selbst kommt aus EG:GetUpgradeState() im Kern; hier wird nur
    angezeigt. Ist kein Upgrade im Spiel, zeigt dasselbe Symbol die Markierungen
    aus EasyGearMarks.lua (Quest, Rezept, Sondieren, Mahlen).
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

local L     = EG.L
local COLOR = EG.COLOR

local TEX_UPGRADE = EG.TEX_UPGRADE
local DEFAULT_ICON_SIZE = 20

local pairs, ipairs, type, tonumber, pcall, select = pairs, ipairs, type, tonumber, pcall, select

------------------------------------------------------------------------------
-- 12  Markierung an einem Button
------------------------------------------------------------------------------

function EG:CreateUpgradeIcon(button)
    if button.EGIcon then return button.EGIcon end
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(TEX_UPGRADE)
    icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    local size = tonumber(self.db and self.db.iconSize) or DEFAULT_ICON_SIZE
    icon:SetWidth(size)
    icon:SetHeight(size)
    icon:Hide()
    button.EGIcon = icon
    return icon
end

--[[ state:  "UPGRADE"  gruen  - echtes Upgrade
             "LEVEL"    gelb   - Upgrade, aber Charakterstufe zu niedrig
             sonst ein Zustand aus EG.MARKS (EasyGearMarks.lua): Quest, Rezept,
             Sondieren, Mahlen ... Das Symbol steht dort.
             nil               - kein Icon

     Das Icon ist an jedem Button dasselbe Textur-Objekt und wird wiederverwendet:
     Textur, Ausschnitt und Farbe muessen deshalb bei jedem Zustand gesetzt werden. ]]
function EG:ApplyIconState(icon, state)
    local mark = state and self.MARK_BY_STATE and self.MARK_BY_STATE[state]
    if state == "UPGRADE" then
        icon:SetTexture(TEX_UPGRADE)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetVertexColor(0, 1, 0)
        icon:Show()
    elseif state == "LEVEL" then
        icon:SetTexture(TEX_UPGRADE)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetVertexColor(1, 0.85, 0)
        icon:Show()
    elseif mark then
        icon:SetTexture(mark.tex)
        icon:SetTexCoord(mark.coords[1], mark.coords[2], mark.coords[3], mark.coords[4])
        icon:SetVertexColor(1, 1, 1)
        icon:Show()
    else
        icon:Hide()
    end
end

--[[ Zustand eines Items fuer die Markierung: Upgrade zuerst, sonst die
     Markierungen aus EasyGearMarks.lua. count ist die Stapelgroesse, wo sie
     bekannt ist (Taschen). Zweiter Rueckgabewert: true, wenn die Itemdaten noch
     nicht im Client liegen.                                                   ]]
function EG:GetMarkerState(link, count)
    local state, pending = self:GetUpgradeState(link)
    if pending then return nil, true end
    if state then return state end
    return self:GetMarkState(link, count)
end

--[[ Aktualisiert das Icon eines Taschen-Buttons.                          ]]
function EG:UpdateBagButton(button, bagID, slotID)
    if not button then return end
    if not (self.db and self.db.showBagIcons) then
        if button.EGIcon then button.EGIcon:Hide() end
        return
    end

    bagID  = tonumber(bagID)
    slotID = tonumber(slotID)
    if not bagID or not slotID then return end

    local link  = GetContainerItemLink(bagID, slotID)
    local sig   = self.epoch or 0
    local count = link and select(2, GetContainerItemInfo(bagID, slotID)) or nil

    -- Nur neu rechnen, wenn sich Inhalt, Stapelgroesse, Profil, Ausruestung oder
    -- Einstellungen geaendert haben (alles erhoeht die Epoche)
    if button.EGLink == link and button.EGSig == sig and button.EGCount == count then
        return
    end
    button.EGLink  = link
    button.EGSig   = sig
    button.EGCount = count

    local icon = self:CreateUpgradeIcon(button)

    if not link then
        icon:Hide()
        return
    end

    local state, pending = self:GetMarkerState(link, count)
    if pending then
        -- Item noch nicht im Client-Cache: Markierung loeschen und
        -- gleich noch einmal versuchen
        button.EGLink = nil
        icon:Hide()
        self:Debounce("bagretry", 0.5, function() self:RefreshAllBags() end)
        return
    end

    self:ApplyIconState(icon, state)
end

--[[ Markierung fuer Buttons ausserhalb der Taschen (Haendler, Beute, ...).
     link = nil raeumt die Markierung weg.                                  ]]
function EG:MarkButton(button, link)
    if not button then return end
    local icon = self:CreateUpgradeIcon(button)
    if not (self.db and self.db.showItemIcons) or not link then
        icon:Hide()
        return
    end

    local state, pending = self:GetMarkerState(link)
    if pending then
        icon:Hide()
        self:Debounce("overlayretry", 0.6, function() self:RefreshOverlays() end)
        return
    end
    self:ApplyIconState(icon, state)
end

------------------------------------------------------------------------------
-- 12d  Haendler, Beute, Wuerfeln, Handel, Auktionshaus, Post
------------------------------------------------------------------------------

local function RefreshMerchant()
    if not (MerchantFrame and MerchantFrame:IsShown()) then return end

    if MerchantFrame.selectedTab == 2 then
        -- Rueckkauf
        for i = 1, (BUYBACK_ITEMS_PER_PAGE or 12) do
            local button = _G["MerchantItem" .. i .. "ItemButton"]
            if button then
                EG:MarkButton(button, (button:IsShown() and GetBuybackItemLink) and GetBuybackItemLink(i) or nil)
            end
        end
        return
    end

    local per  = MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame.page or 1
    for i = 1, per do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            local link
            if button:IsShown() and GetMerchantItemLink then
                link = GetMerchantItemLink((page - 1) * per + i)
            end
            EG:MarkButton(button, link)
        end
    end
end

local function RefreshLoot()
    if not (LootFrame and LootFrame:IsShown()) then return end
    for i = 1, (LOOTFRAME_NUMBUTTONS or 4) do
        local button = _G["LootButton" .. i]
        if button then
            local link
            if button:IsShown() and button.slot and LootSlotIsItem and LootSlotIsItem(button.slot) then
                link = GetLootSlotLink(button.slot)
            end
            EG:MarkButton(button, link)
        end
    end
end

local function MarkRollFrame(frame)
    if not frame then return end
    local link
    if frame:IsShown() and frame.rollID and GetLootRollItemLink then
        link = GetLootRollItemLink(frame.rollID)
    end
    local anchor = frame.IconFrame or (frame.GetName and _G[(frame:GetName() or "") .. "IconFrame"]) or frame
    EG:MarkButton(anchor, link)
end

local function RefreshRolls()
    for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
        local frame = _G["GroupLootFrame" .. i]
        if frame then MarkRollFrame(frame) end
    end
end

local function RefreshTrade()
    if not (TradeFrame and TradeFrame:IsShown() and GetTradeTargetItemLink) then return end
    for i = 1, (MAX_TRADE_ITEMS or 7) do
        local button = _G["TradeRecipientItem" .. i .. "ItemButton"]
        if button then EG:MarkButton(button, GetTradeTargetItemLink(i)) end
    end
end

local function RefreshAuction()
    if not (AuctionFrame and AuctionFrame:IsShown() and BrowseScrollFrame and GetAuctionItemLink) then return end
    local offset = FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(BrowseScrollFrame) or 0
    for i = 1, (NUM_BROWSE_TO_DISPLAY or 8) do
        local button = _G["BrowseButton" .. i .. "Item"]
        if button then
            local link
            if button:IsShown() then link = GetAuctionItemLink("list", offset + i) end
            EG:MarkButton(button, link)
        end
    end
end

local function RefreshInbox()
    if not (InboxFrame and InboxFrame:IsShown() and GetInboxItemLink) then return end
    local per  = INBOXITEMS_TO_DISPLAY or 7
    local page = InboxFrame.pageNum or 1
    for i = 1, per do
        local button = _G["MailItem" .. i .. "Button"]
        if button then
            local link
            if button:IsShown() then link = GetInboxItemLink((page - 1) * per + i, 1) end
            EG:MarkButton(button, link)
        end
    end
end

function EG:RefreshOverlays()
    for _, fn in ipairs({ RefreshMerchant, RefreshLoot, RefreshRolls, RefreshTrade,
                          RefreshAuction, RefreshInbox }) do
        local ok, err = pcall(fn)
        if not ok then self:Debug("overlay error:", err) end
    end
end

local function SafeHook(name, fn)
    if type(_G[name]) == "function" then
        hooksecurefunc(name, fn)
        return true
    end
    return false
end

function EG:HookOverlays()
    if self.hooks.overlays then return end

    self:HookDefaultBags()
    self:HookBank()
    if IsAddOnLoaded("ElvUI") then
        self:HookElvUI()
    elseif IsAddOnLoaded("Bagnon") then
        self:HookBagnon()
    end

    SafeHook("MerchantFrame_UpdateMerchantInfo", RefreshMerchant)
    SafeHook("MerchantFrame_UpdateBuybackInfo",  RefreshMerchant)
    SafeHook("LootFrame_Update",                 RefreshLoot)
    SafeHook("TradeFrame_UpdateTargetItem",      RefreshTrade)
    SafeHook("InboxFrame_Update",                RefreshInbox)
    SafeHook("AuctionFrameBrowse_Update",        RefreshAuction)

    for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
        local frame = _G["GroupLootFrame" .. i]
        if frame and frame.HookScript then
            frame:HookScript("OnShow", MarkRollFrame)
        end
    end

    self.hooks.overlays = true
end

-- Das Auktionshaus-Addon wird erst beim Oeffnen geladen
function EG:OnAddonLoaded(name)
    if name == "Blizzard_AuctionUI" then
        SafeHook("AuctionFrameBrowse_Update", RefreshAuction)
    end
end

function EG:RefreshAllBags()
    if ContainerFrame_Update then
        for i = 1, NUM_CONTAINER_FRAMES or 13 do
            local frame = _G["ContainerFrame" .. i]
            if frame and frame:IsShown() then
                -- Cache invalidieren, damit neu gerechnet wird
                local name = frame:GetName()
                for j = 1, (frame.size or MAX_CONTAINER_ITEMS or 36) do
                    local b = _G[name .. "Item" .. j]
                    if b then b.EGLink = nil end
                end
                ContainerFrame_Update(frame)
            end
        end
    end

    -- Bankfaecher (die Banktaschen laufen ueber die ContainerFrames)
    if BankFrame and BankFrame:IsShown() then
        for i = 1, (NUM_BANKGENERIC_SLOTS or 28) do
            local b = _G["BankFrameItem" .. i]
            if b and b.GetID then
                b.EGLink = nil
                self:UpdateBagButton(b, BANK_CONTAINER or -1, b:GetID())
            end
        end
    end

    if self.RefreshElvUI then self:RefreshElvUI() end
    self:RefreshOverlays()
end

------------------------------------------------------------------------------
-- 12a  Blizzard-Taschen
------------------------------------------------------------------------------

function EG:HookDefaultBags()
    if self.hooks.default or not ContainerFrame_Update then return end

    hooksecurefunc("ContainerFrame_Update", function(frame)
        if not frame then return end
        local bagID = frame:GetID()
        local name  = frame:GetName()
        if not name then return end
        local size  = frame.size or MAX_CONTAINER_ITEMS or 36
        for i = 1, size do
            local button = _G[name .. "Item" .. i]
            if button then
                -- WICHTIG: Der Button-Index entspricht NICHT dem Taschenplatz.
                -- Die Blizzard-Taschen vergeben die IDs rueckwaerts, deshalb
                -- immer button:GetID() verwenden.
                EG:UpdateBagButton(button, bagID, button:GetID())
            end
        end
    end)

    self.hooks.default = true
end

function EG:HookBank()
    if self.hooks.bank or not BankFrameItemButton_Update then return end

    hooksecurefunc("BankFrameItemButton_Update", function(button)
        if not button or button.isBag then return end
        EG:UpdateBagButton(button, BANK_CONTAINER or -1, button:GetID())
    end)

    self.hooks.bank = true
end

------------------------------------------------------------------------------
-- 12b  ElvUI
------------------------------------------------------------------------------

function EG:HookElvUI()
    if self.hooks.elvui or not ElvUI then return end

    local ok, E = pcall(unpack, ElvUI)
    if not ok or not E then return end

    local B = E.GetModule and E:GetModule("Bags", true)
    if not B or not B.UpdateSlot then return end

    self.elvBags = B

    --[[ Die ElvUI-Signaturen unterscheiden sich zwischen den 3.3.5a-Forks:
           B:UpdateSlot(bagID, slotID)
           B:UpdateSlot(frame, bagID, slotID)
         Deshalb werden die Argumente zur Laufzeit ausgewertet.            ]]
    hooksecurefunc(B, "UpdateSlot", function(self_, a, b, c)
        local frame, bagID, slotID
        if type(a) == "table" then
            frame, bagID, slotID = a, b, c
        else
            bagID, slotID = a, b
            frame = self_ and (self_.BagFrame or self_.BankFrame)
        end

        bagID, slotID = tonumber(bagID), tonumber(slotID)
        if not bagID or not slotID then return end

        local button
        if frame and frame.Bags and frame.Bags[bagID] then
            button = frame.Bags[bagID][slotID]
        end
        if not button and self_ and self_.BagFrame and self_.BagFrame.Bags
            and self_.BagFrame.Bags[bagID] then
            button = self_.BagFrame.Bags[bagID][slotID]
        end
        if not button and self_ and self_.BankFrame and self_.BankFrame.Bags
            and self_.BankFrame.Bags[bagID] then
            button = self_.BankFrame.Bags[bagID][slotID]
        end

        if button then
            EG:UpdateBagButton(button, bagID, slotID)
        end
    end)

    function EG:RefreshElvUI()
        local Bmod = self.elvBags
        if not Bmod then return end
        for bagID = 0, NUM_BAG_SLOTS or 4 do
            local numSlots = GetContainerNumSlots(bagID) or 0
            for slotID = 1, numSlots do
                local frame = Bmod.BagFrame
                if frame and frame.Bags and frame.Bags[bagID] then
                    local button = frame.Bags[bagID][slotID]
                    if button then
                        button.EGLink = nil
                        self:UpdateBagButton(button, bagID, slotID)
                    end
                end
            end
        end
    end

    self.hooks.elvui = true
    self:Print(L.HOOK_ELVUI)
end

------------------------------------------------------------------------------
-- 12c  Bagnon
------------------------------------------------------------------------------

function EG:HookBagnon()
    if self.hooks.bagnon or not Bagnon then return end
    if not Bagnon.ItemSlot or not Bagnon.ItemSlot.Update then return end

    hooksecurefunc(Bagnon.ItemSlot, "Update", function(button)
        if not button then return end
        local bag = button.GetBag and button:GetBag() or button.bag
        local slot = button.GetID and button:GetID() or button.slot
        if bag and slot then
            EG:UpdateBagButton(button, bag, slot)
        end
    end)

    self.hooks.bagnon = true
    self:Print(L.HOOK_BAGNON)
end
