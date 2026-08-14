--[[---------------------------------------------------------------------------
    EasyGear 2.3.0 - Profildatenbank (WotLK 3.3.5a)

    Ein Eintrag pro sinnvollem Spielstil, nicht pro Talentbaum: wo sich die
    Gewichtung innerhalb eines Baums real unterscheidet (Blut-Tank gegen
    Blut-DD, Wildheit Katze gegen Baer, Frost beidhaendig gegen Zweihand),
    steht ein eigenes Profil.

    Felder eines Eintrags:
      id     eindeutiger Schluessel (wird gespeichert)
      tab    Talentbaum-Index fuer die automatische Erkennung
      auto   true = Standardwahl, wenn dieser Baum erkannt wird
      role   TANK | MELEE | RANGED | CASTER | HEAL  (nur zur Gruppierung)
      de/en  Anzeigename
      hd/he  kurze Beschreibung
      w      Gewichte in Kurzform, siehe EG:MakeWeights()

    Die Gewichte sind auf das Primaerattribut (1.00) normiert und an die
    gaengigen WotLK-Statwerte angelehnt. Sie sind Richtwerte, keine
    Simulation - fuer Feinabstimmung eigene Profile anlegen.
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

------------------------------------------------------------------------------
-- Profile, die jede Klasse waehlen kann
------------------------------------------------------------------------------

EG.SPECS_ANY = {
    {
        id = "LEVELING", role = "MELEE", auto = false,
        de = "Levelphase (neutral)", en = "Leveling (neutral)",
        hd = "Ausgewogen fuer Stufe 1-79, wenn noch kaum Talente gesetzt sind.",
        he = "Balanced for levels 1-79 with few talents spent.",
        w = { STR = 0.60, AGI = 0.60, INT = 0.60, SPI = 0.30, STA = 0.50,
              AP = 0.30, SP = 0.60, CRIT = 0.40, HIT = 0.40, HASTE = 0.30,
              ARMOR = 0.06, DPS = 4.0 },
    },
    {
        id = "ILVL_ONLY", role = "MELEE", auto = false,
        de = "Nur Gegenstandsstufe", en = "Item level only",
        hd = "Ignoriert Attribute vollstaendig - reiner Gegenstandsstufen-Vergleich.",
        he = "Ignores all attributes - pure item level comparison.",
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
        id = "WARRIOR_ARMS", tab = 1, auto = true, role = "MELEE",
        de = "Waffen (Zweihand)", en = "Arms (two-hand)",
        hd = "Zweihandwaffe, hoher Waffenschaden, Ruestung ignorieren wichtig.",
        he = "Two-hander, weapon damage and armor penetration matter most.",
        w = { STR = 1.00, AP = 0.50, HIT = 1.10, EXP = 1.00, CRIT = 0.75,
              ARP = 1.10, HASTE = 0.55, AGI = 0.30, STA = 0.10,
              ARMOR = 0.02, DPS = 8.0 },
    },
    {
        id = "WARRIOR_FURY", tab = 2, auto = true, role = "MELEE",
        de = "Furor (beidhaendig)", en = "Fury (dual wield)",
        hd = "Beidhaendig - deutlich hoeherer Trefferwertungsbedarf.",
        he = "Dual wield - noticeably higher hit rating requirement.",
        w = { STR = 1.00, AP = 0.50, HIT = 1.30, EXP = 1.10, CRIT = 0.80,
              HASTE = 0.75, ARP = 0.90, AGI = 0.35, STA = 0.10,
              ARMOR = 0.02, DPS = 7.0 },
    },
    {
        id = "WARRIOR_PROT", tab = 3, auto = true, role = "TANK",
        de = "Schutz (Tank)", en = "Protection (tank)",
        hd = "Verteidigungswertung bis zur Unerschuetterlichkeit, dann Ausweichen.",
        he = "Defense rating to uncrittable, then avoidance.",
        w = { STA = 1.00, DEF = 1.20, DODGE = 0.85, PARRY = 0.75,
              BLOCKV = 0.45, BLOCKR = 0.35, ARMOR = 0.06,
              STR = 0.55, AGI = 0.60, AP = 0.15, HIT = 0.45, EXP = 0.70,
              CRIT = 0.25, DPS = 2.0 },
    },
}

----------------------------------------------------------------- Paladin ---
EG.SPECS.PALADIN = {
    {
        id = "PALADIN_HOLY", tab = 1, auto = true, role = "HEAL",
        de = "Heilig (Heiler)", en = "Holy (healer)",
        hd = "Zaubermacht und Tempo, Manaregeneration ueber Intelligenz.",
        he = "Spell power and haste, mana from intellect.",
        w = { SP = 1.00, INT = 0.75, SPI = 0.35, CRIT = 0.60, HASTE = 0.85,
              MP5 = 0.90, STA = 0.15, DPS = 0.3 },
    },
    {
        id = "PALADIN_PROT", tab = 2, auto = true, role = "TANK",
        de = "Schutz (Tank)", en = "Protection (tank)",
        hd = "Blockwert zaehlt hier deutlich mehr als bei anderen Tanks.",
        he = "Block value counts far more than for other tanks.",
        w = { STA = 1.00, DEF = 1.20, DODGE = 0.80, PARRY = 0.70,
              BLOCKV = 0.55, BLOCKR = 0.40, ARMOR = 0.06,
              STR = 0.60, AGI = 0.50, AP = 0.15, HIT = 0.50, EXP = 0.75,
              CRIT = 0.30, SP = 0.25, DPS = 2.0 },
    },
    {
        id = "PALADIN_RET", tab = 3, auto = true, role = "MELEE",
        de = "Vergeltung (Nahkampf)", en = "Retribution (melee)",
        hd = "Staerke und Trefferwertung, etwas Zaubermacht durch Skalierung.",
        he = "Strength and hit, some spell power through scaling.",
        w = { STR = 1.00, AP = 0.45, HIT = 1.20, EXP = 1.00, CRIT = 0.85,
              HASTE = 0.80, ARP = 0.85, AGI = 0.30, INT = 0.10, SP = 0.30,
              STA = 0.10, ARMOR = 0.02, DPS = 8.0 },
    },
}

------------------------------------------------------------------- Jaeger ---
EG.SPECS.HUNTER = {
    {
        id = "HUNTER_BM", tab = 1, auto = true, role = "RANGED",
        de = "Tierherrschaft", en = "Beast Mastery",
        hd = "Angriffskraft skaliert zusaetzlich ueber das Tier.",
        he = "Attack power also scales through the pet.",
        w = { AGI = 1.00, RAP = 0.50, AP = 0.40, HIT = 1.20, CRIT = 0.70,
              HASTE = 0.65, ARP = 0.60, INT = 0.12, STA = 0.10, DPS = 5.0 },
    },
    {
        id = "HUNTER_MM", tab = 2, auto = true, role = "RANGED",
        de = "Treffsicherheit", en = "Marksmanship",
        hd = "Kritische Trefferwertung und Ruestung ignorieren im Vordergrund.",
        he = "Crit rating and armor penetration lead.",
        w = { AGI = 1.00, RAP = 0.50, HIT = 1.20, CRIT = 0.80, ARP = 0.90,
              HASTE = 0.60, INT = 0.12, STA = 0.10, DPS = 6.0 },
    },
    {
        id = "HUNTER_SV", tab = 3, auto = true, role = "RANGED",
        de = "Ueberleben", en = "Survival",
        hd = "Hoher Trefferbedarf, Tempo vor Ruestung ignorieren.",
        he = "High hit requirement, haste over armor penetration.",
        w = { AGI = 1.00, RAP = 0.50, HIT = 1.25, CRIT = 0.75, HASTE = 0.70,
              ARP = 0.55, INT = 0.12, STA = 0.10, DPS = 5.0 },
    },
}

------------------------------------------------------------------ Schurke ---
EG.SPECS.ROGUE = {
    {
        id = "ROGUE_ASSA", tab = 1, auto = true, role = "MELEE",
        de = "Meucheln (Dolche)", en = "Assassination (daggers)",
        hd = "Dolche, sehr hoher Trefferbedarf durch Verstuemmeln.",
        he = "Daggers, very high hit requirement from Mutilate.",
        w = { AGI = 1.00, AP = 0.50, HIT = 1.30, EXP = 1.00, CRIT = 0.75,
              HASTE = 0.70, ARP = 0.70, STR = 0.35, STA = 0.10, DPS = 5.0 },
    },
    {
        id = "ROGUE_COMBAT", tab = 2, auto = true, role = "MELEE",
        de = "Kampf (Schwerter)", en = "Combat (swords)",
        hd = "Ruestung ignorieren ist hier das staerkste Sekundaerattribut.",
        he = "Armor penetration is the strongest secondary here.",
        w = { AGI = 1.00, AP = 0.50, HIT = 1.20, EXP = 1.10, CRIT = 0.70,
              HASTE = 0.80, ARP = 1.10, STR = 0.35, STA = 0.10, DPS = 7.0 },
    },
    {
        id = "ROGUE_SUB", tab = 3, auto = true, role = "MELEE",
        de = "Taeuschung", en = "Subtlety",
        hd = "Ausgewogen zwischen kritischer Trefferwertung und Waffenschaden.",
        he = "Balanced between crit rating and weapon damage.",
        w = { AGI = 1.00, AP = 0.50, HIT = 1.25, EXP = 1.05, CRIT = 0.80,
              HASTE = 0.65, ARP = 0.85, STR = 0.35, STA = 0.10, DPS = 6.0 },
    },
}

------------------------------------------------------------------ Priester ---
EG.SPECS.PRIEST = {
    {
        id = "PRIEST_DISC", tab = 1, auto = true, role = "HEAL",
        de = "Disziplin (Heiler)", en = "Discipline (healer)",
        hd = "Schilde skalieren mit Zaubermacht, Willenskraft weniger wichtig.",
        he = "Shields scale with spell power, spirit matters less.",
        w = { SP = 1.00, INT = 0.70, SPI = 0.30, CRIT = 0.70, HASTE = 0.75,
              MP5 = 0.85, STA = 0.15, DPS = 0.3 },
    },
    {
        id = "PRIEST_HOLY", tab = 2, auto = true, role = "HEAL",
        de = "Heilig (Heiler)", en = "Holy (healer)",
        hd = "Willenskraft und Tempo, hoher Manadurchsatz.",
        he = "Spirit and haste, high mana throughput.",
        w = { SP = 1.00, INT = 0.65, SPI = 0.55, CRIT = 0.60, HASTE = 0.80,
              MP5 = 0.90, STA = 0.15, DPS = 0.3 },
    },
    {
        id = "PRIEST_SHADOW", tab = 3, auto = true, role = "CASTER",
        de = "Schatten (Zauber-DD)", en = "Shadow (caster DPS)",
        hd = "Willenskraft zaehlt mit, da sie ueber Talente Zaubermacht gibt.",
        he = "Spirit counts, since talents convert it to spell power.",
        w = { SP = 1.00, HIT = 1.20, HASTE = 0.95, CRIT = 0.65, INT = 0.35,
              SPI = 0.55, STA = 0.10, SPEN = 0.05, DPS = 0.5 },
    },
}

-------------------------------------------------------------- Todesritter ---
EG.SPECS.DEATHKNIGHT = {
    {
        id = "DK_BLOOD_TANK", tab = 1, auto = true, role = "TANK",
        de = "Blut (Tank)", en = "Blood (tank)",
        hd = "Die uebliche Tankwahl in 3.3.5a.",
        he = "The usual tanking choice in 3.3.5a.",
        w = { STA = 1.00, DEF = 1.15, DODGE = 0.85, PARRY = 0.75,
              ARMOR = 0.06, STR = 0.60, AGI = 0.45, AP = 0.15,
              HIT = 0.55, EXP = 0.80, CRIT = 0.30, DPS = 3.0 },
    },
    {
        id = "DK_BLOOD_DPS", tab = 1, role = "MELEE",
        de = "Blut (Zweihand-DD)", en = "Blood (two-hand DPS)",
        hd = "Zweihandwaffe, Staerke und Ruestung ignorieren.",
        he = "Two-hander, strength and armor penetration.",
        w = { STR = 1.00, AP = 0.50, HIT = 1.15, EXP = 1.00, CRIT = 0.75,
              HASTE = 0.70, ARP = 0.95, STA = 0.10, ARMOR = 0.02, DPS = 8.0 },
    },
    {
        id = "DK_FROST_DW", tab = 2, auto = true, role = "MELEE",
        de = "Frost (beidhaendig)", en = "Frost (dual wield)",
        hd = "Beidhaendig - der hoechste Trefferbedarf aller Nahkampfprofile.",
        he = "Dual wield - the highest hit requirement of all melee profiles.",
        w = { STR = 1.00, AP = 0.50, HIT = 1.40, EXP = 1.15, CRIT = 0.75,
              HASTE = 0.85, ARP = 0.75, STA = 0.10, ARMOR = 0.02, DPS = 6.0 },
    },
    {
        id = "DK_FROST_2H", tab = 2, role = "MELEE",
        de = "Frost (Zweihand)", en = "Frost (two-hand)",
        hd = "Zweihandvariante mit deutlich geringerem Trefferbedarf.",
        he = "Two-hand variant with a much lower hit requirement.",
        w = { STR = 1.00, AP = 0.50, HIT = 1.15, EXP = 1.00, CRIT = 0.80,
              HASTE = 0.75, ARP = 0.85, STA = 0.10, ARMOR = 0.02, DPS = 8.0 },
    },
    {
        id = "DK_UNHOLY", tab = 3, auto = true, role = "MELEE",
        de = "Unheilig (Zweihand-DD)", en = "Unholy (two-hand DPS)",
        hd = "Tempo ist hier wertvoller als bei den anderen Baeumen.",
        he = "Haste is more valuable here than in the other trees.",
        w = { STR = 1.00, AP = 0.50, HIT = 1.20, EXP = 1.00, CRIT = 0.70,
              HASTE = 0.90, ARP = 0.80, STA = 0.10, ARMOR = 0.02, DPS = 8.0 },
    },
    {
        id = "DK_FROST_TANK", tab = 2, role = "TANK",
        de = "Frost (Tank)", en = "Frost (tank)",
        hd = "Alternative Tankvariante, staerker auf Parieren ausgelegt.",
        he = "Alternative tank build, leaning more on parry.",
        w = { STA = 1.00, DEF = 1.15, DODGE = 0.80, PARRY = 0.85,
              ARMOR = 0.06, STR = 0.60, AGI = 0.45, AP = 0.15,
              HIT = 0.55, EXP = 0.80, CRIT = 0.30, DPS = 3.0 },
    },
}

------------------------------------------------------------------ Schamane ---
EG.SPECS.SHAMAN = {
    {
        id = "SHAMAN_ELE", tab = 1, auto = true, role = "CASTER",
        de = "Elementar (Zauber-DD)", en = "Elemental (caster DPS)",
        hd = "Zaubertrefferwertung bis zur Obergrenze, danach Tempo.",
        he = "Spell hit to cap, then haste.",
        w = { SP = 1.00, INT = 0.45, HIT = 1.30, HASTE = 0.90, CRIT = 0.80,
              MP5 = 0.15, STA = 0.10, DPS = 0.5 },
    },
    {
        id = "SHAMAN_ENH", tab = 2, auto = true, role = "MELEE",
        de = "Verstaerkung (Nahkampf)", en = "Enhancement (melee)",
        hd = "Braucht Nahkampf- und Zaubertrefferwertung zugleich.",
        he = "Needs both melee and spell hit rating.",
        w = { AGI = 1.00, AP = 0.50, STR = 0.55, HIT = 1.35, EXP = 1.00,
              CRIT = 0.70, HASTE = 0.85, ARP = 0.60, INT = 0.15, SP = 0.35,
              STA = 0.10, DPS = 6.0 },
    },
    {
        id = "SHAMAN_RESTO", tab = 3, auto = true, role = "HEAL",
        de = "Wiederherstellung (Heiler)", en = "Restoration (healer)",
        hd = "Tempo ist das staerkste Sekundaerattribut.",
        he = "Haste is the strongest secondary.",
        w = { SP = 1.00, INT = 0.70, SPI = 0.45, HASTE = 0.95, CRIT = 0.55,
              MP5 = 0.85, STA = 0.15, DPS = 0.3 },
    },
}

-------------------------------------------------------------------- Magier ---
EG.SPECS.MAGE = {
    {
        id = "MAGE_ARCANE", tab = 1, auto = true, role = "CASTER",
        de = "Arkan", en = "Arcane",
        hd = "Intelligenz zaehlt hier mehr als in den anderen Baeumen.",
        he = "Intellect counts more here than in the other trees.",
        w = { SP = 1.00, INT = 0.55, HIT = 1.30, HASTE = 0.90, CRIT = 0.70,
              SPI = 0.10, STA = 0.10, DPS = 0.5 },
    },
    {
        id = "MAGE_FIRE", tab = 2, auto = true, role = "CASTER",
        de = "Feuer", en = "Fire",
        hd = "Kritische Trefferwertung im Vordergrund.",
        he = "Crit rating leads.",
        w = { SP = 1.00, INT = 0.40, HIT = 1.30, CRIT = 0.85, HASTE = 0.80,
              SPI = 0.10, STA = 0.10, DPS = 0.5 },
    },
    {
        id = "MAGE_FROST", tab = 3, auto = true, role = "CASTER",
        de = "Frost", en = "Frost",
        hd = "Ausgewogen zwischen kritischer Trefferwertung und Tempo.",
        he = "Balanced between crit rating and haste.",
        w = { SP = 1.00, INT = 0.45, HIT = 1.30, CRIT = 0.80, HASTE = 0.85,
              SPI = 0.10, STA = 0.10, DPS = 0.5 },
    },
}

----------------------------------------------------------------- Hexenmeister ---
EG.SPECS.WARLOCK = {
    {
        id = "WARLOCK_AFFLI", tab = 1, auto = true, role = "CASTER",
        de = "Gebrechen", en = "Affliction",
        hd = "Tempo verkuerzt die Zauberzeiten der Flueche spuerbar.",
        he = "Haste shortens the curse rotation noticeably.",
        w = { SP = 1.00, HIT = 1.30, HASTE = 0.95, CRIT = 0.60, INT = 0.35,
              SPI = 0.25, STA = 0.10, DPS = 0.5 },
    },
    {
        id = "WARLOCK_DEMO", tab = 2, auto = true, role = "CASTER",
        de = "Daemonologie", en = "Demonology",
        hd = "Ausgewogen, profitiert zusaetzlich ueber den Daemon.",
        he = "Balanced, also scales through the demon.",
        w = { SP = 1.00, HIT = 1.25, CRIT = 0.75, HASTE = 0.85, INT = 0.35,
              SPI = 0.20, STA = 0.10, DPS = 0.5 },
    },
    {
        id = "WARLOCK_DESTRO", tab = 3, auto = true, role = "CASTER",
        de = "Zerstoerung", en = "Destruction",
        hd = "Kritische Trefferwertung im Vordergrund.",
        he = "Crit rating leads.",
        w = { SP = 1.00, HIT = 1.25, CRIT = 0.85, HASTE = 0.80, INT = 0.35,
              SPI = 0.15, STA = 0.10, DPS = 0.5 },
    },
}

-------------------------------------------------------------------- Druide ---
EG.SPECS.DRUID = {
    {
        id = "DRUID_BALANCE", tab = 1, auto = true, role = "CASTER",
        de = "Gleichgewicht (Eulendruide)", en = "Balance (moonkin)",
        hd = "Willenskraft gibt ueber Talente Zaubertrefferwertung.",
        he = "Spirit converts to spell hit through talents.",
        w = { SP = 1.00, HIT = 1.25, HASTE = 0.90, CRIT = 0.70, INT = 0.40,
              SPI = 0.55, STA = 0.10, DPS = 0.5 },
    },
    {
        id = "DRUID_CAT", tab = 2, auto = true, role = "MELEE",
        de = "Wildheit - Katze (DD)", en = "Feral - cat (DPS)",
        hd = "Ruestung ignorieren ist hier besonders stark.",
        he = "Armor penetration is especially strong here.",
        w = { AGI = 1.00, AP = 0.50, STR = 0.45, HIT = 1.15, EXP = 1.00,
              CRIT = 0.75, ARP = 1.00, HASTE = 0.55, STA = 0.10, DPS = 5.0 },
    },
    {
        id = "DRUID_BEAR", tab = 2, role = "TANK",
        de = "Wildheit - Baer (Tank)", en = "Feral - bear (tank)",
        hd = "Ruestung zaehlt hier mehr als bei jedem anderen Tank, keine Blockwerte.",
        he = "Armor counts more than for any other tank; no block stats.",
        w = { STA = 1.00, AGI = 0.85, ARMOR = 0.10, DODGE = 0.80, DEF = 0.40,
              STR = 0.50, AP = 0.20, HIT = 0.50, EXP = 0.70, CRIT = 0.30,
              DPS = 2.0 },
    },
    {
        id = "DRUID_RESTO", tab = 3, auto = true, role = "HEAL",
        de = "Wiederherstellung (Heiler)", en = "Restoration (healer)",
        hd = "Tempo und Willenskraft fuer den Verjuengungs-Durchsatz.",
        he = "Haste and spirit for rejuvenation throughput.",
        w = { SP = 1.00, INT = 0.65, SPI = 0.50, HASTE = 0.90, CRIT = 0.55,
              MP5 = 0.85, STA = 0.15, DPS = 0.3 },
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
    end
end

for class, list in pairs(EG.SPECS) do
    Prepare(list, class)
end
Prepare(EG.SPECS_ANY, "ANY")
