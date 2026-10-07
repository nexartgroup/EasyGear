--[[---------------------------------------------------------------------------
    EasyGear 3.0.0 - Erbstuecke (WotLK 3.3.5a)

    Alle 37 Erbstuecke aus 3.3.5a. Die IDs sind gegen den Server geprueft;
    /egup verify prueft sie jederzeit erneut gegen den Client und kontrolliert
    zusaetzlich jedes Klassenpaket (siehe unten).

    Wechselnde Ruestungsklasse
    --------------------------
    Erbstueck-Ruestung wechselt mit Stufe 40 die Klasse:

        Kette  zaehlt unterhalb von Stufe 40 als Leder
        Platte zaehlt unterhalb von Stufe 40 als Kette

    Ein Schamane kann die Todesbotenbrustplatte des Champions also ab
    Stufe 1 tragen, obwohl sie als Kette gefuehrt wird. Krieger und Paladin
    tragen die Plattenteile von Anfang an, weil sie unter 40 als Kette
    gelten und beide Klassen Kette ab Stufe 1 beherrschen.

    Deshalb stehen hier keine doppelten Ruestungssaetze: die
    Zielruestungsklasse reicht ueber die gesamte Levelphase.

    Zwei Schulterreihen
    -------------------
    Die 429xx-Schultern stammen von den Abzeichen-Haendlern, die 441xx vom
    Argentumturnier. Sie sind gleichwertige Alternativen fuer denselben
    Platz und werden beide vergeben - je nachdem, welchen Haendler ein
    Charakter erreicht. Ausnahme ist 44100: die einzige Plattenschulter mit
    Intelligenz, damit die einzige fuer einen heiligen Paladin.

    Felder
    ------
      en       englischer Name (angezeigt wird der Name aus dem Client, dieser
               dient nur als Notanzeige und zur Kontrolle)
      loc      erwarteter Ausruestungsplatz
      armor    Ruestungsklasse ab Stufe 40
      weapon   Waffentyp
      stat     Hauptattribut: MELEE_STR, MELEE_AGI, CASTER (Intelligenz /
               Zaubermacht), HEAL (wie CASTER, fuer Heiler gedacht), MELEE
               (Schmuck: Angriffskraft), PVP, ANY
      faction  nur fuer die PvP-Insignien
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

EG.HEIRLOOMS = {

    ------------------------------------------------------------------- SCHMUCK
    [42991] = { en = "Swift Hand of Justice", loc = "INVTYPE_TRINKET", stat = "MELEE" },
    [42992] = { en = "Discerning Eye of the Beast", loc = "INVTYPE_TRINKET", stat = "CASTER" },
    [44098] = { en = "Inherited Insignia of the Alliance", loc = "INVTYPE_TRINKET", stat = "PVP", faction = "Alliance" },
    [44097] = { en = "Inherited Insignia of the Horde", loc = "INVTYPE_TRINKET", stat = "PVP", faction = "Horde" },

    --------------------------------------------------------------------- STOFF
    [48691] = { en = "Tattered Dreadmist Robe", loc = "INVTYPE_CHEST", armor = "CLOTH", stat = "CASTER" },
    [42985] = { en = "Tattered Dreadmist Mantle", loc = "INVTYPE_SHOULDER", armor = "CLOTH", stat = "CASTER" },
    [44107] = { en = "Exquisite Sunderseer Mantle", loc = "INVTYPE_SHOULDER", armor = "CLOTH", stat = "CASTER" },

    --------------------------------------------------------------------- LEDER
    [48689] = { en = "Stained Shadowcraft Tunic", loc = "INVTYPE_CHEST", armor = "LEATHER", stat = "MELEE_AGI" },
    [42952] = { en = "Stained Shadowcraft Spaulders", loc = "INVTYPE_SHOULDER", armor = "LEATHER", stat = "MELEE_AGI" },
    [44103] = { en = "Exceptional Stormshroud Shoulders", loc = "INVTYPE_SHOULDER", armor = "LEATHER", stat = "MELEE_AGI" },
    [48687] = { en = "Preened Ironfeather Breastplate", loc = "INVTYPE_CHEST", armor = "LEATHER", stat = "CASTER" },
    [42984] = { en = "Preened Ironfeather Shoulders", loc = "INVTYPE_SHOULDER", armor = "LEATHER", stat = "CASTER" },
    [44105] = { en = "Lasting Feralheart Spaulders", loc = "INVTYPE_SHOULDER", armor = "LEATHER", stat = "CASTER" },

    --------------------------------------------------------------------- KETTE
    [48677] = { en = "Champion's Deathdealer Breastplate", loc = "INVTYPE_CHEST", armor = "MAIL", stat = "MELEE_AGI" },
    [42950] = { en = "Champion Herod's Shoulder", loc = "INVTYPE_SHOULDER", armor = "MAIL", stat = "MELEE_AGI" },
    [44101] = { en = "Prized Beastmaster's Mantle", loc = "INVTYPE_SHOULDER", armor = "MAIL", stat = "MELEE_AGI" },
    [48683] = { en = "Mystical Vest of Elements", loc = "INVTYPE_CHEST", armor = "MAIL", stat = "CASTER" },
    [42951] = { en = "Mystical Pauldrons of Elements", loc = "INVTYPE_SHOULDER", armor = "MAIL", stat = "CASTER" },
    [44102] = { en = "Aged Pauldrons of The Five Thunders", loc = "INVTYPE_SHOULDER", armor = "MAIL", stat = "CASTER" },

    -------------------------------------------------------------------- PLATTE
    [48685] = { en = "Polished Breastplate of Valor", loc = "INVTYPE_CHEST", armor = "PLATE", stat = "MELEE_STR" },
    [42949] = { en = "Polished Spaulders of Valor", loc = "INVTYPE_SHOULDER", armor = "PLATE", stat = "MELEE_STR" },
    [44099] = { en = "Strengthened Stockade Pauldrons", loc = "INVTYPE_SHOULDER", armor = "PLATE", stat = "MELEE_STR" },
    [44100] = { en = "Pristine Lightforge Spaulders", loc = "INVTYPE_SHOULDER", armor = "PLATE", stat = "HEAL" },

    ------------------------------------------------------------- EINHANDWAFFEN
    [42944] = { en = "Balanced Heartseeker", loc = "INVTYPE_WEAPON", weapon = "DAGGER", stat = "MELEE_AGI" },
    [44091] = { en = "Sharpened Scarlet Kris", loc = "INVTYPE_WEAPON", weapon = "DAGGER", stat = "MELEE_AGI" },
    [42945] = { en = "Venerable Dal'Rend's Sacred Charge", loc = "INVTYPE_WEAPONMAINHAND", weapon = "SWORD1", stat = "MELEE_AGI" },
    [44096] = { en = "Battleworn Thrash Blade", loc = "INVTYPE_WEAPON", weapon = "SWORD1", stat = "MELEE_STR" },
    [48716] = { en = "Venerable Mass of McGowan", loc = "INVTYPE_WEAPON", weapon = "MACE1", stat = "MELEE_STR" },
    [42948] = { en = "Devout Aurastone Hammer", loc = "INVTYPE_WEAPONMAINHAND", weapon = "MACE1", stat = "HEAL" },
    [44094] = { en = "The Blessed Hammer of Grace", loc = "INVTYPE_WEAPONMAINHAND", weapon = "MACE1", stat = "HEAL" },

    ------------------------------------------------------------ ZWEIHANDWAFFEN
    [42943] = { en = "Bloodied Arcanite Reaper", loc = "INVTYPE_2HWEAPON", weapon = "AXE2", stat = "MELEE_STR" },
    [44092] = { en = "Reforged Truesilver Champion", loc = "INVTYPE_2HWEAPON", weapon = "SWORD2", stat = "MELEE_STR" },
    [48718] = { en = "Repurposed Lava Dredger", loc = "INVTYPE_2HWEAPON", weapon = "MACE2", stat = "CASTER" },
    [42947] = { en = "Dignified Headmaster's Charge", loc = "INVTYPE_2HWEAPON", weapon = "STAFF", stat = "CASTER" },
    [44095] = { en = "Grand Staff of Jordan", loc = "INVTYPE_2HWEAPON", weapon = "STAFF", stat = "CASTER" },

    ------------------------------------------------------------------- DISTANZ
    [42946] = { en = "Charmed Ancient Bone Bow", loc = "INVTYPE_RANGED", weapon = "BOW", stat = "MELEE_AGI" },
    [44093] = { en = "Upgraded Dwarven Hand Cannon", loc = "INVTYPE_RANGEDRIGHT", weapon = "GUN", stat = "MELEE_AGI" },

    ---------------------------------------------------------------- SONSTIGES
    -- Nicht Teil der geprueften Erbstueckliste: der Ring ist ein Zusatz-Item
    -- (nicht jeder Server fuehrt ihn), die Taschen sind ueberhaupt keine
    -- Erbstuecke. Beide waren im urspruenglichen EasyGear enthalten und
    -- bleiben deshalb drin. Meldet "/egup verify" sie als fehlend, hier
    -- loeschen.
    [50255] = { en = "Dread Pirate Ring", loc = "INVTYPE_FINGER", stat = "ANY", unverified = true },
    [51809] = { en = "Portable Hole", loc = "", bag = true, unverified = true },
}

------------------------------------------------------------------------------
-- Universell: geht an jede Klasse
------------------------------------------------------------------------------

EG.HEIRLOOM_UNIVERSAL = {
    { id = 50255, count = 1 },   -- Ring
    { id = 51809, count = 4 },   -- Taschen
    { id = 44098, count = 1 },   -- Insigne Allianz  (nach Fraktion gefiltert)
    { id = 44097, count = 1 },   -- Insigne Horde    (nach Fraktion gefiltert)
}

------------------------------------------------------------------------------
-- Klassenpakete
--
-- Aufgenommen wird ein Stueck, wenn die Klasse es fuehren kann UND es fuer
-- mindestens eines ihrer Profile taugt (Hauptattribut mit Gewicht >= 0.3 in
-- einem Klassenprofil). Anlegbar allein reicht nicht: ein Beweglichkeitsdolch
-- geht an einen Priester, nuetzt ihm aber nichts.
--
-- /egup verify prueft genau diese Regel fuer jedes Paket und meldet
--   * unbrauchbare Stuecke   (Klasse kann sie nicht tragen)
--   * ueberfluessige Stuecke (tragbar, aber ohne passendes Attribut)
--   * fehlende Stuecke       (tragbar und passend, aber nicht im Paket)
------------------------------------------------------------------------------

EG.HEIRLOOM_PACKAGES = {

    WARRIOR = {
        { id = 42991, count = 2 },
        { id = 48685 }, { id = 42949 }, { id = 44099 },      -- Platte
        { id = 42943 }, { id = 44092 },                      -- Zweihand
        { id = 48716 }, { id = 42945 }, { id = 44096 },      -- Einhand
        { id = 42946 }, { id = 44093 },                      -- Distanzplatz
    },

    PALADIN = {
        { id = 42991 }, { id = 42992 },
        { id = 48685 }, { id = 42949 }, { id = 44099 },      -- Platte Staerke
        { id = 44100 },                                      -- Platte Intelligenz
        { id = 48683 },                                      -- Kette Intelligenz (Brust)
        { id = 42943 }, { id = 44092 },                      -- Zweihand Staerke
        { id = 48718 },                                      -- Zweihandstreitkolben Int
        { id = 48716 }, { id = 44096 }, { id = 42945 },
        { id = 42948 }, { id = 44094 },                      -- Heilerstreitkolben
    },

    DEATHKNIGHT = {
        { id = 42991, count = 2 },
        { id = 48685 }, { id = 42949 }, { id = 44099 },
        { id = 42943 }, { id = 44092 },
        { id = 48716 }, { id = 42945 }, { id = 44096 },
    },

    -- Jaeger: Staerke bringt nur Nahkampf-Angriffskraft und nuetzt einem
    -- Fernkaempfer nicht - Staerkewaffen (Zweihaender, 44096) fehlen deshalb.
    HUNTER = {
        { id = 42991, count = 2 },
        { id = 48677 }, { id = 42950 }, { id = 44101 },      -- Kette Beweglichkeit
        { id = 42946 }, { id = 44093 },                      -- Bogen und Gewehr
        { id = 42944 }, { id = 44091 },                      -- Dolche
        { id = 42945 },                                      -- Einhandschwert
    },

    SHAMAN = {
        { id = 42991 }, { id = 42992 },
        { id = 48677 }, { id = 42950 }, { id = 44101 },      -- Kette Beweglichkeit
        { id = 48683 }, { id = 42951 }, { id = 44102 },      -- Kette Intelligenz
        { id = 42943 },                                      -- Zweihandaxt
        { id = 48718 },                                      -- Zweihandstreitkolben Int
        { id = 48716 }, { id = 42948 }, { id = 44094 },
        { id = 42944 }, { id = 44091 },                      -- Dolche
        { id = 42947 }, { id = 44095 },                      -- Staebe
    },

    ROGUE = {
        { id = 42991, count = 2 },
        { id = 48689 }, { id = 42952 }, { id = 44103 },      -- Leder
        { id = 42944 }, { id = 44091 },                      -- Dolche
        { id = 42945 }, { id = 44096 }, { id = 48716 },
        { id = 42946 }, { id = 44093 },                      -- Distanzplatz
    },

    DRUID = {
        { id = 42991 }, { id = 42992 },
        { id = 48689 }, { id = 42952 }, { id = 44103 },      -- Leder Beweglichkeit
        { id = 48687 }, { id = 42984 }, { id = 44105 },      -- Leder Intelligenz
        { id = 48718 },                                      -- Zweihandstreitkolben
        { id = 48716 }, { id = 42948 }, { id = 44094 },
        { id = 42944 }, { id = 44091 },                      -- Dolche
        { id = 42947 }, { id = 44095 },                      -- Staebe
    },

    PRIEST = {
        { id = 42992, count = 2 },
        { id = 48691 }, { id = 42985 }, { id = 44107 },      -- Stoff
        { id = 42948 }, { id = 44094 },                      -- Einhandstreitkolben
        { id = 42947 }, { id = 44095 },                      -- Staebe
    },

    MAGE = {
        { id = 42992, count = 2 },
        { id = 48691 }, { id = 42985 }, { id = 44107 },
        { id = 42947 }, { id = 44095 },
    },

    WARLOCK = {
        { id = 42992, count = 2 },
        { id = 48691 }, { id = 42985 }, { id = 44107 },
        { id = 42947 }, { id = 44095 },
    },
}

------------------------------------------------------------------------------
-- Bewusst nicht vergeben
--
--   Priester/Magier/Hexenmeister  Dolche und Einhandschwerter tragen
--                                 Beweglichkeit oder Staerke: anlegbar,
--                                 aber wertlos.
--   Magier/Hexenmeister           48718 ist ein Zweihandstreitkolben und
--                                 fuer beide nicht fuehrbar.
--   Paladin/Todesritter           keine Staebe, Dolche, Distanzwaffen.
--   Druide                        keine Schwerter, Aexte, Distanzwaffen.
--   Schamane                      keine Schwerter - deshalb kein 44092
--                                 und kein 42945/44096.
--   Krieger/Todesritter           48718 traegt Intelligenz.
--   Jaeger                        Staerkewaffen (42943, 44092, 44096).
------------------------------------------------------------------------------
