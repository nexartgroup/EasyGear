--[[ Minimale WoW-3.3.5a-API fuer Offline-Tests mit Lua 5.1.

     Gebaut wird gerade so viel, dass EasyGear laeuft: Frames (alle Methoden
     sind No-Ops, ausser den wenigen, die Werte liefern), Tooltips mit
     Zeilenfarben, Items mit Statistiken, Taschen, Ausruestung, Talente,
     Auktionshaus-Kategorielisten, Cursor und Chat.

     Schnittstelle fuer die Tests: das globale Objekt T (siehe unten).      ]]

local G = _G
T = { failures = {}, checks = 0 }

-- Kurzformen, die der WoW-Client global bereitstellt
G.tinsert, G.tremove = table.insert, table.remove
G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

------------------------------------------------------------------------------
-- Zustand
------------------------------------------------------------------------------

local World
local function ResetWorld()
    World = {
        locale   = T.locale or "enUS",
        class    = "WARRIOR",
        level    = 80,
        faction  = "Alliance",
        name     = "Tester",
        tabs     = { 0, 0, 0 },
        talents  = {},            -- { {tab=, icon=, rank=} }
        equipment = {},           -- slot -> link
        bags     = {},            -- bag -> { size=, [slot] = { link=, count=, locked= } }
        cursor   = nil,
        chat     = {},
        sent     = {},
        popups   = {},
        deleted  = {},
        target   = nil,
        bankOpen = false,
        quest    = nil,
        spells   = {},            -- Zauber-IDs im Zauberbuch
        questLog = {},            -- { { title=, header=bool, objectives={ {desc=, kind=} } } }
    }
    T.world = World
end

------------------------------------------------------------------------------
-- Frames
------------------------------------------------------------------------------

local Frames = {}
T.frames = Frames
local Methods = {}
local FrameMT = {}

FrameMT.__index = function(t, k)
    local m = Methods[k]
    if m then return m end
    if type(k) == "string" and k:match("^%u") and not k:match("^EG") then
        return function() end   -- unbekannte Methode: No-Op
    end
    return nil
end

local function NewFrame(kind, name, parent)
    local f = setmetatable({ _kind = kind, _name = name, _parent = parent,
                             _scripts = {}, _hooks = {}, _events = {},
                             _text = nil, _color = { 1, 1, 1 }, _lines = {} }, FrameMT)
    Frames[#Frames + 1] = f
    if name then G[name] = f end
    return f
end

function Methods.GetName(self) return self._name end
function Methods.GetParent(self) return self._parent end
function Methods.SetScript(self, ev, fn) self._scripts[ev] = fn end
function Methods.GetScript(self, ev) return self._scripts[ev] end
function Methods.HookScript(self, ev, fn)
    self._hooks[ev] = self._hooks[ev] or {}
    table.insert(self._hooks[ev], fn)
end
function Methods.RegisterEvent(self, ev)
    if type(ev) == "string" then self._events[ev] = true end
end
function Methods.UnregisterEvent(self, ev) self._events[ev] = nil end
function Methods.Hide(self) self._shown = false end
function Methods.Show(self)
    local was = self._shown
    self._shown = true
    if was == false then
        if self._scripts.OnShow then self._scripts.OnShow(self) end
        for _, fn in ipairs(self._hooks.OnShow or {}) do fn(self) end
    end
end
function Methods.IsShown(self) return self._shown ~= false end
function Methods.IsVisible(self) return self._shown ~= false end
function Methods.SetText(self, t) self._text = t end
function Methods.GetText(self) return self._text end
function Methods.SetTextColor(self, r, g, b) self._color = { r, g, b } end
function Methods.GetTextColor(self) return self._color[1], self._color[2], self._color[3] end
function Methods.CreateTexture(self) return NewFrame("Texture", nil, self) end
function Methods.CreateFontString(self) return NewFrame("FontString", nil, self) end
function Methods.SetTexture(self, t) self._texture = t end
function Methods.SetVertexColor(self, r, g, b) self._vertex = { r, g, b } end
function Methods.SetTexCoord(self, a, b, c, d) self._coords = { a, b, c, d } end
function Methods.SetChecked(self, v) self._checked = v end
function Methods.GetChecked(self) return self._checked end
function Methods.SetID(self, v) self._id = v end
function Methods.GetID(self) return self._id or 0 end
function Methods.GetWidth(self) return 100 end
function Methods.GetHeight(self) return 100 end
function Methods.GetScale(self) return 1 end
function Methods.GetPoint(self) return "CENTER", nil, "CENTER", 0, 0 end
function Methods.GetTalentTabInfo() end

-- Tooltips
function Methods.SetOwner(self, owner) self._owner = owner end
function Methods.GetOwner(self) return self._owner end
function Methods.ClearLines(self)
    self._lines = {}
    self._tipLink = nil
end
function Methods.NumLines(self) return #self._lines end
function Methods.AddLine(self, text, r, g, b)
    local n = #self._lines + 1
    self._lines[n] = { text = text, r = r, g = g, b = b }
    local fs = G[(self._name or "") .. "TextLeft" .. n]
    if fs then fs._text = text end
end
function Methods.AddDoubleLine(self, l, r)
    Methods.AddLine(self, l)
end
function Methods.GetItem(self) return nil, self._tipLink end
function Methods.SetHyperlink(self, link)
    local fixture = T.tooltipLines(link)
    if not fixture then error("unknown hyperlink " .. tostring(link)) end
    self._lines = {}
    self._tipLink = link
    for i, ln in ipairs(fixture) do
        self._lines[i] = ln
        local fs = G[(self._name or "") .. "TextLeft" .. i]
        if not fs then
            fs = NewFrame("FontString", (self._name or "") .. "TextLeft" .. i, self)
        end
        fs._text = ln.text
        fs._color = T.colors[ln.color or "white"] or T.colors.white
    end
end

T.colors = {
    white = { 1, 1, 1 }, green = { 0.1, 1, 0.1 }, grey = { 0.5, 0.5, 0.5 },
    red = { 1, 0.1, 0.1 }, gold = { 1, 0.82, 0 },
}

function G.CreateFrame(kind, name, parent, template)
    return NewFrame(kind, name, parent)
end

G.UIParent = NewFrame("Frame", "UIParent")
G.GameTooltip = NewFrame("GameTooltip", "GameTooltip")
G.ItemRefTooltip = NewFrame("GameTooltip", "ItemRefTooltip")
G.ShoppingTooltip1 = NewFrame("GameTooltip", "ShoppingTooltip1")
G.ShoppingTooltip2 = NewFrame("GameTooltip", "ShoppingTooltip2")
G.UISpecialFrames = {}
G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(World.chat, tostring(msg)) end }
G.StaticPopupDialogs = {}
G.SlashCmdList = {}

function G.StaticPopup_Show(name, text)
    local dlg = { name = name, text = text, def = G.StaticPopupDialogs[name] }
    table.insert(World.popups, dlg)
    return dlg
end
function G.CloseDropDownMenus() end
function G.UIDropDownMenu_Initialize(frame, fn) frame._init = fn end
function G.UIDropDownMenu_CreateInfo() return {} end
function G.UIDropDownMenu_AddButton(info) T.lastMenu = T.lastMenu or {}; table.insert(T.lastMenu, info) end
function G.UIDropDownMenu_SetWidth() end

------------------------------------------------------------------------------
-- hooksecurefunc
------------------------------------------------------------------------------

function G.hooksecurefunc(a, b, c)
    local tbl, name, fn
    if type(a) == "table" then tbl, name, fn = a, b, c else tbl, name, fn = G, a, b end
    local orig = tbl[name]
    if type(orig) ~= "function" then error("hooksecurefunc: " .. tostring(name) .. " is not a function") end
    tbl[name] = function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
    end
end

------------------------------------------------------------------------------
-- Globals aus GlobalStrings.lua (enUS)
------------------------------------------------------------------------------

local function SetStrings(map) for k, v in pairs(map) do G[k] = v end end

SetStrings({
    DPS_TEMPLATE = "(%s damage per second)",
    ITEM_MIN_LEVEL = "Requires Level %d",
    ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:",
    ITEM_SPELL_TRIGGER_ONUSE = "Use:",
    ITEM_SPELL_TRIGGER_ONPROC = "Chance on hit:",
    ITEM_SOCKET_BONUS = "Socket Bonus: %s",
    ITEM_SPELL_KNOWN = "Already known",
    ITEM_BIND_QUEST = "Quest Item",
    ITEM_STARTS_QUEST = "This Item Begins a Quest",
    ITEM_PROSPECTABLE = "Prospectable",
    ITEM_MILLABLE = "Millable",
    QUEST_OBJECTS_FOUND = "%s: %d/%d",
    BOOKTYPE_SPELL = "spell",
    ITEM_UNIQUE = "Unique",
    ITEM_UNIQUE_EQUIPPABLE = "Unique-Equipped",
    SPELL_STATALL = "All Stats",
    RESISTANCE0_NAME = "Armor",
    YES = "Yes", NO = "No", ACCEPT = "OK", CANCEL = "Cancel",

    ITEM_MOD_STRENGTH_SHORT = "Strength",      ITEM_MOD_STRENGTH = "%c%s Strength",
    ITEM_MOD_AGILITY_SHORT = "Agility",        ITEM_MOD_AGILITY = "%c%s Agility",
    ITEM_MOD_STAMINA_SHORT = "Stamina",        ITEM_MOD_STAMINA = "%c%s Stamina",
    ITEM_MOD_INTELLECT_SHORT = "Intellect",    ITEM_MOD_INTELLECT = "%c%s Intellect",
    ITEM_MOD_SPIRIT_SHORT = "Spirit",          ITEM_MOD_SPIRIT = "%c%s Spirit",
    ITEM_MOD_ATTACK_POWER_SHORT = "Attack Power",
    ITEM_MOD_ATTACK_POWER = "Equip: Increases attack power by %s.",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "Ranged Attack Power",
    ITEM_MOD_RANGED_ATTACK_POWER = "Equip: Increases ranged attack power by %s.",
    ITEM_MOD_SPELL_POWER_SHORT = "Spell Power",
    ITEM_MOD_SPELL_POWER = "Equip: Increases spell power by %s.",
    ITEM_MOD_SPELL_PENETRATION_SHORT = "Spell Penetration",
    ITEM_MOD_SPELL_PENETRATION = "Equip: Increases spell penetration by %s.",
    ITEM_MOD_CRIT_RATING_SHORT = "Critical Strike Rating",
    ITEM_MOD_CRIT_RATING = "Equip: Improves critical strike rating by %s.",
    ITEM_MOD_HASTE_RATING_SHORT = "Haste Rating",
    ITEM_MOD_HASTE_RATING = "Equip: Improves haste rating by %s.",
    ITEM_MOD_HIT_RATING_SHORT = "Hit Rating",
    ITEM_MOD_HIT_RATING = "Equip: Improves hit rating by %s.",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "Expertise Rating",
    ITEM_MOD_EXPERTISE_RATING = "Equip: Increases your expertise rating by %s.",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "Armor Penetration Rating",
    ITEM_MOD_ARMOR_PENETRATION_RATING = "Equip: Increases armor penetration rating by %s.",
    ITEM_MOD_RESILIENCE_RATING_SHORT = "Resilience Rating",
    ITEM_MOD_RESILIENCE_RATING = "Equip: Improves your resilience rating by %s.",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Defense Rating",
    ITEM_MOD_DEFENSE_SKILL_RATING = "Equip: Increases defense rating by %s.",
    ITEM_MOD_DODGE_RATING_SHORT = "Dodge Rating",
    ITEM_MOD_DODGE_RATING = "Equip: Increases your dodge rating by %s.",
    ITEM_MOD_PARRY_RATING_SHORT = "Parry Rating",
    ITEM_MOD_PARRY_RATING = "Equip: Increases your parry rating by %s.",
    ITEM_MOD_BLOCK_RATING_SHORT = "Block Rating",
    ITEM_MOD_BLOCK_RATING = "Equip: Increases your block rating by %s.",
    ITEM_MOD_BLOCK_VALUE_SHORT = "Block Value",
    ITEM_MOD_BLOCK_VALUE = "Equip: Increases the block value of your shield by %s.",
    ITEM_MOD_POWER_REGEN0_SHORT = "Mana Per 5 Sec.",
    ITEM_MOD_POWER_REGEN0 = "Equip: Restores %s mana per 5 sec.",
    ITEM_MOD_HEALTH_REGEN_SHORT = "Health Per 5 Sec.",
    ITEM_MOD_HEALTH_REGEN = "Equip: Restores %s health per 5 sec.",
    ITEM_MOD_HEALTH_SHORT = "Health",          ITEM_MOD_HEALTH = "%c%s Health",
    ITEM_MOD_MANA_SHORT = "Mana",              ITEM_MOD_MANA = "%c%s Mana",

    HEADSLOT = "Head", NECKSLOT = "Neck", SHOULDERSLOT = "Shoulders", SHIRTSLOT = "Shirt",
    CHESTSLOT = "Chest", WAISTSLOT = "Waist", LEGSSLOT = "Legs", FEETSLOT = "Feet",
    WRISTSLOT = "Wrist", HANDSSLOT = "Hands", FINGER0SLOT = "Finger", FINGER1SLOT = "Finger",
    TRINKET0SLOT = "Trinket", TRINKET1SLOT = "Trinket", BACKSLOT = "Back",
    MAINHANDSLOT = "Main Hand", SECONDARYHANDSLOT = "Off Hand", RANGEDSLOT = "Ranged",
    TABARDSLOT = "Tabard",
})

G.NUM_BAG_SLOTS = 4
G.NUM_BANKBAGSLOTS = 7
G.BANK_CONTAINER = -1
G.NUM_CONTAINER_FRAMES = 13

------------------------------------------------------------------------------
-- Spieler, Talente
------------------------------------------------------------------------------

function G.GetLocale() return World.locale end
function G.UnitClass(unit)
    if unit == "target" and World.target then return World.target.className, World.target.class end
    return World.class, World.class
end
function G.UnitLevel() return World.level end
function G.UnitName(unit)
    if unit == "target" and World.target then return World.target.name end
    return World.name
end
function G.UnitExists(unit) if unit == "target" then return World.target ~= nil end return true end
function G.UnitIsPlayer() return true end
function G.UnitFactionGroup(unit)
    if unit == "target" and World.target then return World.target.faction end
    return World.faction
end
function G.UnitGUID() return "0x0000000000000001" end
function G.GetNumTalentTabs() return 3 end
function G.GetTalentTabInfo(i) return "Tab" .. i, "icon", World.tabs[i] or 0 end
function G.GetNumTalents(tab)
    local n = 0
    for _, t in ipairs(World.talents) do if t.tab == tab then n = n + 1 end end
    return n
end
function G.GetTalentInfo(tab, index)
    local n = 0
    for _, t in ipairs(World.talents) do
        if t.tab == tab then
            n = n + 1
            if n == index then return "Talent", "Interface\\Icons\\" .. t.icon, 1, 1, t.rank or 1, 5 end
        end
    end
end
G.IsAddOnLoaded = function() return false end
G.time = os.time
G.GetItemQualityColor = function() return 1, 1, 1 end
G.GetCoinTextureString = function(v) return tostring(v) .. "c" end
G.FauxScrollFrame_GetOffset = function() return 0 end

------------------------------------------------------------------------------
-- Zauberbuch, Questlog, Einstellungsseiten
------------------------------------------------------------------------------

-- Zaubernamen je Clientsprache (nur die, die EasyGear abfragt)
T.spellNames = {
    [31252] = { enUS = "Prospecting", deDE = "Sondieren" },
    [51005] = { enUS = "Milling",     deDE = "Mahlen" },
}
local function SpellName(id)
    local names = T.spellNames[id]
    return names and (names[World.locale] or names.enUS) or nil
end
function G.GetSpellInfo(id)
    local name = SpellName(id)
    if name then return name, "", "Interface\\Icons\\spell" .. id end
end
function G.GetNumSpellTabs() return 2 end
function G.GetSpellTabInfo(tab)
    -- Reiter 1: Zauber 1-3, Reiter 2: ab 4 (der Rest des Zauberbuchs)
    if tab == 1 then return "General", "tex", 0, 3 end
    return "Professions", "tex", 3, math.max(0, #World.spells - 3)
end
function G.GetSpellName(index, book)
    local id = World.spells[index]
    if id then return SpellName(id) or ("Spell" .. id), "" end
end

function G.GetNumQuestLogEntries()
    return #World.questLog, #World.questLog
end
function G.GetQuestLogTitle(i)
    local q = World.questLog[i]
    if not q then return end
    return q.title, 80, nil, nil, q.header and 1 or nil
end
function G.GetNumQuestLeaderBoards(i)
    local q = World.questLog[i]
    return q and q.objectives and #q.objectives or 0
end
function G.GetQuestLogLeaderBoard(j, i)
    local q = World.questLog[i]
    local o = q and q.objectives and q.objectives[j]
    if o then return o.desc, o.kind, o.done end
end

T.optionPanels, T.optionOpened = {}, 0
function G.InterfaceOptions_AddCategory(panel) table.insert(T.optionPanels, panel) end
function G.InterfaceOptionsFrame_OpenToCategory(panel) T.optionOpened = T.optionOpened + 1; T.optionTarget = panel end

------------------------------------------------------------------------------
-- Items
------------------------------------------------------------------------------

local Items = {}        -- link -> item
local ByID = {}         -- id -> first item
T.items = Items

--[[ T.item{ id=, name=, quality=, ilvl=, minLevel=, itype=, subtype=, loc=,
             stats={ ITEM_MOD_X_SHORT = n }, sockets=n, dps=n, armor=n,
             ench=, gems={...}, extra={ {text=, color=} },   zusaetzliche Zeilen
             sellPrice=, unique=bool, red={text,...} }
     Rueckgabe: Itemlink                                                     ]]
function T.item(d)
    d.quality  = d.quality or 2
    d.ilvl     = d.ilvl or 50
    d.minLevel = d.minLevel or 0
    d.itype    = d.itype or ((d.loc == "INVTYPE_WEAPON" or d.loc == "INVTYPE_2HWEAPON"
        or d.loc == "INVTYPE_WEAPONMAINHAND" or d.loc == "INVTYPE_WEAPONOFFHAND") and "Weapon" or "Armor")
    d.subtype  = d.subtype or "Miscellaneous"
    d.stats    = d.stats or {}
    d.ench     = d.ench or 0
    d.gems     = d.gems or {}
    d.name     = d.name or ("Item" .. d.id)
    local link = string.format("|cff1eff00|Hitem:%d:%d:%d:%d:%d:%d:0:0:%d|h[%s]|h|r", d.id, d.ench,
        d.gems[1] or 0, d.gems[2] or 0, d.gems[3] or 0, d.gems[4] or 0, 80, d.name)
    d.link = link
    Items[link] = d
    ByID[d.id] = ByID[d.id] or d
    return link
end

local STAT_SHORT = {
    ITEM_MOD_STRENGTH_SHORT = true, ITEM_MOD_AGILITY_SHORT = true, ITEM_MOD_STAMINA_SHORT = true,
    ITEM_MOD_INTELLECT_SHORT = true, ITEM_MOD_SPIRIT_SHORT = true, ITEM_MOD_HEALTH_SHORT = true,
    ITEM_MOD_MANA_SHORT = true,
}

-- Zeilen, wie sie der echte Tooltip erzeugt
function T.tooltipLines(link)
    local d = Items[link]
    if not d then return nil end
    local lines = { { text = d.name, color = "white" } }
    if d.quality == 7 then lines[#lines + 1] = { text = "Heirloom", color = "gold" } end
    if d.unique then lines[#lines + 1] = { text = d.unique == "equipped" and "Unique-Equipped" or "Unique", color = "white" } end
    for _, text in ipairs(d.red or {}) do lines[#lines + 1] = { text = text, color = "red" } end
    if (d.armor or 0) > 0 then lines[#lines + 1] = { text = d.armor .. " Armor", color = "white" } end
    if d.dps then
        lines[#lines + 1] = { text = string.format("(%.1f damage per second)", d.dps), color = "white" }
    end
    local keys = {}
    for k in pairs(d.stats) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local v = d.stats[key]
        if key ~= "RESISTANCE0_NAME" and v ~= 0 then
            if STAT_SHORT[key] then
                lines[#lines + 1] = { text = string.format("+%d %s", v, G[key]), color = "white" }
            else
                local long = G[(key:gsub("_SHORT$", ""))]
                lines[#lines + 1] = { text = (long:gsub("%%s", tostring(v))), color = "green" }
            end
        end
    end
    for _, ln in ipairs(d.extra or {}) do lines[#lines + 1] = ln end
    if d.setHeader then lines[#lines + 1] = { text = d.setHeader, color = "gold" } ; for _, ln in ipairs(d.setLines or {}) do lines[#lines + 1] = ln end end
    return lines
end

function G.GetItemInfo(x)
    local d
    if type(x) == "number" then d = ByID[x] else d = Items[x] end
    if not d then return nil end
    return d.name, d.link, d.quality, d.ilvl, d.minLevel, d.itype, d.subtype, 1,
           d.loc or "", "Interface\\Icons\\inv_" .. d.id, d.sellPrice or 0
end

function G.GetItemStats(link)
    local d = Items[link]
    if not d then return nil end
    local out = {}
    for k, v in pairs(d.stats) do out[k] = v end
    if (d.armor or 0) > 0 then out.RESISTANCE0_NAME = d.armor end
    if (d.sockets or 0) > 0 then out.EMPTY_SOCKET_RED = d.sockets end
    -- baseStats: der Tooltip darf mehr enthalten (Gems, Verzauberung) als GetItemStats
    if d.baseStats then out = {} for k, v in pairs(d.baseStats) do out[k] = v end
        if (d.armor or 0) > 0 then out.RESISTANCE0_NAME = d.armor end
        if (d.sockets or 0) > 0 then out.EMPTY_SOCKET_RED = d.sockets end end
    return out
end

------------------------------------------------------------------------------
-- Ausruestung, Taschen, Cursor
------------------------------------------------------------------------------

function G.GetInventoryItemLink(unit, slot) return World.equipment[slot] end
function G.GetContainerNumSlots(bag) local b = World.bags[bag]; return b and b.size or 0 end
function G.GetContainerItemLink(bag, slot)
    local b = World.bags[bag]; local e = b and b[slot]; return e and e.link or nil
end
function G.GetContainerItemInfo(bag, slot)
    local b = World.bags[bag]; local e = b and b[slot]
    if not e then return nil end
    return "tex", e.count or 1, e.locked and true or false
end
function G.PickupContainerItem(bag, slot)
    local b = World.bags[bag]; local e = b and b[slot]
    if e and not e.locked then World.cursor = { bag = bag, slot = slot } end
end
function G.CursorHasItem() return World.cursor ~= nil end
function G.ClearCursor() World.cursor = nil end
function G.DeleteCursorItem()
    local c = World.cursor
    if c then
        local e = World.bags[c.bag][c.slot]
        table.insert(World.deleted, { bag = c.bag, slot = c.slot, link = e.link, count = e.count or 1 })
        World.bags[c.bag][c.slot] = nil
        World.cursor = nil
    end
end
function G.SendChatMessage(msg, channel) table.insert(World.sent, msg) end

G.BankFrame = NewFrame("Frame", "BankFrame")
G.BankFrame._shown = false

------------------------------------------------------------------------------
-- Auktionshaus-Kategorien (Reihenfolge wie im 3.3.5a-Client)
------------------------------------------------------------------------------

T.ahLists = {
    enUS = {
        weapon = { "One-Handed Axes", "Two-Handed Axes", "Bows", "Guns", "One-Handed Maces",
                   "Two-Handed Maces", "Polearms", "One-Handed Swords", "Two-Handed Swords",
                   "Staves", "Fist Weapons", "Miscellaneous", "Daggers", "Thrown", "Crossbows",
                   "Wands", "Fishing Poles" },
        armor  = { "Miscellaneous", "Cloth", "Leather", "Mail", "Plate", "Shields", "Librams",
                   "Idols", "Totems", "Sigils" },
    },
    deDE = {
        weapon = { "Einhandäxte", "Zweihandäxte", "Bögen", "Schusswaffen", "Einhandstreitkolben",
                   "Zweihandstreitkolben", "Stangenwaffen", "Einhandschwerter", "Zweihandschwerter",
                   "Stäbe", "Faustwaffen", "Verschiedenes", "Dolche", "Wurfwaffen", "Armbrüste",
                   "Zauberstäbe", "Angelruten" },
        armor  = { "Verschiedenes", "Stoff", "Leder", "Schwere Rüstung", "Platte", "Schilde",
                   "Buchbände", "Götzen", "Totems", "Siegel" },
    },
}
function G.GetAuctionItemSubClasses(i)
    local l = T.ahLists[World.locale]
    if not l then return end
    local list = (i == 1) and l.weapon or l.armor
    return unpack(list)
end

------------------------------------------------------------------------------
-- Test-Schnittstelle
------------------------------------------------------------------------------

function T.reset(opts)
    opts = opts or {}
    T.locale = opts.locale or T.locale
    ResetWorld()
    for k in pairs(Items) do Items[k] = nil end
    for k in pairs(ByID) do ByID[k] = nil end
    if G.EasyGear then
        local EG = G.EasyGear
        EG.itemCache, EG.tipCache = {}, {}
        EG.scoreCache, EG.stateCache, EG.factCache = {}, {}, {}
        EG.factRetries, EG.spellCount = {}, nil
        EG.questNeeds, EG.questNeedsPrint, EG.abilities = nil, nil, nil
        EG.profileCache, EG.equippedTotals, EG.talentCache = nil, nil, nil
        EG.hasTG, EG.hasDW = nil, nil
        EG.epoch = (EG.epoch or 0) + 1
        if EG.charDB then EG.charDB.profile = "AUTO"; EG.charDB.pvp = false; EG.charDB.egup = nil end
        if EG.db then
            for k, v in pairs(EG.DEFAULTS) do if type(v) ~= "table" then EG.db[k] = v end end
            EG.db.socketValue = nil; EG.db.dpsWeight = nil
            EG.db.egupConfirm = false
        end
    end
end

function T.setPlayer(p)
    for k, v in pairs(p) do World[k] = v end
    local EG = G.EasyGear
    if EG then EG:InvalidateTalents(); EG:InvalidateProfile(); EG:WipeItemCache() end
end

function T.equip(slot, link)
    World.equipment[slot] = link
    local EG = G.EasyGear
    if EG then
        if EG:GetActiveProfileID() == "AUTO" then EG.profileCache = nil end
        EG:InvalidateComparisons(); EG:InvalidateEquippedTotals()
    end
end

function T.bag(bag, slot, link, count)
    World.bags[bag] = World.bags[bag] or { size = 16 }
    World.bags[bag][slot] = link and { link = link, count = count or 1 } or nil
end

-- Faehigkeit lernen (Zauber-ID) / Questlog setzen; der Zauberbuch-Eintrag
-- steht an Position 4 oder spaeter (Reiter "Professions")
function T.learnSpell(id)
    local sp = World.spells
    while #sp < 3 do sp[#sp + 1] = 1 end
    sp[#sp + 1] = id
end
function T.setQuestLog(list) World.questLog = list end

function T.fire(event, ...)
    for _, f in ipairs(Frames) do
        if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

-- Alle OnUpdate-Handler so lange laufen lassen, bis alle Timer abgelaufen sind
function T.runTimers(maxSteps)
    for _ = 1, (maxSteps or 400) do
        local any = false
        for _, f in ipairs(Frames) do
            if f._scripts.OnUpdate and f._shown ~= false then
                any = true
                f._scripts.OnUpdate(f, 0.2)
            end
        end
        if not any then return end
    end
end

function T.chat() return table.concat(World.chat, "\n") end
function T.clearChat() World.chat = {} end

function T.slash(cmd, msg)
    local fn = G.SlashCmdList[cmd]
    if not fn then error("no slash command " .. cmd) end
    fn(msg or "")
end

-- Assertions
function T.check(cond, msg)
    T.checks = T.checks + 1
    if not cond then
        T.failures[#T.failures + 1] = msg or "check failed"
        T.failures[#T.failures] = T.failures[#T.failures] .. "  @ " .. (debug.traceback("", 2):match("[^\n]*\n[^\n]*\n\t([^\n]*)") or "")
    end
end
function T.eq(a, b, msg)
    T.checks = T.checks + 1
    if a ~= b then
        T.failures[#T.failures + 1] = string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a))
    end
end
function T.near(a, b, msg, eps)
    T.checks = T.checks + 1
    if type(a) ~= "number" or math.abs(a - b) > (eps or 1e-6) then
        T.failures[#T.failures + 1] = string.format("%s: expected ~%s, got %s", msg or "near", tostring(b), tostring(a))
    end
end

ResetWorld()
