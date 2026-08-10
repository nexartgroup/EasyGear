# EasyGear

EasyGear is a lightweight gear evaluation and GM utility addon for **World of Warcraft 3.3.5a**.

It provides gear comparison, heirloom-aware upgrade detection, class-specific heirloom distribution, and cleanup utilities for GM/private-server environments.

> **Target client:** World of Warcraft 3.3.5a
> **Interface:** `30300`

---

## Features

### Gear Evaluation

EasyGear evaluates items and determines whether they are potential upgrades for the player.

Features include:

* Item-level and stat-based scoring.
* Class-specific stat weights.
* Equipped-item comparison.
* Empty-slot detection.
* Multi-slot equipment handling.
* Quest reward comparison.
* Bag upgrade indicators.
* Blizzard Bags support.
* ElvUI Bags support.
* Bagnon support.
* Manual item comparison with `/EG`.

### Heirloom Support

EasyGear recognizes **Quality 7** items as heirlooms.

While a character is below level 80, an equipped Quality 7 heirloom is treated as the best available item for its equipment slot.

For example:

```text
Character level: 50

Equipped:
Quality 7 Heirloom

Bag:
Level 50 Rare
Level 55 Epic
```

The equipped heirloom will continue to be treated as the preferred item.

At level 80, this special heirloom rule is disabled and normal item scoring is used again.

---

# Commands

EasyGear provides three primary commands:

| Command      | Description                                              |
| ------------ | -------------------------------------------------------- |
| `/EG`        | Manually evaluate an item for an upgrade                 |
| `/EGUP`      | Give a targeted player a class-specific heirloom package |
| `/EGUPCLEAN` | Remove EGUP-provided items that remain in the bags       |

---

# `/EG`

The `/EG` command is used to manually compare an item against the player's currently equipped gear.

Usage:

```text
/EG itemlink
```

Example:

```text
/EG |cff0070dd[Example Item]|r
```

EasyGear calculates the item's score and compares it with the relevant equipped slot.

If the item is better:

```text
Upgrade! 1234 > 1100
```

If it is not:

```text
Not upgrade. 1050 1100
```

---

# `/EGUP`

`/EGUP` stands for **EasyGear Upgrade Package**.

It is designed for GM/private-server use and provides a targeted player with an appropriate set of WotLK 3.3.5a heirloom items.

## Usage

First target the player:

```text
/target PlayerName
```

Then run:

```text
/EGUP
```

EasyGear automatically detects the **target player's class**.

It then generates the required `.additem` commands for the configured package.

Example:

```text
EasyGear EGUP
Giving WotLK leveling package to: PlayerName
Class: ROGUE
Portable Hole: 4 x
Package commands: 10
```

---

# Class-Specific Packages

EGUP attempts to provide useful equipment for the target's class instead of simply giving every heirloom.

For example, a Rogue receives appropriate leather and weapon heirlooms rather than plate or mail armor.

## Rogue

The Rogue package can include:

* Leather chest
* Leather shoulders
* Dagger
* Sword
* Additional leveling weapon
* Off-hand dagger
* Trinkets
* Ring
* Portable Holes

Rogues are not intentionally given:

* Plate armor
* Mail armor
* Heavy armor intended for other classes
* Unusable caster equipment

---

## Druid

Druids receive leather equipment and suitable weapons.

The package can contain:

* Leather chest
* Leather shoulders
* Caster/utility weapon
* Trinkets
* Ring
* Portable Holes

---

## Hunter

Hunters receive mail/agility equipment and a suitable ranged weapon.

The package can contain:

* Mail chest
* Mail shoulders
* Bow
* Trinkets
* Ring
* Portable Holes

---

## Shaman

Shamans receive mail equipment and appropriate weapon options.

The package can contain:

* Mail chest
* Mail shoulders
* Melee weapon
* Caster weapon
* Trinkets
* Ring
* Portable Holes

---

## Warrior

Warriors receive plate equipment and suitable melee weapons.

The package can contain:

* Plate chest
* Plate shoulders
* Two-handed weapon
* Additional melee weapons
* Trinkets
* Ring
* Portable Holes

---

## Paladin

Paladins receive plate equipment and appropriate weapons.

The package can contain:

* Plate chest
* Plate shoulders
* Melee weapon
* Caster-compatible weapon
* Trinkets
* Ring
* Portable Holes

---

## Priest

Priests receive cloth equipment and caster weapons.

The package can contain:

* Cloth chest
* Cloth shoulders
* Caster weapon
* Trinkets
* Ring
* Portable Holes

---

## Mage

Mages receive cloth equipment and caster weapons.

The package can contain:

* Cloth chest
* Cloth shoulders
* Caster weapon
* Trinkets
* Ring
* Portable Holes

---

## Warlock

Warlocks receive cloth equipment and caster weapons.

The package can contain:

* Cloth chest
* Cloth shoulders
* Caster weapon
* Trinkets
* Ring
* Portable Holes

---

# Trinkets

Characters have two trinket slots.

EGUP therefore gives two copies of configured trinkets.

For example:

```text
Swift Hand of Justice ×2
Discerning Eye of the Beast ×2
```

This allows the player to have two copies available for the two trinket slots.

If your server has a `Unique-Equipped` restriction on an item, the server may reject the second copy.

---

# Dread Pirate Ring

EGUP also includes:

```text
Dread Pirate Ring
```

The ring is added once.

The item can be customized in the `EGUP_ITEMS` table if your server uses a different item ID.

---

# Portable Hole

EGUP now provides **four Portable Holes**.

Item ID:

```text
51809
```

Configured as:

```lua
BAGS = {
    {
        id = 51809,
        count = 4,
        name = "Portable Hole"
    },
}
```

When `/EGUP` is executed, the addon generates the equivalent of:

```text
.additem PlayerName 51809 4
```

The four Portable Holes are also recorded by the EGUP session tracker so `/EGUPCLEAN` can identify them later.

---

# `/EGUPCLEAN`

`/EGUPCLEAN` cleans up the items that were supplied by the most recent `/EGUP` operation.

Typical workflow:

```text
/target PlayerName
/EGUP
```

The player equips the items they want to keep.

Then:

```text
/EGUPCLEAN
```

EasyGear scans the bags and removes recorded EGUP items that remain there.

## Example

Suppose `/EGUP` gave:

```text
Swift Hand of Justice ×2
Dread Pirate Ring ×1
Portable Hole ×4
Leather Chest ×1
Leather Shoulders ×1
```

The player equips:

```text
Swift Hand of Justice
Dread Pirate Ring
Leather Chest
Leather Shoulders
```

The remaining EGUP items in the bags can then be cleaned up with:

```text
/EGUPCLEAN
```

---

# Cleanup Safety

`/EGUPCLEAN` is designed to avoid deleting equipped items.

It checks the player's equipment slots before removing matching items.

Equipped items are therefore preserved.

The cleanup also only operates on item IDs and quantities recorded by the most recent `/EGUP` session.

It does **not** indiscriminately delete every item in the player's bags.

---

## Important Cleanup Limitation

WoW 3.3.5a does not provide a perfect persistent identity for individual copies of identical items.

For example, if the player already owned:

```text
Portable Hole ×1
```

before `/EGUP`, and `/EGUP` adds:

```text
Portable Hole ×4
```

the client cannot inherently distinguish the old Portable Hole from the four newly added copies.

Therefore, `/EGUPCLEAN` uses the quantities recorded by the current EGUP session and the current bag contents.

For maximum safety, use:

```text
/EGUP
```

on a character before giving them additional copies of the same configured items.

---

# Heirloom Quality 7 Rule

WotLK heirlooms use item quality:

```text
7
```

EasyGear detects this with the item's quality value.

For characters below level 80:

```lua
item.quality == 7
```

is treated as an equipped best-in-slot item.

This prevents normal leveling equipment from being considered an upgrade over an equipped heirloom.

### Example

At level 30:

```text
Equipped:
Heirloom chest — Quality 7

Bag:
Level 30 Rare chest
Level 32 Rare chest
```

The heirloom remains preferred.

At level 80:

```text
Character level = 80
```

the special heirloom rule is disabled.

The addon then evaluates the item normally using its level and stats.

---

# Item Scoring

EasyGear uses class-specific stat weights to calculate an item's score.

A simplified score is:

```text
Item Level × 2
+
weighted stats
```

Different classes use different weights.

For example, a Rogue favors:

* Agility
* Attack Power
* Hit
* Expertise
* Critical Strike
* Haste

A Mage favors:

* Intellect
* Spell Power
* Hit
* Haste
* Critical Strike

The system can be customized directly in `EasyGear.lua`.

---

# Equipment Slots

EasyGear supports items that can occupy multiple slots.

Examples include:

* Rings
* Trinkets
* One-handed weapons

For example, a trinket can be compared against either:

```text
Trinket 1
```

or:

```text
Trinket 2
```

The addon considers the appropriate available equipment slot when determining whether an item is an upgrade.

---

# EGUP Item Configuration

The EGUP database is contained in:

```lua
local EGUP_ITEMS = {
    ...
}
```

This is the main section to modify if your server uses custom item IDs.

Example:

```lua
MY_WEAPON = {
    id = 12345,
    count = 1,
    name = "My Custom Heirloom"
}
```

The item can then be added to a class package.

---

# Changing Portable Holes

The Portable Hole configuration is:

```lua
BAGS = {
    {
        id = 51809,
        count = 4,
        name = "Portable Hole"
    },
}
```

To give a different number:

```lua
count = 2
```

To use a different item:

```lua
id = 12345
```

---

# Adding Items to a Class

To add an item to a package, first define it in `EGUP_ITEMS`.

Example:

```lua
MY_ITEM = {
    id = 12345,
    count = 1,
    name = "My Heirloom"
}
```

Then add it to the relevant class:

```lua
elseif class == "ROGUE" then

    Add(EGUP_ITEMS.MY_ITEM)

end
```

---

# GM Requirements

EGUP relies on the server accepting GM commands equivalent to:

```text
.additem PlayerName ItemID Count
```

The GM/player account therefore needs the appropriate server security level.

The addon does not modify the server database directly.

It sends the appropriate GM command through the WoW client.

---

# Server Compatibility

EasyGear is intended for:

* World of Warcraft 3.3.5a
* TrinityCore-style servers
* AzerothCore-style 3.3.5a environments
* Other compatible private-server cores

Exact behavior depends on the server implementation.

In particular, item IDs may differ on custom servers.

---

# Custom Item IDs

If your server has modified item templates, replace the IDs in:

```lua
EGUP_ITEMS
```

with the IDs used by your server.

The default configuration is designed around WotLK 3.3.5a item IDs.

---

# Installation

Place the addon in:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── EasyGear/
```

The addon should contain:

```text
EasyGear/
├── EasyGear.lua
├── EasyGear.toc
└── README.md
```

After installation, restart WoW or run:

```text
/reload
```

---

# Recommended Usage

For a new leveling character:

### 1. Target the character

```text
/target PlayerName
```

### 2. Give the package

```text
/EGUP
```

### 3. Equip the desired heirlooms

The addon currently gives the items to the inventory. It does not automatically equip them.

### 4. Clean up unused EGUP items

```text
/EGUPCLEAN
```

This removes applicable EGUP items that remain in the bags while preserving equipped items.

---

# Commands Summary

```text
/EG itemlink
```

Manually checks an item for an upgrade.

```text
/EGUP
```

Gives the targeted player the appropriate class-specific heirloom package.

```text
/EGUPCLEAN
```

Cleans up recorded EGUP items remaining in the bags after the player equips the desired gear.

---

# Project Structure

```text
EasyGear/
├── EasyGear.lua
├── EasyGear.toc
└── README.md
```

## EasyGear.lua

Contains:

* Gear scoring
* Class stat weights
* Heirloom detection
* Level-80 heirloom handling
* Equipment slot detection
* Upgrade comparison
* Quest reward evaluation
* Bag upgrade indicators
* Blizzard Bags integration
* ElvUI integration
* Bagnon integration
* `/EG`
* `/EGUP`
* `/EGUPCLEAN`
* Class-specific heirloom packages
* Portable Hole distribution
* EGUP session tracking
* Bag cleanup

## EasyGear.toc

Contains the WoW addon manifest and interface information.

---

# Development

EasyGear is written in Lua for the WoW 3.3.5a API.

Repository:

[EasyGear on GitHub](https://github.com/nexartgroup/EasyGear?utm_source=chatgpt.com)

After changing Lua code:

```text
/reload
```

For major changes, restarting the WoW client is recommended.

---

# License

No explicit open-source license is currently specified in the repository.

If redistributing modified versions of EasyGear, check with the repository owner regarding applicable licensing terms.

---

# Credits

EasyGear is designed as a lightweight gear evaluation and GM utility addon for WoW 3.3.5a private-server environments.

The project combines:

* Gear evaluation
* Heirloom-aware leveling recommendations
* Class-specific heirloom distribution
* Portable Hole distribution
* GM convenience commands
* Post-distribution cleanup

**EasyGear — gear evaluation and class-aware heirloom management for WoW 3.3.5a.**
