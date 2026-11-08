--[[---------------------------------------------------------------------------
    Contexts.lua - Anbindung an die Fenster der Standard-Oberflaeche von WoW Forever

    Alle Haken sind "hooksecurefunc" (laufen nach der Blizzard-Funktion, aendern nichts an ihr) und
    gegen fehlende Funktionen abgesichert. Das Ergebnis jedes Hakens steht in EG.hookStatus
    (/eg status zeigt es).

    Der zentrale Haken ist SetItemButtonQuality(button, quality, itemIDOrLink, ...): Blizzard ruft ihn
    fuer fast jeden Gegenstandsknopf auf (Taschen, Bank, Beute, Questbelohnungen, Handel, Post,
    Charakterfenster). Der Haendler ruft stattdessen die Methode des Knopfes auf und hat deshalb einen
    eigenen Haken (MerchantFrameItem_UpdateQuality); die Wuerfelfenster auch (GroupLootFrame_SetupItemDisplay).

    Welche Art von Knopf es ist, zeigt der Knopf selbst:
        Taschen        GetBagID()                       (ContainerFrameItemButtonMixin)
        Bank           GetBankTabID()                   (BankPanelItemButtonMixin)
        Beute          Elternfenster mit GetSlotIndex() (LootFrameElementMixin)
        Questwahl      .type "choice" / "reward"        (QuestInfo.lua)
        Handel         TradeRecipientItem<n>ItemButton  (Items des Handelspartners)
        Post           OpenMailAttachmentButton<n>
        Charakter      Character<Platz>Slot
-----------------------------------------------------------------------------]]

local _, EG = ...
local Contexts = {}
EG.Contexts = Contexts

local Recommend, Marks = EG.Recommend, EG.Marks

local pairs, ipairs, type, pcall, tostring, tonumber = pairs, ipairs, type, pcall, tostring, tonumber
local smatch = string.match

------------------------------------------------------------------------------
-- 01  Art eines Knopfes erkennen
------------------------------------------------------------------------------

local ctxOf = setmetatable({}, { __mode = "k" })        -- Knopf -> Art | false

local function NameOf(frame)
    if frame and frame.GetName then
        local ok, name = pcall(frame.GetName, frame)
        if ok then return name end
    end
end

-- Die 19 Ausruestungsplaetze mit ihren Platznummern; die Knoepfe heissen Character<Name>Slot (Charakterfenster)
-- und Inspect<Name>Slot (Inspektion). Character<...>Slot gibt es auch fuer Taschen und Munition - die zaehlen nicht.
local SLOT_OF_NAME = {
    Head = 1, Neck = 2, Shoulder = 3, Shirt = 4, Chest = 5, Waist = 6, Legs = 7, Feet = 8, Wrist = 9, Hands = 10,
    Finger0 = 11, Finger1 = 12, Trinket0 = 13, Trinket1 = 14, Back = 15, MainHand = 16, SecondaryHand = 17,
    Ranged = 18, Tabard = 19,
}

-- Rueckgabe: "Character" | "Inspect", Platznummer - oder nil
function Contexts.SlotOfName(name)
    if type(name) ~= "string" then return nil end
    local kind, base = smatch(name, "^(Character)(%a+%d?)Slot$")
    if not kind then kind, base = smatch(name, "^(Inspect)(%a+%d?)Slot$") end
    if kind and SLOT_OF_NAME[base] then return kind, SLOT_OF_NAME[base] end
    return nil
end

local function Classify(button)
    if type(button) ~= "table" then return false end

    if button.GetBankTabID and button.GetContainerSlotID then return "bank" end
    -- GetBagID haben alle ItemButton (ItemButtonMixin); nur die Knoepfe der Behaelter tragen auch UpdateNewItem
    if button.UpdateNewItem and button.GetBagID and button.GetID then return "bag" end

    local name = NameOf(button)
    if type(name) == "string" then
        if Contexts.SlotOfName(name) == "Character" then return "char" end
        if smatch(name, "^TradeRecipientItem%dItemButton$") then return "trade" end
        if smatch(name, "^OpenMailAttachmentButton%d+$") then return "mail" end
    end

    if button.type == "choice" or button.type == "reward" then
        if button.GetID then return "quest" end
    end

    local parent = button.GetParent and button:GetParent()
    if parent and parent.GetSlotIndex and parent.Item == button then return "loot" end

    return false
end
Contexts.Classify = Classify

------------------------------------------------------------------------------
-- 02  Links ermitteln
------------------------------------------------------------------------------

local function IsLinkOrID(v)
    return (type(v) == "string" and v ~= "") or type(v) == "number"
end

local function QuestChoiceLink(button)
    local qi = _G.QuestInfoFrame
    local idx = button.GetID and button:GetID()
    if not idx then return nil end
    local getter
    if qi and qi.questLog then getter = _G.GetQuestLogItemLink else getter = _G.GetQuestItemLink end
    if type(getter) ~= "function" then return nil end
    local ok, link = pcall(getter, button.type, idx)
    return ok and link or nil
end

local function ResolveLink(ctx, button, idOrLink)
    if ctx == "bag" then
        if type(idOrLink) == "string" then return idOrLink end
        local ok, link = pcall(C_Container.GetContainerItemLink, button:GetBagID(), button:GetID())
        return ok and link or nil
    elseif ctx == "bank" then
        local info = button.itemInfo
        if info and type(info.hyperlink) == "string" and info.hyperlink ~= "" then return info.hyperlink end
        return IsLinkOrID(idOrLink) and idOrLink or nil
    elseif ctx == "mail" then
        -- Blizzard uebergibt nur die Gegenstandsnummer; der Link (mit Zufallsendung, Edelsteinen) steht in der Post
        local getter, inbox = _G.GetInboxItemLink, _G.InboxFrame
        if type(getter) == "function" and type(inbox) == "table" and inbox.openMailID and button.GetID then
            local ok, link = pcall(getter, inbox.openMailID, button:GetID())
            if ok and IsLinkOrID(link) then return link end
        end
        return IsLinkOrID(idOrLink) and idOrLink or nil
    elseif ctx == "quest" then
        -- Blizzard gibt hier den Link (Angebot) oder die Gegenstandsnummer (Questlog) mit; die Kennung des
        -- Knopfes ist in diesem Augenblick noch die des vorigen Gebrauchs
        if IsLinkOrID(idOrLink) then return idOrLink end
        return QuestChoiceLink(button)
    end
    return IsLinkOrID(idOrLink) and idOrLink or nil
end

------------------------------------------------------------------------------
-- 03  Hinweise am Charakterfenster
------------------------------------------------------------------------------

-- Platz -> Eintrag; .ready sagt, dass die Taschen durchsucht wurden. Der Speicher ist bei Core angemeldet: alles, was
-- die Ergebnisse veraltet (Ausruestung, Profil, Einstellungen, geladene Gegenstaende), leert ihn sofort mit.
local hintCache = {}
EG:RegisterCache(hintCache)

function Contexts.InvalidateHints()
    for k in pairs(hintCache) do hintCache[k] = nil end
end

-- Der beste Kandidat aus den Taschen fuer einen Ausruestungsplatz (oder nil)
function Contexts.SlotHint(slot)
    if not hintCache.ready then
        local ok, best = pcall(Recommend.SlotHints)
        if ok and type(best) == "table" then
            for k, v in pairs(best) do hintCache[k] = v end
        end
        hintCache.ready = true
    end
    return hintCache[slot]
end

-- Was in den Taschen liegt, aendert nur die Hinweise am Charakterfenster; die Vergleichsergebnisse selbst
-- haengen von der Ausruestung ab, nicht vom Inhalt der Taschen
EG:On("BAG_UPDATE_DELAYED", function()
    Contexts.InvalidateHints()
    EG:Debounce("charHints", 0.3, function() EG:Fire("REFRESH") end)
end)

------------------------------------------------------------------------------
-- 04  Beste Questbelohnung
------------------------------------------------------------------------------

local function ChoiceInfo(button)
    local qi = _G.QuestInfoFrame
    local idx = button:GetID()
    local getter = (qi and qi.questLog) and _G.GetQuestLogChoiceInfo or _G.GetQuestItemInfo
    if type(getter) ~= "function" then return 1, nil end
    local res
    if qi and qi.questLog then
        res = { pcall(getter, idx) }
    else
        res = { pcall(getter, button.type, idx) }
    end
    if not res[1] then return 1, nil end
    -- res = ok, Name, Textur, Anzahl, Qualitaet, verwendbar
    return tonumber(res[4]) or 1, res[6]
end

function Contexts.UpdateQuestBest()
    local qi = _G.QuestInfoFrame
    local rewards = qi and qi.rewardsFrame
    local buttons = rewards and rewards.RewardButtons
    if type(buttons) ~= "table" then return end
    if rewards.IsVisible and not rewards:IsVisible() then return end

    local entries, byIndex = {}, {}
    for _, b in ipairs(buttons) do
        if b.IsShown and b:IsShown() and b.type == "choice" and (b.objectType == nil or b.objectType == "item") then
            local idx = b:GetID()
            local link = QuestChoiceLink(b)
            if link then
                local count, usable = ChoiceInfo(b)
                entries[#entries + 1] = { index = idx, link = link, count = count, apiUsable = usable }
            end
            byIndex[idx] = b
        end
    end

    -- Bei nur einer Wahl gibt es nichts zu empfehlen
    local best, kind
    if #entries >= 2 and EG:Get("showQuestIcons") then
        best, kind = Recommend.BestReward(entries)
    end
    for idx, b in pairs(byIndex) do
        Marks.SetBest(b, best ~= nil and idx == best, kind)
    end
end

local function ScheduleQuestBest()
    EG:Debounce("questBest", 0.1, Contexts.UpdateQuestBest)
end

-- Ist dieser Knopf die empfohlene Questwahl? (fuer den Tooltip)  Rueckgabe: ja/nein, Art ("UPGRADE" | "VENDOR")
function Contexts.IsRecommended(button)
    local data = type(button) == "table" and Marks.registry[button] or nil
    if data and data.best then return true, data.bestKind end
    return false
end

------------------------------------------------------------------------------
-- 05  Haken
------------------------------------------------------------------------------

local function OnItemButton(button, _, idOrLink)
    local ctx = ctxOf[button]
    if ctx == nil then
        ctx = Classify(button)
        ctxOf[button] = ctx
    end
    if not ctx then return end

    if ctx == "char" then
        local slot = button:GetID()
        Marks.Set(button, nil, { ctx = "char", hint = function() return Contexts.SlotHint(slot) end })
        return
    end

    -- Waehrungsbelohnungen laufen durch dieselbe Funktion, mit der Waehrungsnummer statt einer Gegenstandsnummer
    -- (objectType wird bei Gegenstaenden erst nach dem Aufruf gesetzt, bei Waehrungen schon davor)
    if ctx == "quest" and button.objectType == "currency" and type(button.currencyInfo) == "table"
       and button.currencyInfo.currencyID == idOrLink then
        Marks.Set(button, nil, { ctx = ctx, best = false })
        return
    end

    local link = ResolveLink(ctx, button, idOrLink)
    Marks.Set(button, link, { ctx = ctx, best = false })
    if ctx == "quest" then ScheduleQuestBest() end
end

local function OnMerchantItem(frame, link)
    local button = frame and frame.ItemButton
    if not button then return end
    Marks.Set(button, IsLinkOrID(link) and link or nil, { ctx = "merchant" })
end

-- Der Link zu einem Wuerfelfenster: GetLootRollItemLink (so klickt auch das Fenster den Gegenstand an,
-- GroupLootFrame.xml), sonst die Tooltip-Daten der Oberflaeche
local function RollLink(rollID)
    local getter = _G.GetLootRollItemLink
    if type(getter) == "function" then
        local ok, link = pcall(getter, rollID)
        if ok and IsLinkOrID(link) then return link end
    end
    if C_TooltipInfo and C_TooltipInfo.GetLootRollItem then
        local ok, data = pcall(C_TooltipInfo.GetLootRollItem, rollID)
        if ok and type(data) == "table" then
            if type(data.hyperlink) == "string" and data.hyperlink ~= "" then return data.hyperlink end
            if type(data.id) == "number" then return data.id end
        end
    end
    return nil
end

local function OnRollItem(frame)
    local button = frame and frame.IconFrame
    if not button or not frame.rollID then return end
    local link = RollLink(frame.rollID)
    Marks.Set(button, IsLinkOrID(link) and link or nil, { ctx = "roll" })
end

local function Hook(name, funcName, handler)
    if type(_G[funcName]) == "function" and hooksecurefunc then
        hooksecurefunc(funcName, function(...) EG:Try(name, handler, ...) end)
        EG:HookResult(name, true)
        return true
    end
    EG:HookResult(name, false, tostring(funcName) .. " fehlt")
    return false
end

EG:OnLoad("contexts", function()
    Hook("itembuttons", "SetItemButtonQuality", OnItemButton)
    Hook("merchant", "MerchantFrameItem_UpdateQuality", OnMerchantItem)
    Hook("rolls", "GroupLootFrame_SetupItemDisplay", OnRollItem)
end)

-- QuestInfo_ShowRewards wird hier nicht eingehakt: QuestInfo_Display ruft die Funktionen aus den Vorlagentabellen
-- auf, die beim Laden entstanden sind. Die Belohnungsknoepfe selbst melden sich ueber SetItemButtonQuality
-- (OnItemButton plant die Auswahl); danach ordnet jedes REFRESH sie neu ein, falls ein Gegenstand spaeter geladen hat.
EG:Listen("REFRESH", function() ScheduleQuestBest() end)
