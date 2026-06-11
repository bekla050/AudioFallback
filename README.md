# AudioFallback

AudioFallback ist eine kleine macOS-Menüleisten-App für priorisierte
Standard-Audiogeräte.

Sie verwaltet getrennte Prioritätslisten für Eingabegeräte (Mikrofone) und
Ausgabegeräte (Lautsprecher/Kopfhörer). Wenn Geräte erscheinen oder verschwinden,
wählt sie das erste verfügbare Gerät aus der passenden Liste.

## Umfang

Das ist ein Open-Source-MVP, inspiriert vom Geräteprioritäts-Teil von Apps wie
SoundSource. Per-App-Audio-Routing, Effekte, Lautstärke-Boosting, Aufnahme und
virtuelle Audiotreiber sind bewusst nicht enthalten.

## Starten

```sh
swift run AudioFallback
```

Die App erscheint in der Menüleiste. Über **Einstellungen ...** lassen sich
Mikrofone und Lautsprecher unabhängig sortieren.

Die Einstellungen werden hier gespeichert:

```text
~/Library/Application Support/AudioFallback/preferences.json
```

## Build und Tests

```sh
swift test
swift build
scripts/build-app.sh
```

Das App-Bundle liegt danach unter:

```text
.build/release/AudioFallback.app
```

## Aktuelles Verhalten

- Eingabe- und Ausgabeprioritäten sind unabhängig.
- Neu erkannte Geräte werden ans Ende der passenden Liste gehängt.
- Beim Ausgabewechsel setzt die App sowohl das Standard-Ausgabegerät als auch
  das System-Ausgabegerät.
- Die Rückfallentscheidung ist durch Unit-Tests abgedeckt.

## Einschränkungen

- Das ist eine normale User-Space-App, kein virtueller Audiotreiber.
- Bluetooth-„Nur Ausgabe“-Erzwingung ist noch nicht implementiert. Die App kann
  ein separates Mikrofon gegenüber einem Headset-Mikrofon bevorzugen, aber macOS
  und einzelne Apps können eigenes Audio-Geräteverhalten haben.
- Es gibt noch keinen Login-Item-Installer.
