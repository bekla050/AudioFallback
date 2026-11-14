# UI-Feinschliff: Menüleistenmenü und Einstellungsfenster

Stand: 2026-11-14. Branch `bekla050/mussel`. Ausgangslage: `swift test` grün (36 Tests).

## Anlass (Rückmeldung Jens)

Menüleistenmenü:

1. Zwischenüberschriften schlecht lesbar, keine visuelle Hierarchie.
2. Das Menü schließt sich manchmal, nachdem der Lautstärkeregler bedient wurde.
3. Nicht erkennbar, dass die Gerätewahl im Menü nur eine temporäre Überschreibung der
   Reihenfolge ist, und der Weg zurück zur Reihenfolge fehlt.

Einstellungsfenster:

4. Scrollbalken liegt unter macOS 26 teilweise über den Gerätezeilen.
5. Gescrollte Zeilen werden oben und unten hart abgeschnitten.
6. Funktionsweise wird nicht erklärt.
7. Optik insgesamt rau.

## Wie es heute funktioniert

- `AudioFallbackPlanner.preferredDevice` liefert das manuell gewählte Gerät
  (`manualInputUID`/`manualOutputUID`), solange es verfügbar ist, sonst das erste verfügbare
  Gerät der Prioritätsliste.
- Die manuelle Wahl entsteht nur über `AudioFallbackController.activateDeviceFromMenu`. Sie
  endet, wenn das Gerät getrennt wird (`staleManualUIDs`) oder die Reihenfolge im Fenster
  geändert wird (`moveDevice`). Einen ausdrücklichen Rückweg gibt es nicht.
- `main.swift` ruft bei jeder Änderung von `devices`, `preferences`, `currentInput`,
  `currentOutput`, `currentOutputLevel` `StatusMenuController.rebuildMenu()` auf; das ersetzt
  `statusItem.menu` durch ein neues `NSMenu` — auch während das Menü offen ist. Der Regler
  ändert `currentOutputLevel`, außerdem meldet der CoreAudio-Listener die Lautstärkeänderung
  mit 350 ms Verzögerung zurück. Vermutete Ursache für Punkt 2: Menütausch während des
  Trackings.
- `PriorityListView` rechnet Zeilen- und ScrollView-Breite von Hand (16 pt für den
  Scrollbalken reserviert, feste Breiten). Bei dauerhaft sichtbaren Scrollbalken reicht das
  nicht; vermutete Ursache für Punkt 4.

## Zielverhalten

### Begriff „manuelle Überschreibung"

Eine Überschreibung für eine Geräteart liegt vor, wenn alle Bedingungen gelten:
`autoSwitchEnabled`, `manualUID(for: kind)` gesetzt, dieses Gerät verfügbar, und es ist
**nicht** das Gerät, das die Reihenfolge allein wählen würde.

### Task 1 — Logik und Menüleistenmenü

Dateien: `Core/AudioFallbackPlanner.swift`, `Core/AudioFallbackController.swift`,
`App/StatusMenuController.swift`, `main.swift`, alle `Resources/*.lproj/Localizable.strings`,
Tests.

Logik (mit Tests in `AudioFallbackPlannerTests.swift` bzw. neuem Controller-Test, TDD):

- `AudioFallbackPlanner.priorityDevice(for:preferences:availableDevices:)`: erstes verfügbares
  Gerät der Reihenfolge, ohne Blick auf die manuelle Wahl. `preferredDevice` nutzt es.
- `AudioFallbackPlanner.manualOverrideDevice(for:preferences:availableDevices:)`: das manuell
  gewählte Gerät, wenn eine Überschreibung nach obiger Definition vorliegt, sonst `nil`.
- Controller: `priorityDevice(for:)`, `manualOverrideDevice(for:)`,
  `clearManualOverride(for:)` (setzt `manualUID` auf `nil`; über `preferences.didSet` schaltet
  `applyIfNeeded` zurück auf das Gerät der Reihenfolge).
- `activateDeviceFromMenu`: Wählt der Nutzer genau das Gerät, das die Reihenfolge ohnehin
  wählen würde, wird `manualUID` auf `nil` gesetzt statt auf dieses Gerät.

Menü:

- Ein dauerhaftes `NSMenu`, das nicht mehr ersetzt wird. Inhalt wird in
  `menuNeedsUpdate(_:)` neu aufgebaut (dort auch `controller.refresh()`, vor dem Aufbau).
  Während das Menü offen ist (`menuWillOpen`/`menuDidClose`), wird die Menüstruktur nicht
  angefasst; nur das Statusleisten-Icon und — wenn der Regler nicht gerade bedient wird — der
  Reglerwert werden nachgeführt. `rebuildMenu()` bleibt als Einstieg für `main.swift`
  erhalten und hält diese Regel ein. `makeMenu()` bleibt für die bestehenden Tests nutzbar
  (`UpdateUIIntegrationTests`), ggf. Tests anpassen.
- Zwischenüberschriften über `NSMenuItem.sectionHeader(title:)` (macOS 14) für „Mikrofone"
  und „Lautsprecher". Der bisherige Titel-Eintrag „AudioFallback" wird ebenfalls eine
  Abschnittsüberschrift („Lautstärke", neuer Schlüssel `menu.volume`).
- Bei Überschreibung stehen direkt unter den Geräten des Abschnitts (vor „Weitere …"):
  - ein deaktivierter Hinweis in kleiner Schrift: „Manuell gewählt – Reihenfolge pausiert,
    bis das Gerät getrennt wird" (`menu.manualOverrideHint`),
  - eine Aktion „Zurück zur Reihenfolge: %@" mit dem Namen des Geräts, das die Reihenfolge
    wählen würde (`menu.returnToPriority`), ruft `clearManualOverride(for:)`.
- Ohne Überschreibung erscheinen beide Einträge nicht.
- Neue Texte in allen zehn Sprachdateien übersetzen (de, en, es, fr, it, ja, ko, nl, pt-BR,
  zh-Hans); Schlüssel alphabetisch einsortiert wie bisher.

### Task 2 — Einstellungsfenster

Dateien: `UI/SettingsView.swift`, ggf. `App/StatusMenuController.swift` (nur
`SettingsWindowFactory`), Sprachdateien, `SettingsWindowLayoutTests.swift`.

- Erklärung: Über den beiden Listen eine Überschrift „Geräte-Reihenfolge" und ein kurzer Satz
  in Sekundärfarbe: „AudioFallback verwendet automatisch das oberste verfügbare Gerät. Ziehe
  Geräte, um die Reihenfolge festzulegen. Eine Auswahl im Menüleistenmenü gilt nur, bis das
  Gerät getrennt wird." „Geräte aktualisieren" wandert neben diese Überschrift.
- Die drei Schalter bleiben oben, optisch als eine Gruppe (z. B. `GroupBox` oder gleichwertig
  mit Systemfarben). Reihenfolge der Schalter unverändert.
- Spaltenköpfe „Mikrofone"/„Lautsprecher" mit SF-Symbol (`mic`, `speaker.wave.2`).
- Überschreibung sichtbar: In der betroffenen Spalte über der Liste ein Hinweisstreifen
  „‚%@' ist manuell gewählt. Die Reihenfolge ist pausiert." mit Knopf „Reihenfolge anwenden"
  (`clearManualOverride(for:)`). Das manuell aktive Gerät trägt das Etikett „Manuell" statt
  „Aktiv". Der Streifen darf die Listenhöhe verändern, aber nichts überdecken.
- Scrollbalken: keine handgerechneten Breiten mehr. Zeilen füllen die verfügbare Breite des
  ScrollView-Inhalts; Abstand zum Scrollbalken über `contentMargins` bzw. Systemverhalten,
  sodass der Balken weder bei Overlay- noch bei dauerhaft sichtbaren Scrollbalken
  („Rollbalken einblenden: Immer") über einer Zeile liegt. Breite für die Drag-Vorschau per
  `onGeometryChange` o. ä. messen. Drag-and-drop-Umsortieren muss weiter funktionieren.
- Weiche Kanten: Inhalt läuft oben und unten in eine kurze Verlaufsmaske (ca. 12 pt) aus;
  der Inhalt bekommt oben/unten so viel Innenabstand, dass die erste und letzte Zeile in
  Ruhelage voll sichtbar sind. Unter macOS 26 darf stattdessen der System-Scroll-Edge-Effekt
  verwendet werden (`#available`), wenn das Ergebnis gleichwertig ist. Deployment Target
  bleibt macOS 14.
- Zeilenoptik: Systemfarben statt fester Grauwerte (kein harter 0.56-Grau-Rand), einheitliche
  Radien und Abstände, „Aktiv"/„Manuell"/„Nicht verfügbar" als ruhige Etiketten. Kontrast in
  Hell und Dunkel beachten.
- Bildprüfung: ein durch die Umgebungsvariable `AUDIOFALLBACK_SNAPSHOT_DIR` aktivierter Test
  rendert das Fenster mit Mock-Controller (je 12 Geräte, eines nicht verfügbar, eine
  Überschreibung) hell und dunkel als PNG in dieses Verzeichnis. Ohne die Variable läuft der
  Test als No-op durch.
- Bestehende Layout-Tests: Kopf bleibt oben fixiert, Listen wachsen mit der Fensterhöhe.
  Zusicherungen, die durch die neue Struktur fachlich überholt sind, anpassen und im Report
  begründen.

## Nicht Teil der Arbeit

- Kein neues DMG, daher keine Versionserhöhung.
- Keine Änderung an Audio-Hardware-Zugriff, Sparkle, Release-Skripten.
- Keine Commits durch Subagenten; Commit erst nach Freigabe durch Jens.

## Abnahme

- `swift build` und `swift test` grün.
- Snapshot-PNGs hell/dunkel geprüft.
- Sichtprüfung in einer tart-VM mit macOS 26 (Menü, Regler, Fenster mit Scrollbalken).
- Externes Review mit `codex-sol-review` über den gesamten Diff.
