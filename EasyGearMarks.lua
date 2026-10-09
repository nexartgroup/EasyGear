--[[---------------------------------------------------------------------------
    EasyGear 3.1.0 - weitere Markierungen

    Neben dem Haekchen fuer Ausruestungs-Upgrades zeigt EasyGear an Items, was
    man mit ihnen tun kann oder lassen sollte. Je Item erscheint hoechstens ein
    Symbol, in dieser Rangfolge:

      QUESTNEED  Quest-Fragezeichen   wird fuer eine angenommene Quest gebraucht
      QUESTITEM  Quest-Ausrufezeichen Quest-Item, beginnt eine Quest oder ist
                                      legendaer (nicht ausruestbar): aufheben
      RECIPE     Buch                 Rezept, das der Charakter jetzt lernen kann
      PROSPECT   Edelstein            Erz, das der Charakter sondieren kann
      MILL       Inschriftenkunde     Kraut, das der Charakter mahlen kann
      KNOWN      Muenze               Rezept ist schon bekannt (verkaufbar), aus

    Jedes Symbol hat einen eigenen Schalter (/eg marks, /eg options).

    Quellen:
      Tooltip      Der Scan-Tooltip liefert alles, was im Itemtext steht: "Quest-
                   gegenstand", "Dieser Gegenstand startet eine Quest",
                   "Sondierbar", "Mahlbar", rotes "Bereits bekannt". Die Texte
                   kommen aus den Blizzard-Globals (ITEM_BIND_QUEST usw.) und
                   gelten damit in jeder Clientsprache.
      Questlog     Zielzeilen der Art "Wolfsfell: 3/8". Eingeklappte Gebiete des
                   Questlogs liefert die 3.3.5-API nicht; ihre Quests bleiben
                   unsichtbar, bis das Gebiet aufgeklappt wird.
      Zauberbuch   Sondieren (31252) und Mahlen (51005) sind Faehigkeiten; ob der
                   Charakter sie kann, steht im Zauberbuch.
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

local L     = EG.L
local COLOR = EG.COLOR

local pairs, ipairs, type, tonumber, tostring, pcall = pairs, ipairs, type, tonumber, tostring, pcall
local sformat, smatch, sgsub, slower = string.format, string.match, string.gsub, string.lower
local tconcat, tsort = table.concat, table.sort

local PROSPECT_STACK = 5        -- Sondieren und Mahlen brauchen je 5 Stueck in einem Stapel
local SPELL_PROSPECTING = 31252
local SPELL_MILLING     = 51005
local MAX_QUEST_NAMES   = 3     -- im Tooltip genannte Quests

local TEX_COORDS_ICON  = { 0.08, 0.92, 0.08, 0.92 }   -- Itemsymbole ohne ihren Rand
local TEX_COORDS_FULL  = { 0, 1, 0, 1 }

local function Global(name, default)
    local v = _G[name]
    if type(v) == "string" and v ~= "" then return v end
    return default
end

------------------------------------------------------------------------------
-- 1  Itemklassen
------------------------------------------------------------------------------

--[[ Die Itemklasse kommt als lokalisierter Text aus GetItemInfo(). Die Namen
     stehen in den Sprachdateien (RECIPE_TYPE, QUEST_TYPE; mehrere Schreibweisen
     mit | getrennt); Clientsprache zuerst, dann Englisch.                    ]]
local typeSets = {}             -- Schluessel -> { kleingeschriebener Name = true }

local function TypeSet(key)
    local set = typeSets[key]
    if set then return set end
    set = {}
    local function add(list)
        for _, name in ipairs(EG:SplitAliases(list or "")) do set[slower(name)] = true end
    end
    add(L[key] ~= key and L[key] or "")
    local en = EasyGearLocales and EasyGearLocales.enUS
    if en then add(en[key]) end
    typeSets[key] = set
    return set
end

local function IsType(key, itemType)
    if not itemType or itemType == "" then return false end
    return TypeSet(key)[slower(itemType)] == true
end

function EG:IsRecipeType(itemType) return IsType("RECIPE_TYPE", itemType) end
function EG:IsQuestType(itemType)  return IsType("QUEST_TYPE", itemType) end

-- Systemmeldung "Du hast ... gelernt": die Vorlagen liefert der Client in seiner
-- Sprache (ERR_LEARN_*). Fehlen sie, gelten die englischen als Notanker.
local learnPatterns = nil

function EG:IsLearnMessage(msg)
    if type(msg) ~= "string" then return false end
    if not learnPatterns then
        learnPatterns = {}
        local fallback = {
            ERR_LEARN_RECIPE_S  = "You have learned how to create a new item: %s.",
            ERR_LEARN_SPELL_S   = "You have learned a new spell: %s.",
            ERR_LEARN_ABILITY_S = "You have learned a new ability: %s.",
        }
        for name, default in pairs(fallback) do
            learnPatterns[#learnPatterns + 1] = "^" .. EG:TemplateToPattern(Global(name, default), "(.+)")
        end
    end
    for _, pattern in ipairs(learnPatterns) do
        if smatch(msg, pattern) then return true end
    end
    return false
end

------------------------------------------------------------------------------
-- 2  Itemmerkmale (Tooltip)
------------------------------------------------------------------------------

EG.factCache   = EG.factCache or {}
EG.factRetries = EG.factRetries or {}       -- link -> Fehlversuche des Scan-Tooltips

local MAX_SCAN_TRIES = 3

-- Rueckgabe false, wenn der Tooltip noch nicht bereit ist.
local function ScanTooltipFacts(link, facts)
    if not EG:SetScanTip(link) then return false end

    local tipKnown    = Global("ITEM_SPELL_KNOWN",    "Already known")
    local tipQuest    = Global("ITEM_BIND_QUEST",     "Quest Item")
    local tipStarts   = Global("ITEM_STARTS_QUEST",   "This Item Begins a Quest")
    local tipProspect = Global("ITEM_PROSPECTABLE",   "Prospectable")
    local tipMill     = Global("ITEM_MILLABLE",       "Millable")

    for i = 2, EG.ScanTipObj:NumLines() do
        local fs   = EG:TipLine(i)
        local text = fs and fs:GetText()
        if text and text ~= "" then
            -- "Bereits bekannt" zaehlt in jeder Farbe; jede andere rote Zeile ausser
            -- der Stufenanforderung sperrt das Rezept
            if text == tipKnown then
                facts.known = true
            elseif EG:IsRedLine(fs) and not smatch(text, EG.MinLevelPattern) then
                facts.blocked = true
            end
            if text == tipQuest then
                facts.questItem = true
            elseif text == tipStarts then
                facts.startsQuest = true
            elseif text == tipProspect then
                facts.prospect = true
            elseif text == tipMill then
                facts.mill = true
            end
        end
    end
    return true
end

--[[ Merkmale eines Items, die sich nur durch Lernen oder Fertigkeitsaenderungen
     aendern (InvalidateFacts). Zweiter Rueckgabewert: true, wenn die Itemdaten
     noch nicht im Client liegen. Ausruestbare Items werden nicht gescannt, die
     bewertet der Upgrade-Vergleich.

       name, quality, minLevel, gear
       recipe       Itemklasse Rezept
       known        roter Tooltip-Text "Bereits bekannt"
       blocked      sonst eine rote Zeile (Beruf, Fertigkeit, Klasse, Ruf)
       questType    Itemklasse Quest
       questItem    "Questgegenstand"
       startsQuest  "Dieser Gegenstand startet eine Quest"
       prospect     "Sondierbar"
       mill         "Mahlbar"                                              ]]
function EG:GetItemFacts(link)
    if not link then return nil end
    local hit = self.factCache[link]
    if hit then return hit end

    local name, _, quality, _, minLevel, itemType, _, _, equipLoc = GetItemInfo(link)
    if not name then return nil, true end

    local facts = {
        name     = name,
        quality  = tonumber(quality) or 1,
        minLevel = tonumber(minLevel) or 0,
        gear     = (equipLoc ~= nil and equipLoc ~= "") or false,
    }
    if not facts.gear then
        facts.recipe    = self:IsRecipeType(itemType)
        facts.questType = self:IsQuestType(itemType)
        if not ScanTooltipFacts(link, facts) then
            -- Der Tooltip kann kurz leer sein. Bleibt er es, ohne Tooltip-Merkmale
            -- weitermachen, statt die Taschen ewig neu zu zeichnen.
            local tries = (self.factRetries[link] or 0) + 1
            self.factRetries[link] = tries
            if tries < MAX_SCAN_TRIES then return nil, true end
        end
    end

    self.factCache[link] = facts
    return facts
end

-- Rezept oder Faehigkeit gelernt: alles neu lesen.
function EG:InvalidateFacts()
    self.factCache = {}
    self.factRetries = {}
    self.epoch = (self.epoch or 0) + 1
end

--[[ Fertigkeit oder Ruf gestiegen: nur gesperrte Rezepte koennen dadurch
     erlernbar werden. Beide Ereignisse kommen oft, deshalb bleibt alles andere
     im Speicher. Rueckgabe: true, wenn etwas verworfen wurde.               ]]
function EG:InvalidateBlockedRecipes()
    local dropped = false
    for link, facts in pairs(self.factCache) do
        if facts.recipe and facts.blocked and not facts.known then
            self.factCache[link] = nil
            dropped = true
        end
    end
    if dropped then self.epoch = (self.epoch or 0) + 1 end
    return dropped
end

-- Die Markierungen an Taschen und Fenstern neu bewerten, ohne die Vergleichswerte
-- zu verwerfen.
function EG:MarksChanged()
    self.epoch = (self.epoch or 0) + 1
    self:Debounce("marksrefresh", 0.2, function() self:RefreshAllBags() end)
end

------------------------------------------------------------------------------
-- 3  Questlog
------------------------------------------------------------------------------

EG.questNeeds = nil     -- kleingeschriebener Itemname -> { { quest=, have=, need= }, ... }

local objectivePattern = nil
local function ObjectivePattern()
    if objectivePattern then return objectivePattern end
    local tpl = Global("QUEST_OBJECTS_FOUND", "%s: %d/%d")
    tpl = sgsub(tpl, "%%%d%$", "%%")
    tpl = sgsub(tpl, "%%s", "\1")
    tpl = sgsub(tpl, "%%d", "\2")
    tpl = EG:EscapePattern(tpl)
    tpl = sgsub(tpl, "\1", "(.-)")
    tpl = sgsub(tpl, "\2", "(%%d+)")
    objectivePattern = "^" .. tpl .. "$"
    return objectivePattern
end

local function ParseObjective(desc)
    local name, have, need = smatch(desc, ObjectivePattern())
    if not name then
        name, have, need = smatch(desc, "^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
    end
    name = name and smatch(name, "^%s*(.-)%s*$")
    if not name or name == "" then return nil end
    return name, tonumber(have) or 0, tonumber(need) or 0
end

-- Eine Zeile des Questlogs. Ueberschriften haben keine Zielzeilen; ein Fehler in
-- der Client-API betrifft hoechstens diese eine Zeile (pcall im Aufrufer).
local function ReadQuestEntry(i, needs, fingerprint)
    local title = GetQuestLogTitle(i)
    for j = 1, (tonumber(GetNumQuestLeaderBoards(i)) or 0) do
        local desc, kind = GetQuestLogLeaderBoard(j, i)
        if kind == "item" and type(desc) == "string" then
            local name, have, need = ParseObjective(desc)
            if name then
                local key = slower(name)
                local list = needs[key]
                if not list then list = {}; needs[key] = list end
                list[#list + 1] = { quest = title or "?", have = have, need = need }
                fingerprint[#fingerprint + 1] = key .. "|" .. tostring(title) .. "|" .. have .. "|" .. need
            end
        end
    end
end

local function ReadQuestLog()
    local needs, fingerprint = {}, {}
    if not (GetNumQuestLogEntries and GetQuestLogTitle and GetNumQuestLeaderBoards
            and GetQuestLogLeaderBoard) then
        return needs, ""
    end
    for i = 1, (GetNumQuestLogEntries() or 0) do
        pcall(ReadQuestEntry, i, needs, fingerprint)
    end
    tsort(fingerprint)
    return needs, tconcat(fingerprint, "\n")
end

--[[ Liest das Questlog neu. Rueckgabe: true, wenn sich die benoetigten Items
     seit dem letzten Mal geaendert haben.                                  ]]
function EG:ScanQuestLog()
    local ok, needs, fingerprint = pcall(ReadQuestLog)
    if not ok then
        self:Debug("quest log error:", needs)
        return false
    end
    local changed = (self.questNeedsPrint ~= fingerprint)
    self.questNeeds      = needs
    self.questNeedsPrint = fingerprint
    return changed
end

-- Liste der Quests, die dieses Item brauchen (nil, wenn keine).
function EG:GetQuestNeeds(itemName)
    if not itemName then return nil end
    if not self.questNeeds then self:ScanQuestLog() end
    return self.questNeeds[slower(itemName)]
end

------------------------------------------------------------------------------
-- 4  Berufsfaehigkeiten
------------------------------------------------------------------------------

EG.abilities = nil      -- { prospecting = true, milling = true }

local ABILITY_SPELLS = { prospecting = SPELL_PROSPECTING, milling = SPELL_MILLING }

--[[ Liest das Zauberbuch. Sondieren und Mahlen heissen je nach Clientsprache
     anders; der Name kommt deshalb aus GetSpellInfo(<Zauber-ID>). Rueckgabe:
     true, wenn sich etwas geaendert hat - eine der beiden Faehigkeiten oder die
     Zahl der Zauber, denn ein gelerntes Rezept ist ein neuer Zauber.        ]]
function EG:ScanAbilities()
    local wanted = {}
    if GetSpellInfo then
        for key, id in pairs(ABILITY_SPELLS) do
            local name = GetSpellInfo(id)
            if name then wanted[name] = key end
        end
    end

    local known, total = {}, 0
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellName then
        local book = _G.BOOKTYPE_SPELL or "spell"
        for tab = 1, (GetNumSpellTabs() or 0) do
            local _, _, offset, num = GetSpellTabInfo(tab)
            offset, num = tonumber(offset) or 0, tonumber(num) or 0
            total = total + num
            for i = offset + 1, offset + num do
                local key = wanted[GetSpellName(i, book) or ""]
                if key then known[key] = true end
            end
        end
    end

    local old = self.abilities or {}
    local changed = (old.prospecting ~= known.prospecting) or (old.milling ~= known.milling)
        or (self.spellCount ~= total)
    self.abilities  = known
    self.spellCount = total
    return changed
end

function EG:KnowsAbility(key)
    if not self.abilities then self:ScanAbilities() end
    return self.abilities[key] == true
end

------------------------------------------------------------------------------
-- 5  Die Markierungen
------------------------------------------------------------------------------

local function QuestNeedLine(self, f)
    local list = self:GetQuestNeeds(f.name)
    if not list then return nil end
    local parts = {}
    for i, q in ipairs(list) do
        if i > MAX_QUEST_NAMES then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = sformat("%s (%d/%d)", q.quest, q.have, q.need)
    end
    return COLOR.warn .. sformat(L.MARK_QUESTNEED, tconcat(parts, ", ")) .. COLOR.reset
end

local function QuestItemLine(_, f)
    if f.startsQuest then
        return COLOR.warn .. L.MARK_STARTSQUEST .. COLOR.reset
    elseif f.questItem or f.questType then
        return COLOR.warn .. L.MARK_QUESTITEM .. COLOR.reset
    end
    return COLOR.warn .. L.MARK_LEGENDARY .. COLOR.reset
end

local function Learnable(f)
    return f.recipe and not f.known and not f.blocked
        and (UnitLevel("player") or 1) >= f.minLevel
end

--[[ Reihenfolge = Rangfolge. test(self, facts, count): Zahl der Items im Stapel,
     nil wenn unbekannt (Haendler, Beute, Tooltip).                          ]]
EG.MARKS = {
    { state = "QUESTNEED", setting = "showQuestNeedIcons", default = true,
      name = "MK_QUESTNEED", cmds = { "needed", "questneed", "need" },
      tex = "Interface\\GossipFrame\\ActiveQuestIcon", coords = TEX_COORDS_FULL,
      test = function(self, f) return self:GetQuestNeeds(f.name) ~= nil end,
      line = QuestNeedLine },

    { state = "QUESTITEM", setting = "showQuestItemIcons", default = true,
      name = "MK_QUESTITEM", cmds = { "questitem", "questitems", "qitem" },
      tex = "Interface\\GossipFrame\\AvailableQuestIcon", coords = TEX_COORDS_FULL,
      test = function(_, f)
          return f.questItem or f.startsQuest or f.questType
              or (f.quality == 5 and not f.gear) or false
      end,
      line = QuestItemLine },

    { state = "RECIPE", setting = "showRecipeIcons", default = true,
      name = "MK_RECIPE", cmds = { "recipes", "recipe" },
      tex = EG.TEX_RECIPE, coords = TEX_COORDS_ICON,
      test = function(_, f) return Learnable(f) end,
      line = function() return COLOR.good .. L.RECIPE_LEARNABLE .. COLOR.reset end },

    { state = "PROSPECT", setting = "showProspectIcons", default = true,
      name = "MK_PROSPECT", cmds = { "prospect", "prospecting" },
      tex = "Interface\\Icons\\INV_Misc_Gem_01", coords = TEX_COORDS_ICON,
      test = function(self, f, count)
          return f.prospect and self:KnowsAbility("prospecting")
              and (count == nil or count >= PROSPECT_STACK) or false
      end,
      line = function() return COLOR.title .. L.MARK_PROSPECT .. COLOR.reset end },

    { state = "MILL", setting = "showMillIcons", default = true,
      name = "MK_MILL", cmds = { "mill", "milling" },
      tex = "Interface\\Icons\\INV_Inscription_Tradeskill01", coords = TEX_COORDS_ICON,
      test = function(self, f, count)
          return f.mill and self:KnowsAbility("milling")
              and (count == nil or count >= PROSPECT_STACK) or false
      end,
      line = function() return COLOR.title .. L.MARK_MILL .. COLOR.reset end },

    { state = "KNOWN", setting = "showKnownRecipes", default = false,
      name = "MK_KNOWN", cmds = { "known", "knownrecipes" },
      tex = "Interface\\Icons\\INV_Misc_Coin_01", coords = TEX_COORDS_ICON,
      test = function(_, f) return (f.recipe and f.known) or false end,
      line = function() return COLOR.grey .. L.MARK_KNOWN .. COLOR.reset end },
}

EG.MARK_BY_STATE = {}
for _, spec in ipairs(EG.MARKS) do EG.MARK_BY_STATE[spec.state] = spec end

function EG:MarkEnabled(spec)
    local v = self.db and self.db[spec.setting]
    if v == nil then v = spec.default end
    return v and true or false
end

local function AnyMarkEnabled(self)
    for _, spec in ipairs(EG.MARKS) do
        if self:MarkEnabled(spec) then return true end
    end
    return false
end

--[[ Zustand fuer das Symbol (einer der Namen oben) oder nil. count ist die
     Stapelgroesse, wo sie bekannt ist. Zweiter Rueckgabewert: true, wenn die
     Itemdaten noch nicht im Client liegen.                                  ]]
function EG:GetMarkState(link, count)
    if not link or not AnyMarkEnabled(self) then return nil end
    local facts, pending = self:GetItemFacts(link)
    if not facts then return nil, pending end
    for _, spec in ipairs(EG.MARKS) do
        if self:MarkEnabled(spec) and spec.test(self, facts, count) then
            return spec.state
        end
    end
    return nil
end

-- Wie bisher: nur das Rezept-Symbol ("RECIPE" oder nil).
function EG:GetRecipeState(link)
    local spec = EG.MARK_BY_STATE.RECIPE
    if not link or not self:MarkEnabled(spec) then return nil end
    local facts, pending = self:GetItemFacts(link)
    if not facts then return nil, pending end
    return spec.test(self, facts) and spec.state or nil
end

--[[ Zeilen fuer den Tooltip: eine je zutreffender, eingeschalteter Markierung
     (der Stapel ist hier nicht bekannt, deshalb zaehlt er nicht). nil, wenn
     es nichts zu sagen gibt.                                                ]]
function EG:GetMarkTooltipLines(link)
    if not link or not AnyMarkEnabled(self) then return nil end
    local facts = self:GetItemFacts(link)
    if not facts then return nil end
    local lines
    for _, spec in ipairs(EG.MARKS) do
        if self:MarkEnabled(spec) and spec.test(self, facts, nil) then
            local text = spec.line(self, facts)
            if text then
                lines = lines or {}
                lines[#lines + 1] = text
            end
        end
    end
    return lines
end

------------------------------------------------------------------------------
-- 6  Befehle und Status
------------------------------------------------------------------------------

local function FindMark(name)
    name = slower(name or "")
    if name == "" then return nil end
    for _, spec in ipairs(EG.MARKS) do
        if slower(spec.state) == name then return spec end
        for _, cmd in ipairs(spec.cmds) do
            if cmd == name then return spec end
        end
    end
    return nil
end

function EG:PrintMarkList()
    self:Raw(COLOR.title .. L.MARKS_HEADER .. COLOR.reset)
    for _, spec in ipairs(EG.MARKS) do
        self:Raw(sformat("  %s/eg %-10s%s %s: %s", COLOR.value, spec.cmds[1], COLOR.reset,
            L[spec.name], self:OnOff(self:MarkEnabled(spec))))
    end
    self:Raw(COLOR.grey .. L.MARKS_HINT .. COLOR.reset)
end

function EG:PrintMarkStatus()
    local parts = {}
    for _, spec in ipairs(EG.MARKS) do
        parts[#parts + 1] = L[spec.name] .. ": " .. self:OnOff(self:MarkEnabled(spec))
    end
    self:Raw(L.MARKS_STATUS .. " " .. tconcat(parts, " | "))
end

function EG:SetMark(spec, value)
    self.db[spec.setting] = value and true or false
    EG.ApplySettingChange(false)
    self:Print(L.SET_MARK:format(L[spec.name], self:OnOff(self.db[spec.setting])))
end

--[[ /eg marks                  alle Markierungen mit Stand
     /eg marks <name> [on|off]  umschalten
     /eg <name> [on|off]        Kurzform (recipes, known, prospect, mill, needed, questitem)
     Rueckgabe: true, wenn der Befehl hierher gehoerte.                     ]]
function EG:HandleMarkCommand(cmd, rest)
    if cmd == "marks" or cmd == "mark" then
        local name, arg = smatch(rest or "", "^(%S*)%s*(.-)$")
        local spec = FindMark(name)
        if spec then
            self:SetMark(spec, self:ParseSwitch(arg, self:MarkEnabled(spec)))
        else
            self:PrintMarkList()
        end
        return true
    end
    local spec = FindMark(cmd)
    if spec then
        self:SetMark(spec, self:ParseSwitch(rest, self:MarkEnabled(spec)))
        return true
    end
    return false
end

------------------------------------------------------------------------------
-- 7  Ereignisse
------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
for _, event in ipairs({ "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
                         "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "UPDATE_FACTION" }) do
    pcall(frame.RegisterEvent, frame, event)
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        if event == "UNIT_QUEST_LOG_CHANGED" and arg1 ~= "player" then return end
        EG:Debounce("questmarks", 0.5, function()
            if EG:ScanQuestLog() then EG:MarksChanged() end
        end)
    elseif event == "UPDATE_FACTION" then
        -- Ruf kann ein Rezept freischalten
        EG:Debounce("factionmarks", 1, function()
            if EG:InvalidateBlockedRecipes() then EG:MarksChanged() end
        end)
    else
        EG:Debounce("abilitymarks", 0.5, function()
            if EG:ScanAbilities() then
                -- ein neuer Zauber kann ein eben gelerntes Rezept sein
                EG:InvalidateFacts()
                EG:MarksChanged()
            end
        end)
    end
end)
