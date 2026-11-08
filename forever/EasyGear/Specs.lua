--[[---------------------------------------------------------------------------
    Specs.lua - Gewichtungsprofile der neun Klassen von WoW Forever

    Je Klasse gibt es:

      * ein Profil je Talentbaum (tab = 1..3, in der Reihenfolge, in der der Client die drei
        Baeume zeigt); wo sich die Gewichtung innerhalb eines Baums real unterscheidet
        (Druide: Katze gegen Baer), steht ein eigenes Profil
      * <KLASSE>_LEVELING   fuer alle Stufen unter der Hoechststufe: Ausdauer und Ruestung
                            zaehlen mehr, Wertungen (Treffer, Tempo, ...) kaum
      * <KLASSE>_ALLROUND   deckt alle Baeume der Klasse maessig ab, fuer Hybrid-Ausruestung
                            und eine zweite Spezialisierung

    Dazu zwei klassenunabhaengige Profile (LEVELING und ILVL_ONLY).

    Felder eines Eintrags:
      id        eindeutiger Schluessel (wird gespeichert)
      tab       Talentbaum-Index fuer die automatische Erkennung
      auto      true = Standardwahl, wenn dieser Baum erkannt wird
      hands     "2H" | "DW" - Waffenhaltung, nach der die Erkennung zwischen mehreren Profilen
                desselben Baums waehlt
      role      TANK | MELEE | RANGED | CASTER | HEAL (entscheidet auch, ob eine Einhandwaffe in die
                Nebenhand darf: Tanks, Heiler und Zauberer tragen dort Schild oder Halteitem)
      variants  [Talentbaum] = { w = {...} } - abweichende Gewichte je dominantem Talentbaum
                (nur Leveln-Profile der Hybridklassen)
      w         Gewichte in Kurzform, Schluessel siehe Stats.lua

    Namen und Beschreibungen stehen in Locales/*.lua unter SPEC_<id> und SPEC_<id>_D.

    Die Gewichte sind auf das Hauptattribut des Profils (1.00) normiert. Sie sind Richtwerte,
    keine Simulation: sie lehnen sich an die gaengigen Wertungen aus Burning Crusade und
    Wrath of the Lich King an (Forever bringt Wertungen und Fertigkeiten mit, siehe das
    Charakterfenster). Werte, die ein Gegenstand nicht traegt, kosten nichts; Werte, die
    das Addon nicht kennt, zaehlt es nicht (/eg unknown listet sie). Fuer Feinabstimmung
    eigene Profile anlegen (/egprofile).

    Schluessel: STR AGI STA INT SPI AP RAP FAP SP SPDMG SPHEAL SPEN HIT EXP CRIT HASTE ARP RESIL
                MASTERY VERS DEF DODGE PARRY BLOCKR BLOCKV MP5 HP5 HEALTH MANA ARMOR
                DPS   Waffen-DPS Nahkampf (Nebenhand zaehlt nur zur Haelfte)
                RDPS  Waffen-DPS Fernkampf, Wurfwaffen, Zauberstaebe
-----------------------------------------------------------------------------]]

local _, EG = ...
local Specs = {}
EG.Specs = Specs

local pairs, ipairs = pairs, ipairs

------------------------------------------------------------------------------
-- Profile, die jede Klasse waehlen kann
------------------------------------------------------------------------------

Specs.ANY = {
    {
        id = "LEVELING", role = "MELEE", kind = "LEVELING",
        w = { STR = 0.60, AGI = 0.60, INT = 0.60, SPI = 0.30, STA = 0.50,
              AP = 0.30, SP = 0.60, CRIT = 0.40, HIT = 0.40, HASTE = 0.30,
              ARMOR = 0.06, DPS = 4.0, RDPS = 2.0 },
    },
    {
        id = "ILVL_ONLY", role = "MELEE", kind = "OTHER",
        w = {},
    },
}

------------------------------------------------------------------------------
-- Klassenprofile
------------------------------------------------------------------------------

Specs.CLASS = {}

------------------------------------------------------------------- Krieger ---
Specs.CLASS.WARRIOR = {
    {
        id = "WARRIOR_ARMS", tab = 1, auto = true, role = "MELEE", kind = "SPEC",
        w = { STR = 1.00, AGI = 0.55, AP = 0.50, HIT = 1.00, EXP = 0.90, CRIT = 0.75,
              ARP = 1.05, HASTE = 0.55, STA = 0.10, ARMOR = 0.025, DPS = 8.0, RDPS = 0.5 },
    },
    {
        id = "WARRIOR_FURY", tab = 2, auto = true, role = "MELEE", hands = "DW", kind = "SPEC",
        w = { STR = 1.00, AGI = 0.60, AP = 0.50, HIT = 1.20, EXP = 1.00, CRIT = 0.85,
              HASTE = 0.70, ARP = 0.90, STA = 0.10, ARMOR = 0.02, DPS = 7.0, RDPS = 0.5 },
    },
    {
        id = "WARRIOR_PROT", tab = 3, auto = true, role = "TANK", kind = "SPEC",
        w = { STA = 1.00, DEF = 1.20, DODGE = 0.85, PARRY = 0.75, BLOCKV = 0.45,
              BLOCKR = 0.35, ARMOR = 0.09, STR = 0.55, AGI = 0.60, AP = 0.15,
              HIT = 0.45, EXP = 0.70, CRIT = 0.25, HASTE = 0.20, DPS = 2.0, RDPS = 0.3 },
    },
    {
        id = "WARRIOR_LEVELING", role = "MELEE", kind = "LEVELING",
        w = { STR = 1.00, AGI = 0.40, STA = 0.60, ARMOR = 0.10, AP = 0.50, CRIT = 0.30,
              HIT = 0.30, EXP = 0.20, HASTE = 0.15, DPS = 6.0, RDPS = 0.5 },
    },
    {
        id = "WARRIOR_ALLROUND", role = "MELEE", kind = "ALLROUND",
        w = { STR = 1.00, AGI = 0.55, AP = 0.50, STA = 0.45, ARMOR = 0.06, HIT = 0.85,
              EXP = 0.80, CRIT = 0.65, HASTE = 0.50, ARP = 0.75, DEF = 0.45,
              DODGE = 0.35, PARRY = 0.35, BLOCKV = 0.20, BLOCKR = 0.15,
              DPS = 6.0, RDPS = 0.5 },
    },
}

----------------------------------------------------------------- Paladin ---
Specs.CLASS.PALADIN = {
    {
        id = "PALADIN_HOLY", tab = 1, auto = true, role = "HEAL", kind = "SPEC",
        w = { SP = 1.00, INT = 0.90, CRIT = 0.65, HASTE = 0.55, MP5 = 0.40, SPI = 0.10,
              STA = 0.10, ARMOR = 0.01, DPS = 0.2 },
    },
    {
        id = "PALADIN_PROT", tab = 2, auto = true, role = "TANK", kind = "SPEC",
        w = { STA = 1.00, DEF = 1.20, DODGE = 0.80, PARRY = 0.70, BLOCKV = 0.55,
              BLOCKR = 0.40, ARMOR = 0.09, STR = 0.60, AGI = 0.50, AP = 0.15,
              HIT = 0.50, EXP = 0.75, CRIT = 0.30, HASTE = 0.25, SP = 0.25, DPS = 2.0 },
    },
    {
        id = "PALADIN_RET", tab = 3, auto = true, role = "MELEE", hands = "2H", kind = "SPEC",
        w = { STR = 1.00, AP = 0.45, HIT = 1.15, EXP = 1.00, CRIT = 0.85, HASTE = 0.80,
              ARP = 0.85, AGI = 0.35, INT = 0.10, SP = 0.30, STA = 0.10, ARMOR = 0.02,
              DPS = 8.0 },
    },
    {
        id = "PALADIN_LEVELING", role = "MELEE", kind = "LEVELING",
        w = { STR = 1.00, STA = 0.60, AGI = 0.30, INT = 0.25, AP = 0.45, SP = 0.20,
              CRIT = 0.30, HIT = 0.30, HASTE = 0.15, ARMOR = 0.10, DPS = 6.0 },
    },
    {
        id = "PALADIN_ALLROUND", role = "MELEE", kind = "ALLROUND",
        w = { STR = 1.00, SP = 0.60, INT = 0.60, STA = 0.50, AGI = 0.35, AP = 0.45,
              CRIT = 0.65, HASTE = 0.60, HIT = 0.70, EXP = 0.65, ARP = 0.55,
              DEF = 0.40, DODGE = 0.35, PARRY = 0.35, BLOCKV = 0.30, BLOCKR = 0.20,
              MP5 = 0.20, SPI = 0.10, ARMOR = 0.06, DPS = 5.0 },
    },
}

------------------------------------------------------------------- Jaeger ---
Specs.CLASS.HUNTER = {
    {
        id = "HUNTER_BM", tab = 1, auto = true, role = "RANGED", kind = "SPEC",
        w = { AGI = 1.00, AP = 0.50, RAP = 0.50, HIT = 1.15, CRIT = 0.70, HASTE = 0.65,
              ARP = 0.60, INT = 0.15, STA = 0.10, ARMOR = 0.01, RDPS = 6.0, DPS = 0.3 },
    },
    {
        id = "HUNTER_MM", tab = 2, auto = true, role = "RANGED", kind = "SPEC",
        w = { AGI = 1.00, AP = 0.50, RAP = 0.50, HIT = 1.20, CRIT = 0.80, ARP = 0.95,
              HASTE = 0.60, INT = 0.15, STA = 0.10, ARMOR = 0.01, RDPS = 7.0, DPS = 0.3 },
    },
    {
        id = "HUNTER_SV", tab = 3, auto = true, role = "RANGED", kind = "SPEC",
        w = { AGI = 1.00, AP = 0.50, RAP = 0.50, HIT = 1.20, CRIT = 0.75, HASTE = 0.70,
              ARP = 0.55, INT = 0.20, STA = 0.10, ARMOR = 0.01, RDPS = 6.0, DPS = 0.3 },
    },
    {
        id = "HUNTER_LEVELING", role = "RANGED", kind = "LEVELING",
        w = { AGI = 1.00, AP = 0.50, RAP = 0.50, STA = 0.55, INT = 0.30, SPI = 0.10,
              ARMOR = 0.07, CRIT = 0.30, HIT = 0.30, HASTE = 0.15, RDPS = 6.0, DPS = 0.4 },
    },
    {
        id = "HUNTER_ALLROUND", role = "RANGED", kind = "ALLROUND",
        w = { AGI = 1.00, AP = 0.50, RAP = 0.50, HIT = 1.10, CRIT = 0.75, HASTE = 0.65,
              ARP = 0.75, INT = 0.15, STA = 0.35, ARMOR = 0.02, RDPS = 6.0, DPS = 0.3 },
    },
}

------------------------------------------------------------------ Schurke ---
Specs.CLASS.ROGUE = {
    {
        id = "ROGUE_ASSA", tab = 1, auto = true, role = "MELEE", hands = "DW", kind = "SPEC",
        w = { AGI = 1.00, AP = 0.45, HIT = 1.30, EXP = 1.00, CRIT = 0.75, HASTE = 0.70,
              ARP = 0.70, STR = 0.35, STA = 0.10, ARMOR = 0.02, DPS = 5.0, RDPS = 0.3 },
    },
    {
        id = "ROGUE_COMBAT", tab = 2, auto = true, role = "MELEE", hands = "DW", kind = "SPEC",
        w = { AGI = 1.00, AP = 0.45, HIT = 1.20, EXP = 1.10, CRIT = 0.70, HASTE = 0.80,
              ARP = 1.10, STR = 0.35, STA = 0.10, ARMOR = 0.02, DPS = 7.0, RDPS = 0.3 },
    },
    {
        id = "ROGUE_SUB", tab = 3, auto = true, role = "MELEE", hands = "DW", kind = "SPEC",
        w = { AGI = 1.00, AP = 0.45, HIT = 1.25, EXP = 1.05, CRIT = 0.80, HASTE = 0.65,
              ARP = 0.85, STR = 0.35, STA = 0.10, ARMOR = 0.02, DPS = 6.0, RDPS = 0.3 },
    },
    {
        id = "ROGUE_LEVELING", role = "MELEE", kind = "LEVELING",
        w = { AGI = 1.00, STR = 0.40, AP = 0.45, STA = 0.55, ARMOR = 0.07, CRIT = 0.30,
              HIT = 0.30, HASTE = 0.15, EXP = 0.15, DPS = 7.0, RDPS = 0.3 },
    },
    {
        id = "ROGUE_ALLROUND", role = "MELEE", kind = "ALLROUND",
        w = { AGI = 1.00, AP = 0.45, STR = 0.35, HIT = 1.20, EXP = 1.00, CRIT = 0.75,
              HASTE = 0.70, ARP = 0.85, STA = 0.30, ARMOR = 0.03, DPS = 6.0, RDPS = 0.3 },
    },
}

------------------------------------------------------------------ Priester ---
Specs.CLASS.PRIEST = {
    {
        id = "PRIEST_DISC", tab = 1, auto = true, role = "HEAL", kind = "SPEC",
        w = { SP = 1.00, INT = 0.55, SPI = 0.35, CRIT = 0.80, HASTE = 0.75, MP5 = 0.35,
              STA = 0.15, ARMOR = 0.01, DPS = 0.3, RDPS = 0.5 },
    },
    {
        id = "PRIEST_HOLY", tab = 2, auto = true, role = "HEAL", kind = "SPEC",
        w = { SP = 1.00, INT = 0.60, SPI = 0.65, CRIT = 0.60, HASTE = 0.80, MP5 = 0.35,
              STA = 0.15, ARMOR = 0.01, DPS = 0.3, RDPS = 0.5 },
    },
    {
        id = "PRIEST_SHADOW", tab = 3, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, HIT = 1.20, HASTE = 0.95, CRIT = 0.65, INT = 0.35, SPI = 0.30,
              STA = 0.10, SPEN = 0.05, ARMOR = 0.01, DPS = 0.5, RDPS = 0.5 },
    },
    {
        id = "PRIEST_LEVELING", role = "CASTER", kind = "LEVELING",
        w = { SP = 1.00, INT = 0.70, SPI = 0.60, STA = 0.50, MP5 = 0.20, CRIT = 0.20,
              HASTE = 0.15, ARMOR = 0.02, RDPS = 3.5, DPS = 0.5 },
    },
    {
        id = "PRIEST_ALLROUND", role = "CASTER", kind = "ALLROUND",
        w = { SP = 1.00, INT = 0.60, SPI = 0.45, CRIT = 0.65, HASTE = 0.80, HIT = 0.60,
              MP5 = 0.35, STA = 0.20, ARMOR = 0.01, DPS = 0.3, RDPS = 0.5 },
    },
}

------------------------------------------------------------------ Schamane ---
Specs.CLASS.SHAMAN = {
    {
        id = "SHAMAN_ELE", tab = 1, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, INT = 0.50, HIT = 1.30, HASTE = 0.90, CRIT = 0.80, MP5 = 0.15,
              STA = 0.10, ARMOR = 0.01, DPS = 0.5 },
    },
    {
        id = "SHAMAN_ENH", tab = 2, auto = true, role = "MELEE", hands = "DW", kind = "SPEC",
        w = { AGI = 1.00, AP = 0.50, STR = 0.55, HIT = 1.35, EXP = 1.00, CRIT = 0.70,
              HASTE = 0.85, ARP = 0.60, INT = 0.15, SP = 0.35, STA = 0.10, ARMOR = 0.02,
              DPS = 6.0 },
    },
    {
        id = "SHAMAN_RESTO", tab = 3, auto = true, role = "HEAL", kind = "SPEC",
        w = { SP = 1.00, INT = 0.65, SPI = 0.35, HASTE = 0.95, CRIT = 0.55, MP5 = 0.40,
              STA = 0.15, ARMOR = 0.01, DPS = 0.3 },
    },
    {
        -- Beim Leveln spielen Schamanen meist Verstaerkung oder Elementar:
        -- die Standardgewichte sind Nahkampf, im Elementarbaum gelten die Zauberer-Gewichte.
        id = "SHAMAN_LEVELING", role = "MELEE", kind = "LEVELING",
        w = { AGI = 0.90, STR = 0.55, AP = 0.50, INT = 0.30, SP = 0.35, STA = 0.55,
              ARMOR = 0.07, CRIT = 0.25, HIT = 0.25, HASTE = 0.15, DPS = 5.0 },
        variants = {
            [1] = { w = { SP = 1.00, INT = 0.70, SPI = 0.30, STA = 0.50, MP5 = 0.20,
                          CRIT = 0.25, HIT = 0.20, HASTE = 0.15, ARMOR = 0.03, DPS = 0.5 } },
        },
    },
    {
        id = "SHAMAN_ALLROUND", role = "MELEE", kind = "ALLROUND",
        w = { AGI = 0.80, STR = 0.50, AP = 0.50, SP = 0.70, INT = 0.55, SPI = 0.30,
              STA = 0.30, HIT = 1.00, EXP = 0.60, CRIT = 0.70, HASTE = 0.85, ARP = 0.40,
              MP5 = 0.30, ARMOR = 0.03, DPS = 3.0 },
    },
}

-------------------------------------------------------------------- Magier ---
Specs.CLASS.MAGE = {
    {
        id = "MAGE_ARCANE", tab = 1, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, INT = 0.65, HIT = 1.30, HASTE = 0.90, CRIT = 0.65, SPI = 0.20,
              STA = 0.10, ARMOR = 0.01, DPS = 0.5, RDPS = 0.5 },
    },
    {
        id = "MAGE_FIRE", tab = 2, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, INT = 0.45, HIT = 1.30, CRIT = 0.85, HASTE = 0.80, SPI = 0.25,
              STA = 0.10, ARMOR = 0.01, DPS = 0.5, RDPS = 0.5 },
    },
    {
        id = "MAGE_FROST", tab = 3, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, INT = 0.45, HIT = 1.30, CRIT = 0.80, HASTE = 0.85, SPI = 0.25,
              STA = 0.10, ARMOR = 0.01, DPS = 0.5, RDPS = 0.5 },
    },
    {
        id = "MAGE_LEVELING", role = "CASTER", kind = "LEVELING",
        w = { SP = 1.00, INT = 0.75, SPI = 0.45, STA = 0.45, CRIT = 0.25, HIT = 0.20,
              HASTE = 0.15, ARMOR = 0.02, RDPS = 3.5, DPS = 0.5 },
    },
    {
        id = "MAGE_ALLROUND", role = "CASTER", kind = "ALLROUND",
        w = { SP = 1.00, INT = 0.55, HIT = 1.20, CRIT = 0.75, HASTE = 0.85, SPI = 0.25,
              STA = 0.15, ARMOR = 0.01, DPS = 0.4, RDPS = 0.5 },
    },
}

----------------------------------------------------------------- Hexenmeister ---
Specs.CLASS.WARLOCK = {
    {
        id = "WARLOCK_AFFLI", tab = 1, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, HIT = 1.30, HASTE = 0.95, CRIT = 0.60, INT = 0.35, SPI = 0.35,
              STA = 0.15, ARMOR = 0.01, DPS = 0.5, RDPS = 0.5 },
    },
    {
        id = "WARLOCK_DEMO", tab = 2, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, HIT = 1.25, CRIT = 0.75, HASTE = 0.85, INT = 0.35, SPI = 0.35,
              STA = 0.15, ARMOR = 0.01, DPS = 0.5, RDPS = 0.5 },
    },
    {
        id = "WARLOCK_DESTRO", tab = 3, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, HIT = 1.25, CRIT = 0.85, HASTE = 0.80, INT = 0.35, SPI = 0.35,
              STA = 0.15, ARMOR = 0.01, DPS = 0.5, RDPS = 0.5 },
    },
    {
        id = "WARLOCK_LEVELING", role = "CASTER", kind = "LEVELING",
        w = { SP = 1.00, INT = 0.60, SPI = 0.50, STA = 0.65, CRIT = 0.25, HIT = 0.20,
              HASTE = 0.15, ARMOR = 0.02, RDPS = 3.5, DPS = 0.5 },
    },
    {
        id = "WARLOCK_ALLROUND", role = "CASTER", kind = "ALLROUND",
        w = { SP = 1.00, HIT = 1.20, CRIT = 0.75, HASTE = 0.85, INT = 0.35, SPI = 0.35,
              STA = 0.20, ARMOR = 0.01, DPS = 0.4, RDPS = 0.5 },
    },
}

-------------------------------------------------------------------- Druide ---
Specs.CLASS.DRUID = {
    {
        id = "DRUID_BALANCE", tab = 1, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, HIT = 1.25, HASTE = 0.90, CRIT = 0.70, INT = 0.50, SPI = 0.45,
              FAP = 0.20, STA = 0.10, ARMOR = 0.01, DPS = 0.5 },
    },
    {
        id = "DRUID_CAT", tab = 2, auto = true, role = "MELEE", kind = "SPEC",
        w = { AGI = 1.00, AP = 0.50, FAP = 0.50, STR = 0.85, HIT = 1.15, EXP = 1.00, CRIT = 0.75,
              ARP = 1.00, HASTE = 0.55, STA = 0.10, ARMOR = 0.02, DPS = 0.5 },
    },
    {
        id = "DRUID_BEAR", tab = 2, role = "TANK", kind = "SPEC",
        w = { STA = 1.00, AGI = 0.85, ARMOR = 0.10, DODGE = 0.80, DEF = 0.40,
              STR = 0.50, AP = 0.20, FAP = 0.20, HIT = 0.50, EXP = 0.70, CRIT = 0.30, HASTE = 0.20,
              DPS = 0.5 },
    },
    {
        id = "DRUID_RESTO", tab = 3, auto = true, role = "HEAL", kind = "SPEC",
        w = { SP = 1.00, INT = 0.60, SPI = 0.50, HASTE = 0.95, CRIT = 0.50, MP5 = 0.35,
              STA = 0.15, ARMOR = 0.01, DPS = 0.3 },
    },
    {
        -- Standard: Wildheit (Katze/Baer gemischt); im Gleichgewichtsbaum gelten die Zauberer-Gewichte.
        id = "DRUID_LEVELING", role = "MELEE", kind = "LEVELING",
        w = { AGI = 1.00, STR = 0.85, AP = 0.50, FAP = 0.50, STA = 0.65, ARMOR = 0.09, INT = 0.20,
              CRIT = 0.25, HIT = 0.25, HASTE = 0.15, DPS = 0.5 },
        variants = {
            [1] = { w = { SP = 1.00, INT = 0.70, SPI = 0.50, STA = 0.45, ARMOR = 0.02,
                          CRIT = 0.25, HASTE = 0.15, DPS = 0.5 } },
        },
    },
    {
        id = "DRUID_ALLROUND", role = "MELEE", kind = "ALLROUND",
        w = { AGI = 0.90, STR = 0.65, AP = 0.50, FAP = 0.50, SP = 0.55, INT = 0.50, SPI = 0.35,
              STA = 0.45, ARMOR = 0.06, HIT = 0.90, EXP = 0.60, CRIT = 0.70, HASTE = 0.80,
              ARP = 0.55, DODGE = 0.40, DEF = 0.20, MP5 = 0.20, DPS = 0.5 },
    },
}

------------------------------------------------------------------------------
-- Nachbereitung
------------------------------------------------------------------------------

-- Klassenkennung (UnitClass 2. Rueckgabewert) in der Reihenfolge der Klassennummern von Forever
Specs.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

Specs.BY_ID = {}

local function Prepare(list, class)
    for _, spec in ipairs(list) do
        spec.class = class
        spec.builtin = true
        Specs.BY_ID[spec.id] = spec
    end
end

for class, list in pairs(Specs.CLASS) do Prepare(list, class) end
Prepare(Specs.ANY, "ANY")
