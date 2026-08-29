# EasyGear

Gear scoring, upgrade detection and item comparison for **World of Warcraft 3.3.5a (WotLK)**.

EasyGear tells you whether an item in your bags, on a vendor or in a quest reward
list is actually better than what you are wearing — using stat weights for your
spec rather than item level alone.

* Interface `30300`, Lua 5.1, no XML files
* English and German clients; all source files are pure ASCII (umlauts stored as
  `\195\188` escapes), so no editor or HD-client setup can corrupt the encoding
* Optional integration with **ElvUI**, **Bagnon** and **Immersion**

---

## Contents

- [Installation](#installation)
- [Commands](#commands)
- [Item comparison window](#item-comparison-window-eggui)
- [Scoring](#scoring)
- [Profiles](#profiles-egprofile)
- [Bags and tooltips](#bags-and-tooltips)
- [Quest rewards](#quest-rewards)
- [Weapon slots](#weapon-slots)
- [Heirlooms](#heirlooms)
- [EGUP — GM heirloom packages](#egup--gm-heirloom-packages)
- [Settings](#settings)
- [Known limits](#known-limits)

---

## Installation

Copy the `EasyGear` folder into your AddOns directory:

```
World of Warcraft/
└── Interface/
    └── AddOns/
        └── EasyGear/
            ├── EasyGear.lua            core: scoring, comparison, hooks
            ├── EasyGearSpecs.lua       36 stat weight profiles
            ├── EasyGearHeirlooms.lua   heirloom database and class packages
            ├── EasyGearGUI.lua         item comparison window
            ├── EasyGearProfileGUI.lua  profile comparison window
            └── EasyGear.toc
```

Then `/reload` or restart the client. Load order matters and is handled by the
`.toc` — do not reorder the files.

---

## Commands

| Command | Effect |
| --- | --- |
| `/eg` | open the comparison window |
| `/eggui` | same, explicit |
| `/eg <itemlink>` | full breakdown in chat |
| `/eg <itemID>` | same, by item ID |
| `/egprofile` | profile overview, comparison and editor |
| `/eg profile list` | list all profiles in chat |
| `/eg profile <id\|auto>` | activate a profile |
| `/eg pvp` | toggle PvP mode |
| `/eg role <auto\|tank\|melee\|ranged\|caster\|heal>` | pick the first profile of your class with that role |
| `/eg ilvl <number>` | item level weight (at level 80) |
| `/eg ilvlscale <on\|off>` | scale the item level term with character level |
| `/eg mindelta <number>` | absolute minimum gain to call something an upgrade |
| `/eg mindeltapct <percent>` | relative minimum gain (default 1 %) |
| `/eg icons` · `quest` · `tooltip` · `heirloom` | toggle the individual displays |
| `/eg scale <0.5–2.0>` | window scale |
| `/eg status` | current settings |
| `/eg reset` | back to defaults |
| `/egup` | GM: send a class heirloom package to your target |
| `/egup list [class]` | show a package without sending anything |
| `/egup verify [class]` | check the stored item IDs against the client |
| `/egupclean` | remove recorded EGUP items from the bags |

---

## Item comparison window (`/EGGUI`)

Drag an item onto the slot, shift-click it while the window is open, or use
`/eg <itemlink>`.

* **Left** — the candidate item with the full calculation: attribute → value →
  weight → points, plus the item level base, weapon DPS and empty sockets.
* **Right** — the equipped counterpart. For rings, trinkets and one-handers the
  tabs at the top right switch between both slots.
* **Bottom** — verdict, point difference and notes (heirloom rule, two-hander
  special case, and so on).

Right-clicking the slot clears it. *Print to chat* writes the same breakdown as
text. The window is movable and closes with ESC; position and scale are stored
per character.

---

## Scoring

```
score = item level × ilvlWeight × (character level / 80)
      + Σ (attribute × weight)
      + weapon DPS × weight
      + empty sockets × socketValue
```

### Why the item level term scales with character level

The stat weights are calibrated for level-80 magnitudes, where an item carries
three-digit attribute values. At level 5 they are single digits. A **fixed**
point value per item level therefore drowns out the actual attributes across the
entire levelling range — one item level used to outweigh six times the armor:

```
Frayed Bracers          ilvl 5,  4 armor    2.50 + 0.08 = 2.58  <- counted as upgrade
Very Light Chain Braces ilvl 4, 25 armor    2.00 + 0.50 = 2.50
```

With scaling (character level 5 → effective weight 0.03) and the higher armor
weight in the beginner profile:

```
Frayed Bracers          0.16 + 0.24 = 0.40
Very Light Chain Braces 0.13 + 1.50 = 1.62  <- correctly preferred
```

At level 80 the factor is 1, so nothing changes there. Disable with
`/eg ilvlscale off`.

### Upgrade threshold

A 0.1 point lead on a score of 2.5 is noise. The threshold is therefore absolute
**and** relative: `max(minDelta, minDeltaPercent % of the compared score)`,
1 % by default.

### Enchants and gems

`GetItemStats()` only reads the base values out of the item link. Enchants live
in `SpellItemEnchantment.dbc` and do **not** appear there — an enchanted weapon
returned exactly the same values as an unenchanted one.

EasyGear therefore also scans the tooltip, where the enchant sits on its own
green line. WotLK uses two formats and both are recognised:

```
+55 Stamina                          primary attributes, gems
Equip: Improves haste rating by 55.  ratings
```

The patterns are built at runtime from the localised Blizzard globals
(`ITEM_MOD_*_SHORT` and `ITEM_MOD_*`), so they are not tied to one language.
They are anchored at both ends — otherwise a proc line such as *"Increases
attack power by 340 for 10 sec."* would be counted as a permanent stat.

Base values and tooltip sums are merged by taking the **maximum**: the tooltip
lists base, enchant and gems on separate lines, so its sum is normally the
larger figure. If a line cannot be parsed the base value survives, so nothing is
lost and nothing is counted twice.

Further safeguards against double counting:

* **Grey lines are skipped** — those are inactive socket and set bonuses.
* **Scanning stops at the set header** (`Name (2/5)`), because set bonuses come
  from other pieces and would otherwise be added to every one of them.
* **Red lines never count**; they still drive the usability check.

Whether an item is enchanted or gemmed is shown in the comparison window and in
the chat output. All three tooltip passes (usability, weapon DPS, stats) happen
in a single sweep that is cached per item link, so this is faster than the
previous two-pass approach despite doing more work.

---

## Profiles (`/EGPROFILE`)

36 built-in profiles: every talent tree of all ten classes, plus separate
entries wherever the weighting genuinely differs **within** a tree — blood tank
vs. blood DPS, dual-wield vs. two-hand frost, feral cat vs. bear. Two more are
class independent: *Leveling (neutral)* and *Item level only*.

| Class | Profiles |
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

The differences are not cosmetic. Dual-wield frost weights hit rating at 1.40,
the two-hand variant at 1.15 — dual wielding simply needs more hit. The bear
weights armor at 0.10 and has no block stats at all, while the protection
paladin weights block value at 0.55.

**Selection.** Without any input the talent tree with the most points is
detected and its default profile used. Where a tree has several profiles one is
marked as default (blood → tank, feral → cat, frost DK → dual wield); the
alternatives are picked in the window. Below 5 spent talent points *Leveling
(neutral)* applies.

**The window** mirrors the item comparison, with profiles instead of items:

```
        Comparison profile                  Active profile
        Protection (tank)                   Arms (two-hand)

Attribute       Value  Weight  Points   Attribute       Value  Weight  Points
Stamina          1450  x 1.00    1450   Stamina          1450  x 0.10     145
Defense           540  x 1.20     648   Defense           540  x 0.00       0
Strength          980  x 0.55     539   Strength          980  x 1.00     980
...

Gear score              7755     Gear score              7710
```

The left side is the profile you select (class and profile via the two dropdowns
at the top), the right side is always the **currently active** one. The value
column is identical on both sides — those are the totals of your equipped gear.
Only weight and points differ, so you can see directly what your current gear
would be worth under another build and which attributes carry the points.

Both sides share **one row list** (the union of both weight sets) so the same
attribute lines up on the left and right. The points column is green where that
side scores more and red where it scores less. The mouse wheel scrolls when the
list outgrows the window.

The class dropdown also reaches the profiles of **other** classes — as a
reference or as a starting point for your own.

> A caveat the window states itself: totals of two profiles are only roughly
> comparable, because the weight sets are normalised to the primary attribute
> but not calibrated against each other. A higher total does **not** mean "this
> profile is better for you". What matters is the per-attribute distribution.

If an item is loaded in the item window, its score under both profiles is shown
underneath — so you can see immediately whether something is an upgrade only
under one build.

**PvP mode.** One switch instead of 36 extra profiles: resilience gets at least
1.00 and stamina is raised 2.5×, applied on top of the active profile.

**Custom profiles.** *Edit* turns the left weight column into input fields;
points and totals recalculate as you type while the active profile stays visible
on the right as a reference. Edit mode shows every attribute, including those
weighted 0, so you can add one that was unused. Then either *Save as new
profile* (this also works starting from a built-in profile) or *Save* to
overwrite your own. Custom profiles are marked with `*`, are account-wide and
appear in the selection immediately.

---

## Bags and tooltips

Bag slots get a marker when the item beats what you have equipped:

* **green check** — a real upgrade
* **yellow check** — would be an upgrade, but your level is too low

Supported bag UIs: the default Blizzard bags, the bank, **ElvUI** and
**Bagnon**. The ElvUI hook handles both `UpdateSlot` signatures found in 3.3.5a
forks.

Item tooltips gain a score line, the compared value and the difference. Turn
individual parts off with `/eg icons`, `/eg tooltip`, `/eg quest`.

The usability check is language independent: it reads the **red tooltip lines**,
which covers class restrictions, reputation, race and profession requirements no
matter how a server names its item subtypes. Armor and weapon proficiency tables
per class act as a second gate, including the level requirements (plate at 40
for warriors and paladins, mail at 40 for hunters and shamans).

---

## Quest rewards

Both the Blizzard quest frame and **Immersion** are supported, including
Immersion's shift-key overview.

Rewards are ranked by **gain**, not by absolute score. The difference matters
when a slot is still empty:

```
Moonbrook Fur Cloak       score 0.51   equipped 0.30   gain +0.21
Moonbrook Leather Boots   score 0.61   equipped 0.00   gain +0.61   <- chosen
```

If no reward is an upgrade, the highest total vendor value wins (unit price ×
stack size).

<details>
<summary>Implementation notes for the Immersion integration</summary>

The reward buttons live under
`ImmersionFrame.TalkBox.Elements.Content.RewardsFrame.Buttons` and are
identified by `type == "choice"`, with the choice index in `:GetID()`.

EasyGear hooks `Elements:Display()`, **not** `Elements:ShowRewards()`. Immersion
stores its templates as lists of function references and calls them through
`elementsTable[i](self)`; that reference still points at the original function,
so a hook on the frame would never fire. `Display()` on the other hand is called
as a real method in `Frame:AddQuestInfo()`.

The tooltip lines hang off `GameTooltip:SetQuestItem` rather than
`OnTooltipSetItem`, because `GetItem()` does not reliably return a link for
quest rewards. That covers the talk frame of both UIs, since Immersion uses the
same `GameTooltip` there.

The shift overview does not use the buttons at all — it fills pooled tooltip
frames (`ImmersionItemTooltipTemplate`) in `Frame:SetItemTooltip()`. Those are
separate frame objects, so the `GameTooltip` hook does not reach them; EasyGear
hooks `SetItemTooltip` on `ImmersionFrame` instead. Because those frames come
from a pool and get reused, the "already decorated" marker and the check icon
are reset on every fill — otherwise the previous quest's recommendation would
stick.
</details>

---

## Weapon slots

While a two-handed weapon is equipped the off hand is not free — it is occupied
by the two-hander. Equipping a shield or off-hand item therefore costs the whole
two-hander, so the comparison runs against **main hand plus off hand together**,
not against the apparently empty slot 17. Otherwise any off-hand item would
count as an improvement, because an empty slot scores 0.

| Candidate | Equipped | Compared against |
| --- | --- | --- |
| shield / off hand | two-hander | main hand + off hand |
| shield / off hand | one-hander | off hand |
| one-hander | two-hander | main hand |
| one-hander | one-hander + off hand | the weaker of the two slots |
| two-hander | anything | main hand + off hand |

---

## Heirlooms

All 37 heirlooms of 3.3.5a are in `EasyGearHeirlooms.lua`: 4 trinkets (including
both PvP insignia), 13 shoulders, 6 chests and 14 weapons, plus the Dread Pirate
Ring and the bags, which are not heirlooms but belong to the package.

### Comparison rules

Heirlooms scale with your level and grant bonus experience; a normal levelling
item cannot compete. Three rules apply below level 80:

| Candidate | Equipped | Result |
| --- | --- | --- |
| normal | heirloom | always loses |
| heirloom | normal | always wins |
| heirloom | heirloom | ranked normally by score |

Slot precision matters: with an heirloom ring in finger 1 and a normal ring in
finger 2, a better normal ring is still recommended for finger 2. The
comparison is only blocked when **every** eligible slot holds an heirloom.

For "heirloom beats normal" the point difference can be negative — the item is
still the recommendation because it grows with you, and the reason is printed on
the line below. From level 80 heirlooms no longer scale and the rule is
inactive; `/eg heirloom` disables it entirely.

### Changing armor type

Heirloom armor changes its class at level 40: **mail counts as leather below
40, plate counts as mail**. A shaman can therefore wear Champion's Deathdealer
Breastplate from level 1, and warriors and paladins wear the plate pieces right
away because they count as mail, which both classes know from level 1.

`EG:CanUseItem` accounts for this. Without it a mail heirloom would be reported
as unusable for a level-20 shaman and never flagged.

### Two shoulder series

The 429xx shoulders come from the emblem vendors, the 441xx ones from the Argent
Tournament. They are equivalent alternatives for the same slot and both are
handed out, depending on which vendor a character can reach. The exception is
44100 — the only plate shoulder with intellect, and therefore the only one for a
holy paladin.

---

## EGUP — GM heirloom packages

`/egup` sends `.additem` commands for a class-appropriate heirloom package to
your current target. A confirmation dialog appears first
(`EasyGearDB.egupConfirm = false` disables it).

| Class | Items | Class | Items |
| --- | --- | --- | --- |
| Warrior | 11 | Shaman | 17 |
| Paladin | 15 | Rogue | 11 |
| Death Knight | 9 | Druid | 16 |
| Hunter | 12 | Priest | 8 |
| Mage | 6 | Warlock | 6 |

An item is included when the class can **use** it and it is **useful** — an
agility dagger is equippable by a priest but worthless to one. The PvP insignia
are faction bound; the matching one is picked via `UnitFactionGroup` of the
target.

The command template is configurable, because cores differ:

```lua
EasyGearDB.egupCommand = ".additem {name} {id} {count}"
-- TrinityCore applying to the selected target, for example:
EasyGearDB.egupCommand = ".additem {id} {count}"
```

### Verifying item IDs

A wrong item ID does **not** announce itself: the server reports the error, the
player receives nothing, and the package still looks correct. Use:

```
/egup verify           check every stored ID
/egup verify HUNTER    only one class package
/egup list [class]     show a package without sending anything
```

`verify` looks up each ID in the client cache and reports whether it exists,
whether it really is an heirloom (quality 7) and which slot and subtype it
actually has. Fix any deviation directly in `EasyGearHeirlooms.lua` — the file
is separated out for exactly that purpose.

An item that has never been seen in the client is simply uncached and will be
reported as missing even though the ID is correct; viewing it once at a vendor
is enough.

### Cleaning up

`/egupclean` removes the recorded IDs and quantities from the bags, leaves
equipped copies alone and can split partial stacks. The session is stored **per
character** and survives a relog, so cleanup still works later.

---

## Settings

Stored in `EasyGearDB` (account-wide) and `EasyGearCharDB` (per character).

| Key | Default | Meaning |
| --- | --- | --- |
| `ilvlWeight` | `0.5` | points per item level at level 80 |
| `ilvlScaling` | `true` | scale that term with character level |
| `socketValue` | `8` | points per empty socket |
| `minDelta` | `0` | absolute upgrade threshold |
| `minDeltaPercent` | `1` | relative upgrade threshold, in percent |
| `showBagIcons` | `true` | bag markers |
| `showQuestIcons` | `true` | quest reward markers |
| `showTooltip` | `true` | tooltip lines |
| `protectHeirlooms` | `true` | heirloom rules below level 80 |
| `iconSize` | `20` | marker size in pixels |
| `egupCommand` | `.additem {name} {id} {count}` | GM command template |
| `egupConfirm` | `true` | confirmation before EGUP |
| `custom` | `{}` | your own profiles |

Per character: `profile` (profile ID or `AUTO`), `pvp`, window positions and the
last EGUP session.

---

## Known limits

* The score is a heuristic. Hit and expertise caps, set bonuses, procs and
  weapon speed are not modelled.
* Enchants without a numeric value (*Crusader*, *Berserking*) cannot be scored
  and do not contribute.
* Scores run from roughly 0–5 at low level to three digits at 80. The number is
  a relative ranking, not an absolute value — only scores of the same character
  at the same time are comparable.
* Heirloom values are read from the tooltip and are approximations.
* The client cannot tell identical copies of the same item apart, so
  `/egupclean` works from the recorded quantities.
* On heavily customised cores item IDs and the `.additem` syntax may differ.
  Run `/egup verify` first.

---

# EasyGear

Item-Bewertung, Upgrade-Erkennung und Ausrüstungsvergleich für **World of Warcraft 3.3.5a (WotLK)**.

* Interface: `30300`
* Getestet gegen deDE und enUS, Dateien sind reines ASCII (Umlaute als `\195\188`-Escapes) — dadurch encodingunabhängig auf HD-Clients.
* Keine XML-Dateien, reines Lua 5.1.

---

## Installation

```
World of Warcraft/
└── Interface/
    └── AddOns/
        └── EasyGear/
            ├── EasyGear.lua            Kern: Bewertung, Vergleich, Hooks
            ├── EasyGearSpecs.lua       36 Gewichtungsprofile
            ├── EasyGearHeirlooms.lua   Erbstücke und Klassenpakete
            ├── EasyGearGUI.lua         Item-Vergleichsfenster
            ├── EasyGearProfileGUI.lua  Profil-Vergleichsfenster
            └── EasyGear.toc
```

Danach `/reload` oder Client neu starten.

---

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/eg` | öffnet das Vergleichsfenster |
| `/eggui` | dasselbe, expliziter Aufruf |
| `/eg <itemlink>` | ausführliche Auswertung im Chat |
| `/eg <itemID>` | Auswertung über die Item-ID |
| `/egprofile` | Profilübersicht, Vergleich und Editor |
| `/eg profile list` | alle Profile im Chat |
| `/eg profile <id\|auto>` | Profil aktivieren |
| `/eg pvp` | PvP-Modus umschalten |
| `/eg role <auto\|tank\|melee\|ranged\|caster\|heal>` | wählt das erste Profil der Klasse mit dieser Rolle |
| `/eg ilvl <zahl>` | Gewicht der Gegenstandsstufe (auf Stufe 80) |
| `/eg ilvlscale <on\|off>` | Skalierung der Gegenstandsstufe mit der Charakterstufe |
| `/eg mindelta <zahl>` | absoluter Mindestvorsprung für „Verbesserung" |
| `/eg mindeltapct <prozent>` | relativer Mindestvorsprung (Standard 1 %) |
| `/eg icons` / `quest` / `tooltip` / `heirloom` | Anzeigen ein-/ausschalten |
| `/eg scale <0.5–2.0>` | Fenstergröße |
| `/eg status` | aktuelle Einstellungen |
| `/eg reset` | Standardwerte |
| `/egup` | GM: Klassenpaket an das Ziel |
| `/egup list [klasse]` | Paket anzeigen, ohne zu senden |
| `/egup verify [klasse]` | hinterlegte Item-IDs gegen den Client prüfen |
| `/egupclean` | erfasste EGUP-Items aus den Taschen entfernen |

---

## Vergleichsfenster (`/EGGUI`)

* **Links:** das abgelegte Item. Item per Drag & Drop auf das Feld ziehen, oder bei geöffnetem Fenster mit **Shift-Klick** anwählen, oder `/eg <itemlink>`.
* **Rechts:** das aktuell angelegte Gegenstück. Bei Ringen, Schmuck und Einhandwaffen schalten die Reiter oben rechts zwischen beiden Slots um.
* **Beide Seiten** zeigen die vollständige Berechnungsgrundlage: Attribut → Wert → Gewicht → Punkte, plus Basis aus der Gegenstandsstufe, Waffen-DPS und freien Sockeln.
* **Unten:** Ergebnis, Punktedifferenz und Hinweise (Erbstückschutz, Zweihandwaffen-Sonderfall usw.).
* Fenster ist verschiebbar, ESC-schließbar; Position und Skalierung werden pro Charakter gespeichert.

Rechtsklick auf das Ablagefeld leert es. Der Knopf „In den Chat" gibt dieselbe Auswertung als Text aus.

---

## Bewertung

```
Wertung = Gegenstandsstufe × ilvlWeight × (Charakterstufe / 80)
        + Σ (Attribut × Gewicht)
        + Waffen-DPS × Gewicht
        + freie Sockel × socketValue
```

### Warum die Gegenstandsstufe mit der Charakterstufe skaliert

Die Statgewichte sind auf Stufe-80-Größenordnungen kalibriert: dort trägt ein Item
dreistellige Attributwerte, auf Stufe 5 dagegen einstellige. Ein **fester** Punktwert
pro Gegenstandsstufe übertönt deshalb im gesamten Bereich darunter die eigentlichen
Attribute — eine Gegenstandsstufe mehr wog dann schwerer als der sechsfache
Rüstungswert:

```
Ausgefranste Armschienen   ilvl 5, 4 Rüstung    2.50 + 0.08 = 2.58  <- galt als Upgrade
Sehr leichte Kettenarm.    ilvl 4, 25 Rüstung   2.00 + 0.50 = 2.50
```

Mit der Skalierung (Charakterstufe 5, wirksames Gewicht 0.03) und der höheren
Rüstungsgewichtung im Anfängerprofil:

```
Ausgefranste Armschienen   0.16 + 0.24 = 0.40
Sehr leichte Kettenarm.    0.13 + 1.50 = 1.62  <- korrekt bevorzugt
```

Auf Stufe 80 ist der Faktor 1, dort ändert sich nichts. Abschaltbar mit
`/eg ilvlscale off`.

### Schwelle für „Verbesserung"

Ein Vorsprung von 0.1 Punkten bei einer Wertung von 2.5 ist Rauschen. Die Schwelle
ist deshalb absolut **und** relativ: `max(minDelta, minDeltaPercent % des
Vergleichswerts)`, standardmäßig 1 %.

Die Gewichte kommen aus einem **Profil**. Siehe unten.

### Verzauberungen und Sockelsteine

`GetItemStats()` liest nur die Basiswerte aus dem Itemlink. Verzauberungen
stehen in `SpellItemEnchantment.dbc` und tauchen dort **nicht** auf — eine
verzauberte Waffe lieferte damit dieselben Werte wie eine unverzauberte.

Deshalb wird zusätzlich der Tooltip ausgewertet, denn dort steht die
Verzauberung als eigene grüne Zeile. WotLK benutzt zwei Formate, beide werden
erkannt:

```
+55 Ausdauer                                 Primärattribute, Sockelsteine
Ausrüsten: Verbessert Tempowertung um 55.    Wertungen
```

Die Muster werden zur Laufzeit aus den lokalisierten Blizzard-Globals gebaut
(`ITEM_MOD_*_SHORT` und `ITEM_MOD_*`), sind also nicht auf eine Sprache
festgelegt. Sie sind vorne und hinten verankert — sonst würde ein Proc-Text wie
*„Erhöht Eure Angriffskraft um 340 für 10 Sek."* als dauerhafter Wert gezählt.

Zusammengeführt wird über das Maximum aus Basiswert und Tooltipsumme: Der
Tooltip listet Basis, Verzauberung und Steine in getrennten Zeilen, seine Summe
ist also normalerweise der größere Wert. Scheitert das Auslesen einer Zeile,
bleibt der Basiswert erhalten — so kann nichts verlorengehen und nichts doppelt
gezählt werden.

Weitere Vorkehrungen gegen Doppelzählung:

* **Graue Zeilen** werden übersprungen — das sind inaktive Sockel- und Setboni.
* **Ab der Set-Kopfzeile** (`Name (2/5)`) wird abgebrochen, weil Setboni an
  anderen Teilen hängen und sonst mehrfach in die Summe gingen.
* **Rote Zeilen** zählen nicht; sie dienen weiter der Verwendbarkeitsprüfung.

Ob ein Item verzaubert oder gesockelt ist, steht jetzt im Vergleichsfenster und
in der Chat-Ausgabe. Da alle drei Tooltip-Auswertungen (Verwendbarkeit,
Waffen-DPS, Werte) in einem Durchlauf passieren und pro Itemlink
zwischengespeichert werden, ist das trotz des Mehraufwands schneller als vorher.

---

## Profile (`/EGPROFILE`)

36 Profile sind eingebaut: für jede der 10 Klassen jeder Talentbaum, plus eigene
Einträge dort, wo sich die Gewichtung **innerhalb** eines Baums real
unterscheidet — Blut-Tank gegen Blut-DD, Frost beidhändig gegen Zweihand,
Wildheit Katze gegen Bär. Dazu zwei klassenunabhängige: „Levelphase (neutral)"
und „Nur Gegenstandsstufe".

| Klasse | Profile |
| --- | --- |
| Krieger | Waffen (Zweihand), Furor (beidhändig), Schutz (Tank) |
| Paladin | Heilig, Schutz (Tank), Vergeltung |
| Jäger | Tierherrschaft, Treffsicherheit, Überleben |
| Schurke | Meucheln (Dolche), Kampf (Schwerter), Täuschung |
| Priester | Disziplin, Heilig, Schatten |
| Todesritter | Blut (Tank), Blut (Zweihand-DD), Frost (beidhändig), Frost (Zweihand), Frost (Tank), Unheilig |
| Schamane | Elementar, Verstärkung, Wiederherstellung |
| Magier | Arkan, Feuer, Frost |
| Hexenmeister | Gebrechen, Dämonologie, Zerstörung |
| Druide | Gleichgewicht, Wildheit Katze, Wildheit Bär, Wiederherstellung |

Die Unterschiede sind keine Kosmetik. Beispiele: Frost-Todesritter beidhändig
gewichtet Trefferwertung mit 1.40, die Zweihandvariante mit 1.15 — beidhändig
braucht schlicht mehr Treffer. Der Bär gewichtet Rüstung mit 0.10 und hat gar
keine Blockwerte, der Schutzpaladin dagegen Blockwert mit 0.55.

**Auswahl.** Ohne Zutun wird der Talentbaum mit den meisten Punkten erkannt und
das dortige Standardprofil genommen. Wo ein Baum mehrere Profile hat, ist eines
als Standard markiert (Blut → Tank, Wildheit → Katze, Frost-DK → beidhändig);
die Alternativen wählst du im Fenster. Unter 5 gesetzten Talentpunkten greift
„Levelphase (neutral)".

**Fenster (`/EGPROFILE`).** Aufbau wie der Item-Vergleich, nur mit Profilen
statt Items:

```
        Vergleichsprofil                    Aktives Profil
        Schutz (Tank)                       Waffen (Zweihand)

Attribut        Wert  Gewicht  Punkte   Attribut        Wert  Gewicht  Punkte
Ausdauer        1450  x 1.00   1450     Ausdauer        1450  x 0.10    145
Verteidigung     540  x 1.20    648     Verteidigung     540  x 0.00      0
Stärke           980  x 0.55    539     Stärke           980  x 1.00    980
...

Ausrüstungswertung     7755     Ausrüstungswertung     7710
```

Links das gewählte Vergleichsprofil (Klasse und Profil über die beiden
Auswahlfelder oben), rechts immer das **aktuell aktive**. Die Wertespalte ist auf
beiden Seiten identisch — es sind die Summen deiner angelegten Ausrüstung.
Unterschiedlich sind Gewicht und Punkte. Damit siehst du direkt, was deine
aktuelle Ausrüstung unter einem anderen Build wert wäre und welche Attribute die
Punkte tragen.

Beide Seiten benutzen **eine gemeinsame Zeilenliste** (Vereinigung beider
Gewichtssätze), damit dasselbe Attribut links und rechts auf derselben Zeile
steht. Die Punktespalte ist grün, wo diese Seite mehr Punkte holt, und rot, wo
weniger. Mausrad scrollt, falls die Liste länger wird als das Fenster.

Über die Klassenauswahl erreichst du auch die Profile **anderer** Klassen — als
Nachschlagewerk oder als Ausgangspunkt für ein eigenes Profil.

> Ein Vorbehalt, den das Fenster auch selbst anzeigt: Die Gesamtsummen zweier
> Profile sind nur grob vergleichbar, weil die Gewichtssätze zwar auf das
> Primärattribut normiert, aber nicht gegeneinander geeicht sind. Ein höherer
> Gesamtwert heißt **nicht** „dieses Profil ist besser für dich". Aussagekräftig
> ist die Verteilung je Attribut.

Liegt im Item-Vergleichsfenster ein Item, steht unten zusätzlich dessen Wertung
unter beiden Profilen — du siehst also sofort, ob ein Item nur unter dem einen
Build ein Upgrade ist.

**PvP-Modus.** Ein Schalter statt 36 zusätzlicher Profile: Abhärtung bekommt
mindestens 1.00, Ausdauer wird auf das 2,5-fache angehoben. Gilt für das jeweils
aktive Profil.

**Aktivieren.** „A aktivieren" setzt das links gewählte Profil als aktives — die
rechte Seite zieht dann nach.

**Eigene Profile.** „Bearbeiten" macht aus der linken Gewichtsspalte
Eingabefelder; die Punkte und die Summe rechnen live mit, während du tippst, und
rechts steht weiter das aktive Profil als Referenz. Im Bearbeitungsmodus werden
alle Attribute gezeigt, auch die mit Gewicht 0 — so lässt sich ein bisher
ungenutztes ergänzen. Dann entweder „Als neues Profil speichern" (funktioniert
auch ausgehend von einem eingebauten Profil) oder bei einem eigenen Profil
„Speichern" zum Überschreiben. Eigene Profile sind mit `*` markiert, gelten
accountweit und stehen sofort in der Auswahl.

### Questbelohnungen

Unterstützt werden das Blizzard-Questfenster und **Immersion**. Bei Immersion
liegen die Belohnungsknöpfe unter
`ImmersionFrame.TalkBox.Elements.Content.RewardsFrame.Buttons`; erkannt werden
sie an `type == "choice"`, der Auswahlindex steht in `:GetID()`. Klappt man die
Großansicht auf, hängt Immersion dieselben Knopfobjekte in den Inspector um —
das Markierungs-Icon wandert mit, weil es am Knopf hängt.

Gehakt wird `Elements:Display()`, nicht `Elements:ShowRewards()`: Immersion legt
seine Vorlagen als Liste von Funktionsreferenzen an und ruft sie über
`elementsTable[i](self)` auf. Diese Referenz zeigt weiter auf die ursprüngliche
Funktion, ein Hook auf dem Frame würde also nie auslösen. `Display()` dagegen
wird in `Frame:AddQuestInfo()` als echte Methode aufgerufen.

Die Tooltip-Anzeige hängt an `GameTooltip:SetQuestItem` statt an
`OnTooltipSetItem`, weil `GetItem()` bei Questbelohnungen keinen verlässlichen
Link liefert. Das deckt das Sprechfenster beider Oberflächen ab, da Immersion
dort denselben `GameTooltip` benutzt.

**Großansicht (Shift).** Der Shift-Modus zeigt die Belohnungen nicht über die
Knöpfe, sondern über gepoolte Tooltip-Frames (`ImmersionItemTooltipTemplate`),
die in `Frame:SetItemTooltip()` befüllt werden — eigene Frame-Objekte, auf die
der `GameTooltip`-Hook nicht greift. Gehakt wird deshalb `SetItemTooltip` am
`ImmersionFrame`; Immersion hängt seine Methoden per `L.Mixin(L.frame, Frame)`
direkt ans Frame und ruft sie als echte Methode auf. Die empfohlene Belohnung
bekommt dort ein Häkchen und eine zusätzliche Zeile.

Da die Frames aus einem Pool stammen und wiederverwendet werden, setzt EasyGear
seinen Merker und das Häkchen bei jedem Befüllen neu — sonst bliebe die
Empfehlung der vorherigen Quest stehen.


Gewertet wird nach dem **Zugewinn**, nicht nach der absoluten Wertung. Der
Unterschied ist erheblich, wenn ein Slot noch leer ist:

```
Mondweidenfellumhang    Wertung 0.51   angelegt 0.30   Zugewinn +0.21
Mondweidenlederstiefel  Wertung 0.61   angelegt 0.00   Zugewinn +0.61   <- gewählt
```

Ist keine Belohnung ein Upgrade, entscheidet der Gesamtverkaufswert
(Stückpreis × Anzahl).

### Waffenhand und Schildhand

Solange eine Zweihandwaffe geführt wird, ist die Schildhand nicht frei — sie wird
von der Zweihandwaffe belegt. Ein Schild oder Nebenhand-Item anzulegen kostet
also die komplette Zweihandwaffe. Verglichen wird deshalb gegen **Waffenhand
plus Schildhand zusammen**, nicht gegen den scheinbar leeren Slot 17; sonst
gälte jedes beliebige Nebenhand-Item als Verbesserung, weil ein leerer Slot mit
0 Punkten bewertet wird. Ein Erbstück in der Waffenhand schützt in dieser
Konstellation also auch gegen Nebenhand-Vorschläge.

Eine Einhandwaffe geht bei geführter Zweihandwaffe nur in die Waffenhand und
wird auch nur gegen diese gerechnet — beidhändig führen ließe sie sich erst nach
dem Ablegen des Zweihänders.

| Kandidat | angelegt | verglichen gegen |
| --- | --- | --- |
| Schild / Nebenhand | Zweihänder | Waffenhand + Schildhand |
| Schild / Nebenhand | Einhandwaffe | Schildhand |
| Einhandwaffe | Zweihänder | Waffenhand |
| Einhandwaffe | Einhandwaffe + Nebenhand | schwächerer der beiden Slots |
| Zweihandwaffe | beliebig | Waffenhand + Schildhand |

---

## Was sich gegenüber 1.x geändert hat

**Fehlerbehebungen**

* **Todesritter fehlte komplett** — weder Statgewichte noch Waffen-/Rüstungskenntnisse. Jetzt vollständig enthalten.
* **Taschen-Icons saßen auf dem falschen Item.** Die Blizzard-Taschen vergeben die Button-IDs rückwärts; der alte Code benutzte den Schleifenindex als Taschenplatz. Jetzt wird `button:GetID()` verwendet.
* **Timer überschrieben sich gegenseitig.** `PU:After()` teilte sich einen einzigen Frame — jeder neue Aufruf verwarf den laufenden Timer. Das betraf Questanzeige, EGUP-Warteschlange und Aufräumen gleichzeitig. Jetzt laufen beliebig viele Timer parallel.
* **Debug-Ausgaben im Questpfad** (`QUEST BUTTON DEBUG …`) sind entfernt.
* **Belohnungsmenge wurde nie erkannt.** Das Feld `button.count` existiert in 3.3.5a nicht, dadurch war der Verkaufswert von Stapelbelohnungen immer der Einzelpreis. Jetzt über `GetQuestItemInfo("choice", i)`.
* **Rüstungsklassen ohne Stufenprüfung.** Platte ab 40 (Krieger/Paladin), Kette ab 40 (Jäger/Schamane) — vorher galt alles ab Stufe 1 als tragbar.
* **Schamane konnte keine Schilde tragen**, Reliktslots (Buchband, Götze, Totem, Sigelrune) fehlten ganz.
* **Einhandwaffen wurden allen Klassen auf beide Hände gerechnet** — auch Magiern. Beidhändigkeit wird jetzt geprüft.
* **Questbelohnungen wurden nach absoluter Wertung gewählt** statt nach Zugewinn. Ein Item, das einen leeren Slot füllt, verlor damit gegen ein minimal höher bewertetes, das bereits Vorhandenes ersetzt.
* **Zauber- und Heilprofile hatten gar kein Rüstungsgewicht.** Auf niedrigen Stufen, wo Items oft nur Rüstung und sonst nichts tragen, blieb dadurch die Gegenstandsstufe als einziges Unterscheidungsmerkmal.
* **`Äxte` statt `Einhandäxte`** und weitere ungenaue deutsche Untertypnamen; jetzt Token-basiert mit Aliaslisten für deDE und enUS.
* **Fest verdrahtete deutsche Slotnamen** — jetzt über die lokalisierten Blizzard-Globals (`HEADSLOT`, `FINGER0SLOT`, …).
* **`✓` und `✗`** wurden benutzt; diese Zeichen fehlen in `FRIZQT__.TTF` und erscheinen als Kästchen. Ersetzt.
* **Erbstücke:** `GetItemStats()` liefert die ungeskalierten Basiswerte. Die tatsächlichen Werte werden jetzt aus dem Tooltip gelesen.

**Leistung**

* Die Gewichtstabelle und die komplette Klassen-/Untertyp-Matrix wurden bei **jedem** Aufruf neu aufgebaut — also einmal pro Taschenplatz pro Taschenaktualisierung. Jetzt einmalig beim Laden.
* Item-Daten, Wertungen und Verwendbarkeit werden zwischengespeichert; Taschen-Buttons rechnen nur bei Inhalts-, Profil- oder Einstellungsänderung neu.
* Ereignisse werden entprellt statt bei jedem `BAG_UPDATE` alles neu zu berechnen.

**Neu**

* Vergleichsfenster `/EGGUI` mit vollständiger Berechnungsgrundlage auf beiden Seiten.
* Spec-Erkennung über den Talentbaum, plus manuelle Rollenwahl.
* Tooltip-Integration: Wertung, Vergleichswert und Differenz direkt am Item.
* Waffen-DPS und freie Sockel fließen in die Wertung ein.
* Zweihandwaffen werden gegen **Waffenhand + Schildhand zusammen** gerechnet.
* Sprachunabhängige Verwendbarkeitsprüfung über die roten Tooltipzeilen (deckt Klassenbindung, Ruf, Rasse und Beruf ab).
* Bankfächer werden mitmarkiert; gelbe Markierung für „wäre besser, Stufe reicht noch nicht".
* Einstellungen in `EasyGearDB` / `EasyGearCharDB` gespeichert.
* ElvUI-Hook erkennt beide gängigen 3.3.5a-Signaturen von `UpdateSlot`.
* Unterstützung für Immersion (Questbelohnungen und Tooltips).

---

## EGUP (GM-Funktion)

`/egup` schickt `.additem`-Befehle für ein klassenpassendes Erbstückpaket an das anvisierte Ziel.

* Vorher erscheint eine Sicherheitsabfrage (`EasyGearDB.egupConfirm = false` schaltet sie ab).
* Das Befehlsmuster ist konfigurierbar — nützlich, weil Cores unterschiedliche Syntax verwenden:

```lua
EasyGearDB.egupCommand = ".additem {name} {id} {count}"
-- TrinityCore mit Zielauswahl z. B.:
EasyGearDB.egupCommand = ".additem {id} {count}"
```

* Die Sitzung wird **pro Charakter gespeichert** und übersteht ein Relog — `/egupclean` funktioniert also auch später noch.
* `/egupclean` entfernt nur die erfassten IDs und Mengen, lässt angelegte Exemplare in Ruhe und kann jetzt auch Teilstapel auflösen (`SplitContainerItem`).

### Erbstücke

Alle 37 Erbstücke aus 3.3.5a stehen in `EasyGearHeirlooms.lua`: 4 Schmuckstücke
(inklusive beider PvP-Insignien), 13 Schultern, 6 Brustteile und 14 Waffen. Dazu
Ring und Taschen, die keine Erbstücke sind, aber zum Paket gehören.

| Klasse | Teile | Klasse | Teile |
| --- | --- | --- | --- |
| Krieger | 11 | Schamane | 17 |
| Paladin | 15 | Schurke | 11 |
| Todesritter | 9 | Druide | 16 |
| Jäger | 12 | Priester | 8 |
| Magier | 6 | Hexenmeister | 6 |

Ein Stück geht an eine Klasse, wenn sie es **führen kann** und es **sinnvoll**
ist — ein Beweglichkeitsdolch wäre für einen Priester tragbar, aber wertlos. Die
PvP-Insignien sind fraktionsgebunden; vergeben wird die passende, ermittelt über
`UnitFactionGroup` des Ziels.

**Wechselnde Rüstungsklasse.** Erbstück-Rüstung wechselt mit Stufe 40 die Klasse:
Kette gilt darunter als Leder, Platte als Kette. Ein Schamane kann die
Todesbotenbrustplatte also ab Stufe 1 tragen. `EG:CanUseItem` berücksichtigt das
— sonst würde ein Kettenerbstück beim Schamanen unter 40 als „nicht verwendbar"
gelten und nie markiert.

**Zwei Schulterreihen.** Die 429xx-Schultern stammen von den Abzeichen-Händlern,
die 441xx vom Argentumturnier. Sie sind gleichwertige Alternativen für denselben
Platz und werden beide vergeben. Ausnahme ist 44100 — die einzige
Plattenschulter mit Intelligenz und damit die einzige für einen heiligen Paladin.

### Erbstücke im Vergleich

| Kandidat | angelegt | Ergebnis |
| --- | --- | --- |
| normal | Erbstück | verliert immer |
| Erbstück | normal | gewinnt immer |
| Erbstück | Erbstück | ganz normal nach Punkten |

Entscheidend ist die Slot-Genauigkeit: Liegt in Ring 1 ein Erbstück und in Ring 2
ein normaler Ring, wird ein besserer normaler Ring weiterhin für Ring 2
empfohlen. Blockiert wird nur, wenn **alle** infrage kommenden Plätze belegt
sind. Bei „Erbstück schlägt normal" kann die Differenz negativ sein — das Item
ist trotzdem die Empfehlung, weil es mitwächst.

### Item-IDs prüfen

Eine falsche ID fällt bei `.additem` **nicht auf**: Der Server meldet den Fehler,
der Spieler bekommt nichts, und im Paket sieht alles richtig aus.

```
/egup verify           alle IDs prüfen
/egup verify HUNTER    nur ein Klassenpaket
/egup list [klasse]    Paket anzeigen, ohne zu senden
```

`verify` schlägt jede ID im Client-Cache nach und meldet, ob sie existiert, ob es
wirklich ein Erbstück ist (Qualität 7) und welchen Slot und Untertyp sie
tatsächlich hat. Korrekturen gehören in `EasyGearHeirlooms.lua`.

Ein Item, das noch nie im Client zu sehen war, ist schlicht ungecacht und wird
als fehlend gemeldet, obwohl die ID stimmt — einmal beim Händler ansehen genügt.

---

## Bekannte Grenzen

* Verzauberungen ohne Zahlenwert (z. B. *Kreuzfahrer*, *Berserker*) lassen sich nicht bewerten und fließen nicht ein.
* Wertungen liegen auf niedrigen Stufen im Bereich 0–5 und auf Stufe 80 im dreistelligen Bereich. Die Zahl ist eine relative Rangfolge, kein absoluter Wert — vergleichbar sind nur Wertungen desselben Charakters zum selben Zeitpunkt.
* Die Wertung ist eine Heuristik. Trefferwertungs-Obergrenzen, Setboni, Prozeduren und Waffengeschwindigkeit werden nicht bewertet.
* Erbstückwerte stammen aus dem Tooltip und sind Näherungswerte.
* Wie in 1.x kann der Client identische Exemplare desselben Items nicht auseinanderhalten; `/egupclean` arbeitet deshalb mit den erfassten Mengen.
* Bei stark abweichenden Custom-Cores können Item-IDs und die `.additem`-Syntax abweichen.
