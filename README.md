# EasyGear

**EasyGear** is a lightweight gear comparison and recommendation addon for **World of Warcraft 3.3.5a**.

It evaluates equipment using class-specific stat weights and helps you quickly identify potential upgrades in your bags and quest rewards. EasyGear also recognizes **Heirloom items (Quality 7)** and protects equipped heirlooms from being considered replaceable until the character reaches level 80.

> **Target client:** World of Warcraft 3.3.5a
> **Interface:** `30300`

## Features

* **Automatic item scoring**

  * Calculates a score from item level and relevant stats.
  * Uses class-specific stat weights.
  * Includes armor weighting for characters at or below level 80.

* **Upgrade detection**

  * Compares items against currently equipped gear.
  * Handles equipment that can occupy multiple slots, such as rings, trinkets, and one-handed weapons.
  * Detects empty equipment slots as potential upgrades.

* **Heirloom protection**

  * Recognizes **Quality 7** items as Heirlooms.
  * An equipped Heirloom is treated as the **best possible item** while the character is below level 80.
  * Normal gear will therefore not be recommended as a replacement for an equipped Heirloom.
  * Once the character reaches level 80, Heirlooms are evaluated using the normal gear score again.

* **Bag upgrade indicators**

  * Displays a green checkmark on items considered upgrades.
  * Supports Blizzard's default bags.
  * Supports ElvUI bags.
  * Supports Bagnon.

* **Quest reward recommendations**

  * Evaluates available quest rewards.
  * Identifies the highest-scoring equippable reward.
  * Marks the recommended reward with a green indicator.

* **Manual item comparison**

  * Allows an item to be manually checked with `/puc`.

## Supported Classes

EasyGear currently provides stat weights for:

* Warrior
* Paladin
* Hunter
* Rogue
* Priest
* Mage
* Warlock
* Druid
* Shaman

The stat weights are defined in `EasyGear.lua` and can be customized to match different gearing priorities or private-server environments.

## Gear Scoring

EasyGear uses a weighted scoring system.

The initial score is based on item level:

```text
Base Score = Item Level × 2
```

Relevant item stats are then added according to the player's class:

```text
Score = (Item Level × 2) + Σ(Stat Value × Stat Weight)
```

For example, if a class has a stat weight of `5` for a particular stat, every point of that stat contributes five points to the item's score.

Only stats present in the class's configured stat-weight table contribute to the score.

### Example

An item with:

```text
Item Level: 100
Spell Power: 20
Haste: 10
```

and weights of:

```text
Spell Power: 8
Haste: 3
```

would receive:

```text
(100 × 2) + (20 × 8) + (10 × 3)
= 200 + 160 + 30
= 390
```

## Heirlooms

EasyGear gives special treatment to **Heirlooms**.

In WoW 3.3.5a, Heirlooms use **item quality 7**. EasyGear detects this quality directly from the item information.

### Before level 80

If an equipped item has:

```text
Quality = 7
```

EasyGear treats it as the best possible item for that equipment slot.

For example:

```text
Equipped:
Heirloom Chest — Quality 7

Bag:
Chest — Score 850
```

The normal chest will **not** be marked as an upgrade, regardless of its calculated score.

This prevents a leveling character from being repeatedly told to replace an heirloom with ordinary leveling equipment.

### At level 80

Once:

```text
Character Level >= 80
```

the special Heirloom protection is disabled.

Heirlooms are then compared using their normal calculated score.

For example:

```text
Level 79:
Heirloom → always preferred

Level 80:
Heirloom → normal score comparison
```

This allows EasyGear to continue functioning normally once the character reaches the maximum level targeted by the addon.

### Rings, Trinkets and One-Handed Weapons

EasyGear also handles items that can occupy more than one equipment slot.

For example, if a character has:

```text
Ring Slot 1: Heirloom
Ring Slot 2: Normal Ring
```

a new ring can still be considered an upgrade if it is better than the **replaceable normal ring**.

The heirloom protection applies to the equipped heirloom slot rather than preventing all upgrades of that item category.

## Installation

1. Download the repository.
2. Place the `EasyGear` folder into your World of Warcraft `Interface/AddOns` directory.

The resulting structure should look like:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── EasyGear/
            ├── EasyGear.lua
            ├── EasyGear.toc
            └── README.md
```

3. Start World of Warcraft.
4. Open the **AddOns** menu at character selection.
5. Enable **EasyGear**.
6. Enter the game.

EasyGear initializes when the player enters the world.

## Usage

### Bag upgrades

Open your bags and EasyGear automatically evaluates equippable items.

Items considered upgrades receive a green checkmark.

Supported bag interfaces include:

* Blizzard Bags
* ElvUI Bags
* Bagnon

EasyGear selects the appropriate integration based on which supported addon is loaded.

### Quest rewards

When a quest offers multiple item rewards, EasyGear evaluates the available choices.

The highest-scoring equippable reward receives a green checkmark.

This can make it easier to choose between several quest rewards without manually comparing every item.

### Manual comparison

Use:

```text
/puc itemlink
```

to manually compare an item against your currently equipped gear.

For an upgrade, EasyGear reports:

```text
Upgrade! 1234 > 1100
```

For an item that isn't an upgrade:

```text
Not upgrade. 1050 1100
```

## Integrations

### Blizzard Bags

EasyGear supports the default Blizzard bag interface.

When no supported third-party bag addon is detected, EasyGear hooks into the Blizzard container frames and adds its upgrade indicators.

### ElvUI

EasyGear detects ElvUI and hooks into its Bags module.

When enabled, EasyGear displays:

```text
EasyGear: ElvUI bag support enabled.
```

Upgrade indicators are then updated as ElvUI bag slots refresh.

### Bagnon

EasyGear can also integrate with Bagnon through its `ItemSlot` implementation.

When detected, EasyGear displays:

```text
EasyGear: Bagnon support enabled.
```

## Customizing Stat Weights

Stat weights are defined in:

```lua
function PU:GetStatWeights()
```

Each class has its own table.

For example:

```lua
MAGE = {
    ITEM_MOD_INTELLECT_SHORT = 10,
    ITEM_MOD_STAMINA_SHORT = 4,
    ITEM_MOD_HASTE_RATING_SHORT = 3,
    ITEM_MOD_CRIT_RATING_SHORT = 3,
    ITEM_MOD_SPELL_POWER_SHORT = 8,
    ITEM_MOD_HIT_RATING_SHORT = 5,
},
```

The values can be changed to adjust how EasyGear evaluates gear.

### Important

Changing stat weights directly changes upgrade recommendations.

The included values should therefore be considered a baseline rather than mathematically optimal values for every specialization, server, or encounter.

## Limitations

EasyGear is intentionally a simple gear-scoring addon rather than a full character simulator.

It does not currently model:

* Talent specialization
* DPS or healing rotations
* Set bonuses
* Gem bonuses
* Enchantments
* Item procs
* On-use effects
* Encounter-specific stat priorities
* Detailed stat caps
* Character-specific optimization
* Full simulation-based gear evaluation

The Heirloom rule is also intentionally simple:

> **Quality 7 equipped item = best item until level 80.**

This is designed specifically for leveling convenience.

## Private Server Compatibility

EasyGear targets the **World of Warcraft 3.3.5a** API.

Private servers that modify item data, localization, item types, equipment slots, or API behavior may require adjustments to the addon.

In particular, the class equipment compatibility tables use item subtype strings and may need to be changed for servers using different localization or custom item types.

## Debugging

EasyGear includes an internal item debugging function:

```lua
EasyGear:DebugItem(itemLink)
```

It outputs information about an item, including:

* Item link
* Item level
* Item quality
* Equipment location
* Detected item stats

This is useful when troubleshooting unusual items or adapting EasyGear for a custom server.

## Development

EasyGear is written entirely in Lua and does not require a build system or external dependencies.

Clone the repository:

```bash
git clone https://github.com/nexartgroup/EasyGear.git
```

Then place the addon directory in:

```text
Interface/AddOns/
```

After making changes, reload the WoW UI with:

```text
/reload
```

## Project Structure

```text
EasyGear/
├── EasyGear.lua    # Main addon implementation
├── EasyGear.toc    # WoW addon manifest
└── README.md       # Documentation
```

### `EasyGear.lua`

Contains:

* Class stat weights
* Item information extraction
* Item scoring
* Item quality detection
* Heirloom handling
* Equipment compatibility checks
* Equipment-slot detection
* Upgrade comparison
* Quest reward comparison
* Bag upgrade indicators
* Blizzard bag integration
* ElvUI integration
* Bagnon integration
* `/puc` command
* Addon initialization

### `EasyGear.toc`

Contains the addon metadata and declares the WoW interface version and Lua file used by EasyGear.

## Compatibility

| Component        | Support                      |
| ---------------- | ---------------------------- |
| WoW 3.3.5a       | ✅ Target                     |
| Interface 30300  | ✅                            |
| Blizzard Bags    | ✅                            |
| ElvUI Bags       | ✅                            |
| Bagnon           | ✅                            |
| Other bag addons | ❌ Not specifically supported |
| WoW Retail       | ❌ Not supported              |

## Contributing

Contributions and improvements are welcome.

Potential areas for improvement include:

* Specialization-specific stat weights
* Better stat-cap handling
* More accurate class profiles
* Set-bonus evaluation
* Gem and enchant evaluation
* Additional bag integrations
* Localization
* Configuration UI
* More advanced gear comparison
* Improved custom-server compatibility

When changing the scoring system, test several equipment types and equipment slots to ensure that the upgrade indicators continue to behave correctly.

## License

The repository currently does not contain an explicit open-source license.

If you intend to redistribute or publish modified versions of EasyGear, contact the repository owner regarding the applicable licensing terms.

## Repository

[EasyGear on GitHub](https://github.com/nexartgroup/EasyGear?utm_source=chatgpt.com)

---

**EasyGear** — simple, fast gear recommendations for WoW 3.3.5a.