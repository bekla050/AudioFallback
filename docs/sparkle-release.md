# Sparkle-Release

AudioFallback veröffentlicht neue Versionen über einen signierten GitHub-Release. Ein Push eines Versionstags im Format `vX.Y.Z` startet die Release-Pipeline. Die Pipeline testet und baut die App, signiert sie mit einer Developer-ID, erzeugt und signiert das DMG, notarisiert es und erstellt einen signierten Sparkle-Appcast. DMG und `appcast.xml` werden als Assets desselben GitHub-Releases veröffentlicht; GitHub Pages wird nicht verwendet.

## Repository-Secrets

Die Pipeline benötigt diese Secrets im Repository `bekla050/AudioFallback`:

```text
MACOS_CERT_P12
MACOS_CERT_PASSWORD
MACOS_SIGN_IDENTITY = Developer ID Application: Jens Walter (Q7HS294VFS)
NOTARY_APPLE_ID
NOTARY_TEAM_ID = Q7HS294VFS
NOTARY_PASSWORD
SPARKLE_PRIVATE_KEY
```

Private Werte dürfen nie in Repository-Dateien, Commits oder Logs geschrieben werden. `MACOS_CERT_P12` enthält das Base64-kodierte Developer-ID-Zertifikat, `NOTARY_PASSWORD` ein anwendungsspezifisches Apple-ID-Passwort und `SPARKLE_PRIVATE_KEY` den privaten EdDSA-Schlüssel aus dem Schlüsselbund-Konto `app.audiofallback`. Das Zertifikat wird für den Import ausschließlich temporär im Dateisystem des GitHub-Runners abgelegt und unmittelbar danach gelöscht.

## Version vorbereiten

Bei jedem neuen DMG müssen die SemVer-Version und die Buildnummer gemeinsam angepasst werden. Dazu gehören mindestens:

- `APP_VERSION`, `BUILD_VERSION` und damit der DMG-Dateiname in `scripts/build-app.sh`
- der Download-Link in `README.md`
- der neue DMG-Dateiname unter `dist/`, falls das DMG lokal abgelegt wird

Vor dem Tag-Push wird die Release-Konfiguration lokal geprüft:

```sh
swift test
scripts/build-app.sh
scripts/validate-release.sh v0.3.0
```

## Release veröffentlichen

Nach einem Review des Release-Commits wird der passende Tag erstellt und nach `origin` gepusht:

```sh
git tag v0.3.0
git push origin v0.3.0
```

Die Pipeline legt den GitHub-Release zunächst als Entwurf an. Erst nachdem DMG und `appcast.xml` erfolgreich erzeugt und hochgeladen wurden, wird der Release veröffentlicht und als `latest` markiert. Sparkle lädt den stabilen Feed über `releases/latest/download/appcast.xml`.
