#!/usr/bin/env python3
"""Mutation check for the unit tests.

    python3 tests/mutate.py [name filter]

Copies EasyGear/ to a temporary folder, applies one small change at a time (a flipped comparison, a dropped
condition, a changed constant, ...) and runs the test suite on the copy. A mutation counts as killed when the
suite fails. Survivors are changes the tests do not notice - each is either a test gap or an equivalent change.
Run from the forever/ folder; needs Lua 5.1 (lua5.1).
"""
import os
import shutil
import subprocess
import sys
import tempfile

# (id, file, old text (must occur exactly once), new text)
MUTATIONS = [
    # ---- Score
    ("off-hand factor", "Score.lua", "local OFFHAND_FACTOR = 0.5", "local OFFHAND_FACTOR = 1.0"),
    ("level gate", "Score.lua", "result.isUpgrade = result.usable and (not result.levelTooLow) and result.wouldUpgrade",
     "result.isUpgrade = result.usable and result.wouldUpgrade"),
    ("equal is not better", "Score.lua", "result.wouldUpgrade = (result.delta > 0 and result.delta >= result.threshold)",
     "result.wouldUpgrade = (result.delta >= result.threshold)"),
    ("ilvl scaling", "Score.lua", "return w * factor, w, factor", "return w, w, factor"),
    ("socket discount", "Score.lua", "return level * 0.22 * best * 0.9", "return level * 0.22 * best"),
    ("best slot choice", "Score.lua", "if not best or d > best.d + 1e-9 or (d > best.d - 1e-9 and es < best.es) then",
     "if not best or d < best.d - 1e-9 then"),
    ("two-hand shield", "Score.lua", 'if Score.HasTwoHandEquipped() then return { 16, 17 }, "BOTH", 17 end',
     'if Score.HasTwoHandEquipped() then return { 17 }, "SINGLE" end'),
    ("off-hand slot", "Score.lua", "return slot == 17 and item.handKind == \"MELEE\"", "return slot == 16 and item.handKind == \"MELEE\""),
    ("unique pool", "Score.lua", "if item.unique and #pool > 1 then", "if false and #pool > 1 then"),
    ("relative threshold", "Score.lua", "local relative = (result.targetScore > 0) and (result.targetScore * pct / 100) or 0",
     "local relative = 0"),
    ("dual wield tanks", "Score.lua", 'if role == "TANK" or role == "HEAL" or role == "CASTER" then',
     'if role == "HEAL" or role == "CASTER" then'),
    ("empty slot reason", "Score.lua", "if best.entry.empty then result.reason = L.R_EMPTY end", "if false then result.reason = L.R_EMPTY end"),
    ("pending state", "Score.lua", "if not r then return nil, rwhy == \"loading\" end", "if not r then return nil, false end"),
    ("statdiff candidate slot", "Score.lua", "local cand = (item.dps or 0) * (IsOffhandWeapon(item, candSlot) and OFFHAND_FACTOR or 1)", "local cand = (item.dps or 0)"),
    ("shield no dual wield", "Score.lua", 'if loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then return false end', ""),
    ("gear change wipes at once", "Score.lua", "local function Changed()\n    EG:InvalidateResults()", "local function Changed()\n    --"),
    ("unit inventory player", "Score.lua", 'if unit == "player" then Changed() end', "Changed()"),
    ("totals gear only", "Score.lua", "elseif item.isGear then ", "elseif item then "),
    ("totals partial", "Score.lua", "if complete then totalsCache.t = t end", "totalsCache.t = t"),
    ("totals cache registered", "Score.lua", "EG:RegisterCache(totalsCache)", ""),
    ("compare reason", "Score.lua", 'if not item then return nil, why or "loading" end', 'if not item then return nil, "loading" end'),
    ("worn reason", "Score.lua", 'if not eq then return nil, eqWhy or "loading" end', 'if not eq then return nil, "loading" end'),
    # ---- Stats
    ("red lines", "Stats.lua", "return r and r > 0.85 and g < 0.25 and b < 0.25 or false", "return r and r > 0.85 and g < 0.25 and b < 2 or false"),
    ("extras add up", "Stats.lua", "stats[k] = (stats[k] or 0) + v\n                extra[k] = v", "stats[k] = v\n                extra[k] = v"),
    ("base takes max", "Stats.lua", "if v > (stats[k] or 0) then stats[k] = v end", "if v < (stats[k] or 0) then stats[k] = v end"),
    ("inactive bonus", "Stats.lua", "elseif not IsGrey(line.leftColor) then", "elseif IsGrey(line.leftColor) or true then"),
    ("set header", "Stats.lua", "stopAtSet = true\n            elseif", "stopAtSet = false\n            elseif"),
    ("api max", "Stats.lua", "if value > (stats[key] or 0) then stats[key] = value end", "if value < (stats[key] or 0) or not stats[key] then stats[key] = value end"),
    ("level type", "Stats.lua", "elseif reqLevelType ~= nil and ltype == T.UsageRequirement", "elseif ltype == T.UsageRequirement"),
    ("all stats", "Stats.lua", 'for _, k in ipairs(ALL_STATS) do stats[k] = (stats[k] or 0) + value end', 'for _, k in ipairs({ "STR" }) do stats[k] = (stats[k] or 0) + value end'),
    # ---- Profiles
    ("min points", "Profiles.lua", "local MIN_POINTS = 5", "local MIN_POINTS = 0"),
    ("leveling cap", "Profiles.lua", "if level < maxLevel then return leveling end\n        return allround", "if level <= maxLevel then return leveling end\n        return allround"),
    ("healer exception", "Profiles.lua", 'and spec.role ~= "TANK" and spec.role ~= "HEAL" then', 'and spec.role ~= "TANK" then'),
    ("tree order", "Profiles.lua", "if type(displays) ~= \"table\" or #displays == 0 then return nil end\n",
     "if type(displays) ~= \"table\" or #displays == 0 then return nil end\n    tsort(displays, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)\n"),
    ("tank role pick", "Profiles.lua", 'local want = (apiRole == "TANK" and "TANK") or (apiRole == "HEALER" and "HEAL") or nil',
     'local want = nil'),
    ("heal damage share", "Profiles.lua", "out.SPDMG = (role == \"HEAL\") and sp * 0.35 or sp", "out.SPDMG = sp"),
    ("delete resets", "Profiles.lua", 'if Profiles.ActiveID() == id then EG.cdb.profile = "AUTO" end', ""),
    ("custom class filter", "Profiles.lua", 'if type(c) == "table" and (not c.class or c.class == "ANY" or c.class == class) then',
     'if type(c) == "table" then'),
    ("raw weights copy", "Profiles.lua", "local weights = source and Profiles.RawWeights(source) or {}", "local weights = source and Profiles.WeightsFor(source) or {}"),
    ("rev bump", "Profiles.lua", "c.weights = out\n    c.rev = (c.rev or 1) + 1", "c.weights = out"),
    # ---- Items
    ("req level", "Items.lua", "data.reqLevel = math.max(data.minLevel or 0, scan.reqLevel or 0)", "data.reqLevel = math.min(data.minLevel or 0, scan.reqLevel or 0)"),
    ("usable flag", "Items.lua", "if scan.validType == false or scan.validSlot == false then", "if false then"),
    ("loading request", "Items.lua", "if id and not requested[id] and C_Item and C_Item.RequestLoadItemDataByID then", "if false then"),
    ("cosmetic", "Items.lua", "if ok and cosmetic then data.isGear = false end", ""),
    ("effective ilvl", "Items.lua", "if ok and type(actual) == \"number\" and actual > 0 then effectiveLevel = actual end", ""),
    ("cache signature", "Items.lua", 'return tostring(EG:Get("includeEnchants")) .. ":" .. tostring(UnitLevel and UnitLevel("player"))', "return \"x\""),
    ("failed ids", "Items.lua", 'if id and failed[id] then return nil, "invalid" end', ""),
    ("failed event", "Items.lua", "        if id then failed[id] = true end\n        return\n    end", "        if id then failed[id] = true end\n    end"),
    ("partial flag", "Items.lua", "data.partial = (lines == nil and tooltipsExist) or nil", "data.partial = nil"),
    ("partial bound", "Items.lua", "if tries <= MAX_PARTIAL_TRIES then", "if true then"),
    ("sockets gem rule", "Items.lua", "data.sockets = withExtras and sockets or 0", "data.sockets = sockets"),
    # ---- Contexts / Marks
    ("hint cache registered", "Contexts.lua", "EG:RegisterCache(hintCache)", ""),
    ("mail link", "Contexts.lua", "local ok, link = pcall(getter, inbox.openMailID, button:GetID())", "local ok, link = false, nil"),
    ("roll getter", "Contexts.lua", "local ok, link = pcall(getter, rollID)", "local ok, link = false, nil"),
    ("quest frame visible", "Contexts.lua", "if rewards.IsVisible and not rewards:IsVisible() then return end", ""),
    ("stock corner", "Marks.lua", 'if type(stock) == "table" and stock.IsShown and stock:IsShown() then corner = "TOPRIGHT" end', ""),
    ("balance feral power", "Specs.lua", '              STA = 0.10, ARMOR = 0.01, DPS = 0.5 },\n    },\n    {\n        id = "DRUID_CAT"',
     '              FAP = 0.20, STA = 0.10, ARMOR = 0.01, DPS = 0.5 },\n    },\n    {\n        id = "DRUID_CAT"'),
    # ---- Recommend
    ("tie by value", "Recommend.lua", "if delta > bestUpDelta or (delta == bestUpDelta and total > bestUpValue) then", "if delta > bestUpDelta then"),
    ("upgrade sort", "Recommend.lua", "if a.delta ~= b.delta then return a.delta > b.delta end", "if a.delta ~= b.delta then return a.delta < b.delta end"),
    ("unusable rewards", "Recommend.lua", "if e.apiUsable ~= false then", "if true then"),
    ("vendor total", "Recommend.lua", "local total = (item.sellPrice or 0) * (tonumber(e.count) or 1)", "local total = (item.sellPrice or 0)"),
    ("bank tabs", "Recommend.lua", "if includeBank and Enum and Enum.BagIndex then", "if false then"),
    # ---- Tooltip
    ("slot whitelist", "Contexts.lua", "if kind and SLOT_OF_NAME[base] then return kind, SLOT_OF_NAME[base] end", "if kind then return kind, SLOT_OF_NAME[base] or 0 end"),
    ("shopping mode", "Tooltip.lua", '    elseif IsShoppingTooltip(tooltip) then\n        mode, slot = "SCORE", WornSlotOf(item)\n    end', '    end'),
    ("compare header", "Tooltip.lua", "if tooltip.isShopping or tooltip.CompareHeader then return true end", "if tooltip.isShopping then return true end"),
    ("worn slot lookup", "Tooltip.lua", 'mode, slot = "SCORE", WornSlotOf(item)', 'mode, slot = "SCORE", nil'),
    ("owner slot score", "Tooltip.lua", 'mode, slot = "SCORE", ownerSlot', 'mode, slot = "SCORE", nil'),
    ("builder slot", "Tooltip.lua", "local score = result and result.score or Score.Of(item, extra and extra.slot)", "local score = result and result.score or Score.Of(item)"),
    ("diff candidate slot", "Tooltip.lua", "local diffs = Score.StatDiff(item, result.replaced, result.candSlot)", "local diffs = Score.StatDiff(item, result.replaced)"),
    ("diff empty slot", "Tooltip.lua", "local diffs = Score.StatDiff(item, {}, result.candSlot)", "local diffs = Score.StatDiff(item, {})"),
    ("diff limit", "Tooltip.lua", "local MAX_DIFF_LINES = 8", "local MAX_DIFF_LINES = 0"),
    ("verdict sign", "Tooltip.lua", "verdict.rightColor = (result.delta > 0) and GREEN or ((result.delta < 0) and RED or GREY)", "verdict.rightColor = GREEN"),
    ("pick line", "Tooltip.lua", "if extra and extra.pick then lines[#lines + 1] = PickLine(extra.pick) end\n    if extra and extra.hint then", "if extra and extra.hint then"),
    ("setting off", "Tooltip.lua", 'if not EG:Get("showTooltip") then return end', ""),
    # ---- Marks / Contexts
    ("level color", "Marks.lua", 'if state == "LEVEL" then', 'if state == "NEVER" then'),
    ("setting for chars", "Marks.lua", 'quest = "showQuestIcons", char = "showCharIcons",', 'quest = "showQuestIcons", char = "showBagIcons",'),
    ("best kind", "Marks.lua", "data.bestKind = data.best and kind or nil", "data.bestKind = nil"),
    ("bag button", "Contexts.lua", 'if button.UpdateNewItem and button.GetBagID and button.GetID then return "bag" end', 'if button.GetBagID and button.GetID then return "bag" end'),
    ("bank button", "Contexts.lua", 'if button.GetBankTabID and button.GetContainerSlotID then return "bank" end', ""),
    ("char pattern", "Contexts.lua", '"^(Character)(%a+%d?)Slot$"', '"^(Character)(%a+)Slot$"'),
    ("currency skip", "Contexts.lua", 'if ctx == "quest" and button.objectType == "currency"', 'if false and button.objectType == "currency"'),
    ("one choice", "Contexts.lua", "if #entries >= 2 and EG:Get(\"showQuestIcons\") then", "if #entries >= 1 and EG:Get(\"showQuestIcons\") then"),
    ("merchant hook", "Contexts.lua", 'Hook("merchant", "MerchantFrameItem_UpdateQuality", OnMerchantItem)', ""),
    ("roll hook", "Contexts.lua", 'Hook("rolls", "GroupLootFrame_SetupItemDisplay", OnRollItem)', ""),
    ("quest schedule", "Contexts.lua", 'if ctx == "quest" then ScheduleQuestBest() end', ""),
    ("quest refresh", "Contexts.lua", 'EG:Listen("REFRESH", function() ScheduleQuestBest() end)', ""),
    ("hint refresh", "Contexts.lua", "    Contexts.InvalidateHints()\n    EG:Debounce(\"charHints\"", "    EG:Debounce(\"charHints\""),
    ("trade pattern", "Contexts.lua", '"^TradeRecipientItem%dItemButton$"', '"^TradeItem%dItemButton$"'),
    ("loot parent", "Contexts.lua", "if parent and parent.GetSlotIndex and parent.Item == button then return \"loot\" end", ""),
    # ---- Core
    ("score format", "Core.lua", "if math.abs(v) >= 100 or v == math.floor(v) then", "if math.abs(v) >= 10 or v == math.floor(v) then"),
    ("percent sign", "Core.lua", 'return sformat("%s%.1f%%", v >= 0 and "+" or "-", math.abs(v))', 'return sformat("%s%.1f%%", "+", math.abs(v))'),
    ("debounce again", "Core.lua", "debounce[key].again = true\n        return", "return"),
    ("reset keeps custom", "Core.lua", "self.db.custom = custom\n    CopyDefaults(self.db, DEFAULTS)\n    self.cdb.profile", "CopyDefaults(self.db, DEFAULTS)\n    self.cdb.profile"),
    ("locale alias", "Core.lua", 'local ALIAS = { enGB = "enUS", esMX = "esES" }', "local ALIAS = { enGB = \"enUS\" }"),
    # ---- Options
    ("setting callback", "Options.lua", '    setting:SetValueChangedCallback(EG:Guard("settings", Changed))\n    Settings.CreateCheckbox', "    Settings.CreateCheckbox"),
    ("notifying guard", "Options.lua", "    if notifying then return end\n    EG:InvalidateAll()", "    EG:InvalidateAll()"),
    ("panel shown", "Options.lua", 'if type(panel) == "table" and type(panel.IsShown) == "function" and not panel:IsShown() then return end', ""),
    ("profile notify", "Options.lua", '    variables[#variables + 1] = "EasyGear_PROFILE"', ""),
    ("reset confirm", "Options.lua", "local ok = pcall(StaticPopup_ShowCustomGenericConfirmation, { text = L.OPT_RESET_PROMPT, callback = Do })", "local ok = false"),
    ("compartment right", "Options.lua", 'if buttonName == "RightButton" then', 'if buttonName == "LeftButton" then'),
    # ---- Slash
    ("ilvl range", "Slash.lua", "local v = ReadRange(rest, 0, 10)", "local v = ParseNumber(rest)"),
    ("scale range", "Slash.lua", "local v = ReadRange(rest, 0.5, 2.0)", "local v = ParseNumber(rest)"),
    ("range upper", "Slash.lua", "if v and v >= lo and v <= hi then return v end", "if v and v >= lo then return v end"),
    ("finite numbers", "Slash.lua", "if not v or v ~= v or v == math.huge or v == -math.huge then return nil end", "if not v then return nil end"),
    ("item string", "Slash.lua", '        or smatch(text, "(item:%d+[%d:%-]*)")', ""),
    ("item id check", "Slash.lua", "if id and id >= 1 and id % 1 == 0 then return id end", "if id then return id end"),
    ("profile case", "Slash.lua", "if slower(candidate.id) == low then spec = candidate break end", ""),
    ("report order", "Slash.lua", '    local ok = Slash.PrintReport(link)\n    if EG.Window then EG:Try("window", EG.Window.SetItem, link) end\n    return ok',
     '    if EG.Window then EG.Window.SetItem(link) end\n    return Slash.PrintReport(link)'),
    ("switch parse", "Slash.lua", 'if arg == "off" or arg == "0" or arg == "aus" then return false end', ""),
    ("weight custom only", "Slash.lua", "if not (spec and spec.custom) then", "if false then"),
    ("link report", "Slash.lua", "        if link then\n            ReportFor(link)\n        elseif id then", "        if false then\n            ReportFor(link)\n        elseif id then"),
    ("decimal comma", "Slash.lua", 'local v = tonumber((sgsub(text, ",", ".")))', "local v = tonumber(text)"),
    # ---- Window / ProfileWindow
    ("shift click", "Window.lua", "if frame and frame:IsShown() and IsShiftKeyDown and IsShiftKeyDown() and Window.IsItemRef(link) then", "if frame and frame:IsShown() and Window.IsItemRef(link) then"),
    ("window nil guard", "Window.lua", "if not (item and result) then", "if not item then"),
    ("item ref string", "Window.lua", 'return type(v) == "string" and string.find(v, "item:", 1, true) ~= nil', 'return type(v) == "string"'),
    ("item ref number", "Window.lua", 'if type(v) == "number" then return v > 0 end', 'if type(v) == "number" then return true end'),
    ("window word wrap", "Window.lua", "col.name:SetWordWrap(item == nil)", "col.name:SetWordWrap(true)"),
    ("window invalid text", "Window.lua", 'hint = (why == "invalid" or resultWhy == "invalid") and L.INVALID_ITEM or L.ITEM_LOADING', "hint = L.ITEM_LOADING"),
    ("script guard", "Core.lua", "return function(...) EG:Try(label, fn, ...) end", "return fn"),
    ("save as new weights", "ProfileWindow.lua", "Profiles.SetCustomWeights(id, weights)", ""),
    ("comma weights", "ProfileWindow.lua", 'local clean = EG.Trim(sgsub(text or "", ",", "."))', 'local clean = EG.Trim(text or "")'),
    ("weight finite", "ProfileWindow.lua", "elseif v and v == v and v ~= math.huge and v ~= -math.huge then", "elseif v then"),
    ("weight empty", "ProfileWindow.lua", 'if clean == "" or v == 0 then', "if v == 0 then"),
    ("delete argument", "ProfileWindow.lua", 'text = text, text_arg1 = arg1, callback = EG:Guard("profiles", onAccept), showAlert = true,', 'text = text, callback = EG:Guard("profiles", onAccept), showAlert = true,'),
    ("delete confirm", "ProfileWindow.lua", "        if ok then return end\n    end\n    onAccept()", "        if ok then end\n    end\n    onAccept()"),
    ("overwrite only custom", "ProfileWindow.lua", "if not (state.edit and state.draft and spec and spec.custom) then", "if not (state.edit and state.draft and spec) then"),
    ("scroll clamp", "ProfileWindow.lua", "if state.offset > maxOffset then state.offset = maxOffset end", ""),
    ("default other profile", "ProfileWindow.lua", "if not active or s.id ~= active.id then return s end", "return s"),
]


def main():
    flt = sys.argv[1] if len(sys.argv) > 1 else None
    src = "EasyGear"
    survivors, killed, bad = [], 0, []
    for name, fname, old, new in MUTATIONS:
        if flt and flt not in name:
            continue
        tmp = tempfile.mkdtemp(prefix="eg_mut_")
        dst = os.path.join(tmp, "EasyGear")
        shutil.copytree(src, dst)
        path = os.path.join(dst, fname)
        text = open(path, encoding="utf-8").read()
        if text.count(old) != 1:
            bad.append("%s: pattern occurs %d times in %s" % (name, text.count(old), fname))
            shutil.rmtree(tmp)
            continue
        open(path, "w", encoding="utf-8").write(text.replace(old, new))
        env = dict(os.environ, EASYGEAR_DIR=dst)
        r = subprocess.run(["lua5.1", "tests/run.lua"], env=env, capture_output=True, text=True, timeout=300)
        shutil.rmtree(tmp)
        if r.returncode == 0:
            survivors.append(name)
            print("SURVIVED  %s  (%s)" % (name, fname))
        else:
            killed += 1
    for b in bad:
        print("BAD PATTERN  " + b)
    print("%d mutations: %d killed, %d survived, %d not applicable" % (killed + len(survivors) + len(bad), killed, len(survivors), len(bad)))
    sys.exit(1 if survivors or bad else 0)


if __name__ == "__main__":
    main()
