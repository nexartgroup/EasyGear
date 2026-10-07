# EasyGear

Gear scoring, upgrade detection and item comparison for **World of Warcraft 3.3.5a (WotLK)**.

EasyGear tells you whether an item is actually better than what you are wearing — using
stat weights for **your talents, your level and the rest of your equipment**, not item
level alone. The answer shows up wherever an item appears: bags, bank, quest rewards,
vendors, loot windows, loot rolls, trade, auction house, mail and every item tooltip.

* Interface `30300`, Lua 5.1, no XML files
* **Any client language**: texts come from one language file per locale
  (`Locales/<locale>.lang.lua`), English is the fallback for everything untranslated;
  armor and weapon types are recognised through the client itself, not by name
* Optional integration with **ElvUI**, **Bagnon** and **Immersion**

[Deutsche Version weiter unten](#easygear-deutsch)

---

## Contents

- [Installation](#installation)
- [Commands](#commands)
- [Where EasyGear shows upgrades](#where-easygear-shows-upgrades)
- [Item comparison window](#item-comparison-window-eggui)
- [Scoring](#scoring)
- [Enchants, gems and sockets](#enchants-gems-and-sockets)
- [Profiles](#profiles-egprofile)
- [Weapon slots, rings, trinkets](#weapon-slots-rings-trinkets)
- [Heirlooms](#heirlooms)
- [EGUP — GM heirloom packages](#egup--gm-heirloom-packages)
- [Languages](#languages)
- [Settings](#settings)
- [Tests](#tests)
- [Known limits](#known-limits)
- [Changes in 3.0](#changes-in-30)

---

## Installation

Copy the `EasyGear` folder into your AddOns directory:

```
World of Warcraft/
└── Interface/
    └── AddOns/
        └── EasyGear/
            ├── EasyGear.toc
            ├── EasyGear.lua            core: scoring, slots, comparison, quest, tooltip
            ├── EasyGearSpecs.lua       56 stat weight profiles
            ├── EasyGearHeirlooms.lua   heirloom database and class packages
            ├── EasyGearOverlays.lua    markers: bags, vendors, loot, rolls, trade, AH, mail
            ├── EasyGearEGUP.lua        GM package and cleanup
            ├── EasyGearGUI.lua         item comparison window
            ├── EasyGearProfileGUI.lua  profile comparison window
            └── Locales/
                ├── enUS.lang.lua       English - the complete reference
                ├── deDE.lang.lua       Deutsch
                └── frFR / esES / ruRU / koKR / zhCN / zhTW .lang.lua
```

Then `/reload` or restart the client. Load order matters and is handled by the `.toc`.
The `tests/` folder is only for development and may be left out.

---

## Commands

| Command | Effect |
| --- | --- |
| `/eg` · `/eggui` | open the comparison window |
| `/eg <itemlink>` · `/eg <itemID>` | full breakdown in chat |
| `/eg upgrades` | **list every upgrade in your bags** (and the bank, if open), best first |
| `/egprofile` | profile overview, comparison and editor |
| `/eg profile list` | list all profiles in chat |
| `/eg profile <id\|auto>` | activate a profile |
| `/eg autolevel [on\|off]` | below level 80 use the *Leveling* profile of your class |
| `/eg pvp` | toggle PvP mode |
| `/eg role <auto\|tank\|melee\|ranged\|caster\|heal>` | first profile of your class with that role |
| `/eg heirloom [on\|off]` | prefer heirlooms while levelling |
| `/eg heirloombonus <1.0–3.0>` | score bonus for heirlooms (default 1.5) |
| `/eg enchants [on\|off]` | count enchants and gems |
| `/eg socket <number\|auto>` | points per empty socket (auto = from level and profile) |
| `/eg ilvl <number>` · `ilvlscale [on\|off]` | item level weight / scale it with character level |
| `/eg mindelta <number>` · `mindeltapct <percent>` | minimum gain to call something an upgrade |
| `/eg icons` · `quest` · `items` · `tooltip` · `diff` | toggle bag markers / quest markers / vendor-loot-AH markers / tooltip lines / stat differences |
| `/eg scale <0.5–2.0>` | window scale |
| `/eg status` | current settings |
| `/eg locale` | which language file is active, how armor/weapon types were recognised |
| `/eg reset` | back to defaults (your own profiles are kept) |
| `/egup` · `/egup self` | GM: send the class package to your target / to yourself |
| `/egup list [class]` | show a package without sending anything |
| `/egup verify [class]` | check IDs, slots, primary attributes and every class package |
| `/egupclean` · `/egupclean list` | remove **all** unequipped package items / show what would go |

---

## Where EasyGear shows upgrades

A **green check** on the item icon means *better than what you wear*, a **yellow check**
means *would be better, but your level is too low*.

| Place | Markers | Tooltip |
| --- | :---: | :---: |
| Bags — Blizzard, ElvUI, Bagnon — and bank | ✔ | ✔ |
| Quest rewards (NPC window, quest log, **Immersion** incl. shift overview) | ✔ best pick | ✔ |
| Vendor offer and buyback | ✔ | ✔ |
| Loot window and group loot rolls (Need/Greed) | ✔ | ✔ |
| Trade partner's items | ✔ | ✔ |
| Auction house (browse), mail inbox | ✔ | ✔ |
| Chat links | — | ✔ |

The tooltip adds a score line, the slot and score of what would be replaced, the verdict
with absolute and relative gain, and — like RatingBuster — the **stat differences** to the
replaced item:

```
EasyGear                          Score: 412
Chest                                  378
UPGRADE  +34  (+9.0%)
+50 Strength
+22 Critical Strike Rating
-14 Stamina
```

On the character sheet and in compare-tooltips only the score is shown — comparing an item
with itself is meaningless.

Quest rewards are ranked by **gain**, not by absolute score, so a boot that fills an empty
slot beats a cloak that merely replaces a slightly worse one. If no reward is an upgrade,
the highest vendor value (unit price × stack) wins.

<details>
<summary>Implementation notes for the Immersion integration</summary>

The reward buttons live under
`ImmersionFrame.TalkBox.Elements.Content.RewardsFrame.Buttons` and are identified by
`type == "choice"`, with the choice index in `:GetID()`.

EasyGear hooks `Elements:Display()`, **not** `Elements:ShowRewards()`. Immersion stores its
templates as lists of function references and calls them through `elementsTable[i](self)`;
that reference still points at the original function, so a hook on the frame would never
fire. `Display()` on the other hand is called as a real method in `Frame:AddQuestInfo()`.

The tooltip lines hang off `GameTooltip:SetQuestItem` / `SetQuestLogItem` rather than
`OnTooltipSetItem`, because `GetItem()` does not reliably return a link for quest rewards.

The shift overview does not use the buttons at all — it fills pooled tooltip frames
(`ImmersionItemTooltipTemplate`) in `Frame:SetItemTooltip()`. EasyGear hooks
`SetItemTooltip` on `ImmersionFrame` instead and resets its marker on every fill, because
the frames are reused.
</details>

---

## Item comparison window (`/EGGUI`)

Drag an item onto the slot, shift-click it while the window is open, or use
`/eg <itemlink>`.

* **Left** — the candidate with the full calculation: attribute → value → weight → points,
  plus item level base, weapon DPS, empty sockets and the heirloom bonus. For rings and
  one-handers the header names the slot it fits best.
* **Right** — the equipped counterpart. For rings, trinkets and one-handers the tabs at the
  top right switch between both slots; the slot that would be replaced is shown first.
* **Bottom** — verdict, point difference in absolute and percent, and notes (heirloom
  preference, two-hander / Titan's Grip case, unique items, points carried by enchants).

Right-clicking the slot clears it. *Print to chat* writes the same breakdown as text.

---

## Scoring

```
score = item level × ilvlWeight × (character level / 80)
      + Σ (attribute × weight)           incl. enchants, gems, active socket bonus
      + weapon DPS × weight              off hand counts half
      + empty sockets × socket value
      × heirloom factor                  below level 80, heirlooms only
```

**Item level term.** The stat weights are calibrated for level-80 magnitudes. At level 5
items carry single-digit stats, so a fixed point value per item level would drown the real
attributes across the whole levelling range. The term therefore grows with character
level (`/eg ilvlscale off` disables that).

**Threshold.** A 0.1 point lead on a score of 2.5 is noise. An upgrade must beat
`max(minDelta, minDeltaPercent % of the compared score)` — 1 % by default.

**Weapon DPS.** Melee (`DPS`) and ranged/wand (`RDPS`) weapon DPS are weighted separately —
a hunter's bow matters enormously, his dagger hardly; a levelling priest values the wand.
An **off-hand weapon deals half damage**, so its DPS counts half; that is also why a dual
wielder's best slot for a new one-hander is not always the same.

**Empty sockets.** Valued as one typical gem of your level (about 0.22 points per level ×
the profile's main-stat weight, minus 10 % for a mismatched colour) — about 16 points at
level 80. Override with `/eg socket <number>`.

---

## Enchants, gems and sockets

`GetItemStats()` only reads the base values out of the item link. Enchants live in
`SpellItemEnchantment.dbc` and do **not** appear there. EasyGear therefore also reads the
tooltip. Four line shapes occur and all are understood:

```
+55 Stamina                               primary attributes
Equip: Improves haste rating by 55.       ratings
+10 Strength and +15 Stamina              gems and enchants (several values per line)
Socket Bonus: +4 Stamina                  socket bonus - only while active (green)
```

* Patterns are built at runtime from the localised Blizzard globals
  (`ITEM_MOD_*_SHORT`, `ITEM_MOD_*`, `ITEM_SOCKET_BONUS`, `SPELL_STATALL`), so they are not
  tied to one language.
* Base and long-form lines are anchored at both ends — otherwise a proc such as *"Increases
  attack power by 340 for 10 sec."* would count as a permanent stat. Lines starting with
  *Equip:/Use:/Chance on hit:* are never read as gem or enchant text.
* Attribute names are matched longest first, so *"+6 Mana per 5 sec."* is mana regeneration,
  not mana, and *"+20 Armor Penetration Rating"* is not armor. *"+10 All Stats"* adds to
  strength, agility, stamina, intellect and spirit.
* Base values and tooltip sums are merged by taking the **maximum**: the tooltip lists base,
  enchant and gems on separate lines, so its sum is normally the larger figure. If a line
  cannot be parsed the base value survives — nothing is lost and nothing counted twice.
* Grey lines (inactive socket and set bonuses) are skipped, scanning stops at a set header
  (`Name (2/5)`), red lines never count.

The comparison window and the chat output say whether an item is enchanted or gemmed. When
the **equipped** item carries points from enchants and gems that a fresh drop will not have,
EasyGear tells you (*"The equipped item carries 24 points from enchants and gems"*) — a
negative difference is then not the whole story. `/eg enchants off` compares base stats only.

---

## Profiles (`/EGPROFILE`)

**56 built-in profiles.** For each of the ten classes:

| | |
| --- | --- |
| one profile per talent tree | and per play style inside a tree: Blood tank / Blood two-hand, Frost dual wield / two-hand / tank, feral cat / bear |
| **Leveling** | levels 1–79: strength/agility, **stamina and armor** count far more, ratings barely — they hardly exist on levelling gear. Hunters value the ranged weapon, casters the wand |
| **All-round** | covers every spec of the class at moderate weight — for hybrid gear and a second spec |

plus two class independent entries, *Leveling (neutral)* and *Item level only*.

| Class | Talent profiles |
| --- | --- |
| Warrior | Arms (two-hand), Fury (dual wield), Protection (tank) |
| Paladin | Holy, Protection (tank), Retribution |
| Hunter | Beast Mastery, Marksmanship, Survival |
| Rogue | Assassination (daggers), Combat (swords), Subtlety |
| Priest | Discipline, Holy, Shadow |
| Death Knight | Blood (tank), Blood (two-hand DPS), Frost (dual wield), Frost (two-hand), Frost (tank), Unholy |
| Shaman | Elemental, Enhancement, Restoration |
| Mage | Arcane, Fire, Frost |
| Warlock | Affliction, Demonology, Destruction |
| Druid | Balance, Feral cat, Feral bear (tank), Restoration |

### Automatic selection

Without any input EasyGear decides from **talents, level and weapons**:

1. Fewer than 5 talent points → *Leveling* (below 80) or *All-round* (at 80).
2. **Below level 80** → the *Leveling* profile of your class — except **tank and healer
   trees**, which keep their profile because their weighting differs fundamentally.
   (`/eg autolevel off` always uses the talent profile.)
3. **Level 80** → the profile of your deepest talent tree.
4. Where a tree has several profiles, the **weapons you wear** decide: Frost with a
   two-hander → *Frost (two-hand)*, dual wielding → *Frost (dual wield)*; Blood with a
   two-hander → *Blood (two-hand DPS)*, otherwise the tank. Pick another by hand in the window.
5. Hybrid *Leveling* profiles switch their weights with the deepest tree: a shaman with most
   points in Elemental levels with caster weights, in Enhancement with melee weights; a
   druid in Balance with caster weights, in Feral with feral weights.

### Weights

Weights are normalised to the main attribute of the profile (1.00). The derivation is in
the header of `EasyGearSpecs.lua`: 1 strength = 2 attack power for the strength classes,
1 weapon DPS ≈ 14 attack power ≈ 7–8 strength, 1000 armor ≈ 2.2 % damage taken ≈ 90 stamina
for a tank (0.09), a hunter's agility gives 2 ranged attack power (AP = RAP = 0.50), a
warlock's Fel Armor turns 30 % of spirit into spell power (spirit 0.35), and so on. They
are good starting values, **not a simulation**: tune them with your own profile.

### Profile window

```
        Comparison profile                  Active profile
        Protection (tank)                   Arms (two-hand)

Attribute       Value  Weight  Points   Attribute       Value  Weight  Points
Stamina          1450  x 1.00    1450   Stamina          1450  x 0.10     145
Defense           540  x 1.20     648   Defense           540  x 0.00       0
...
```

The left side is the profile you select (class and profile via the two dropdowns), the
right side always the **currently active** one. The value column is identical — those are
the totals of your equipped gear — only weight and points differ, so you see what your gear
would be worth under another build and which attributes carry the points. Both sides share
one row list; points are green where that side scores more. The class dropdown also
reaches the profiles of **other** classes.

> Totals of two profiles are only roughly comparable, because the weight sets are
> normalised to the main attribute but not calibrated against each other. What matters is
> the per-attribute distribution.

If an item is loaded in the item window, its score under both profiles is shown below.

**PvP mode.** One switch instead of extra profiles: resilience gets at least 1.00 and
stamina is raised 2.5×, applied on top of the active profile.

**Custom profiles.** *Edit* turns the left weight column into input fields (every attribute,
including those weighted 0, plus both weapon DPS rows). *Save as new profile* works from
built-in profiles too; custom profiles are marked `*`, account-wide, and survive `/eg reset`.

---

## Weapon slots, rings, trinkets

The candidate is "tried" in every slot it can occupy and compared with what is there; the
slot with the largest gain wins. That makes all special cases fall out naturally:

| Candidate | Equipped | Compared against |
| --- | --- | --- |
| ring, trinket | two of them | the **weaker** of the two slots |
| shield / off hand | two-hander | main hand **+** off hand together (not the "empty" slot 17) |
| shield / off hand | one-hander | off hand |
| one-hander | two-hander | main hand — it would replace the two-hander |
| one-hander | one-hander + off hand | main hand or off hand, whichever gains more |
| two-hander | anything | main hand + off hand together |
| two-hander, **Titan's Grip** | two two-handers | one of the two hands |
| unique ring/trinket | the same one | its twin — a second copy replaces the first |

* **Off hand.** Weapon DPS in the off hand counts half. Shields and held-in-off-hand items
  are not weapons and unaffected.
* **Role aware.** Dual wield alone is not enough: a protection warrior *can* dual wield but
  wears a shield, so for tank, healer and caster profiles a one-hander only competes for the
  main hand — unless an off-hand weapon is already equipped. Rogues, enhancement shamans,
  fury warriors and the like compare for both hands.
* **Titan's Grip** is recognised from the talent's icon (language independent) or from two
  two-handers in your hands. Shaman **dual wield** needs the Enhancement talent and level 40.
* **Cosmetics and tools.** Shirts, tabards, fishing poles and mining picks carry no stats;
  they are never marked as upgrades.

---

## Heirlooms

All 37 heirlooms of 3.3.5a are in `EasyGearHeirlooms.lua`, plus the Dread Pirate Ring and the
bags, which are not heirlooms but belong to the package.

### Preference while levelling

Heirlooms scale with your level and grant bonus experience; a normal levelling item cannot
keep up. Instead of a rigid "heirloom always wins", an heirloom gets a **score bonus**:

| Character level | Bonus (default) |
| --- | --- |
| up to 60 | × 1.5 |
| 60 → 80 | falls linearly to × 1.0 (× 1.25 at 70) |
| 80 | none — they no longer scale |

So a normal item has to be clearly better to replace an equipped heirloom, an heirloom
beats a *somewhat* better normal item — but a heirloom with **useless stats** (strength on a
healer) no longer blocks a fitting item, which the old hard rule did. The bonus appears as
its own row in the calculation. Adjust with `/eg heirloombonus <1.0–3.0>`, switch off with
`/eg heirloom off`.

### Changing armor type

Heirloom armor changes its class at level 40: **mail counts as leather below 40, plate counts
as mail**. In practice a shaman or hunter may wear heirloom mail, a warrior or paladin
heirloom plate, from level 1 — without the level-40 requirement of the normal armor
class. `EG:CanUseItem` implements exactly that (`GetProficiencyLevel(class, token, heirloom)`).

### Two shoulder series

The 429xx shoulders come from the emblem vendors, the 441xx ones from the Argent
Tournament. They are equivalent alternatives and both are handed out. The exception is
44100 — the only plate shoulder with intellect, therefore the only one for a holy paladin.

---

## EGUP — GM heirloom packages

`/egup` sends `.additem` commands for a class-appropriate heirloom package to your target
(`/egup self` to yourself). A confirmation dialog appears first
(`EasyGearDB.egupConfirm = false` disables it).

| Class | Items | Class | Items |
| --- | --- | --- | --- |
| Warrior | 11 | Shaman | 17 |
| Paladin | 15 | Rogue | 11 |
| Death Knight | 9 | Druid | 16 |
| Hunter | **9** | Priest | 8 |
| Mage | 6 | Warlock | 6 |

(not counting ring, bags and insignia that every class gets; the PvP insignia is faction
bound and picked via the target's faction)

The command template is configurable, because cores differ:

```lua
EasyGearDB.egupCommand = ".additem {name} {id} {count}"
-- TrinityCore applying to the selected target, for example:
EasyGearDB.egupCommand = ".additem {id} {count}"
```

### What goes into a package

A piece is included when the class can **use** it *and* it **fits**: its primary attribute
is a primary attribute of the class (weapons may also carry a secondary one — agility for
plate wearers, strength for leather and mail wearers). An agility dagger can be wielded by a
priest and is still worthless to one. For armor only the **best wearable class** per slot
and attribute goes in (plate before mail before leather before cloth), unless no piece of
that class exists. This is what changed: a **hunter** no longer receives the three
strength weapons — strength gives a ranged character nothing.

### Verify

A wrong item ID does **not** announce itself: the server reports the error, the player
receives nothing, and the package still looks correct. `/egup verify [class]`

* looks up every ID in the client cache — does it exist, is it really an heirloom
  (quality 7), does it have the expected slot, and does the **tooltip's primary attribute**
  match the one stored in the table;
* audits every class package against the rules above and lists
  *unusable* (class cannot wear it), *useless* (wearable, no fitting attribute) and
  *missing* (wearable and fitting, but not in the package) pieces.

Fix deviations directly in `EasyGearHeirlooms.lua`. An item never seen by the client is
simply uncached and reported as missing even though the ID is correct; viewing it once at a
vendor is enough.

### Cleaning up

`/egupclean` removes **every unequipped copy** of every package item from your bags — and
from the bank if the bank window is open. Equipped items are not in the bags and therefore
stay, as do bags sitting in a bag slot. Previously only the quantities recorded by the last
`/egup` were deleted, so anything left from an earlier session, a lost record or a moved
stack stayed behind. Now:

* the target set is every item in `EasyGearHeirlooms.lua` plus the stored session;
* it runs in **several passes** until nothing is left — a slot the server still holds locked
  is retried on the next pass, and anything that could not be removed is reported;
* a confirmation shows the number of items and stacks first (`egupConfirm`);
  `/egupclean list` only shows what would go.

---

## Languages

Every text lives in `Locales/<locale>.lang.lua`, one file per client language. Each is
plain Lua that registers one table:

```lua
EasyGearLocales = EasyGearLocales or {}
EasyGearLocales["deDE"] = { LOADED = "EasyGear %s geladen.", ... }
```

| | |
| --- | --- |
| **Resolution** | key by key: client language → English → the key itself. A partial translation is fine; an unsupported client language shows English throughout. `enGB` uses `enUS`, `esMX` uses `esES`. |
| **Shipped** | `enUS` (complete reference), `deDE` (complete), `frFR`, `esES`, `ruRU`, `koKR`, `zhCN`, `zhTW` (interface texts and profile names; profile descriptions fall back to English) |
| **Content** | output texts, labels, profile names `SPEC_<id>` / descriptions `SPEC_<id>_D`, and the armor/weapon subtype names `SUBTYPE_<TOKEN>` |
| **Encoding** | language files are UTF-8 without BOM; all code files stay pure ASCII |

**Why `.lang.lua`.** The client only reliably loads `.lua` and `.xml` files listed in the
`.toc`. `.lang` marks a file as a language file, the trailing `.lua` makes sure it loads. If you
know your client also loads plain `.lang` files, rename them and the `.toc` lines — nothing
else changes.

**Language independence of the basic function.** Which armor and weapon types your class
may use needs the item's *subtype*, which `GetItemInfo()` only returns as localised text.
EasyGear builds the name → type table in this order:

1. from the client's own **auction house category lists** (`GetAuctionItemSubClasses`) —
   fixed order, client language, no text knowledge needed;
2. from the `SUBTYPE_*` names in the language files for anything step 1 did not deliver.

Every recognised type is checked against the item's slot (a head piece cannot be a staff);
implausible ones are dropped, and after three of them step 1 is switched off. Usability is
in any case also decided by the item's **red tooltip lines**, which are language independent
by nature. `/eg locale` shows what is active and how the types were recognised.

**Adding a language.** Copy `enUS.lang.lua`, rename it to the locale code, change the table
key, translate what you like, add a `Locales\<code>.lang.lua` line to `EasyGear.toc`, run
`python3 tests/run_tests.py` — it checks keys, placeholders and encoding.

---

## Settings

Stored in `EasyGearDB` (account-wide) and `EasyGearCharDB` (per character).

| Key | Default | Meaning |
| --- | --- | --- |
| `ilvlWeight` | `0.5` | points per item level at level 80 |
| `ilvlScaling` | `true` | scale that term with character level |
| `socketValue` | `nil` | points per empty socket; `nil` = automatic |
| `dpsWeight` | `nil` | override the profile's weapon DPS weight |
| `minDelta` / `minDeltaPercent` | `0` / `1` | upgrade threshold, absolute / in percent |
| `includeEnchants` | `true` | count enchants and gems |
| `autoLeveling` | `true` | below level 80 use the *Leveling* profile |
| `protectHeirlooms` | `true` | prefer heirlooms while levelling |
| `heirloomBonus` | `1.5` | heirloom score factor (up to level 60) |
| `showBagIcons` · `showQuestIcons` · `showItemIcons` | `true` | markers: bags / quests / vendor-loot-roll-trade-AH-mail |
| `showTooltip` · `showTooltipStats` · `tooltipDiff` | `true` | tooltip lines / slot line / stat differences |
| `iconSize` | `20` | marker size in pixels |
| `egupCommand` · `egupConfirm` · `egupDelay` | see above | GM command template / confirmations / pause between commands |
| `custom` | `{}` | your own profiles |

Per character: `profile` (profile ID or `AUTO`), `pvp`, window positions, the last EGUP
session.

---

## Tests

```
pip install lupa
python3 tests/run_tests.py            # everything
python3 tests/run_tests.py -k egup    # only cases whose name contains "egup"
```

The suite runs the addon under real **Lua 5.1** against a small WoW API stub
(`tests/wow_stub.lua`) — frames, tooltips with line colours, items, bags, equipment, talents,
cursor, timers — once per client language, and checks the files statically (ASCII code,
UTF-8 language files, `.toc` complete, language keys used / present / same placeholders).
Test cases are in `tests/cases.lua`; they cover tooltip parsing, every slot situation in the
table above, the heirloom rules, usability, subtype recognition, profile selection, EGUP
packages and cleanup, slash commands, tooltip lines and the markers.

It is an offline harness, **not** a replacement for playing: the stub models the API as
documented for 3.3.5a, not the real client.

---

## Known limits

* The score is a heuristic. **Hit and expertise caps**, set bonuses, procs, meta gem
  conditions and weapon speed are not modelled; weights are reasoned starting points.
* Enchants without a numeric value (*Crusader*, *Berserking*) cannot be scored.
* In languages whose gem text is grammatically inflected (Russian: "+20 к силе") gem lines
  may not be recognised; base values and all "Equip:" lines still count.
* Scores run from roughly 0–5 at low level to three digits at 80. The number is a relative
  ranking — only scores of the same character at the same time are comparable.
* Heirloom values are read from the tooltip and are approximations. The **primary
  attribute of each heirloom in the table is an assumption** that `/egup verify` cross-checks
  against the client — run it once on your server.
* On heavily customised cores item IDs and the `.additem` syntax may differ.

---

## Changes in 3.0

**New**

* Markers at **vendors, loot, loot rolls, trade, auction house and mail**; quest log rewards;
  `/eg upgrades`; stat differences and percent gain in the tooltip.
* **Languages**: one `.lang.lua` file per client language, English fallback, armor/weapon
  types recognised through the client's own category lists.
* **56 profiles**: a *Leveling* and an *All-round* profile for every class; the Leveling
  profile is chosen automatically below 80 (not for tanks and healers), the profile within a
  tree by the weapons you wear; hybrid classes switch weights with the deepest tree.
* **Titan's Grip**, role-aware dual wield, **off-hand DPS at half weight**, unique items,
  separate ranged/wand DPS weight.
* **Socket bonus**, gems with several values, *All Stats*, automatic empty-socket value,
  note when the equipped item carries enchant/gem points.
* **Heirloom preference** as a tapering score bonus instead of a hard rule; heirloom armor
  type rule actually implemented in `CanUseItem`.
* EGUP: `/egupclean` removes everything unequipped (multi-pass, bank, confirmation, dry run);
  `/egup verify` audits every class package and cross-checks attributes; hunter package corrected;
  `/egup self`.
* Offline test suite.

**Fixed**

* Heirloom armor was reported as "level too low" for shamans/hunters/warriors/paladins
  (the README claimed otherwise).
* A heirloom with the wrong stats blocked every better item.
* Shirts, tabards and fishing poles could show up as "upgrades".
* A tank's one-hander was compared against his shield.
* `/eg reset` deleted the custom profiles and aliased the defaults table.
* Quest-log rewards were never evaluated.

---

# EasyGear (Deutsch)

Item-Bewertung, Upgrade-Erkennung und Ausrüstungsvergleich für **World of Warcraft 3.3.5a (WotLK)**.

EasyGear sagt dir, ob ein Item wirklich besser ist als das, was du trägst — nach
Statgewichten für **deine Talente, deine Stufe und den Rest deiner Ausrüstung**, nicht nur
nach Gegenstandsstufe. Die Antwort erscheint überall, wo ein Item auftaucht: Taschen, Bank,
Questbelohnungen, Händler, Beutefenster, Würfelfenster, Handel, Auktionshaus, Post und in
jedem Item-Tooltip.

* Interface `30300`, Lua 5.1, keine XML-Dateien
* **Jede Clientsprache**: Texte kommen aus je einer Sprachdatei (`Locales/<Sprache>.lang.lua`),
  Englisch ist der Fallback für alles Unübersetzte; Rüstungs- und Waffentypen erkennt der
  Client selbst, nicht ein Namensvergleich
* Optionale Anbindung an **ElvUI**, **Bagnon** und **Immersion**

---

## Installation

Den Ordner `EasyGear` nach `Interface/AddOns/` kopieren (Dateiliste siehe oben), dann
`/reload` oder Client neu starten. Die Ladereihenfolge steckt in der `.toc`. Der Ordner
`tests/` ist nur für die Entwicklung und darf fehlen.

---

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/eg` · `/eggui` | Vergleichsfenster öffnen |
| `/eg <itemlink>` · `/eg <itemID>` | ausführliche Auswertung im Chat |
| `/eg upgrades` | **alle Verbesserungen in den Taschen** (und der Bank, wenn offen) auflisten, beste zuerst |
| `/egprofile` | Profilübersicht, Vergleich und Editor |
| `/eg profile list` | alle Profile im Chat |
| `/eg profile <id\|auto>` | Profil aktivieren |
| `/eg autolevel [on\|off]` | unter Stufe 80 das *Leveln*-Profil der Klasse benutzen |
| `/eg pvp` | PvP-Modus umschalten |
| `/eg role <auto\|tank\|melee\|ranged\|caster\|heal>` | erstes Profil der Klasse mit dieser Rolle |
| `/eg heirloom [on\|off]` | Erbstücke beim Leveln bevorzugen |
| `/eg heirloombonus <1.0–3.0>` | Wertungsaufschlag für Erbstücke (Standard 1.5) |
| `/eg enchants [on\|off]` | Verzauberungen und Sockelsteine mitrechnen |
| `/eg socket <zahl\|auto>` | Punkte je freiem Sockel (auto = aus Stufe und Profil) |
| `/eg ilvl <zahl>` · `ilvlscale [on\|off]` | Gewicht der Gegenstandsstufe / Skalierung mit der Charakterstufe |
| `/eg mindelta <zahl>` · `mindeltapct <prozent>` | Mindestvorsprung für „Verbesserung“ |
| `/eg icons` · `quest` · `items` · `tooltip` · `diff` | Markierungen Taschen / Quests / Händler-Beute-AH, Tooltipzeilen, Attribut-Differenzen ein-/ausschalten |
| `/eg scale <0.5–2.0>` | Fenstergröße |
| `/eg status` | aktuelle Einstellungen |
| `/eg locale` | welche Sprachdatei aktiv ist, wie Rüstungs-/Waffentypen erkannt wurden |
| `/eg reset` | Standardwerte (eigene Profile bleiben) |
| `/egup` · `/egup self` | GM: Klassenpaket an das Ziel / an sich selbst |
| `/egup list [klasse]` | Paket anzeigen, ohne zu senden |
| `/egup verify [klasse]` | IDs, Slots, Hauptattribute und jedes Klassenpaket prüfen |
| `/egupclean` · `/egupclean list` | **alle** nicht angelegten Paket-Items entfernen / anzeigen, was entfernt würde |

---

## Wo EasyGear Verbesserungen zeigt

Ein **grünes Häkchen** am Item bedeutet *besser als das, was du trägst*, ein **gelbes**
*wäre besser, aber deine Stufe reicht noch nicht*.

| Ort | Markierung | Tooltip |
| --- | :---: | :---: |
| Taschen — Blizzard, ElvUI, Bagnon — und Bank | ✔ | ✔ |
| Questbelohnungen (NPC-Fenster, Questlog, **Immersion** samt Shift-Übersicht) | ✔ beste Wahl | ✔ |
| Händlerangebot und Rückkauf | ✔ | ✔ |
| Beutefenster und Gruppenwürfeln (Bedarf/Gier) | ✔ | ✔ |
| Items des Handelspartners | ✔ | ✔ |
| Auktionshaus (Durchsuchen), Postfach | ✔ | ✔ |
| Chatlinks | — | ✔ |

Der Tooltip ergänzt Wertung, Slot und Wertung des ersetzten Items, das Urteil mit
absolutem und relativem Zugewinn und — wie bei RatingBuster — die **Attribut-Differenzen**
zum ersetzten Item. Auf dem Charakterfenster und in Vergleichstooltips steht nur die
Wertung: ein Item mit sich selbst zu vergleichen ergibt keinen Sinn.

Questbelohnungen werden nach **Zugewinn** gewertet, nicht nach absoluter Wertung: Stiefel,
die einen leeren Slot füllen, schlagen einen Umhang, der nur einen etwas schlechteren
ersetzt. Ist keine Belohnung ein Upgrade, entscheidet der Gesamtverkaufswert
(Stückpreis × Anzahl).

---

## Vergleichsfenster (`/EGGUI`)

* **Links:** das abgelegte Item mit allen Berechnungsgrundlagen (Attribut → Wert → Gewicht →
  Punkte), Basis aus der Gegenstandsstufe, Waffen-DPS, freie Sockel und Erbstück-Bonus. Bei
  Ringen und Einhandwaffen nennt die Kopfzeile den Slot, in den es am besten passt.
* **Rechts:** das angelegte Gegenstück. Bei Ringen, Schmuck und Einhandwaffen schalten die
  Reiter zwischen beiden Slots um; zuerst steht der Slot, der ersetzt würde.
* **Unten:** Ergebnis, Differenz absolut und in Prozent, Hinweise (Erbstück-Bevorzugung,
  Zweihand-/Titanengriff-Fall, einzigartige Items, Punkte aus Verzauberungen).

Item per Drag & Drop, Shift-Klick bei offenem Fenster oder `/eg <itemlink>`. Rechtsklick
auf das Feld leert es.

---

## Bewertung

```
Wertung = Gegenstandsstufe × ilvlWeight × (Charakterstufe / 80)
        + Σ (Attribut × Gewicht)           inkl. Verzauberung, Steine, aktivem Sockelbonus
        + Waffen-DPS × Gewicht             Nebenhand zählt halb
        + freie Sockel × Sockelwert
        × Erbstück-Faktor                  nur Erbstücke, unter Stufe 80
```

* **Gegenstandsstufe.** Die Statgewichte sind auf Stufe-80-Größenordnungen kalibriert; auf
  Stufe 5 tragen Items einstellige Werte. Ein fester Punktwert je Gegenstandsstufe würde die
  Attribute im gesamten Levelbereich übertönen — der Term wächst deshalb mit der
  Charakterstufe (`/eg ilvlscale off` schaltet das ab).
* **Schwelle.** Ein Vorsprung von 0.1 Punkten bei einer Wertung von 2.5 ist Rauschen. Eine
  Verbesserung muss `max(minDelta, minDeltaPercent % des Vergleichswerts)` schlagen,
  standardmäßig 1 %.
* **Waffen-DPS.** Nahkampf (`DPS`) und Fernkampf/Zauberstab (`RDPS`) werden getrennt
  gewichtet — für einen Jäger zählt der Bogen enorm, der Dolch kaum; ein levelnder Priester
  schätzt den Zauberstab. Eine **Waffe in der Schildhand verursacht nur halben Schaden**,
  ihre DPS zählen deshalb nur zur Hälfte.
* **Freie Sockel.** Bewertet als ein typischer Stein der Stufe (ca. 0.22 Punkte je Stufe ×
  Hauptattributgewicht, 10 % Abzug für nicht passende Farbe) — auf Stufe 80 rund 16 Punkte.
  Mit `/eg socket <zahl>` überschreibbar.

### Verzauberungen, Sockelsteine, Sockelbonus

`GetItemStats()` liest nur die Basiswerte aus dem Itemlink; Verzauberungen tauchen dort
**nicht** auf. EasyGear liest deshalb zusätzlich den Tooltip. Vier Zeilenformen kommen vor,
alle werden erkannt:

```
+55 Ausdauer                              Primärattribute
Ausrüsten: Verbessert Tempowertung um 55. Wertungen
+10 Stärke und +15 Ausdauer               Edelsteine, Verzauberungen (mehrere Werte je Zeile)
Sockelbonus: +4 Ausdauer                  Sockelbonus - nur solange aktiv (grün)
```

* Die Muster werden zur Laufzeit aus den lokalisierten Blizzard-Globals gebaut, sind also
  nicht an eine Sprache gebunden.
* Basis- und Langformzeilen sind vorne und hinten verankert — sonst würde ein Proc-Text wie
  *„Erhöht Eure Angriffskraft um 340 für 10 Sek.“* als dauerhafter Wert gezählt. Zeilen mit
  Ausrüsten-/Benutzen-/Proc-Präfix gelten nie als Stein- oder Verzauberungstext.
* Attributnamen werden längster zuerst abgeglichen: *„+6 Mana alle 5 Sek.“* ist
  Manaregeneration, nicht Mana; *„+20 Rüstungsdurchschlagwertung“* ist keine Rüstung.
  *„+10 Alle Werte“* geht auf Stärke, Beweglichkeit, Ausdauer, Intelligenz und Willenskraft.
* Basiswert und Tooltipsumme werden über das **Maximum** zusammengeführt. Scheitert das
  Auslesen einer Zeile, bleibt der Basiswert erhalten — nichts geht verloren, nichts wird
  doppelt gezählt.
* Graue Zeilen (inaktive Sockel- und Setboni) werden übersprungen, bei der Set-Kopfzeile
  (`Name (2/5)`) wird abgebrochen, rote Zeilen zählen nie.

Trägt das **angelegte** Item Punkte aus Verzauberungen und Steinen, die ein frischer Drop
nicht hat, weist EasyGear darauf hin — eine negative Differenz ist dann nicht die ganze
Wahrheit. `/eg enchants off` vergleicht nur Basiswerte.

---

## Profile (`/EGPROFILE`)

**56 eingebaute Profile.** Für jede der zehn Klassen:

| | |
| --- | --- |
| je Talentbaum ein Profil | und je Spielstil innerhalb eines Baums: Blut-Tank / Blut-Zweihand, Frost beidhändig / Zweihand / Tank, Wildheit Katze / Bär |
| **Leveln** | Stufe 1–79: Stärke/Beweglichkeit, **Ausdauer und Rüstung** zählen deutlich mehr, Wertungen kaum — die gibt es auf Levelausrüstung fast nicht. Jäger bewerten die Fernkampfwaffe, Zauberer den Zauberstab |
| **Allround** | deckt alle Spezialisierungen der Klasse mäßig ab — für Hybrid-Ausrüstung und Zweitspezialisierung |

Dazu zwei klassenunabhängige: *Levelphase (neutral)* und *Nur Gegenstandsstufe*.

### Automatische Wahl

Ohne Zutun entscheidet EasyGear nach **Talenten, Stufe und Waffen**:

1. Weniger als 5 Talentpunkte → *Leveln* (unter 80) bzw. *Allround* (ab 80).
2. **Unter Stufe 80** → das *Leveln*-Profil der Klasse — außer bei **Tank- und Heilbäumen**,
   die ihr Profil behalten, weil sich dort die Gewichtung grundlegend unterscheidet.
   (`/eg autolevel off` nimmt immer das Talentprofil.)
3. **Stufe 80** → Profil des Talentbaums mit den meisten Punkten.
4. Hat ein Baum mehrere Profile, entscheiden die **getragenen Waffen**: Frost mit Zweihänder →
   *Frost (Zweihand)*, beidhändig → *Frost (beidhändig)*; Blut mit Zweihänder → *Blut
   (Zweihand-DD)*, sonst der Tank. Eine andere Wahl triffst du im Fenster.
5. *Leveln*-Profile der Hybridklassen wechseln ihre Gewichte mit dem stärksten Baum: ein
   Schamane mit den meisten Punkten in Elementar levelt mit Zauberer-Gewichten, in
   Verstärkung mit Nahkampf-Gewichten; ein Druide in Gleichgewicht mit Zauberer-, in
   Wildheit mit Wildheits-Gewichten.

### Gewichte

Die Gewichte sind auf das Hauptattribut des Profils (1.00) normiert. Die Herleitung steht im
Kopf von `EasyGearSpecs.lua`: 1 Stärke = 2 Angriffskraft bei den Stärkeklassen, 1 Waffen-DPS
≈ 14 Angriffskraft ≈ 7–8 Stärke, 1000 Rüstung ≈ 2,2 % weniger Schaden ≈ 90 Ausdauer für einen
Tank (0.09), Beweglichkeit gibt dem Jäger 2 Fernkampf-Angriffskraft (AK = FAK = 0.50), die
Teufelsrüstung macht 30 % Willenskraft zu Zaubermacht (Willenskraft 0.35) usw. Es sind
gute Startwerte, **keine Simulation**: Für Feinabstimmung ein eigenes Profil anlegen.

### Profilfenster

Aufbau wie der Item-Vergleich, nur mit Profilen: links das gewählte Vergleichsprofil
(Klasse und Profil über die Auswahlfelder), rechts immer das **aktuell aktive**. Die
Wertespalte ist auf beiden Seiten identisch — die Summen deiner angelegten Ausrüstung —,
unterschiedlich sind Gewicht und Punkte. So siehst du, was deine Ausrüstung unter einem
anderen Build wert wäre und welche Attribute die Punkte tragen. Beide Seiten teilen sich
eine Zeilenliste; die Punktespalte ist grün, wo diese Seite mehr holt. Über die
Klassenauswahl erreichst du auch die Profile **anderer** Klassen.

> Gesamtsummen zweier Profile sind nur grob vergleichbar, weil die Gewichtssätze zwar auf
> das Hauptattribut normiert, aber nicht gegeneinander geeicht sind. Aussagekräftig ist die
> Verteilung je Attribut.

**PvP-Modus.** Abhärtung bekommt mindestens 1.00, Ausdauer wird auf das 2,5-fache angehoben —
oben auf das aktive Profil. **Eigene Profile.** „Bearbeiten“ macht die linke Gewichtsspalte
zu Eingabefeldern (alle Attribute, auch mit Gewicht 0, sowie beide Waffen-DPS-Zeilen). „Als
neues Profil speichern“ geht auch ausgehend von eingebauten Profilen; eigene Profile sind
mit `*` markiert, accountweit und überstehen `/eg reset`.

---

## Waffenhand, Schildhand, Ringe, Schmuck

Der Kandidat wird in jeden Slot „eingesetzt“, in den er passt, und mit dem dort Angelegten
verglichen; der Slot mit dem größten Zugewinn gewinnt. Damit ergeben sich alle Sonderfälle
von selbst:

| Kandidat | angelegt | verglichen gegen |
| --- | --- | --- |
| Ring, Schmuck | zwei davon | der **schwächere** der beiden Slots |
| Schild / Nebenhand | Zweihänder | Waffenhand **+** Schildhand zusammen (nicht der „leere“ Slot 17) |
| Schild / Nebenhand | Einhandwaffe | Schildhand |
| Einhandwaffe | Zweihänder | Waffenhand — sie würde den Zweihänder ersetzen |
| Einhandwaffe | Einhandwaffe + Nebenhand | Waffenhand oder Schildhand, je nach Zugewinn |
| Zweihandwaffe | beliebig | Waffenhand + Schildhand zusammen |
| Zweihandwaffe mit **Titanengriff** | zwei Zweihänder | eine der beiden Hände |
| einzigartiger Ring/Schmuck | derselbe | sein Zwilling — das zweite Exemplar ersetzt das erste |

* **Schildhand.** Waffen-DPS in der Schildhand zählen halb. Schilde und Halteitems sind keine
  Waffen und davon unberührt.
* **Rollenbewusst.** Beidhändigkeit allein genügt nicht: Ein Schutzkrieger *kann* beidhändig
  kämpfen, trägt aber ein Schild. Bei Tank-, Heiler- und Zauberprofilen konkurriert eine
  Einhandwaffe deshalb nur um die Waffenhand — es sei denn, in der Schildhand liegt bereits
  eine Waffe. Schurken, Verstärkungsschamanen, Furor-Krieger u. ä. vergleichen für beide Hände.
* **Titanengriff** wird am (sprachunabhängigen) Talentsymbol erkannt oder daran, dass in
  beiden Händen ein Zweihänder liegt. Die **Beidhändigkeit des Schamanen** braucht das
  Verstärkungs-Talent und Stufe 40.
* **Kosmetik und Werkzeug.** Hemden, Wappenröcke, Angelruten und Spitzhacken tragen keine
  Werte und werden nie als Verbesserung markiert.

---

## Erbstücke

Alle 37 Erbstücke aus 3.3.5a stehen in `EasyGearHeirlooms.lua`, dazu der Ring des
Schreckenspiraten und die Taschen, die zwar keine Erbstücke sind, aber zum Paket gehören.

### Bevorzugung beim Leveln

Erbstücke wachsen mit der Stufe und geben Bonuserfahrung; ein normales Levelitem kann nicht
mithalten. Statt der starren Regel „Erbstück gewinnt immer“ bekommt ein Erbstück einen
**Wertungsaufschlag**:

| Charakterstufe | Aufschlag (Standard) |
| --- | --- |
| bis 60 | × 1.5 |
| 60 → 80 | fällt linear auf × 1.0 (× 1.25 auf Stufe 70) |
| 80 | keiner — sie skalieren nicht mehr |

Ein normales Item muss also deutlich besser sein, um ein angelegtes Erbstück zu ersetzen, und
ein Erbstück schlägt auch ein *etwas* besseres normales Item. Ein Erbstück mit **unbrauchbaren
Werten** (Stärke auf einem Heiler) blockiert dagegen kein passendes Item mehr — das tat die
alte harte Regel. Der Aufschlag steht als eigene Zeile in der Berechnung. Einstellbar mit
`/eg heirloombonus <1.0–3.0>`, abschaltbar mit `/eg heirloom off`.

### Wechselnde Rüstungsklasse

Erbstück-Rüstung wechselt mit Stufe 40 die Klasse: **Kette zählt darunter als Leder, Platte als
Kette.** Praktisch tragen Schamane und Jäger Kettenerbstücke, Krieger und Paladin
Plattenerbstücke ab Stufe 1 — ohne die Stufe-40-Anforderung der normalen Rüstungsklasse.
`EG:CanUseItem` setzt genau das um (`GetProficiencyLevel(Klasse, Token, Erbstück)`).

### Zwei Schulterreihen

Die 429xx-Schultern stammen von den Abzeichen-Händlern, die 441xx vom Argentumturnier. Sie
sind gleichwertige Alternativen und werden beide vergeben. Ausnahme ist 44100 — die einzige
Plattenschulter mit Intelligenz und damit die einzige für einen heiligen Paladin.

---

## EGUP (GM-Funktion)

`/egup` schickt `.additem`-Befehle für ein klassenpassendes Erbstückpaket an das anvisierte
Ziel (`/egup self` an dich selbst). Vorher erscheint eine Sicherheitsabfrage
(`EasyGearDB.egupConfirm = false` schaltet sie ab). Das Befehlsmuster ist konfigurierbar:

```lua
EasyGearDB.egupCommand = ".additem {name} {id} {count}"
-- TrinityCore mit Zielauswahl z. B.:
EasyGearDB.egupCommand = ".additem {id} {count}"
```

| Klasse | Teile | Klasse | Teile |
| --- | --- | --- | --- |
| Krieger | 11 | Schamane | 17 |
| Paladin | 15 | Schurke | 11 |
| Todesritter | 9 | Druide | 16 |
| Jäger | **9** | Priester | 8 |
| Magier | 6 | Hexenmeister | 6 |

(ohne Ring, Taschen und Insignien, die jede Klasse bekommt; die PvP-Insignien sind
fraktionsgebunden und werden über die Fraktion des Ziels gewählt)

### Was ins Paket kommt

Ein Stück geht an eine Klasse, wenn sie es **führen kann** *und* es **passt**: Sein
Hauptattribut ist ein Hauptattribut der Klasse (Waffen dürfen zusätzlich ein Nebenattribut
tragen — Beweglichkeit bei Plattenträgern, Stärke bei Leder- und Kettenträgern). Ein
Beweglichkeitsdolch ist für einen Priester tragbar und trotzdem wertlos. Bei Rüstung kommt je
Slot und Attribut nur die **beste tragbare Rüstungsklasse** ins Paket (Platte vor Kette vor
Leder vor Stoff), außer es gibt dort kein Teil der besten Klasse. Das hat sich geändert: Ein
**Jäger** bekommt die drei Stärkewaffen nicht mehr — Stärke bringt einem Fernkämpfer nichts.

### Prüfen

Eine falsche ID fällt bei `.additem` **nicht auf**: Der Server meldet den Fehler, der Spieler
bekommt nichts, und im Paket sieht alles richtig aus. `/egup verify [klasse]`

* schlägt jede ID im Client-Cache nach: existiert sie, ist es wirklich ein Erbstück
  (Qualität 7), stimmt der Slot, und passt das **Hauptattribut im Tooltip** zu dem in der
  Tabelle hinterlegten;
* prüft jedes Klassenpaket gegen die Regeln oben und meldet *unbrauchbare* (Klasse kann es
  nicht tragen), *überflüssige* (tragbar, aber kein passendes Attribut) und *fehlende*
  (tragbar und passend, aber nicht im Paket) Stücke.

Korrekturen gehören in `EasyGearHeirlooms.lua`. Ein Item, das der Client noch nie gesehen hat,
ist ungecacht und wird als fehlend gemeldet, obwohl die ID stimmt — einmal beim Händler
ansehen genügt.

### Aufräumen

`/egupclean` entfernt **jedes nicht angelegte Exemplar** jedes Paket-Items aus den Taschen —
und aus der Bank, wenn das Bankfenster offen ist. Angelegte Items liegen nicht in den Taschen
und bleiben deshalb, ebenso Taschen, die in einem Taschenplatz stecken. Früher wurden nur die
beim letzten `/egup` erfassten Mengen gelöscht; war die Sitzung weg, schon teilweise
aufgeräumt oder ein Stapel verschoben, blieb etwas liegen. Jetzt:

* Zielmenge ist jedes Item aus `EasyGearHeirlooms.lua` plus die gespeicherte Sitzung;
* es läuft in **mehreren Durchgängen**, bis nichts mehr übrig ist — ein Fach, das der Server
  noch gesperrt hält, wird im nächsten Durchgang erneut versucht; was sich nicht entfernen
  ließ, wird gemeldet;
* vorher fragt ein Dialog mit Anzahl der Items und Stapel (`egupConfirm`);
  `/egupclean list` zeigt nur an, was entfernt würde.

---

## Sprachen

Jeder Text steht in `Locales/<Sprache>.lang.lua`, eine Datei je Clientsprache — reines Lua,
das eine Tabelle registriert:

```lua
EasyGearLocales = EasyGearLocales or {}
EasyGearLocales["deDE"] = { LOADED = "EasyGear %s geladen.", ... }
```

* **Auflösung** je Schlüssel: Clientsprache → Englisch → der Schlüssel selbst. Eine
  unvollständige Übersetzung ist in Ordnung; eine nicht unterstützte Clientsprache zeigt
  durchgehend Englisch. `enGB` nutzt `enUS`, `esMX` nutzt `esES`.
* **Mitgeliefert:** `enUS` (vollständige Referenz), `deDE` (vollständig), `frFR`, `esES`,
  `ruRU`, `koKR`, `zhCN`, `zhTW` (Oberflächentexte und Profilnamen; Profilbeschreibungen fallen
  auf Englisch zurück).
* **Inhalt:** Ausgabetexte, Bezeichnungen, Profilnamen `SPEC_<id>` / -beschreibungen
  `SPEC_<id>_D` und die Untertypnamen `SUBTYPE_<TOKEN>` für Rüstung und Waffen.
* **Kodierung:** Sprachdateien sind UTF-8 ohne BOM; alle Codedateien bleiben reines ASCII.

**Warum `.lang.lua`.** Der Client lädt aus der `.toc` zuverlässig nur `.lua`- und
`.xml`-Dateien. `.lang` kennzeichnet die Sprachdatei, das angehängte `.lua` stellt sicher,
dass sie geladen wird. Wenn du weißt, dass dein Client auch reine `.lang`-Dateien lädt:
Dateien und `.toc`-Zeilen umbenennen, mehr ändert sich nicht.

**Sprachunabhängige Grundfunktion.** Welche Rüstungs- und Waffentypen deine Klasse tragen
darf, braucht den *Untertyp* des Items, den `GetItemInfo()` nur als lokalisierten Text
liefert. EasyGear baut die Zuordnung Name → Typ in dieser Reihenfolge:

1. aus den **Kategorielisten des Auktionshauses** des Clients (`GetAuctionItemSubClasses`) —
   feste Reihenfolge, Clientsprache, keine Textkenntnis nötig;
2. aus den `SUBTYPE_*`-Namen der Sprachdateien für alles, was Schritt 1 nicht liefert.

Jeder erkannte Typ wird gegen den Ausrüstungsplatz geprüft (ein Kopfteil kann kein Stab sein);
Unplausibles wird verworfen, nach drei Fällen wird Schritt 1 abgeschaltet. Die
Verwendbarkeit entscheiden ohnehin zusätzlich die **roten Tooltipzeilen**, die von Natur aus
sprachunabhängig sind. `/eg locale` zeigt, was aktiv ist und wie die Typen erkannt wurden.

**Sprache ergänzen.** `enUS.lang.lua` kopieren, nach dem Sprachcode benennen, den
Tabellenschlüssel ändern, übersetzen, was du magst, eine Zeile `Locales\<code>.lang.lua` in
die `EasyGear.toc` eintragen und `python3 tests/run_tests.py` ausführen — das prüft
Schlüssel, Platzhalter und Kodierung.

---

## Einstellungen

Gespeichert in `EasyGearDB` (accountweit) und `EasyGearCharDB` (pro Charakter). Schlüssel,
Standardwerte und Bedeutung siehe Tabelle im englischen Teil.

Pro Charakter: `profile` (Profil-ID oder `AUTO`), `pvp`, Fensterpositionen, letzte
EGUP-Sitzung.

---

## Tests

```
pip install lupa
python3 tests/run_tests.py            # alles
python3 tests/run_tests.py -k egup    # nur Fälle, deren Name „egup“ enthält
```

Die Suite lässt das Addon unter echtem **Lua 5.1** gegen eine kleine WoW-API-Attrappe
(`tests/wow_stub.lua`) laufen — Frames, Tooltips mit Zeilenfarben, Items, Taschen,
Ausrüstung, Talente, Cursor, Timer — einmal je Clientsprache, und prüft die Dateien statisch
(ASCII-Code, UTF-8-Sprachdateien, vollständige `.toc`, Sprachschlüssel benutzt / vorhanden /
gleiche Platzhalter). Die Fälle stehen in `tests/cases.lua`.

Das ist ein Offline-Werkzeug und **kein Ersatz fürs Spielen**: Die Attrappe bildet die API
nach Dokumentation für 3.3.5a nach, nicht den echten Client.

---

## Bekannte Grenzen

* Die Wertung ist eine Heuristik. **Trefferwertungs- und Waffenkunde-Grenzen**, Setboni,
  Prozeduren, Metasteinbedingungen und Waffengeschwindigkeit werden nicht bewertet; die
  Gewichte sind begründete Startwerte.
* Verzauberungen ohne Zahlenwert (*Kreuzfahrer*, *Berserker*) lassen sich nicht bewerten.
* In Sprachen mit gebeugtem Edelsteintext (Russisch: „+20 к силе“) werden Steinzeilen
  möglicherweise nicht erkannt; Basiswerte und alle „Ausrüsten:“-Zeilen zählen weiterhin.
* Wertungen liegen auf niedrigen Stufen im Bereich 0–5 und auf Stufe 80 im dreistelligen
  Bereich — eine relative Rangfolge, vergleichbar nur für denselben Charakter zum selben
  Zeitpunkt.
* Erbstückwerte stammen aus dem Tooltip und sind Näherungswerte. Das **Hauptattribut jedes
  Erbstücks in der Tabelle ist eine Annahme**, die `/egup verify` gegen den Client gegenprüft —
  einmal auf deinem Server ausführen.
* Bei stark abweichenden Custom-Cores können Item-IDs und die `.additem`-Syntax abweichen.

---

## Änderungen in 3.0

**Neu**

* Markierungen bei **Händlern, Beute, Würfeln, Handel, Auktionshaus und Post**;
  Questlog-Belohnungen; `/eg upgrades`; Attribut-Differenzen und Prozent-Zugewinn im Tooltip.
* **Sprachen**: eine `.lang.lua`-Datei je Clientsprache, englischer Fallback, Rüstungs- und
  Waffentypen über die Kategorielisten des Clients erkannt.
* **56 Profile**: ein *Leveln*- und ein *Allround*-Profil für jede Klasse; das Leveln-Profil
  wird unter 80 automatisch gewählt (nicht für Tanks und Heiler), das Profil innerhalb eines
  Baums nach den getragenen Waffen; Hybridklassen wechseln die Gewichte mit dem stärksten Baum.
* **Titanengriff**, rollenbewusste Beidhändigkeit, **Schildhand-DPS zur Hälfte**, einzigartige
  Items, getrenntes Nah-/Fernkampf-DPS-Gewicht.
* **Sockelbonus**, Steine mit mehreren Werten, *Alle Werte*, automatischer Wert freier Sockel,
  Hinweis, wenn das angelegte Item Verzauberungs-/Steinpunkte trägt.
* **Erbstück-Bevorzugung** als abklingender Wertungsaufschlag statt harter Regel; die
  Erbstück-Rüstungsregel steckt jetzt tatsächlich in `CanUseItem`.
* EGUP: `/egupclean` entfernt alles Nichtangelegte (mehrere Durchgänge, Bank, Rückfrage,
  Probelauf); `/egup verify` prüft jedes Klassenpaket und gleicht Attribute ab;
  Jägerpaket korrigiert; `/egup self`.
* Offline-Testsuite.

**Behoben**

* Erbstück-Rüstung wurde für Schamane/Jäger/Krieger/Paladin als „Stufe zu niedrig“ gemeldet
  (die README behauptete das Gegenteil).
* Ein Erbstück mit falschen Werten blockierte jedes bessere Item.
* Hemden, Wappenröcke und Angelruten konnten als „Verbesserung“ erscheinen.
* Die Einhandwaffe eines Tanks wurde gegen sein Schild verglichen.
* `/eg reset` löschte die eigenen Profile und verband die Standardtabelle per Alias.
* Questlog-Belohnungen wurden nie bewertet.
