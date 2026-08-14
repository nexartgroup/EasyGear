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
| `/egprofile` | Profilübersicht, Vergleich und Editor |
| `/eg profile list` | alle Profile im Chat |
| `/eg profile <id\|auto>` | Profil aktivieren |
| `/eg pvp` | PvP-Modus umschalten |
| `/eg role <auto\|tank\|melee\|ranged\|caster\|heal>` | wählt das erste Profil der Klasse mit dieser Rolle |
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

Die Gewichte kommen aus einem **Profil**. Siehe unten.

### Verzauberungen und Sockelsteine

`GetItemStats()` liest nur die Basiswerte aus dem Itemlink. Verzauberungen
stehen in `SpellItemEnchantment.dbc` und tauchen dort **nicht** auf — eine
verzauberte Waffe lieferte damit dieselben Werte wie eine unverzauberte.

Deshalb wird zusätzlich der Tooltip ausgewertet, denn dort steht die
Verzauberung als eigene grüne Zeile. WotLK benutzt zwei Formate, beide werden
erkannt:

```
+55 Ausdauer                                 Primärattribute, Sockelsteine
Ausrüsten: Verbessert Tempowertung um 55.    Wertungen
```

Die Muster werden zur Laufzeit aus den lokalisierten Blizzard-Globals gebaut
(`ITEM_MOD_*_SHORT` und `ITEM_MOD_*`), sind also nicht auf eine Sprache
festgelegt. Sie sind vorne und hinten verankert — sonst würde ein Proc-Text wie
*„Erhöht Eure Angriffskraft um 340 für 10 Sek."* als dauerhafter Wert gezählt.

Zusammengeführt wird über das Maximum aus Basiswert und Tooltipsumme: Der
Tooltip listet Basis, Verzauberung und Steine in getrennten Zeilen, seine Summe
ist also normalerweise der größere Wert. Scheitert das Auslesen einer Zeile,
bleibt der Basiswert erhalten — so kann nichts verlorengehen und nichts doppelt
gezählt werden.

Weitere Vorkehrungen gegen Doppelzählung:

* **Graue Zeilen** werden übersprungen — das sind inaktive Sockel- und Setboni.
* **Ab der Set-Kopfzeile** (`Name (2/5)`) wird abgebrochen, weil Setboni an
  anderen Teilen hängen und sonst mehrfach in die Summe gingen.
* **Rote Zeilen** zählen nicht; sie dienen weiter der Verwendbarkeitsprüfung.

Ob ein Item verzaubert oder gesockelt ist, steht jetzt im Vergleichsfenster und
in der Chat-Ausgabe. Da alle drei Tooltip-Auswertungen (Verwendbarkeit,
Waffen-DPS, Werte) in einem Durchlauf passieren und pro Itemlink
zwischengespeichert werden, ist das trotz des Mehraufwands schneller als vorher.

---

## Profile (`/EGPROFILE`)

36 Profile sind eingebaut: für jede der 10 Klassen jeder Talentbaum, plus eigene
Einträge dort, wo sich die Gewichtung **innerhalb** eines Baums real
unterscheidet — Blut-Tank gegen Blut-DD, Frost beidhändig gegen Zweihand,
Wildheit Katze gegen Bär. Dazu zwei klassenunabhängige: „Levelphase (neutral)"
und „Nur Gegenstandsstufe".

| Klasse | Profile |
| --- | --- |
| Krieger | Waffen (Zweihand), Furor (beidhändig), Schutz (Tank) |
| Paladin | Heilig, Schutz (Tank), Vergeltung |
| Jäger | Tierherrschaft, Treffsicherheit, Überleben |
| Schurke | Meucheln (Dolche), Kampf (Schwerter), Täuschung |
| Priester | Disziplin, Heilig, Schatten |
| Todesritter | Blut (Tank), Blut (Zweihand-DD), Frost (beidhändig), Frost (Zweihand), Frost (Tank), Unheilig |
| Schamane | Elementar, Verstärkung, Wiederherstellung |
| Magier | Arkan, Feuer, Frost |
| Hexenmeister | Gebrechen, Dämonologie, Zerstörung |
| Druide | Gleichgewicht, Wildheit Katze, Wildheit Bär, Wiederherstellung |

Die Unterschiede sind keine Kosmetik. Beispiele: Frost-Todesritter beidhändig
gewichtet Trefferwertung mit 1.40, die Zweihandvariante mit 1.15 — beidhändig
braucht schlicht mehr Treffer. Der Bär gewichtet Rüstung mit 0.10 und hat gar
keine Blockwerte, der Schutzpaladin dagegen Blockwert mit 0.55.

**Auswahl.** Ohne Zutun wird der Talentbaum mit den meisten Punkten erkannt und
das dortige Standardprofil genommen. Wo ein Baum mehrere Profile hat, ist eines
als Standard markiert (Blut → Tank, Wildheit → Katze, Frost-DK → beidhändig);
die Alternativen wählst du im Fenster. Unter 5 gesetzten Talentpunkten greift
„Levelphase (neutral)".

**Fenster (`/EGPROFILE`).** Aufbau wie der Item-Vergleich, nur mit Profilen
statt Items:

```
        Vergleichsprofil                    Aktives Profil
        Schutz (Tank)                       Waffen (Zweihand)

Attribut        Wert  Gewicht  Punkte   Attribut        Wert  Gewicht  Punkte
Ausdauer        1450  x 1.00   1450     Ausdauer        1450  x 0.10    145
Verteidigung     540  x 1.20    648     Verteidigung     540  x 0.00      0
Stärke           980  x 0.55    539     Stärke           980  x 1.00    980
...

Ausrüstungswertung     7755     Ausrüstungswertung     7710
```

Links das gewählte Vergleichsprofil (Klasse und Profil über die beiden
Auswahlfelder oben), rechts immer das **aktuell aktive**. Die Wertespalte ist auf
beiden Seiten identisch — es sind die Summen deiner angelegten Ausrüstung.
Unterschiedlich sind Gewicht und Punkte. Damit siehst du direkt, was deine
aktuelle Ausrüstung unter einem anderen Build wert wäre und welche Attribute die
Punkte tragen.

Beide Seiten benutzen **eine gemeinsame Zeilenliste** (Vereinigung beider
Gewichtssätze), damit dasselbe Attribut links und rechts auf derselben Zeile
steht. Die Punktespalte ist grün, wo diese Seite mehr Punkte holt, und rot, wo
weniger. Mausrad scrollt, falls die Liste länger wird als das Fenster.

Über die Klassenauswahl erreichst du auch die Profile **anderer** Klassen — als
Nachschlagewerk oder als Ausgangspunkt für ein eigenes Profil.

> Ein Vorbehalt, den das Fenster auch selbst anzeigt: Die Gesamtsummen zweier
> Profile sind nur grob vergleichbar, weil die Gewichtssätze zwar auf das
> Primärattribut normiert, aber nicht gegeneinander geeicht sind. Ein höherer
> Gesamtwert heißt **nicht** „dieses Profil ist besser für dich". Aussagekräftig
> ist die Verteilung je Attribut.

Liegt im Item-Vergleichsfenster ein Item, steht unten zusätzlich dessen Wertung
unter beiden Profilen — du siehst also sofort, ob ein Item nur unter dem einen
Build ein Upgrade ist.

**PvP-Modus.** Ein Schalter statt 36 zusätzlicher Profile: Abhärtung bekommt
mindestens 1.00, Ausdauer wird auf das 2,5-fache angehoben. Gilt für das jeweils
aktive Profil.

**Aktivieren.** „A aktivieren" setzt das links gewählte Profil als aktives — die
rechte Seite zieht dann nach.

**Eigene Profile.** „Bearbeiten" macht aus der linken Gewichtsspalte
Eingabefelder; die Punkte und die Summe rechnen live mit, während du tippst, und
rechts steht weiter das aktive Profil als Referenz. Im Bearbeitungsmodus werden
alle Attribute gezeigt, auch die mit Gewicht 0 — so lässt sich ein bisher
ungenutztes ergänzen. Dann entweder „Als neues Profil speichern" (funktioniert
auch ausgehend von einem eingebauten Profil) oder bei einem eigenen Profil
„Speichern" zum Überschreiben. Eigene Profile sind mit `*` markiert, gelten
accountweit und stehen sofort in der Auswahl.

### Questbelohnungen

Gewertet wird nach dem **Zugewinn**, nicht nach der absoluten Wertung. Der
Unterschied ist erheblich, wenn ein Slot noch leer ist:

```
Mondweidenfellumhang    Wertung 0.51   angelegt 0.30   Zugewinn +0.21
Mondweidenlederstiefel  Wertung 0.61   angelegt 0.00   Zugewinn +0.61   <- gewählt
```

Ist keine Belohnung ein Upgrade, entscheidet der Gesamtverkaufswert
(Stückpreis × Anzahl).

### Waffenhand und Schildhand

Solange eine Zweihandwaffe geführt wird, ist die Schildhand nicht frei — sie wird
von der Zweihandwaffe belegt. Ein Schild oder Nebenhand-Item anzulegen kostet
also die komplette Zweihandwaffe. Verglichen wird deshalb gegen **Waffenhand
plus Schildhand zusammen**, nicht gegen den scheinbar leeren Slot 17; sonst
gälte jedes beliebige Nebenhand-Item als Verbesserung, weil ein leerer Slot mit
0 Punkten bewertet wird. Ein Erbstück in der Waffenhand schützt in dieser
Konstellation also auch gegen Nebenhand-Vorschläge.

Eine Einhandwaffe geht bei geführter Zweihandwaffe nur in die Waffenhand und
wird auch nur gegen diese gerechnet — beidhändig führen ließe sie sich erst nach
dem Ablegen des Zweihänders.

| Kandidat | angelegt | verglichen gegen |
| --- | --- | --- |
| Schild / Nebenhand | Zweihänder | Waffenhand + Schildhand |
| Schild / Nebenhand | Einhandwaffe | Schildhand |
| Einhandwaffe | Zweihänder | Waffenhand |
| Einhandwaffe | Einhandwaffe + Nebenhand | schwächerer der beiden Slots |
| Zweihandwaffe | beliebig | Waffenhand + Schildhand |

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
* **Questbelohnungen wurden nach absoluter Wertung gewählt** statt nach Zugewinn. Ein Item, das einen leeren Slot füllt, verlor damit gegen ein minimal höher bewertetes, das bereits Vorhandenes ersetzt.
* **Zauber- und Heilprofile hatten gar kein Rüstungsgewicht.** Auf niedrigen Stufen, wo Items oft nur Rüstung und sonst nichts tragen, blieb dadurch die Gegenstandsstufe als einziges Unterscheidungsmerkmal.
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

* Verzauberungen ohne Zahlenwert (z. B. *Kreuzfahrer*, *Berserker*) lassen sich nicht bewerten und fließen nicht ein.
* Wertungen liegen auf niedrigen Stufen im Bereich 0–5 und auf Stufe 80 im dreistelligen Bereich. Die Zahl ist eine relative Rangfolge, kein absoluter Wert — vergleichbar sind nur Wertungen desselben Charakters zum selben Zeitpunkt.
* Die Wertung ist eine Heuristik. Trefferwertungs-Obergrenzen, Setboni, Prozeduren und Waffengeschwindigkeit werden nicht bewertet.
* Erbstückwerte stammen aus dem Tooltip und sind Näherungswerte.
* Wie in 1.x kann der Client identische Exemplare desselben Items nicht auseinanderhalten; `/egupclean` arbeitet deshalb mit den erfassten Mengen.
* Bei stark abweichenden Custom-Cores können Item-IDs und die `.additem`-Syntax abweichen.
