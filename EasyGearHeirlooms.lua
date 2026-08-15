--[[---------------------------------------------------------------------------
    EasyGear 2.6.0 - Erbstuecke (WotLK 3.3.5a)

    Alle 37 Erbstuecke aus 3.3.5a. Die IDs sind gegen den Server geprueft.

    Wechselnde Ruestungsklasse
    --------------------------
    Erbstueck-Ruestung wechselt mit Stufe 40 die Klasse:

        Kette  zaehlt unterhalb von Stufe 40 als Leder
        Platte zaehlt unterhalb von Stufe 40 als Kette

    Ein Schamane kann die "Todesbotenbrustplatte des Champions" also ab
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
      name     gepruefter deutscher Name (angezeigt wird der Name aus dem
               Client, dieser dient der Kontrolle)
      loc      erwarteter Ausruestungsplatz
      armor    Ruestungsklasse ab Stufe 40
      weapon   Waffentyp
      faction  nur fuer die PvP-Insignien
-----------------------------------------------------------------------------]]

local EG = EasyGear
if not EG then return end

EG.HEIRLOOMS = {

    ------------------------------------------------------------------- SCHMUCK
    [42991] = { name = "Schnelle Hand der Gerechtigkeit", loc = "INVTYPE_TRINKET", stat = "MELEE" },
    [42992] = { name = "Scharfes Auge der Bestie", loc = "INVTYPE_TRINKET", stat = "CASTER" },
    [44098] = { name = "Geerbtes Insigne der Allianz", loc = "INVTYPE_TRINKET", stat = "PVP", faction = "Alliance" },
    [44097] = { name = "Geerbtes Insigne der Horde", loc = "INVTYPE_TRINKET", stat = "PVP", faction = "Horde" },

    --------------------------------------------------------------------- STOFF
    [48691] = { name = "Zerlumpte Robe der Furcht", loc = "INVTYPE_CHEST", armor = "CLOTH", stat = "CASTER" },
    [42985] = { name = "Zerlumpter Mantel der Furcht", loc = "INVTYPE_SHOULDER", armor = "CLOTH", stat = "CASTER" },
    [44107] = { name = "Exquisiter Mantel des blinden Sehers", loc = "INVTYPE_SHOULDER", armor = "CLOTH", stat = "CASTER" },

    --------------------------------------------------------------------- LEDER
    [48689] = { name = "Befleckte Tunika der Schattenkunst", loc = "INVTYPE_CHEST", armor = "LEATHER", stat = "MELEE_AGI" },
    [42952] = { name = "Befleckte Schiftung der Schattenkunst", loc = "INVTYPE_SHOULDER", armor = "LEATHER", stat = "MELEE_AGI" },
    [44103] = { name = "Au\195\159ergew\195\182hnliche Sturmschleierschultern", loc = "INVTYPE_SHOULDER", armor = "LEATHER", stat = "MELEE_AGI" },
    [48687] = { name = "Geputzte Eisenfederbrustplatte", loc = "INVTYPE_CHEST", armor = "LEATHER", stat = "CASTER" },
    [42984] = { name = "Geputzte Eisenfederschultern", loc = "INVTYPE_SHOULDER", armor = "LEATHER", stat = "CASTER" },
    [44105] = { name = "Ausdauernde Schiftung des ungez\195\164hmten Herzens", loc = "INVTYPE_SHOULDER", armor = "LEATHER", stat = "CASTER" },

    --------------------------------------------------------------------- KETTE
    [48677] = { name = "Todesbotenbrustplatte des Champions", loc = "INVTYPE_CHEST", armor = "MAIL", stat = "MELEE_AGI" },
    [42950] = { name = "Champion Herods Schulter", loc = "INVTYPE_SHOULDER", armor = "MAIL", stat = "MELEE_AGI" },
    [44101] = { name = "Wertvoller Mantel der Tierherrschaft", loc = "INVTYPE_SHOULDER", armor = "MAIL", stat = "MELEE_AGI" },
    [48683] = { name = "Mystische Weste der Elemente", loc = "INVTYPE_CHEST", armor = "MAIL", stat = "CASTER" },
    [42951] = { name = "Mystische Schulterst\195\188cke der Elemente", loc = "INVTYPE_SHOULDER", armor = "MAIL", stat = "CASTER" },
    [44102] = { name = "Alte Schulterst\195\188cke der f\195\188nf Donner", loc = "INVTYPE_SHOULDER", armor = "MAIL", stat = "CASTER" },

    -------------------------------------------------------------------- PLATTE
    [48685] = { name = "Polierte Brustplatte der Ehre", loc = "INVTYPE_CHEST", armor = "PLATE", stat = "MELEE_STR" },
    [42949] = { name = "Polierte Schiftung der Ehre", loc = "INVTYPE_SHOULDER", armor = "PLATE", stat = "MELEE_STR" },
    [44099] = { name = "Verst\195\164rkte Palisadenschulterst\195\188cke", loc = "INVTYPE_SHOULDER", armor = "PLATE", stat = "MELEE_STR" },
    [44100] = { name = "Makellose Schiftung des Lichts", loc = "INVTYPE_SHOULDER", armor = "PLATE", stat = "HEAL" },

    ------------------------------------------------------------- EINHANDWAFFEN
    [42944] = { name = "Ausbalancierter Herzsucher", loc = "INVTYPE_WEAPON", weapon = "DAGGER", stat = "MELEE_AGI" },
    [44091] = { name = "Gesch\195\164rfter Scharlachroter Kris", loc = "INVTYPE_WEAPON", weapon = "DAGGER", stat = "MELEE_AGI" },
    [42945] = { name = "Des ehrw\195\188rdigen Dal'Rends hochheilige Attacke", loc = "INVTYPE_WEAPONMAINHAND", weapon = "SWORD1", stat = "MELEE_AGI" },
    [44096] = { name = "Kampferprobte Hauklinge", loc = "INVTYPE_WEAPON", weapon = "SWORD1", stat = "MELEE_STR" },
    [48716] = { name = "Ehrw\195\188rdige Masse von McGowan", loc = "INVTYPE_WEAPON", weapon = "MACE1", stat = "MELEE_STR" },
    [42948] = { name = "Frommer Aurasteinhammer", loc = "INVTYPE_WEAPONMAINHAND", weapon = "MACE1", stat = "HEAL" },
    [44094] = { name = "Der gesegnete Hammer der Anmut", loc = "INVTYPE_WEAPONMAINHAND", weapon = "MACE1", stat = "HEAL" },

    ------------------------------------------------------------ ZWEIHANDWAFFEN
    [42943] = { name = "Blutbefleckter Arkanitschnitter", loc = "INVTYPE_2HWEAPON", weapon = "AXE2", stat = "MELEE_STR" },
    [44092] = { name = "Neugeschmiedeter Echtsilberchampion", loc = "INVTYPE_2HWEAPON", weapon = "SWORD2", stat = "MELEE_STR" },
    [48718] = { name = "Wiederverwendeter Lavagreifer", loc = "INVTYPE_2HWEAPON", weapon = "MACE2", stat = "CASTER" },
    [42947] = { name = "Attacke des w\195\188rdevollen Direktors", loc = "INVTYPE_2HWEAPON", weapon = "STAFF", stat = "CASTER" },
    [44095] = { name = "Gro\195\159stab des Jordan", loc = "INVTYPE_2HWEAPON", weapon = "STAFF", stat = "CASTER" },

    ------------------------------------------------------------------- DISTANZ
    [42946] = { name = "Verzauberter antiker Knochenbogen", loc = "INVTYPE_RANGED", weapon = "BOW", stat = "MELEE_AGI" },
    [44093] = { name = "Aufger\195\188stete zwergische Handkanone", loc = "INVTYPE_RANGEDRIGHT", weapon = "GUN", stat = "MELEE_AGI" },
    ---------------------------------------------------------------- SONSTIGES
    -- Nicht Teil der geprueften Erbstueckliste: der Ring stammt vom
    -- Dunkelmond-Jahrmarkt, die Taschen sind ueberhaupt keine Erbstuecke.
    -- Beide waren im urspruenglichen EasyGear enthalten und bleiben
    -- deshalb drin. Meldet "/egup verify" sie als fehlend, hier loeschen.
    [50255] = { name = "Ring des Schreckenspiraten", loc = "INVTYPE_FINGER", stat = "ANY", unverified = true },
    [51809] = { name = "Tragbares Loch", loc = "", bag = true, unverified = true },
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
-- mindestens eine ihrer Spezialisierungen taugt. Anlegbar allein reicht
-- nicht: ein Beweglichkeitsdolch geht an einen Priester, nuetzt ihm aber
-- nichts.
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

    HUNTER = {
        { id = 42991, count = 2 },
        { id = 48677 }, { id = 42950 }, { id = 44101 },      -- Kette Beweglichkeit
        { id = 42946 }, { id = 44093 },                      -- Bogen und Gewehr
        { id = 42944 }, { id = 44091 },                      -- Dolche
        { id = 42945 }, { id = 44096 },                      -- Einhandschwerter
        { id = 42943 }, { id = 44092 },                      -- Zweihand
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
------------------------------------------------------------------------------
