--[[---------------------------------------------------------------------------
    EasyGear 3.0.0 - Profildatenbank (WotLK 3.3.5a)

    Je Klasse gibt es:

      * ein Profil je Spielstil der Talentbaeume (Waffen, Furor, Schutz, ...);
        wo sich die Gewichtung innerhalb eines Baums real unterscheidet (Blut-
        Tank gegen Blut-DD, Wildheit Katze gegen Baer, Frost beidhaendig gegen
        Zweihand), steht ein eigenes Profil
      * <KLASSE>_LEVELING   fuer Stufe 1-79: Ausdauer und Ruestung zaehlen mehr,
                            Wertungen (Treffer, Tempo, ...) kaum - sie kommen auf
                            niedrigen Stufen fast nicht vor
      * <KLASSE>_ALLROUND   deckt alle Spezialisierungen der Klasse maessig ab,
                            fuer Hybrid-Ausruestung und Zweitspezialisierung

    Dazu zwei klassenunabhaengige Profile (LEVELING und ILVL_ONLY).

    Felder eines Eintrags:
      id        eindeutiger Schluessel (wird gespeichert)
      tab       Talentbaum-Index fuer die automatische Erkennung
      auto      true = Standardwahl, wenn dieser Baum erkannt wird
      hands     "2H" | "DW" - Waffenhaltung, nach der die Erkennung zwischen
                mehreren Profilen desselben Baums waehlt
      role      TANK | MELEE | RANGED | CASTER | HEAL
                (Gruppierung; entscheidet auch, ob eine Einhandwaffe in die
                Schildhand darf - Tanks, Heiler und Zauberer tragen dort Schild
                oder Halteitem)
      variants  [Talentbaum] = { w = {...} }  - abweichende Gewichte je
                dominantem Talentbaum (nur Leveln-Profile der Hybridklassen)
      w         Gewichte in Kurzform, siehe EG:MakeWeights()

    Namen und Beschreibungen stehen in Locales/*.lang.lua unter SPEC_<id> und
    SPEC_<id>_D.

    Die Gewichte sind auf das Hauptattribut des Profils (1.00) normiert und an
    die gaengigen WotLK-Statwerte angelehnt (Umrechnungen auf Stufe 80, siehe
    unten). Sie sind Richtwerte, keine Simulation - fuer Feinabstimmung eigene
    Profile anlegen (/egprofile).

    Schluessel: STR AGI STA INT SPI AP RAP SP SPEN HIT EXP CRIT HASTE ARP RESIL
                DEF DODGE PARRY BLOCKR BLOCKV MP5 HP5 HEALTH MANA ARMOR
                DPS   Waffen-DPS Nahkampf (Nebenhand zaehlt nur zur Haelfte)
                RDPS  Waffen-DPS Fernkampf, Wurfwaffen, Zauberstaebe

    Herleitung der Groessenordnungen (Stufe 80, Hauptattribut = 1.00):
      * 1 Staerke = 2 Angriffskraft (Krieger, Paladin, Todesritter, Druide in
        Katzen-/Baerengestalt) bzw. 1 (Schurke, Jaeger, Schamane) -> AP 0.50
        bei Staerkeklassen
      * 1 Waffen-DPS entspricht rund 14 Angriffskraft -> 7-8 Staerke (DPS 7-8,
        auf Nebenhand halbiert)
      * Wertungen liegen zwischen 0.55 und 1.10 Hauptattribut je Punkt; Treffer
        und Waffenkunde sind unterhalb ihrer Grenze am wertvollsten und mit
        1.1-1.4 angesetzt, weil ein Item allein die Grenze nie ueberschreitet
      * Ruestung: 1000 Ruestung ~ 2.2 % weniger Schaden ~ 90 Ausdauer fuer
        Tanks (0.09); fuer Nicht-Tanks nur Tiebreaker (0.01-0.03)
      * Jaeger: Beweglichkeit gibt 2 Fernkampf-AP, deshalb AP = RAP = 0.50
      * Hexenmeister: Teufelsruestung macht 30 % Willenskraft zu Zaubermacht
        (SPI 0.35); Magier: Magische Ruestung macht Willenskraft zu
        kritischer Trefferwertung (SPI 0.25)
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

-- Praefix der Profil-IDs, wo er vom Klassenschluessel abweicht
EG.PROFILE_PREFIX = { DEATHKNIGHT = "DK" }

------------------------------------------------------------------------------
-- Profile, die jede Klasse waehlen kann
------------------------------------------------------------------------------

EG.SPECS_ANY = {
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

EG.SPECS = {}

------------------------------------------------------------------- Krieger ---
EG.SPECS.WARRIOR = {
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
EG.SPECS.PALADIN = {
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
EG.SPECS.HUNTER = {
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
EG.SPECS.ROGUE = {
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
EG.SPECS.PRIEST = {
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

-------------------------------------------------------------- Todesritter ---
EG.SPECS.DEATHKNIGHT = {
    {
        id = "DK_BLOOD_TANK", tab = 1, auto = true, role = "TANK", kind = "SPEC",
        w = { STA = 1.00, DEF = 1.15, DODGE = 0.85, PARRY = 0.75, ARMOR = 0.09,
              STR = 0.60, AGI = 0.45, AP = 0.15, HIT = 0.55, EXP = 0.80, CRIT = 0.30,
              HASTE = 0.20, DPS = 3.0 },
    },
    {
        id = "DK_BLOOD_DPS", tab = 1, role = "MELEE", hands = "2H", kind = "SPEC",
        w = { STR = 1.00, AP = 0.50, HIT = 1.10, EXP = 1.00, CRIT = 0.70, HASTE = 0.65,
              ARP = 0.90, AGI = 0.30, STA = 0.10, ARMOR = 0.02, DPS = 8.0 },
    },
    {
        id = "DK_FROST_DW", tab = 2, auto = true, role = "MELEE", hands = "DW", kind = "SPEC",
        w = { STR = 1.00, AP = 0.50, HIT = 1.40, EXP = 1.15, CRIT = 0.75, HASTE = 0.85,
              ARP = 0.75, AGI = 0.30, STA = 0.10, ARMOR = 0.02, DPS = 6.0 },
    },
    {
        id = "DK_FROST_2H", tab = 2, role = "MELEE", hands = "2H", kind = "SPEC",
        w = { STR = 1.00, AP = 0.50, HIT = 1.15, EXP = 1.00, CRIT = 0.80, HASTE = 0.75,
              ARP = 0.85, AGI = 0.30, STA = 0.10, ARMOR = 0.02, DPS = 8.0 },
    },
    {
        id = "DK_UNHOLY", tab = 3, auto = true, role = "MELEE", hands = "2H", kind = "SPEC",
        w = { STR = 1.00, AP = 0.50, HIT = 1.20, EXP = 1.00, CRIT = 0.70, HASTE = 0.90,
              ARP = 0.80, AGI = 0.30, STA = 0.10, ARMOR = 0.02, DPS = 8.0 },
    },
    {
        id = "DK_FROST_TANK", tab = 2, role = "TANK", kind = "SPEC",
        w = { STA = 1.00, DEF = 1.15, DODGE = 0.80, PARRY = 0.85, ARMOR = 0.09,
              STR = 0.60, AGI = 0.45, AP = 0.15, HIT = 0.55, EXP = 0.80, CRIT = 0.30,
              HASTE = 0.20, DPS = 3.0 },
    },
    {
        id = "DK_LEVELING", role = "MELEE", kind = "LEVELING",
        w = { STR = 1.00, STA = 0.65, AGI = 0.30, AP = 0.50, ARMOR = 0.09, CRIT = 0.30,
              HIT = 0.30, EXP = 0.15, HASTE = 0.15, DPS = 7.0 },
    },
    {
        id = "DK_ALLROUND", role = "MELEE", kind = "ALLROUND",
        w = { STR = 1.00, AP = 0.50, HIT = 0.90, EXP = 0.90, CRIT = 0.65, HASTE = 0.65,
              ARP = 0.75, AGI = 0.30, STA = 0.40, DEF = 0.35, DODGE = 0.30, PARRY = 0.30,
              ARMOR = 0.05, DPS = 6.5 },
    },
}

------------------------------------------------------------------ Schamane ---
EG.SPECS.SHAMAN = {
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
EG.SPECS.MAGE = {
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
EG.SPECS.WARLOCK = {
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
EG.SPECS.DRUID = {
    {
        id = "DRUID_BALANCE", tab = 1, auto = true, role = "CASTER", kind = "SPEC",
        w = { SP = 1.00, HIT = 1.25, HASTE = 0.90, CRIT = 0.70, INT = 0.50, SPI = 0.45,
              STA = 0.10, ARMOR = 0.01, DPS = 0.5 },
    },
    {
        id = "DRUID_CAT", tab = 2, auto = true, role = "MELEE", kind = "SPEC",
        w = { AGI = 1.00, AP = 0.50, STR = 0.85, HIT = 1.15, EXP = 1.00, CRIT = 0.75,
              ARP = 1.00, HASTE = 0.55, STA = 0.10, ARMOR = 0.02, DPS = 0.5 },
    },
    {
        id = "DRUID_BEAR", tab = 2, role = "TANK", kind = "SPEC",
        w = { STA = 1.00, AGI = 0.85, ARMOR = 0.10, DODGE = 0.80, DEF = 0.40,
              STR = 0.50, AP = 0.20, HIT = 0.50, EXP = 0.70, CRIT = 0.30, HASTE = 0.20,
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
        w = { AGI = 1.00, STR = 0.85, AP = 0.50, STA = 0.65, ARMOR = 0.09, INT = 0.20,
              CRIT = 0.25, HIT = 0.25, HASTE = 0.15, DPS = 0.5 },
        variants = {
            [1] = { w = { SP = 1.00, INT = 0.70, SPI = 0.50, STA = 0.45, ARMOR = 0.02,
                          CRIT = 0.25, HASTE = 0.15, DPS = 0.5 } },
        },
    },
    {
        id = "DRUID_ALLROUND", role = "MELEE", kind = "ALLROUND",
        w = { AGI = 0.90, STR = 0.65, AP = 0.50, SP = 0.55, INT = 0.50, SPI = 0.35,
              STA = 0.45, ARMOR = 0.06, HIT = 0.90, EXP = 0.60, CRIT = 0.70, HASTE = 0.80,
              ARP = 0.55, DODGE = 0.40, DEF = 0.20, MP5 = 0.20, DPS = 0.5 },
    },
}

------------------------------------------------------------------------------
-- Nachbereitung: Kurzform in echte Statschluessel uebersetzen
------------------------------------------------------------------------------

local function Prepare(list, class)
    for _, spec in ipairs(list) do
        spec.class   = class
        spec.weights = EG:MakeWeights(spec.w)
        spec.builtin = true
        if spec.variants then
            for _, variant in pairs(spec.variants) do
                variant.weights = EG:MakeWeights(variant.w)
            end
        end
    end
end

for class, list in pairs(EG.SPECS) do
    Prepare(list, class)
end
Prepare(EG.SPECS_ANY, "ANY")
