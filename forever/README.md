# EasyGear for WoW Forever

Gear scoring, upgrade detection and item comparison for **World of Warcraft Forever**.

EasyGear tells you whether an item is actually better than what you are wearing - using stat
weights for **your talents, your level and the rest of your equipment**, not item level alone -
and puts the answer where you look at items: bags, bank, vendors, loot, rolls, quest rewards,
trade, mail, the character window and every item tooltip.

It **only compares and recommends**. It does not equip anything, send commands, create items or
need any other addon: it is built on the default Forever interface and nothing else.

* Interface `16001`, Lua 5.1, no XML files
* Settings page in *Options > AddOns*, entry in the minimap addon compartment, comparison window and
  profile window in the standard frame style
* Texts in English and German; other client languages are partly translated and fall back to English

[Deutsche Version weiter unten](#easygear-für-wow-forever-deutsch)

> **Status.** This edition was written against the source of the Forever user interface (1.60.1) and
> checked offline: static checks against that source and unit tests on a model of the client (see
> [Verification](#verification)). **It has not been run in the game yet.** The stat weights are
> estimates (see [Known limits](#known-limits)). If something looks wrong, `/eg status` and
> `/eg parse` show what the addon sees.

---

## Contents

- [Installation](#installation)
- [What you see](#what-you-see)
- [Commands](#commands)
- [Scoring](#scoring)
- [Profiles](#profiles)
- [Slots, weapons, rings](#slots-weapons-rings)
- [Settings](#settings)
- [Troubleshooting](#troubleshooting)
- [Verification](#verification)
- [Known limits](#known-limits)
- [The 3.3.5a edition](#the-335a-edition)
- [Changes in 4.0.0](#changes-in-400)

---

## Installation

Copy the folder `EasyGear` (the one that contains `EasyGear.toc`) into the `Interface/AddOns` folder of
your WoW Forever installation, so that you end up with `.../Interface/AddOns/EasyGear/EasyGear.toc`.
Restart the game or `/reload`. Saved settings are `EasyGearDB` (account) and `EasyGearCharDB` (character).

At login the chat shows `EasyGear 4.0.0 loaded.`

## What you see

| Where | What |
|---|---|
| Bags, bank | green **arrow** at the top left of an item that is better than what you wear |
| Vendors, loot windows, loot rolls, trade (their items), mail attachments | the same arrow |
| Quest rewards | the arrow, and a green **check mark** on the best choice when there are several (the largest upgrade, otherwise the highest vendor price) |
| Character window | an arrow on an equipment slot when something better for that slot is in your bags |
| Item tooltips | `EasyGear  Score: 81` - the slot and score of the item you would replace, the verdict (`UPGRADE +37 (+83.1%)`, `NO UPGRADE`, `NOT USABLE`, `UPGRADE from level 45`) and the attribute differences |
| Worn items, compare tooltips | only the score (comparing an item with itself is pointless) |

A **yellow** arrow means: it would be an upgrade, but your level is too low for it yet.
Items the client marks as unusable for you (wrong armor type, class) never get an arrow.

**Comparison window** (`/eg`, `/eggui`, or the addon-compartment entry): drag an item onto the
left slot, shift-click an item while the window is open, or type `/eg <item link>`. It shows the
full calculation of both items - attribute, value, weight, points - and the verdict. Rings, trinkets
and one-hand weapons get a tab for each slot.

**Profile window** (`/egprofile`): the weighting profile of your choice on the left, your active profile
on the right, both applied to the gear you are wearing. See [Profiles](#profiles).

## Commands

`/eg` or `/easygear`; `/eggui` opens the window, `/egprofile` the profile window.

| Command | Does |
|---|---|
| `/eg` | open or close the comparison window |
| `/eg <item link or item ID>` | report in chat and in the window |
| `/eg upgrades` | list every upgrade in your bags (and the open bank), best first |
| `/eg profile list` / `/eg profile <id>` / `/eg profile auto` | list, choose, or detect automatically |
| `/eg weight <stat> <value>` | set a weight in your active *own* profile (`/eg weight CRIT 0.8`) |
| `/eg autolevel [on\|off]` | below the maximum level use the Leveling profile of your class |
| `/eg enchants [on\|off]` | count enchants, gems and active socket bonuses |
| `/eg socket <0-1000\|auto>` | points per empty socket (auto: from level and profile) |
| `/eg ilvl <0-2>` / `/eg ilvlscale [on\|off]` | item level weight / scale it with your level |
| `/eg mindelta <0-1000>` / `/eg mindeltapct <0-10>` | minimum gain for "upgrade" (absolute points / percent) |
| `/eg icons \| items \| quest \| char \| tooltip \| stats \| diff` | switch marker groups and tooltip parts on or off |
| `/eg options` | open the settings page |
| `/eg scale <0.5-2>` | window scale |
| `/eg status` | profile, detected talent points, settings, state of every interface hook |
| `/eg parse <item link>` | what was read from an item (base values, extras, unknown stats) |
| `/eg unknown` | item stats in your gear and bags that the addon does not know |
| `/eg locale` | language file in use and how much of it is translated |
| `/eg reset` | back to defaults (your own profiles are kept) |

## Scoring

```
score =  item level x item level weight x (character level / maximum level)
       + sum of  (value x weight)    base values + enchant + gems + active socket bonus
       + weapon DPS x weight         (an off-hand weapon counts half)
       + empty sockets x socket value
```

* **Item level weight** 0.5 points per level at the maximum level (`/eg ilvl`). It grows with your
  level so that low-level attributes are not drowned out by the item level (`/eg ilvlscale off`).
* **Weights** come from the profile, normalised so that the main attribute of the profile is 1.00.
* **Values** come from `C_Item.GetItemStats` (language independent) and the tooltip lines (enchants,
  gems, socket bonus, ratings the API does not list). Lines are read with patterns built at run time
  from the client's own strings, so no text of one language is hard-coded.
* **Empty sockets** are worth a typical gem of your level for the main attribute of the profile, minus 10 %.
* **Upgrade** means: the gain is positive *and* at least `max(minimum, percent of the worn item's score)` -
  defaults 0 points and 1 %. Small differences are noise, not upgrades.

Every item is compared per slot: the candidate is "put into" each slot it fits and compared with what
is worn there; the slot with the largest gain wins.

## Profiles

A profile is a set of weights, for example *Arms*, *Protection* or *Holy*. For every one of the nine
classes there is a profile per talent tree, a *Leveling* profile and an *All-round* profile; plus two
general ones (*Leveling (neutral)* and *Item level only*).

**Automatic selection** (default): the tree with the most talent points decides (at least 5 points).
Below the maximum level the *Leveling* profile of your class is used instead - except for tank and
healer trees, whose weights differ too much (`/eg autolevel off` to always use the tree profile).
A tree with two profiles (the Druid's second tree has *Cat* and *Bear*; the Warrior's Fury tree has a dual-wield
and a two-hand variant) is resolved by the role the client reports for the tree (tank, healer), then by the weapons
you carry, otherwise the first profile is used - for that Druid tree this is *Cat*, so choose *Bear* yourself
(`/eg profile DRUID_BEAR`) if the client does not report the tree as a tank tree.
Without talent information the addon uses *All-round* (maximum level) or *Leveling*.

**Custom profiles** are made in the profile window: pick any profile, press *Edit*, change the weights
(decimal comma works), *Save as new profile*. Own profiles can be overwritten, renamed and deleted there.
They are stored for the whole account; the choice of the active profile is stored per character.
Stats the addon does not know can be weighted in a custom profile by their raw name:
`/eg unknown` lists them, `/eg weight ITEM_MOD_xxx_SHORT 0.5` sets the weight.

## Slots, weapons, rings

* Rings and trinkets are compared with both slots; the one that gains most is the target.
* A one-hand weapon may go to the off hand if your character can dual wield *and* the profile wants it
  (tanks, healers and casters only when a weapon is already in the off hand; never while a shield or
  held-in-off-hand item is worn); off-hand weapons count half of their damage.
* A two-hander is compared with main hand plus off hand together; a shield or off-hand item while a
  two-hander is worn is compared with that two-hander.
* Unique items: the second copy replaces the first.
* Shirts and tabards are never compared.

## Settings

*Options > AddOns > EasyGear*: marker groups (bags/bank, vendors/loot/rolls/trade/mail, quest rewards,
character window), tooltip parts, enchants, Leveling profile, item level weight and scaling, minimum
gain, the profile choice and a reset button. Everything takes effect immediately - also when you change
a value by chat command while the page is open.
The addon-compartment entry on the minimap: left click opens the comparison window, right click the settings.

## Troubleshooting

`/eg status` shows the interface hooks the addon installed (`itembuttons`, `merchant`, `rolls`,
`tooltip`, `settings`, `shiftclick`): a red name with a reason means that part of the client interface
was not found and that feature is off. It also prints the detected talent points and the last internal error.
Internal errors are printed once in the chat as `EasyGear[label]: message`.

If an item scores oddly, `/eg parse <item link>` shows the values read from it; `/eg unknown` shows
stats that are read but not scored.

**Reporting a problem:** please include the output of `/eg status` (it names the client version, the
detected talent points and which interface hooks work), plus `/eg parse <item link>` for a wrongly scored item
and the exact text of any Lua error (`/console scriptErrors 1` shows them).

## Verification

Run from this folder (`forever/`):

```
lua5.1 tests/run.lua                 # unit tests on a model of the client (Lua 5.1 only), ~240 checks
python3 tests/mutate.py              # mutation check: breaks the addon in ~140 small ways, the tests must notice
tools/check.sh <Interface/AddOns of the Forever UI source>
                                     # luacheck against a std built from the UI source + checks that every
                                     # method, event, template, font, atlas and global the addon names exists
```

What this proves and what it does not:

* The static checks read the real Forever UI source (the `forever` branch of `Gethe/wow-ui-source`, 1.60.1)
  and apply the load rules of the game type (`[Family]` = Mainline, `[Game]` = Camelot). A function,
  event or template that does not exist there is an error.
* The unit tests run on `tests/wow_mock.lua`, a model of the client that follows the call patterns and
  data shapes of that source. It is written by the same author as the addon: it catches logic errors and
  regressions, not wrong assumptions about the client.
* **Nothing here replaces running the addon in the game.**

## Known limits

* Not run in the real game yet (see Status).
* **Weights are estimates.** They follow the common stat priorities of the classic ratings systems and are
  normalised to the main attribute of each profile. Forever's own itemisation and balance may differ;
  tune the weights in a custom profile.
* The three talent trees are assumed to be in the order the client shows them (tree 1, 2, 3 of the class).
  If automatic detection picks the wrong profile, choose one yourself and check `/eg status`.
* Item effects (procs, on-use, set bonuses) are not scored; stats written as percentages are not parsed.
* Every item gets the item level term, also one without scored stats; an item that adds nothing else
  still has a score of item level x weight.
* Two-handers are always compared with main hand plus off hand together; carrying two two-handers
  (Titan's Grip style) is not modelled.
* Whether you can use an item (class, armor type, reputation, profession) is read from the red lines of its
  tooltip when the addon first looks at the item; it is not re-evaluated when you gain reputation or a skill
  until the next level-up or `/reload`.
* The auction house is not marked; own trade items and sent mail are not marked.
* Heirlooms, gem or enchant recommendations and automatic equipping do not exist by design.
* Texts: English and German are complete; other languages are partly translated (missing texts show in English).

## The 3.3.5a edition

The addon for the old Wrath client (interface 30300, with ElvUI/Bagnon/Immersion support and the GM
heirloom tools) is unchanged in the top-level folder of this repository.
This edition is a new codebase for the Forever client, not an update of that one.

## Changes in 4.0.0

First edition for WoW Forever.

* Default Forever interface only: item button hook (`SetItemButtonQuality`) for bags, bank, loot, quest
  rewards, trade, mail and the character window; vendor and roll hooks; tooltip data processor.
* Settings page through the Settings API, addon compartment entry, windows built from the standard frame
  templates, standard menus (`DropdownButton`) and dialogs (`StaticPopup`).
* Nine classes with a profile per talent tree, Leveling and All-round profiles; talent detection through
  `C_SpecializationInfo` and `C_Traits`.
* Removed from the 3.3.5a edition: GM heirloom packages, heirloom handling, PvP mode, recipe/prospecting/
  milling markers, third-party addon integration.

---
---

# EasyGear für WoW Forever (Deutsch)

Ausrüstungsbewertung, Upgrade-Erkennung und Vergleich für **World of Warcraft Forever**.

EasyGear sagt dir, ob ein Item wirklich besser ist als das, was du trägst - mit Gewichten für **deine
Talente, deine Stufe und den Rest deiner Ausrüstung**, nicht nur nach Gegenstandsstufe - und zeigt die
Antwort dort, wo du Items ansiehst: Taschen, Bank, Händler, Beute, Würfeln, Questbelohnungen, Handel,
Post, Charakterfenster und in jedem Item-Tooltip.

Es **vergleicht und empfiehlt nur**. Es legt nichts an, schickt keine Befehle, erzeugt keine Items und
braucht kein weiteres Addon: es baut allein auf der Standard-Oberfläche von Forever auf.

> **Stand.** Diese Ausgabe wurde gegen den Quelltext der Forever-Oberfläche (1.60.1) geschrieben und
> offline geprüft: statische Prüfungen gegen diesen Quelltext und Tests auf einem Modell des Clients
> (siehe [Prüfung](#prüfung)). **Im Spiel wurde sie noch nicht ausgeführt.** Die Gewichte sind
> Schätzwerte (siehe [Bekannte Grenzen](#bekannte-grenzen)). Wirkt etwas falsch, zeigen `/eg status`
> und `/eg parse`, was das Addon sieht.

## Installation

Den Ordner `EasyGear` (der mit `EasyGear.toc`) in den Ordner `Interface/AddOns` deiner WoW-Forever-
Installation kopieren, sodass `.../Interface/AddOns/EasyGear/EasyGear.toc` entsteht. Spiel neu starten
oder `/reload`. Gespeichert wird in `EasyGearDB` (Konto) und `EasyGearCharDB` (Charakter).

## Was du siehst

| Wo | Was |
|---|---|
| Taschen, Bank | grüner **Pfeil** oben links an einem Item, das besser ist als das Getragene |
| Händler, Beute, Würfelfenster, Handel (Items des Partners), Post-Anhänge | derselbe Pfeil |
| Questbelohnungen | der Pfeil und ein grüner **Haken** an der besten Wahl, wenn es mehrere gibt (größte Verbesserung, sonst höchster Verkaufspreis) |
| Charakterfenster | ein Pfeil am Ausrüstungsplatz, für den in den Taschen etwas Besseres liegt |
| Item-Tooltips | `EasyGear  Wertung: 81` - Platz und Wertung des ersetzten Items, das Urteil (`VERBESSERUNG +37 (+83.1%)`, `KEINE VERBESSERUNG`, `NICHT VERWENDBAR`, `VERBESSERUNG ab Stufe 45`) und die Attribut-Unterschiede |
| Getragene Items, Vergleichs-Tooltips | nur die Wertung |

Ein **gelber** Pfeil heißt: wäre eine Verbesserung, aber deine Stufe reicht noch nicht. Items, die der Client
als unbrauchbar für dich kennzeichnet (falsche Rüstungsart, Klasse), bekommen nie einen Pfeil.

**Vergleichsfenster** (`/eg`, `/eggui` oder der Eintrag im Addon-Fach): ein Item auf das linke Feld ziehen,
bei offenem Fenster mit Umschalt anklicken oder `/eg <Itemlink>` eingeben. Es zeigt die volle Rechnung beider
Items (Attribut, Wert, Gewicht, Punkte) und das Urteil. Ringe, Schmuck und Einhandwaffen haben je einen Reiter
pro Platz.

**Profilfenster** (`/egprofile`): links das gewählte Vergleichsprofil, rechts dein aktives, beide auf die
Ausrüstung angewandt, die du gerade trägst.

## Befehle

`/eg` oder `/easygear`; `/eggui` öffnet das Fenster, `/egprofile` das Profilfenster. Die Befehle sind oben in
der englischen Tabelle aufgeführt und in jeder Sprache gleich; `/eg help` erklärt sie in deiner Sprache.
Wichtig sind `/eg upgrades` (alle Verbesserungen in den Taschen), `/eg profile ...` (Profil wählen),
`/eg weight <Wert> <Gewicht>` (Gewicht im eigenen Profil), `/eg status` (Profil, erkannte Talentpunkte,
Zustand jeder Oberflächen-Anbindung), `/eg parse <Itemlink>` (was aus einem Item gelesen wurde) und
`/eg unknown` (Werte, die das Addon nicht kennt).

## Bewertung

```
Wertung =  Gegenstandsstufe x Stufengewicht x (Charakterstufe / Höchststufe)
         + Summe aus (Wert x Gewicht)       Basiswerte + Verzauberung + Edelsteine + aktiver Sockelbonus
         + Waffen-DPS x Gewicht             (Nebenhand zählt halb)
         + leere Sockel x Sockelwert
```

* **Stufengewicht** 0,5 Punkte je Stufe auf der Höchststufe (`/eg ilvl`); wächst mit deiner Stufe
  (`/eg ilvlscale off` schaltet das ab).
* **Gewichte** stammen aus dem Profil, normiert auf das Hauptattribut des Profils (1,00).
* **Werte** kommen aus `C_Item.GetItemStats` (sprachunabhängig) und den Tooltipzeilen (Verzauberungen, Edelsteine,
  Sockelbonus). Die Zeilen werden mit Mustern gelesen, die zur Laufzeit aus den Texten des Clients gebaut werden.
* **Leere Sockel** zählen wie ein typischer Stein deiner Stufe für das Hauptattribut, minus 10 %.
* **Verbesserung** heißt: der Zugewinn ist positiv *und* mindestens `max(Minimum, Prozent der Wertung des Getragenen)`
  - Standard 0 Punkte und 1 %.

Verglichen wird je Platz: der Kandidat wird in jeden passenden Platz "eingesetzt"; der Platz mit dem größten
Zugewinn gewinnt.

## Profile

Ein Profil ist ein Satz Gewichte, z. B. *Waffen*, *Schutz* oder *Heilig*. Für jede der neun Klassen gibt es ein
Profil je Talentbaum, ein *Leveln*- und ein *Allround*-Profil, dazu zwei klassenunabhängige.

**Automatische Wahl** (Standard): der Talentbaum mit den meisten Punkten entscheidet (mindestens 5 Punkte). Unter der
Höchststufe gilt stattdessen das *Leveln*-Profil deiner Klasse - außer bei Tank- und Heilerbäumen
(`/eg autolevel off`: immer das Baumprofil). Ohne Talentangaben: *Allround* (Höchststufe) bzw. *Leveln*.
Hat ein Baum zwei Profile (der zweite Druidenbaum: *Katze* und *Bär*; der Furor-Baum der Krieger: Zweihand- und
Beidhändig-Variante), entscheidet die Rolle, die der Client für den Baum meldet (Tank, Heiler), dann die getragenen
Waffen, sonst das erste Profil - beim Druidenbaum also *Katze*. Meldet der Client den Baum nicht als Tankbaum,
wähle *Bär* selbst (`/eg profile DRUID_BEAR`).

**Eigene Profile** entstehen im Profilfenster: ein beliebiges Profil wählen, *Bearbeiten*, Gewichte ändern
(Dezimalkomma geht), *Als neues Profil speichern*. Eigene Profile lassen sich dort überschreiben, umbenennen und
löschen; sie gelten für das ganze Konto, das aktive Profil wird je Charakter gemerkt. Unbekannte Werte lassen
sich mit ihrem rohen Namen gewichten: `/eg unknown` listet sie, `/eg weight ITEM_MOD_xxx_SHORT 0.5` setzt das Gewicht.

## Plätze, Waffen, Ringe

Ringe und Schmuck werden mit beiden Plätzen verglichen. Eine Einhandwaffe darf in die Nebenhand, wenn der
Charakter beidhändig kämpfen kann und das Profil es will (Tanks, Heiler, Zauberer nur, wenn dort schon eine
Waffe liegt; nie, solange ein Schild oder Buch in der Nebenhand liegt); Nebenhand-Waffen zählen halb. Eine Zweihandwaffe wird mit Waffen- plus Nebenhand verglichen.
Einzigartige Items: das zweite Exemplar ersetzt das erste. Hemd und Wappenrock werden nie verglichen.

## Einstellungen

*Optionen > AddOns > EasyGear*: Markierungsgruppen, Tooltip-Teile, Verzauberungen, Leveln-Profil, Stufengewicht
und -skalierung, Mindestzugewinn, Profilwahl und ein Zurücksetzen-Knopf. Alles wirkt sofort - auch wenn du einen
Wert per Chatbefehl änderst, während die Seite offen ist.
Der Eintrag im Addon-Fach der Minimap: Linksklick Vergleichsfenster, Rechtsklick Einstellungen.

## Fehlersuche

`/eg status` zeigt die Oberflächen-Anbindungen (`itembuttons`, `merchant`, `rolls`, `tooltip`, `settings`,
`shiftclick`): ein roter Name mit Grund heißt, dass dieser Teil der Client-Oberfläche nicht gefunden wurde und die
Funktion aus ist. Dazu die erkannten Talentpunkte und der letzte interne Fehler. Interne Fehler erscheinen einmalig im Chat als `EasyGear[Name]: Meldung`.

**Fehler melden:** bitte die Ausgabe von `/eg status` mitschicken (Clientversion, erkannte Talentpunkte, welche
Anbindungen funktionieren), bei falsch bewerteten Items `/eg parse <Itemlink>` und den genauen Text eines
Lua-Fehlers (`/console scriptErrors 1` zeigt sie an).

## Prüfung

Im Ordner `forever/`: `lua5.1 tests/run.lua` (Modultests auf einem Modell des Clients), `python3 tests/mutate.py`
(Mutationsprüfung: die Tests müssen künstliche Fehler bemerken), `tools/check.sh <Interface/AddOns des Forever-
Quelltexts>` (luacheck gegen eine aus dem Quelltext gebaute Standardbibliothek; jede Methode, jedes Ereignis, jede
Vorlage, Schrift, jeder Atlas und jede Funktion, die das Addon nennt, muss dort vorkommen).

Das belegt die Form der Aufrufe gegen den echten Quelltext und die Logik auf einem Modell - **es ersetzt keinen Lauf
im Spiel**.

## Bekannte Grenzen

* Im Spiel noch nicht ausgeführt.
* **Die Gewichte sind Schätzwerte** nach den üblichen Prioritäten klassischer Wertungssysteme. Itemisierung und
  Balance von Forever können abweichen; im eigenen Profil nachstellen.
* Die drei Talentbäume werden in der Reihenfolge angenommen, in der der Client sie zeigt. Wählt die Erkennung ein
  falsches Profil, ein Profil selbst wählen und `/eg status` prüfen.
* Item-Effekte (Procs, Benutzen, Setboni) werden nicht bewertet; Prozentangaben in Texten nicht gelesen.
* Jedes Item bekommt den Stufenanteil, auch eines ohne bewertete Werte: es hat dann mindestens Stufe x Gewicht.
* Zweihandwaffen werden immer mit Waffen- plus Nebenhand zusammen verglichen; zwei Zweihänder gleichzeitig
  (Titanengriff-Art) sind nicht abgebildet.
* Ob du ein Item benutzen kannst (Klasse, Rüstungsart, Ruf, Beruf), liest das Addon aus den roten Zeilen des Tooltips,
  wenn es das Item zum ersten Mal ansieht; nach Rufgewinn oder neuer Fertigkeit gilt das erst nach dem nächsten
  Stufenaufstieg oder `/reload`.
* Das Auktionshaus wird nicht markiert. Heirlooms, Edelstein- oder Verzauberungsempfehlungen und automatisches
  Anlegen gibt es absichtlich nicht.
* Texte: Englisch und Deutsch vollständig; andere Sprachen teilweise übersetzt (Fehlendes erscheint englisch).

## Die 3.3.5a-Ausgabe

Das Addon für den alten Wrath-Client (Interface 30300, mit ElvUI/Bagnon/Immersion und den GM-Heirloom-Werkzeugen)
liegt unverändert im Hauptordner dieses Repositories. Diese Ausgabe ist ein neuer Code für den Forever-Client,
keine Aktualisierung jener.
