# Sparkle-Updates über GitHub — Entwurf

**Datum:** 2026-07-14
**Status:** Vom Nutzer freigegeben

## Ziel

AudioFallback erhält automatische, signierte Updates über Sparkle 2.9.2. Ein Push
eines SemVer-Tags im Format `vX.Y.Z` nach `origin` startet die GitHub-Actions-Pipeline.
Sie baut, signiert und notarisiert die App, erzeugt ein DMG sowie einen signierten
Appcast und veröffentlicht beides als Assets eines GitHub-Releases.

Die App prüft standardmäßig einmal täglich auf Updates. Der Nutzer kann diese
automatischen Prüfungen in den Einstellungen ein- oder ausschalten und jederzeit über
„Nach Updates suchen …“ im Statusmenü eine manuelle Prüfung starten.

## Abgrenzung

Enthalten sind:

- Sparkle als fest angeheftete SwiftPM-Abhängigkeit,
- das Updater-Wiring in App, Einstellungen und Statusmenü,
- vollständige Lokalisierung in den bereits unterstützten zehn Sprachen,
- der Sparkle-Appcast und seine EdDSA-Signatur,
- eine Tag-gesteuerte GitHub-Release-Pipeline einschließlich Developer-ID-Signatur,
  Notarisierung und Stapling,
- die Release-Version `0.3.0` mit Buildnummer `5`,
- automatisierte Tests für Update-Zustand, UI-Wiring und Release-Konfiguration,
- eine kurze Dokumentation der benötigten GitHub-Secrets und des künftigen
  Release-Ablaufs.

Nicht enthalten sind Delta-Updates, Vorabversionen, ein eigener Update-Server,
GitHub Pages oder eine Änderung der vorhandenen Audio-Fallback-Logik.

## Hosting-Entscheidung

DMG und `appcast.xml` werden als Assets desselben GitHub-Releases veröffentlicht.
Die App verwendet den stabilen Feed:

```text
https://github.com/bekla050/AudioFallback/releases/latest/download/appcast.xml
```

Der Appcast verweist auf das versionierte DMG des jeweiligen Releases, beispielsweise:

```text
https://github.com/bekla050/AudioFallback/releases/download/v0.3.0/AudioFallback-0.3.0.dmg
```

Damit ist weder ein zusätzlicher Pages-Zweig noch ein CI-Schreibzugriff auf `main`
nötig. Der neueste veröffentlichte, nicht als Vorabversion markierte GitHub-Release
bestimmt den Feed. Das ist für diesen Entwurf bewusst auf stabile Releases beschränkt.

## App-Architektur

### Sparkle-Abhängigkeit und Bundle-Konfiguration

`Package.swift` bindet das Sparkle-Produkt in exakt der von VoiceBlade verwendeten
Version 2.9.2 ein. `scripts/build-app.sh` verpackt das Framework und dessen Helfer in
das App-Bundle.

Die erzeugte `Info.plist` enthält zusätzlich:

- `SUFeedURL` mit der stabilen GitHub-Feed-URL,
- `SUPublicEDKey` mit einem ausschließlich für AudioFallback erzeugten öffentlichen
  EdDSA-Schlüssel,
- `SUEnableAutomaticChecks = true` als Standard,
- `SUScheduledCheckInterval = 86400` für eine tägliche Prüfung.

Der private EdDSA-Schlüssel wird nie eingecheckt. Er liegt ausschließlich als
Repository-Secret `SPARKLE_PRIVATE_KEY` in GitHub Actions. Das veröffentlichte DMG wird
nach der Notarisierung signiert und danach bytegenau unverändert hochgeladen.

### Update-Treiber

Eine kleine interne Treiber-Schnittstelle trennt Sparkle vom beobachtbaren Zustand der
App. Der Produktionstreiber kapselt `SPUStandardUpdaterController`; ein Fake-Treiber
ermöglicht deterministische Tests.

Ein `UpdaterController` veröffentlicht mindestens:

- ob eine manuelle Prüfung aktuell möglich ist,
- ob automatische Prüfungen eingeschaltet sind,
- eine Aktion für die manuelle Prüfung,
- eine Aktion zum Ein- und Ausschalten automatischer Prüfungen.

Sparkles eigener, in `UserDefaults` gespeicherter Wert bleibt die maßgebliche Quelle
für die Einstellung. Die App hält keine zweite, davon unabhängige Präferenz vor.
Änderungen werden auf dem Hauptthread in den beobachtbaren Zustand gespiegelt.

### App-Start

`AppDelegate` besitzt den `UpdaterController` für die gesamte Laufzeit der App und
startet Sparkles geplante Prüfungen im normalen App-Lauf. Tests erhalten einen
Fake-Treiber und starten weder Netzwerkzugriffe noch Sparkle-Helfer.

### Einstellungen

In `SettingsView` erscheint unter den vorhandenen allgemeinen Optionen der Schalter
„Automatisch nach Updates suchen“. Er liest und schreibt unmittelbar den von Sparkle
verwalteten Wert. Die vorhandene Fensterstruktur und die bereits uncommittierten
Layout- und Lautstärkeänderungen bleiben erhalten.

### Statusmenü

Das Statusmenü erhält in der Gruppe mit „Einstellungen …“ und „Geräte aktualisieren“
den Eintrag „Nach Updates suchen …“. Er startet eine interaktive Sparkle-Prüfung und
ist deaktiviert, solange Sparkle keine Prüfung ausführen kann. Ein Schalter für
automatische Prüfungen erscheint ausdrücklich nicht im Statusmenü.

### Lokalisierung

Die beiden neuen sichtbaren Texte werden in Deutsch, Englisch, Französisch, Spanisch,
Italienisch, brasilianischem Portugiesisch, vereinfachtem Chinesisch, Japanisch,
Koreanisch und Niederländisch ergänzt. Für Auslassungspunkte wird die in der jeweiligen
bestehenden Übersetzung übliche Schreibweise beibehalten.

## Release-Pipeline

`.github/workflows/release.yml` reagiert ausschließlich auf Tags im Format `v*.*.*`.
Der Ablauf ist:

1. Repository vollständig auschecken und den Tag als striktes `vX.Y.Z` validieren.
2. Prüfen, dass die Tag-Version mit `CFBundleShortVersionString` in
   `scripts/build-app.sh`, dem DMG-Dateinamen und dem Download-Link in `README.md`
   übereinstimmt.
3. `swift test` ausführen und anschließend das Release-App-Bundle bauen.
4. Ein temporäres Signing-Keychain anlegen und das Developer-ID-Zertifikat importieren.
5. Sparkle-Helfer, Frameworks und ausführbare Dateien von innen nach außen mit
   Developer ID, Timestamp und Hardened Runtime signieren; zuletzt das App-Bundle
   signieren und strikt prüfen.
6. `dist/AudioFallback-0.3.0.dmg` mit einem Drag-to-Applications-Layout erzeugen und
   signieren.
7. Das DMG mit `notarytool` einreichen, auf Annahme warten und das Ticket stapeln.
8. Das fertig gestapelte DMG mit Sparkles EdDSA-Werkzeug signieren und daraus
   `appcast.xml` mit `sparkle:version = 5`,
   `sparkle:shortVersionString = 0.3.0` und Mindestversion macOS 14.0 erzeugen.
9. Einen GitHub-Release-Entwurf mit automatisch erzeugten Release Notes anlegen, DMG
   und Appcast hochladen und den Release erst danach veröffentlichen.

Die Pipeline verändert weder `main` noch einen Pages-Zweig. Ein Fehler vor der
Veröffentlichung kann höchstens einen nicht sichtbaren Entwurf hinterlassen; der
bestehende `latest`-Feed bleibt auf dem letzten erfolgreichen Release.

## Versionierung

Sparkle ist eine neue abwärtskompatible Funktion. Entsprechend `AGENTS.md` ist der
erste Release ein Minor-Release:

- `CFBundleShortVersionString`: `0.3.0`,
- `CFBundleVersion`: `5`,
- DMG: `dist/AudioFallback-0.3.0.dmg`,
- README-Download: versioniertes Asset des Releases `v0.3.0`.

Der Tag ersetzt die Werte in den Dateien nicht, sondern bestätigt sie. Künftige
Releases erhöhen vor dem Tag-Setzen gemeinsam Marketing-Version, Buildnummer,
DMG-Dateinamen und README-Link. Die Pipeline bricht bei jeder Abweichung ab. Dadurch
bleiben die Repository-Anweisungen und Sparkles Anforderung an monoton steigende
Buildnummern gleichzeitig erfüllt.

## Geheimnisse und externe Voraussetzungen

Die Pipeline erwartet folgende Repository-Secrets:

- `MACOS_CERT_P12`,
- `MACOS_CERT_PASSWORD`,
- `MACOS_SIGN_IDENTITY`,
- `NOTARY_APPLE_ID`,
- `NOTARY_TEAM_ID`,
- `NOTARY_PASSWORD`,
- `SPARKLE_PRIVATE_KEY`.

Der Workflow erhält ausschließlich `contents: write`, um den GitHub-Release anzulegen.
Fehlende Secrets führen zu einem frühen, verständlichen Abbruch. Der öffentliche
Sparkle-Schlüssel wird im App-Bundle eingecheckt; alle privaten Schlüssel und
Zugangsdaten bleiben außerhalb des Repositories.

## Fehlerbehandlung

- Tag-, Versions- oder Dateinamenabweichungen stoppen den Release vor dem Build.
- Test-, Build-, Signatur-, Notarisierungs- oder Uploadfehler stoppen die Pipeline vor
  der Veröffentlichung.
- Sparkle behandelt Feed-, Netzwerk-, Download- und EdDSA-Fehler in seiner eigenen
  Update-Oberfläche.
- Der manuelle Menüpunkt folgt Sparkles `canCheckForUpdates` und verhindert parallele
  oder aktuell unmögliche Prüfungen.
- Tests erzeugen keine Netzwerkzugriffe und verändern keine produktiven
  Sparkle-Einstellungen.

## Tests und Verifikation

Die Umsetzung folgt testgetriebenen Red-Green-Zyklen. Automatisiert geprüft werden:

- der initiale Zustand des `UpdaterController` aus dem Treiber,
- die Weiterleitung einer manuellen Prüfung,
- das Umschalten und Spiegeln automatischer Prüfungen,
- der deaktivierte Zustand des manuellen Menüeintrags,
- der Einstellungs-Schalter im vorhandenen Layout,
- alle neuen Lokalisierungsschlüssel in allen zehn Sprachen,
- Übereinstimmung von Tag, Bundle-Version, Buildnummer, DMG-Dateiname, Appcast-URL und
  README-Link,
- `swift test` sowie ein vollständiger lokaler Debug- und Release-Build.

Die GitHub-Pipeline selbst wird syntaktisch geprüft. Die Ende-zu-Ende-Abnahme erfolgt
mit dem ersten Tag `v0.3.0`: erfolgreicher Workflow, gültige Developer-ID-Signatur,
angenommene Notarisierung, erreichbare Release-Assets, gültiger Appcast und ein
angebotenes Update ausgehend von AudioFallback 0.2.1.

## Release-Ablauf für den Nutzer

Nach Umsetzung und Einrichtung der Secrets besteht ein Release aus:

```sh
git tag v0.3.0
git push origin v0.3.0
```

Der Tag muss auf dem bereits nach `origin` gepushten Release-Commit liegen. Die
Pipeline übernimmt alle weiteren Schritte; ein lokales DMG muss nicht vorab gebaut
oder eingecheckt werden.
