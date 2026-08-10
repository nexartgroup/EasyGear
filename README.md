# EasyGear

EasyGear is a lightweight gear evaluation and GM utility addon for **World of Warcraft 3.3.5a**.

It provides two main features:

1. **Gear evaluation** — identifies potential upgrades based on class-specific stat weights.
2. **EGUP** — gives a targeted player a class-appropriate collection of WotLK heirloom items through GM `.additem` commands.

> **Target client:** World of Warcraft 3.3.5a
> **Interface:** `30300`

---

## Features

### Gear Evaluation

* Calculates item scores from item level and stats.
* Uses class-specific stat weights.
* Compares items against currently equipped gear.
* Handles equipment with multiple possible slots.
* Detects empty equipment slots.
* Supports quest reward comparison.
* Supports Blizzard Bags.
* Supports ElvUI Bags.
* Supports Bagnon.
* Provides the `/eg` manual comparison command.

### Heirloom Handling

EasyGear recognizes **Quality 7** items as Heirlooms.

While the character is below level 80:

```lua
itemQuality == 7
```

is treated as an equipped best-in-slot heirloom.

Consequently, a normal leveling item will not be recommended as an upgrade over an equipped heirloom.

At level 80, this special behavior stops and heirlooms are evaluated normally according to their item level and stats.

---

# EGUP

## What is EGUP?

**EGUP** stands for **EasyGear Upgrade Package**.

It is a GM convenience command designed for WotLK 3.3.5a private servers.

A GM targets a player and enters:

```text
/EGUP
```

EasyGear then:

1. Detects the selected player's class.
2. Builds the appropriate heirloom package.
3. Adds the appropriate WotLK heirlooms to the player.
4. Adds two copies of dual-slot trinkets.
5. Adds the Dread Pirate Ring.
6. Adds class-appropriate armor.
7. Adds appropriate weapons.
8. Avoids giving armor types that are inappropriate for the class.

The command is intended for servers where `.additem` is available to the GM.

---

## Basic Usage

Target the player who should receive the heirlooms:

```text
Target: ExamplePlayer
```

Then type:

```text
/EGUP
```

EasyGear detects the target's class automatically.

Example:

```text
EasyGear EGUP
Giving WotLK heirlooms to: ExamplePlayer
Class: ROGUE
Items: 10
```

The addon then processes the required `.additem` commands with a short delay between commands.

---

# Class Selection

EGUP uses the **target player's class**, not the GM's class.

For example:

```lua
local _, class = UnitClass("target")
```

This means a GM can target any player and use:

```text
/EGUP
```

without changing their own character.

---

# Rogue Example

For a Rogue, EGUP prioritizes **leather armor and Rogue-compatible weapons**.

The package includes leather chest and shoulders, appropriate daggers/swords, and leveling weapons.

It does **not** intentionally give the Rogue:

* Plate armor
* Mail armor
* Heavy armor intended for Warriors/Paladins
* Unusable caster equipment

The Rogue package can contain:

```text
Stained Shadowcraft Tunic
Stained Shadowcraft Spaulders
Balanced Heartseeker
Venerable Dal'Rend's Sacred Charge
Battleworn Thrash Blade
Sharpened Scarlet Kris
```

along with the common trinkets and ring.

---

# Trinkets

Characters have two trinket slots.

EGUP therefore adds two copies of each configured leveling trinket.

For example:

```text
Swift Hand of Justice ×2
Discerning Eye of the Beast ×2
```

This allows both trinket slots to be filled when the item is not prevented by server-side uniqueness restrictions.

If your server treats a particular trinket as unique-equipped, the server may reject the second copy.

---

# Ring

EGUP also adds:

```text
Dread Pirate Ring
```

The ring is added once because it is intended to occupy a single unique-equipped ring slot.

The character can obtain additional rings through other server-specific methods if required.

---

# Armor Selection

EGUP attempts to keep armor appropriate to the target's class.

## Cloth

Cloth packages are used for:

* Priest
* Mage
* Warlock

The package contains the relevant cloth heirloom chest and shoulder items.

## Leather

Leather packages are used for:

* Rogue
* Druid

Rogues receive the physical/leather leveling package.

Druids can receive leather caster and physical leveling equipment where appropriate.

## Mail

Mail packages are used for:

* Hunter
* Shaman

Hunters receive physical/agility-oriented equipment.

Shamans can receive physical and caster-compatible weapon options.

## Plate

Plate packages are used for:

* Warrior
* Paladin

These classes receive the appropriate plate chest and shoulder heirlooms plus suitable weapons.

---

# Weapon Selection

Weapon selection is class dependent.

Examples include:

### Rogue

```text
Daggers
Swords
Off-hand weapons
```

### Hunter

```text
Ranged weapon
```

### Priest / Mage / Warlock

```text
Caster weapon
```

### Warrior / Paladin

```text
Two-handed / melee weapon
```

### Shaman

```text
One-handed melee/caster-compatible weapons
```

The current implementation is designed as a practical heirloom distribution package rather than a full combat simulator.

---

# GM Command Compatibility

EGUP generates commands equivalent to:

```text
.additem PlayerName ItemID Count
```

For example:

```text
.additem ExamplePlayer 42991 2
```

The addon sends these commands through the player's normal chat connection.

Your server must allow the GM to use `.additem`.

Typical TrinityCore/AzerothCore-style servers require an appropriate GM/security level.

If your server does not allow addon-generated GM commands, the commands will need to be executed manually through the server's GM command interface.

---

# Important Server Difference

The exact heirloom item IDs can differ on custom/private servers.

The IDs included in `EasyGear.lua` are intended for the standard **WotLK 3.3.5a heirloom item database**.

If your server has:

* Custom item IDs
* Modified heirlooms
* Custom vendors
* Different item templates
* Replaced heirloom items

you should change the IDs in:

```lua
EGUP_ITEMS
```

For example:

```lua
ROGUE = {
    CHEST = {
        id = 48689,
        count = 1
    }
}
```

---

# Configuration

The EGUP item database is located near the bottom of `EasyGear.lua`:

```lua
local EGUP_ITEMS = {
    ...
}
```

This table controls what items are given to each class.

You can change:

```lua
id
```

to the item entry used by your server.

You can also change:

```lua
count
```

to control how many copies are added.

Example:

```lua
{
    id = 42991,
    count = 2,
    name = "Swift Hand of Justice"
}
```

means:

```text
Item ID: 42991
Amount: 2
```

---

# Adding Another Heirloom

To add an item to a class package, first define it in `EGUP_ITEMS`.

Example:

```lua
MY_WEAPON = {
    id = 12345,
    count = 1,
    name = "My Heirloom Weapon"
}
```

Then add it to the desired class:

```lua
elseif class == "ROGUE" then

    Add(EGUP_ITEMS.MY_WEAPON)
```

When `/EGUP` is used on a Rogue, the item will then be added.

---

# `/eg`

EasyGear also provides the original manual comparison command:

```text
/eg itemlink
```

Example:

```text
/eg |cff0070dd[Example Item]|r
```

EasyGear compares the item with the currently equipped gear.

If it is better:

```text
Upgrade! 1234 > 1100
```

If it is not:

```text
Not upgrade. 1050 1100
```

---

# Heirloom Upgrade Rule

EasyGear has a special rule for equipped heirlooms.

If:

```lua
Quality == 7
```

and:

```lua
UnitLevel("player") < 80
```

then the equipped heirloom is treated as the best item for that slot.

Therefore:

```text
Level 50

Equipped:
Quality 7 Heirloom

Bag:
Level 50 Rare

Result:
Heirloom remains preferred
```

This prevents leveling characters from receiving upgrade warnings for ordinary gear that would replace their heirlooms.

At:

```text
Level 80
```

the special rule is disabled.

The addon returns to normal item-score comparison.

---

# Multi-Slot Equipment

EasyGear accounts for equipment types that can occupy multiple slots.

Examples:

```text
Ring
Trinket
One-handed weapon
```

For these items, EasyGear compares the candidate against the appropriate equipped slots.

An empty slot is treated as an available upgrade opportunity.

An equipped heirloom in one slot does not automatically prevent a suitable item from being considered for the other slot.

---

# Installation

Copy the addon directory into:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── EasyGear/
```

The directory should contain:

```text
EasyGear/
├── EasyGear.lua
├── EasyGear.toc
└── README.md
```

Restart WoW or reload the interface:

```text
/reload
```

---

# Commands

| Command         | Description                                                             |
| --------------- | ----------------------------------------------------------------------- |
| `/EGUP`         | Give the targeted player the configured class-specific heirloom package |
| `/eg itemlink` | Manually compare an item against equipped gear                          |

---

# Recommended EGUP Workflow

For a GM leveling a new character:

### 1. Target the character

```text
/target PlayerName
```

### 2. Run:

```text
/EGUP
```

### 3. Verify the inventory

The player should receive the configured heirloom package.

### 4. Equip the items

The addon currently **gives the items to the inventory**; it does not automatically equip them.

This is intentional because `/EGUP` is a distribution command rather than an equipment automation command.

---

# Limitations

EGUP does not currently:

* Purchase heirlooms from vendors.
* Automatically create missing heirlooms.
* Automatically equip the distributed items.
* Determine which specialization the player intends to use.
* Simulate DPS/healing performance.
* Verify that a custom server uses the standard WotLK item IDs.
* Bypass server-side item restrictions.
* Bypass unique-equipped restrictions.
* Modify the server database.

It simply generates the appropriate `.additem` commands for the configured class package.

---

# Supported Classes

EasyGear supports:

* Warrior
* Paladin
* Hunter
* Rogue
* Priest
* Mage
* Warlock
* Druid
* Shaman

---

# Project Structure

```text
EasyGear/
├── EasyGear.lua
├── EasyGear.toc
└── README.md
```

### EasyGear.lua

Contains:

* Item scoring
* Class stat weights
* Heirloom detection
* Level-80 heirloom handling
* Equipment slot detection
* Upgrade comparison
* Quest reward recommendations
* Bag indicators
* Blizzard bag integration
* ElvUI integration
* Bagnon integration
* `/eg`
* `/EGUP`
* Class-specific heirloom packages
* GM `.additem` command generation

### EasyGear.toc

Contains the WoW addon manifest and interface metadata.

---

# Development

EasyGear is written in Lua for the WoW 3.3.5a API.

Repository:

[EasyGear on GitHub](https://github.com/nexartgroup/EasyGear?utm_source=chatgpt.com)

After changing Lua code, reload the interface:

```text
/reload
```

For larger changes, restarting the WoW client is recommended.

---

# Customizing EGUP

The most important section for server administrators is:

```lua
local EGUP_ITEMS = {
```

This is where the heirloom item IDs and quantities are defined.

For a custom server, replace the standard item IDs with the IDs from your server database.

The class-selection logic can also be modified to provide different packages.

For example:

```lua
elseif class == "ROGUE" then

    Add(EGUP_ITEMS.LEATHER_AGI.CHEST)
    Add(EGUP_ITEMS.LEATHER_AGI.SHOULDERS)
    Add(EGUP_ITEMS.LEATHER_AGI.DAGGER)
    Add(EGUP_ITEMS.LEATHER_AGI.SWORD)
```

This makes it straightforward to customize the Rogue package.

---

# License

No explicit open-source license is currently specified in the repository.

If redistributing modified versions of EasyGear, check with the repository owner regarding applicable licensing terms.

---

# Credits

EasyGear was created as a lightweight gear recommendation and GM utility addon for WoW 3.3.5a private-server environments.

The EGUP system extends the addon with a convenient class-aware heirloom distribution system.

---

**EasyGear — gear evaluation and class-aware heirloom distribution for WoW 3.3.5a.**