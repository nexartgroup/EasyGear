# EasyGear 2.0

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
            ├── EasyGear.lua
            ├── EasyGearGUI.lua
            ├── EasyGear.toc
            └── README.md
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
| `/eg role <auto\|tank\|melee\|ranged\|caster\|heal>` | Rollenprofil festlegen |
| `/eg ilvl <zahl>` | Gewicht der Gegenstandsstufe (auf Stufe 80) |
| `/eg ilvlscale <on\|off>` | Skalierung der Gegenstandsstufe mit der Charakterstufe |
| `/eg mindelta <zahl>` | absoluter Mindestvorsprung für „Verbesserung" |
| `/eg mindeltapct <prozent>` | relativer Mindestvorsprung (Standard 1 %) |
| `/eg icons` / `quest` / `tooltip` / `heirloom` | Anzeigen ein-/ausschalten |
| `/eg scale <0.5–2.0>` | Fenstergröße |
| `/eg status` | aktuelle Einstellungen |
| `/eg reset` | Standardwerte |
| `/egup` | GM: Klassenpaket an das Ziel |
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

Die Gewichte kommen aus einem **Rollenprofil**. Das Profil wird automatisch aus dem Talentbaum mit den meisten Punkten abgeleitet (z. B. Paladin Schutz → Tank, Schamane Elementar → Caster) und lässt sich mit `/eg role` oder dem Knopf im Fenster überschreiben. Unter Stufe 15 greift ein neutrales Anfängerprofil.

Eigene Gewichte pro Charakter sind über `EasyGearCharDB.weights` möglich, z. B.:

```lua
EasyGearCharDB.weights = { ITEM_MOD_HIT_RATING_SHORT = 2.0 }
```

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

Item-IDs stehen in der Tabelle `EGUP_ITEMS`, die Klassenzuordnung in `EGUP_PACKAGES` — beides oben in `EasyGear.lua`.

---

## Bekannte Grenzen

* Wertungen liegen auf niedrigen Stufen im Bereich 0–5 und auf Stufe 80 im dreistelligen Bereich. Die Zahl ist eine relative Rangfolge, kein absoluter Wert — vergleichbar sind nur Wertungen desselben Charakters zum selben Zeitpunkt.
* Die Wertung ist eine Heuristik. Trefferwertungs-Obergrenzen, Setboni, Prozeduren und Waffengeschwindigkeit werden nicht bewertet.
* Erbstückwerte stammen aus dem Tooltip und sind Näherungswerte.
* Wie in 1.x kann der Client identische Exemplare desselben Items nicht auseinanderhalten; `/egupclean` arbeitet deshalb mit den erfassten Mengen.
* Bei stark abweichenden Custom-Cores können Item-IDs und die `.additem`-Syntax abweichen.
