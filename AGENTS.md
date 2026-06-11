# AGENTS.md

Bei jedem neu erstellten DMG muss die App-Version passend nach SemVer erhöht
werden. Das umfasst mindestens:

- `CFBundleShortVersionString` in `scripts/build-app.sh`
- `CFBundleVersion` in `scripts/build-app.sh`
- den DMG-Dateinamen unter `dist/`
- den Download-Link in `README.md`

Patch-Releases für reine Bugfixes erhöhen die Patch-Version, Minor-Releases für
neue abwärtskompatible Funktionen erhöhen die Minor-Version, und inkompatible
Änderungen erhöhen die Major-Version.
