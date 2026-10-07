--[[---------------------------------------------------------------------------
    EasyGear 3.0.0 - EGUP: GM-Klassenpaket und Aufraeumen

      /egup                 sendet das Paket der Klasse des Ziels (.additem ...)
      /egup list [Klasse]   zeigt ein Paket, ohne etwas zu senden
      /egup verify [Klasse] prueft IDs gegen den Client und jedes Paket gegen
                            die Klassenregeln (siehe EG:AuditHeirloomPackage)
      /egupclean            entfernt ALLE nicht angelegten Paket-Items aus den
                            Taschen (und der Bank, wenn sie offen ist)
      /egupclean list       zeigt, was entfernt wuerde

    Die Daten stehen in EasyGearHeirlooms.lua.
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

local L     = EG.L
local COLOR = EG.COLOR

local pairs, ipairs, type, tonumber, tostring, select = pairs, ipairs, type, tonumber, tostring, select
local tinsert, tconcat, tsort = table.insert, table.concat, table.sort
local sformat, slower, sgsub, smatch = string.format, string.lower, string.gsub, string.match
local mmax, mmin = math.max, math.min

local HEIRLOOM_QUALITY = 7
local MAX_EQUIP_SLOT   = 19

------------------------------------------------------------------------------
-- 15  Pakete
------------------------------------------------------------------------------

--[[ Die Erbstueckdaten stehen in EasyGearHeirlooms.lua:
       EG.HEIRLOOMS           Stammdaten je Item-ID
       EG.HEIRLOOM_UNIVERSAL  Ring, Taschen und Insignien fuer jede Klasse
       EG.HEIRLOOM_PACKAGES   Zuordnung je Klasse                          ]]

function EG:GetHeirloomInfo(id)
    return self.HEIRLOOMS and self.HEIRLOOMS[id] or nil
end

-- Angezeigter Name: bevorzugt der lokalisierte aus dem Client
function EG:GetHeirloomName(id)
    local name = GetItemInfo(id)
    if name then return name end
    local info = self:GetHeirloomInfo(id)
    return (info and info.en) or ("Item " .. tostring(id))
end

--[[ Baut das Paket fuer eine Klasse.
     Rueckgabe: Liste aus { id, count, name }
     faction: "Alliance" oder "Horde". Die beiden PvP-Insignien sind
     fraktionsgebunden; ohne Angabe werden beide mitgegeben.              ]]
function EG:GetEGUPPackage(class, faction)
    local package, seen = {}, {}

    local function Add(entry)
        if not entry or not entry.id then return end
        local id = entry.id

        local info = self:GetHeirloomInfo(id)
        if info and info.faction and faction and info.faction ~= faction then
            return   -- gehoert der anderen Fraktion
        end
        if seen[id] then
            -- gleiche ID zweimal gelistet: hoechste Menge gewinnt
            local rec = package[seen[id]]
            rec.count = mmax(rec.count, entry.count or 1)
            return
        end
        package[#package + 1] = {
            id = id, count = entry.count or 1, name = self:GetHeirloomName(id),
        }
        seen[id] = #package
    end

    for _, entry in ipairs(self.HEIRLOOM_UNIVERSAL or {}) do Add(entry) end

    local list = self.HEIRLOOM_PACKAGES and self.HEIRLOOM_PACKAGES[class or ""]
    if list then
        for _, entry in ipairs(list) do Add(entry) end
    end

    return package
end

------------------------------------------------------------------------------
-- Pruefung der Klassenpakete
------------------------------------------------------------------------------

--[[ Regeln, nach denen /egup verify jedes Paket beurteilt:

     tragbar      die Klasse beherrscht Ruestungs- bzw. Waffentyp (Erbstuecke
                  ohne Stufenanforderung: Kette ab 1 fuer Jaeger/Schamanen,
                  Platte ab 1 fuer Krieger/Paladine)
     passend      das Hauptattribut des Stuecks ist ein Hauptattribut der Klasse
                  (PRIMARY). Waffen duerfen zusaetzlich ein Nebenattribut
                  tragen (SECONDARY): Beweglichkeit fuer Plattentraeger, Staerke
                  fuer Leder-/Kettentraeger - es liefert Angriffskraft bzw.
                  kritische Treffer.
     Ruestung     je Platz und Attribut kommt nur die hoechste tragbare
                  Ruestungsklasse ins Paket (Platte vor Kette vor Leder vor
                  Stoff) - ausser es gibt dort kein Teil der hoechsten Klasse.

     Daraus folgen drei Befunde je Paket:
       unbrauchbar    im Paket, aber nicht tragbar
       ueberfluessig  im Paket, tragbar, aber ohne passendes Attribut
       fehlend        passend und tragbar, aber nicht im Paket              ]]
local PRIMARY = {
    WARRIOR = { STR = true },                PALADIN = { STR = true, INT = true },
    DEATHKNIGHT = { STR = true },            HUNTER = { AGI = true },
    ROGUE = { AGI = true },                  SHAMAN = { AGI = true, INT = true },
    DRUID = { AGI = true, INT = true },      PRIEST = { INT = true },
    MAGE = { INT = true },                   WARLOCK = { INT = true },
}
local SECONDARY = {
    WARRIOR = { AGI = true }, PALADIN = { AGI = true }, DEATHKNIGHT = { AGI = true },
    ROGUE = { STR = true },   SHAMAN = { STR = true },  DRUID = { STR = true },
}
local STAT_GROUP = { MELEE_STR = "STR", MELEE_AGI = "AGI", CASTER = "INT", HEAL = "INT" }
local ARMOR_RANK = { CLOTH = 1, LEATHER = 2, MAIL = 3, PLATE = 4 }

EG.HEIRLOOM_CLASSES = { "WARRIOR", "PALADIN", "DEATHKNIGHT", "HUNTER", "ROGUE",
                        "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function IsUniversalEntry(info)
    return info.bag or info.stat == "ANY" or info.stat == "PVP"
end

-- Kann die Klasse das Stueck (Erbstueck-Regeln) tragen?
function EG:HeirloomUsableByClass(id, class)
    local info = self:GetHeirloomInfo(id)
    if not info then return false end
    if info.bag or info.stat == "ANY" or info.stat == "PVP" then return true end
    local token = info.armor or info.weapon
    if not token then return true end   -- Schmuck, Ringe
    return self:GetProficiencyLevel(class, token, true) ~= nil
end

-- Hat das Stueck ein Hauptattribut der Klasse? (Waffen auch Nebenattribut)
function EG:HeirloomMatchesClass(id, class)
    local info = self:GetHeirloomInfo(id)
    if not info then return false end
    if IsUniversalEntry(info) then return true end

    local primary, secondary = PRIMARY[class] or {}, SECONDARY[class] or {}

    if info.loc == "INVTYPE_TRINKET" then
        if info.stat == "MELEE" then return (primary.STR or primary.AGI) and true or false end
        return primary.INT and true or false
    end

    local group = STAT_GROUP[info.stat]
    if not group then return false end
    if primary[group] then return true end
    -- Nebenattribut nur bei Waffen
    return (info.weapon ~= nil and secondary[group]) and true or false
end

-- Ist das Stueck das beste Ruestungsteil seiner Art, das die Klasse tragen kann?
local function IsTopArmor(self, id, class)
    local info = self:GetHeirloomInfo(id)
    if not (info and info.armor) then return true end
    local group = STAT_GROUP[info.stat]
    local mine = ARMOR_RANK[info.armor] or 0
    for otherID, o in pairs(self.HEIRLOOMS) do
        if o.armor and o.loc == info.loc and STAT_GROUP[o.stat] == group
            and self:HeirloomUsableByClass(otherID, class) then
            if (ARMOR_RANK[o.armor] or 0) > mine then return false end
        end
    end
    return true
end

--[[ Rueckgabe: { unusable = {ids}, useless = {ids}, missing = {ids} }       ]]
function EG:AuditHeirloomPackage(class)
    local audit = { unusable = {}, useless = {}, missing = {} }
    if not (self.HEIRLOOMS and self.HEIRLOOM_PACKAGES) then return audit end

    local inPackage = {}
    for _, entry in ipairs(self.HEIRLOOM_PACKAGES[class] or {}) do
        inPackage[entry.id] = true
        if not self:HeirloomUsableByClass(entry.id, class) then
            audit.unusable[#audit.unusable + 1] = entry.id
        elseif not self:HeirloomMatchesClass(entry.id, class) then
            audit.useless[#audit.useless + 1] = entry.id
        end
    end

    local universal = {}
    for _, entry in ipairs(self.HEIRLOOM_UNIVERSAL or {}) do universal[entry.id] = true end

    local ids = {}
    for id in pairs(self.HEIRLOOMS) do ids[#ids + 1] = id end
    tsort(ids)

    for _, id in ipairs(ids) do
        local info = self.HEIRLOOMS[id]
        if not inPackage[id] and not universal[id] and not IsUniversalEntry(info) then
            -- Fehlend zaehlt nur, was ein HAUPTattribut trifft (Nebenattribute
            -- sind erlaubt, aber nicht verlangt)
            local primary = PRIMARY[class] or {}
            local isPrimary
            if info.loc == "INVTYPE_TRINKET" then
                isPrimary = (info.stat == "MELEE") and (primary.STR or primary.AGI) or (info.stat ~= "MELEE" and primary.INT)
            else
                isPrimary = primary[STAT_GROUP[info.stat] or ""]
            end
            if isPrimary and self:HeirloomUsableByClass(id, class) and IsTopArmor(self, id, class) then
                audit.missing[#audit.missing + 1] = id
            end
        end
    end
    return audit
end

--[[ Prueft alle hinterlegten IDs gegen den Client-Cache und danach die
     Klassenpakete.

     Eine falsche ID faellt bei ".additem" sonst nicht auf: der Server
     meldet den Fehler, der Spieler bekommt nichts, und im Paket sieht
     alles richtig aus. Geprueft wird deshalb, ob das Item existiert, ob
     es Erbstueckqualitaet hat und welchen Slot es tatsaechlich belegt.  ]]
function EG:VerifyHeirlooms(classFilter)
    if not self.HEIRLOOMS then
        self:Print(COLOR.bad .. L.EGUP_NO_DATA .. COLOR.reset)
        return
    end

    local ids = {}
    if classFilter then
        for _, e in ipairs(self:GetEGUPPackage(classFilter)) do ids[#ids + 1] = e.id end
    else
        for id in pairs(self.HEIRLOOMS) do ids[#ids + 1] = id end
        tsort(ids)
    end

    self:Raw(COLOR.title .. "===== " .. L.EGUP_VERIFY_HEAD .. " =====" .. COLOR.reset)

    local ok, missing, wrong = 0, 0, 0

    for _, id in ipairs(ids) do
        local info = self:GetHeirloomInfo(id)
        local name, link, quality, _, _, _, subType, _, equipLoc = GetItemInfo(id)

        if not name then
            missing = missing + 1
            self:Raw(sformat("  %s%-6d%s %s%s%s  %s", COLOR.value, id, COLOR.reset,
                COLOR.bad, L.EGUP_VERIFY_MISSING, COLOR.reset,
                COLOR.grey .. (info and info.en or "?") .. COLOR.reset))
        else
            local problems = {}

            if not (info and info.bag) and quality ~= HEIRLOOM_QUALITY then
                problems[#problems + 1] = sformat(L.EGUP_VERIFY_QUALITY, tostring(quality))
            end
            if info and info.loc and info.loc ~= "" and equipLoc ~= info.loc then
                -- Bogen kann je nach Client RANGED oder RANGEDRIGHT sein
                local rangedOK = (info.loc == "INVTYPE_RANGED" and equipLoc == "INVTYPE_RANGEDRIGHT")
                    or (info.loc == "INVTYPE_RANGEDRIGHT" and equipLoc == "INVTYPE_RANGED")
                -- Schildhand-/Waffenhand-Varianten derselben Einhandwaffe
                local handOK = (info.loc == "INVTYPE_WEAPON" or info.loc == "INVTYPE_WEAPONMAINHAND")
                    and (equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND")
                if not rangedOK and not handOK then
                    problems[#problems + 1] = sformat(L.EGUP_VERIFY_SLOT,
                        tostring(equipLoc), tostring(info.loc))
                end
            end

            -- Hauptattribut gegen den echten Tooltip: die Statrolle in der Tabelle
            -- ist eine Annahme, hier faellt sie auf, wenn der Client etwas anderes zeigt
            local expect = info and STAT_GROUP[info.stat]
            if expect and link then
                local scan = self:ScanItemTooltip(link)
                if scan and scan.hasStats then
                    local st = scan.stats
                    local str, agi = st[self.STAT_KEYS.STR] or 0, st[self.STAT_KEYS.AGI] or 0
                    local int, sp  = st[self.STAT_KEYS.INT] or 0, st[self.STAT_KEYS.SP] or 0
                    local actual
                    if int > 0 or sp > 0 then
                        if int >= str and int >= agi then actual = "INT" end
                    end
                    if not actual then actual = (str >= agi) and "STR" or "AGI" end
                    if (str + agi + int + sp) > 0 and actual ~= expect then
                        problems[#problems + 1] = sformat(L.EGUP_VERIFY_STAT, actual, expect)
                    end
                end
            end

            if #problems > 0 then
                wrong = wrong + 1
                self:Raw(sformat("  %s%-6d%s %s  %s%s%s", COLOR.value, id, COLOR.reset,
                    link or name, COLOR.warn, tconcat(problems, ", "), COLOR.reset))
            else
                ok = ok + 1
                self:Raw(sformat("  %s%-6d%s %s  %s%s%s", COLOR.value, id, COLOR.reset,
                    link or name, COLOR.grey, tostring(subType or ""), COLOR.reset))
            end
        end
    end

    self:Raw(sformat("%s%s%s  %s%d%s  |  %s%d%s  |  %s%d%s",
        COLOR.title, L.EGUP_VERIFY_SUM, COLOR.reset,
        COLOR.good, ok, COLOR.reset,
        COLOR.warn, wrong, COLOR.reset,
        COLOR.bad, missing, COLOR.reset))

    if missing > 0 then
        self:Raw(COLOR.grey .. L.EGUP_VERIFY_HINT .. COLOR.reset)
    end

    -- Klassenpakete
    self:Raw(COLOR.title .. "===== " .. L.EGUP_AUDIT_HEAD .. " =====" .. COLOR.reset)
    local classes = classFilter and { classFilter } or self.HEIRLOOM_CLASSES
    local problems = 0
    for _, class in ipairs(classes) do
        local a = self:AuditHeirloomPackage(class)
        local function Names(list)
            local out = {}
            for _, id in ipairs(list) do out[#out + 1] = self:GetHeirloomName(id) .. " (" .. id .. ")" end
            return tconcat(out, ", ")
        end
        local n = #a.unusable + #a.useless + #a.missing
        problems = problems + n
        local head = COLOR.value .. tostring(class) .. COLOR.reset
        if n == 0 then
            self:Raw("  " .. head .. "  " .. COLOR.good .. "OK" .. COLOR.reset)
        else
            self:Raw("  " .. head)
            if #a.unusable > 0 then self:Raw("    " .. COLOR.bad .. L.EGUP_AUDIT_UNUSABLE .. COLOR.reset .. " " .. Names(a.unusable)) end
            if #a.useless  > 0 then self:Raw("    " .. COLOR.warn .. L.EGUP_AUDIT_USELESS .. COLOR.reset .. " " .. Names(a.useless)) end
            if #a.missing  > 0 then self:Raw("    " .. COLOR.warn .. L.EGUP_AUDIT_MISSING .. COLOR.reset .. " " .. Names(a.missing)) end
        end
    end
    if problems == 0 then
        self:Raw(COLOR.good .. L.EGUP_AUDIT_CLEAN .. COLOR.reset)
    end
end

-- Paketvorschau ohne etwas zu senden
function EG:PrintEGUPPackage(class, faction)
    local package = self:GetEGUPPackage(class, faction)
    if #package == 0 then
        self:Print(COLOR.bad .. sformat(L.EGUP_NO_PACKAGE, tostring(class)) .. COLOR.reset)
        return
    end
    self:Raw(COLOR.title .. sformat("%s: %s (%d)", L.EGUP_PACKAGE_HEAD,
        tostring(class), #package) .. COLOR.reset)
    for _, e in ipairs(package) do
        local link = select(2, GetItemInfo(e.id))
        self:Raw(sformat("  %s%-6d%s x%d  %s", COLOR.value, e.id, COLOR.reset,
            e.count, link or e.name))
    end
end

------------------------------------------------------------------------------
-- Senden
------------------------------------------------------------------------------

function EG:SendEGUPCommand(command)
    SendChatMessage(command, "SAY")
end

function EG:BuildEGUPCommand(targetName, id, count)
    local template = (self.db and self.db.egupCommand) or self.DEFAULTS.egupCommand
    -- Ersatztexte duerfen kein "%" enthalten (gsub-Ersetzung)
    local cmd = sgsub(template, "{name}",  (sgsub(tostring(targetName), "%%", "%%%%")))
    cmd = sgsub(cmd, "{id}",    tostring(id))
    cmd = sgsub(cmd, "{count}", tostring(count))
    return cmd
end

EG.EGUPQueue   = {}
EG.EGUPRunning = false

function EG:ProcessEGUPQueue()
    if self.EGUPRunning then return end
    if #self.EGUPQueue == 0 then return end

    self.EGUPRunning = true
    local index = 1
    local delay = tonumber(self.db and self.db.egupDelay) or self.DEFAULTS.egupDelay

    local function SendNext()
        if index > #self.EGUPQueue then
            self.EGUPQueue   = {}
            self.EGUPRunning = false
            self:Print(COLOR.good .. L.EGUP_DONE .. COLOR.reset)
            self:Print(L.EGUP_HINT)
            return
        end
        local command = self.EGUPQueue[index]
        index = index + 1
        self:SendEGUPCommand(command)
        self:After(delay, SendNext)
    end

    SendNext()
end

function EG:StartEGUP(targetName, class, faction)
    local package = self:GetEGUPPackage(class, faction)
    if not package or #package == 0 then
        self:Print(COLOR.bad .. sformat(L.EGUP_NO_PACKAGE, tostring(class)) .. COLOR.reset)
        return
    end

    local session = {
        targetName = targetName,
        targetGUID = UnitGUID("target"),
        class      = class,
        faction    = faction,
        items      = {},
        active     = true,
        time       = time and time() or 0,
    }

    self.EGUPQueue = {}
    for _, item in ipairs(package) do
        local rec = session.items[item.id]
        if not rec then
            rec = { id = item.id, name = item.name, count = 0 }
            session.items[item.id] = rec
        end
        rec.count = rec.count + (item.count or 1)
        self.EGUPQueue[#self.EGUPQueue + 1] =
            self:BuildEGUPCommand(targetName, item.id, item.count or 1)
    end

    self.charDB.egup = session
    self.EGUPSession = session

    self:Print(sformat(L.EGUP_RUNNING, COLOR.value .. targetName .. COLOR.reset))
    self:Print(L.EGUP_CLASS_LINE:format(COLOR.value .. tostring(class) .. COLOR.reset,
        COLOR.value .. #package .. COLOR.reset))

    self:ProcessEGUPQueue()
end

StaticPopupDialogs["EASYGEAR_EGUP_CONFIRM"] = {
    text = "%s",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(self)
        local d = self.data or EasyGear.pendingEGUP
        if d then EasyGear:StartEGUP(d.name, d.class, d.faction) end
        EasyGear.pendingEGUP = nil
    end,
    OnCancel = function() EasyGear.pendingEGUP = nil end,
    timeout = 30, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function EG:RunEGUP(useSelf)
    local unit = "target"
    if useSelf or not UnitExists("target") then
        if useSelf then
            unit = "player"
        else
            self:Print(COLOR.bad .. L.EGUP_NO_TARGET .. COLOR.reset); return
        end
    end
    if not UnitIsPlayer(unit) then
        self:Print(COLOR.bad .. L.EGUP_NOT_PLAYER .. COLOR.reset); return
    end

    local targetName = UnitName(unit)
    local _, class   = UnitClass(unit)
    local faction    = UnitFactionGroup and UnitFactionGroup(unit) or nil

    if not targetName then
        self:Print(COLOR.bad .. L.EGUP_NO_TARGET .. COLOR.reset); return
    end
    if not class then
        self:Print(COLOR.bad .. L.EGUP_NO_CLASS .. COLOR.reset); return
    end

    local package = self:GetEGUPPackage(class, faction)
    if not package or #package == 0 then
        self:Print(COLOR.bad .. sformat(L.EGUP_NO_PACKAGE, class) .. COLOR.reset); return
    end

    if self.db.egupConfirm then
        self.pendingEGUP = { name = targetName, class = class, faction = faction }
        local dialog = StaticPopup_Show("EASYGEAR_EGUP_CONFIRM",
            sformat(L.EGUP_CONFIRM, class, #package, targetName))
        if dialog then dialog.data = self.pendingEGUP end
        return
    end

    self:StartEGUP(targetName, class, faction)
end

------------------------------------------------------------------------------
-- 15a  EGUPCLEAN
------------------------------------------------------------------------------

--[[ Entfernt alle Paket-Items, die NICHT angelegt sind.

     Frueher wurden nur die beim letzten /egup erfassten Mengen geloescht -
     war die Sitzung weg, schon teilweise aufgeraeumt oder das Item in die
     Bank gewandert, blieb etwas liegen. Jetzt gilt:

       * Ziel ist jedes Item, das in EasyGearHeirlooms.lua steht (Erbstuecke,
         Ring, Taschen, Insignien) plus alles aus der gespeicherten Sitzung.
       * Es werden ALLE Exemplare in Taschen - und bei geoeffneter Bank auch
         in Bankfaechern - entfernt. Angelegte Items liegen nicht in den
         Taschen und bleiben deshalb von selbst; das gilt auch fuer Taschen,
         die in einem Taschenplatz stecken.
       * Es laeuft in mehreren Durchgaengen, bis nichts mehr uebrig ist:
         gesperrte Fachinhalte (Server laedt noch) werden beim naechsten
         Durchgang erneut versucht.
       * Vorher gibt es eine Rueckfrage (egupConfirm); /egupclean list zeigt
         nur an, was entfernt wuerde.                                      ]]

function EG:GetEGUPCleanSet()
    local set = {}
    for id in pairs(self.HEIRLOOMS or {}) do set[id] = true end
    for _, entry in ipairs(self.HEIRLOOM_UNIVERSAL or {}) do set[entry.id] = true end
    local session = self.charDB and self.charDB.egup
    if session and session.items then
        for id in pairs(session.items) do set[tonumber(id) or id] = true end
    end
    return set
end

function EG:IsItemIDEquipped(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    for slot = 1, MAX_EQUIP_SLOT do
        local link = GetInventoryItemLink("player", slot)
        if link and self:GetItemIDFromLink(link) == itemID then
            return true
        end
    end
    return false
end

-- Alle Fachnummern, die gerade durchsucht werden duerfen
function EG:GetCleanContainers()
    local bags = {}
    for bagID = 0, (NUM_BAG_SLOTS or 4) do bags[#bags + 1] = bagID end
    if BankFrame and BankFrame:IsShown() then
        bags[#bags + 1] = BANK_CONTAINER or -1
        local first = (NUM_BAG_SLOTS or 4) + 1
        for bagID = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do bags[#bags + 1] = bagID end
    end
    return bags
end

function EG:GetBagItemLocations(itemID)
    local locations = {}
    itemID = tonumber(itemID)
    if not itemID then return locations end
    for _, bagID in ipairs(self:GetCleanContainers()) do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
            local link = GetContainerItemLink(bagID, slotID)
            if link and self:GetItemIDFromLink(link) == itemID then
                local _, count = GetContainerItemInfo(bagID, slotID)
                locations[#locations + 1] = {
                    bag = bagID, slot = slotID, count = tonumber(count) or 1, link = link, id = itemID,
                }
            end
        end
    end
    return locations
end

--[[ Alle Faecher, die jetzt aufzuraeumen waeren: { bag, slot, count, link, id }.  ]]
function EG:ScanEGUPLeftovers()
    local set  = self:GetEGUPCleanSet()
    local list = {}
    for _, bagID in ipairs(self:GetCleanContainers()) do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
            local link = GetContainerItemLink(bagID, slotID)
            if link then
                local id = self:GetItemIDFromLink(link)
                if id and set[id] then
                    local _, count, locked = GetContainerItemInfo(bagID, slotID)
                    list[#list + 1] = {
                        bag = bagID, slot = slotID, id = id, link = link,
                        count = tonumber(count) or 1, locked = locked and true or false,
                    }
                end
            end
        end
    end
    return list
end

function EG:DeleteBagSlot(bagID, slotID)
    if CursorHasItem() then ClearCursor() end
    PickupContainerItem(bagID, slotID)
    if CursorHasItem() then
        DeleteCursorItem()
        return true
    end
    ClearCursor()
    return false
end

local MAX_CLEAN_PASSES = 8

function EG:StartEGUPClean()
    if self.EGUPCleaning then
        self:Print(L.EGUP_CLEAN_BUSY)
        return
    end
    self.EGUPCleaning = true
    self:Print(L.EGUP_CLEAN_START)

    local state = { removed = 0, pass = 0 }

    local function Finish()
        self.EGUPCleaning = false
        local session = self.charDB and self.charDB.egup
        local left = #self:ScanEGUPLeftovers()
        if left == 0 and session then session.active = false end
        self:Print(COLOR.good .. sformat(L.EGUP_CLEAN_DONE, state.removed) .. COLOR.reset)
        if left > 0 then
            self:Print(COLOR.warn .. sformat(L.EGUP_CLEAN_LEFT, left) .. COLOR.reset)
        end
    end

    local function Pass()
        state.pass = state.pass + 1
        local targets = self:ScanEGUPLeftovers()
        if #targets == 0 or state.pass > MAX_CLEAN_PASSES then
            Finish()
            return
        end

        local index = 0
        local function Next()
            index = index + 1
            if index > #targets then
                -- naechster Durchgang: gesperrte Faecher erneut versuchen
                self:After(0.4, Pass)
                return
            end

            local t = targets[index]
            local link = GetContainerItemLink(t.bag, t.slot)
            if link and self:GetItemIDFromLink(link) == t.id then
                local _, count, locked = GetContainerItemInfo(t.bag, t.slot)
                if not locked then
                    if self:DeleteBagSlot(t.bag, t.slot) then
                        state.removed = state.removed + (tonumber(count) or 1)
                    end
                end
            end
            self:After(0.12, Next)
        end
        Next()
    end

    Pass()
end

StaticPopupDialogs["EASYGEAR_EGUP_CLEAN_CONFIRM"] = {
    text = "%s",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function() EasyGear:StartEGUPClean() end,
    timeout = 30, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function EG:RunEGUPClean(arg)
    arg = slower(arg or "")

    local list = self:ScanEGUPLeftovers()

    if arg == "list" then
        if #list == 0 then self:Print(L.EGUP_CLEAN_NONE); return end
        self:Raw(COLOR.title .. L.EGUP_CLEAN_LIST_HEAD .. COLOR.reset)
        for _, t in ipairs(list) do
            self:Raw(sformat("  %s%-6d%s x%d  %s", COLOR.value, t.id, COLOR.reset, t.count, t.link))
        end
        return
    end

    if #list == 0 then
        self:Print(L.EGUP_CLEAN_NONE)
        local session = self.charDB and self.charDB.egup
        if session then session.active = false end
        return
    end

    if self.db.egupConfirm then
        local items = 0
        for _, t in ipairs(list) do items = items + t.count end
        StaticPopup_Show("EASYGEAR_EGUP_CLEAN_CONFIRM", sformat(L.EGUP_CLEAN_CONFIRM, items, #list))
        return
    end

    self:StartEGUPClean()
end

------------------------------------------------------------------------------
-- Slash-Befehle
------------------------------------------------------------------------------

SLASH_EGUP1 = "/egup"
SlashCmdList["EGUP"] = function(msg)
    local cmd, rest = smatch(msg or "", "^%s*(%S*)%s*(.-)%s*$")
    cmd = slower(cmd or "")

    if cmd == "verify" or cmd == "check" or cmd == "pruefen" then
        local class = rest ~= "" and string.upper(rest) or nil
        EG:VerifyHeirlooms(class)
        return
    elseif cmd == "list" or cmd == "paket" then
        local class = rest ~= "" and string.upper(rest) or nil
        local faction
        if not class and UnitExists("target") and UnitIsPlayer("target") then
            class   = select(2, UnitClass("target"))
            faction = UnitFactionGroup and UnitFactionGroup("target") or nil
        end
        if not faction then
            faction = UnitFactionGroup and UnitFactionGroup("player") or nil
        end
        EG:PrintEGUPPackage(class or EG:GetPlayerClass(), faction)
        return
    elseif cmd == "help" or cmd == "?" then
        EG:Raw(COLOR.value .. "/egup" .. COLOR.reset .. "  " .. COLOR.grey .. L.H_EGUP .. COLOR.reset)
        EG:Raw(COLOR.value .. "/egup self" .. COLOR.reset .. "  " .. COLOR.grey .. L.H_EGUP_SELF .. COLOR.reset)
        EG:Raw(COLOR.value .. "/egup list [class]" .. COLOR.reset)
        EG:Raw(COLOR.value .. "/egup verify [class]" .. COLOR.reset)
        EG:Raw(COLOR.value .. "/egupclean [list]" .. COLOR.reset .. "  " .. COLOR.grey .. L.H_EGUPCLEAN .. COLOR.reset)
        return
    end

    EG:RunEGUP(cmd == "self")
end

SLASH_EGUPCLEAN1 = "/egupclean"
SlashCmdList["EGUPCLEAN"] = function(msg)
    local arg = smatch(msg or "", "^%s*(%S*)")
    EG:RunEGUPClean(arg)
end
