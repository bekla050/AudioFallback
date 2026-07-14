# Sparkle Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AudioFallback prüft täglich und auf Wunsch manuell auf signierte Sparkle-Updates, während ein `vX.Y.Z`-Tag eine vollständig signierte, notarisierte GitHub-Release-Pipeline startet.

**Architecture:** Ein testbarer `UpdaterController` trennt den beobachtbaren App-Zustand von einem Sparkle-basierten Treiber. Die App bindet diesen Controller in Einstellungen und Statusmenü ein. Der Build verpackt Sparkle 2.9.2, und GitHub Actions veröffentlicht ein versioniertes DMG zusammen mit `appcast.xml` als gemeinsam sichtbare Release-Assets.

**Tech Stack:** Swift 6, AppKit, SwiftUI, Combine, Swift Testing, Swift Package Manager, Sparkle 2.9.2, zsh, GitHub Actions, `gh`, Apple `codesign`/`notarytool`/`stapler`/`hdiutil`.

## Global Constraints

- Sparkle ist exakt auf Version `2.9.2` angeheftet.
- Der Feed lautet exakt `https://github.com/bekla050/AudioFallback/releases/latest/download/appcast.xml`.
- Der Download für Version `0.3.0` lautet exakt `https://github.com/bekla050/AudioFallback/releases/download/v0.3.0/AudioFallback-0.3.0.dmg`.
- `SUPublicEDKey` lautet exakt `iAIs1MYTW9kxpXK+DXdhWBFr6geSS14RG0CwZR3DFgs=`; der zugehörige private Schlüssel bleibt außerhalb des Repositories.
- Automatische Prüfungen sind standardmäßig aktiv und laufen alle `86400` Sekunden.
- Der erste Release verwendet `CFBundleShortVersionString = 0.3.0`, `CFBundleVersion = 5` und `dist/AudioFallback-0.3.0.dmg`.
- Ein Schalter für automatische Prüfungen erscheint in den Einstellungen; das Statusmenü enthält nur „Nach Updates suchen …“.
- Alle neuen sichtbaren Texte werden in den vorhandenen zehn Sprachen lokalisiert.
- Ein Release wird ausschließlich durch einen Tag im Format `vX.Y.Z` ausgelöst; der Tag muss zur eingecheckten Version passen.
- DMG und `appcast.xml` liegen als Assets desselben GitHub-Releases; GitHub Pages wird nicht verwendet.
- Die Pipeline veröffentlicht erst nach erfolgreichen Tests, Signatur, Notarisierung, Stapling und Appcast-Erzeugung.
- Die vorhandenen Lautstärkeänderungen sind im Ausgangs-Commit `32aae39` gesichert und dürfen nicht zurückgenommen werden.
- Die nicht zugehörigen unversionierten Pfade `.vscode/` und `CLAUDE.md` bleiben unverändert und werden nicht committed.
- Produktionscode entsteht in jedem Task erst nach einem beobachteten, erwarteten Testfehlschlag.

---

### Task 1: Testbarer Sparkle-Updater-Kern

**Files:**
- Create: `Sources/AudioFallback/Update/UpdateDriver.swift`
- Create: `Sources/AudioFallback/Update/UpdaterController.swift`
- Create: `Tests/AudioFallbackTests/TestUpdateDriver.swift`
- Create: `Tests/AudioFallbackTests/UpdaterControllerTests.swift`
- Modify: `Package.swift`
- Create: `Package.resolved`

**Interfaces:**
- Produces: `@MainActor protocol UpdateDriver: AnyObject` mit `canCheckForUpdates`, `automaticallyChecksForUpdates`, `stateDidChange` und `checkForUpdates()`.
- Produces: `@MainActor final class UpdaterController: ObservableObject` mit den beiden veröffentlichten Zuständen, `checkForUpdates()` und `setAutomaticallyChecksForUpdates(_:)`.
- Produces: `@MainActor final class TestUpdateDriver` für spätere Tests.
- Consumes: Sparkle 2.9.2 `SPUStandardUpdaterController` und dessen KVO-konforme Updater-Properties.

- [ ] **Step 1: Write the failing updater tests and shared fake**

Create `Tests/AudioFallbackTests/TestUpdateDriver.swift`:

```swift
@testable import AudioFallback

@MainActor
final class TestUpdateDriver: UpdateDriver {
    var canCheckForUpdates: Bool
    var automaticallyChecksForUpdates: Bool
    var stateDidChange: (() -> Void)?
    private(set) var checkForUpdatesCallCount = 0

    init(canCheckForUpdates: Bool = true, automaticallyChecksForUpdates: Bool = true) {
        self.canCheckForUpdates = canCheckForUpdates
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }

    func sendStateChange() {
        stateDidChange?()
    }
}
```

Create `Tests/AudioFallbackTests/UpdaterControllerTests.swift`:

```swift
import Testing
@testable import AudioFallback

@MainActor
struct UpdaterControllerTests {
    @Test func mirrorsInitialDriverState() {
        let driver = TestUpdateDriver(canCheckForUpdates: false, automaticallyChecksForUpdates: true)
        let controller = UpdaterController(driver: driver)
        #expect(controller.canCheckForUpdates == false)
        #expect(controller.automaticallyChecksForUpdates == true)
    }

    @Test func forwardsManualChecks() {
        let driver = TestUpdateDriver()
        let controller = UpdaterController(driver: driver)
        controller.checkForUpdates()
        #expect(driver.checkForUpdatesCallCount == 1)
    }

    @Test func persistsAndMirrorsAutomaticCheckChanges() {
        let driver = TestUpdateDriver(automaticallyChecksForUpdates: true)
        let controller = UpdaterController(driver: driver)
        controller.setAutomaticallyChecksForUpdates(false)
        #expect(driver.automaticallyChecksForUpdates == false)
        #expect(controller.automaticallyChecksForUpdates == false)
    }

    @Test func refreshesWhenDriverStateChanges() {
        let driver = TestUpdateDriver(canCheckForUpdates: false, automaticallyChecksForUpdates: true)
        let controller = UpdaterController(driver: driver)
        driver.canCheckForUpdates = true
        driver.automaticallyChecksForUpdates = false
        driver.sendStateChange()
        #expect(controller.canCheckForUpdates == true)
        #expect(controller.automaticallyChecksForUpdates == false)
    }
}
```

- [ ] **Step 2: Run the updater tests and verify red**

Run `swift test --filter UpdaterControllerTests`.

Expected: compilation fails because `UpdateDriver` and `UpdaterController` do not exist.

- [ ] **Step 3: Add Sparkle and implement the driver/controller boundary**

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2")
],
```

The executable target receives:

```swift
dependencies: [
    .product(name: "Sparkle", package: "Sparkle")
],
linkerSettings: [
    .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
]
```

Create `Sources/AudioFallback/Update/UpdateDriver.swift`:

```swift
import Foundation
import Sparkle

@MainActor
protocol UpdateDriver: AnyObject {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    var stateDidChange: (() -> Void)? { get set }
    func checkForUpdates()
}

@MainActor
final class SparkleUpdateDriver: UpdateDriver {
    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }
    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
    var stateDidChange: (() -> Void)?

    private let controller: SPUStandardUpdaterController
    private var canCheckObservation: NSKeyValueObservation?
    private var automaticChecksObservation: NSKeyValueObservation?

    init(startAutomatically: Bool) {
        controller = SPUStandardUpdaterController(
            startingUpdater: startAutomatically,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) {
            [weak self] _, _ in
            Task { @MainActor in self?.stateDidChange?() }
        }
        automaticChecksObservation = controller.updater.observe(
            \.automaticallyChecksForUpdates,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor in self?.stateDidChange?() }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
```

Create `Sources/AudioFallback/Update/UpdaterController.swift`:

```swift
import Combine

@MainActor
final class UpdaterController: ObservableObject {
    @Published private(set) var canCheckForUpdates: Bool
    @Published private(set) var automaticallyChecksForUpdates: Bool
    private let driver: any UpdateDriver

    convenience init(startAutomatically: Bool) {
        self.init(driver: SparkleUpdateDriver(startAutomatically: startAutomatically))
    }

    init(driver: any UpdateDriver) {
        self.driver = driver
        canCheckForUpdates = driver.canCheckForUpdates
        automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates
        driver.stateDidChange = { [weak self] in self?.refreshState() }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        driver.checkForUpdates()
        refreshState()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        driver.automaticallyChecksForUpdates = enabled
        refreshState()
    }

    private func refreshState() {
        canCheckForUpdates = driver.canCheckForUpdates
        automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates
    }
}
```

Run `swift package resolve`. If Swift 6 diagnoses the KVO callback as crossing actor isolation unsafely, adapt only the callback hop while keeping all public state on `@MainActor`; do not use `nonisolated(unsafe)`.

- [ ] **Step 4: Run focused and full tests**

Run:

```sh
swift test --filter UpdaterControllerTests
swift test
```

Expected: four updater tests and the full suite pass.

- [ ] **Step 5: Verify linkage and commit**

Run:

```sh
swift build -c release
otool -L .build/release/AudioFallback | grep Sparkle
otool -l .build/release/AudioFallback | grep -A2 '@executable_path/../Frameworks'
git diff --check
git add Package.swift Package.resolved Sources/AudioFallback/Update Tests/AudioFallbackTests/TestUpdateDriver.swift Tests/AudioFallbackTests/UpdaterControllerTests.swift
git commit -m "feat: Sparkle-Updaterkern einbinden"
```

Expected: the executable references `@rpath/Sparkle.framework`, the app-bundle rpath is present, and the commit succeeds.

---

### Task 2: Einstellungen, Statusmenü und Lokalisierungen

**Files:**
- Create: `Tests/AudioFallbackTests/UpdateUIIntegrationTests.swift`
- Create: `Tests/AudioFallbackTests/UpdateLocalizationTests.swift`
- Modify: `Sources/AudioFallback/main.swift`
- Modify: `Sources/AudioFallback/App/StatusMenuController.swift`
- Modify: `Sources/AudioFallback/UI/SettingsView.swift`
- Modify: `Tests/AudioFallbackTests/SettingsWindowLayoutTests.swift`
- Modify: all ten `Sources/AudioFallback/Resources/*.lproj/Localizable.strings` files

**Interfaces:**
- Consumes: Task 1 `UpdaterController` and `TestUpdateDriver`.
- Produces: `StatusMenuController.init(controller:updaterController:)` and internal `makeMenu()`.
- Produces: `SettingsWindowFactory.makeWindow(controller:updaterController:layoutObserver:)`.
- Produces: localization keys `menu.checkForUpdates` and `settings.automaticUpdateChecks`.

- [ ] **Step 1: Write failing UI and localization tests**

Create `Tests/AudioFallbackTests/UpdateLocalizationTests.swift`:

```swift
import Foundation
import Testing

struct UpdateLocalizationTests {
    @Test func everySupportedLocalizationContainsUpdateStrings() throws {
        let locales = ["de", "en", "es", "fr", "it", "ja", "ko", "nl", "pt-BR", "zh-Hans"]
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for locale in locales {
            let file = root
                .appendingPathComponent("Sources/AudioFallback/Resources")
                .appendingPathComponent("\(locale).lproj/Localizable.strings")
            let contents = try String(contentsOf: file, encoding: .utf8)
            #expect(contents.components(separatedBy: "\"menu.checkForUpdates\"").count == 2)
            #expect(contents.components(separatedBy: "\"settings.automaticUpdateChecks\"").count == 2)
        }
    }
}
```

Create `Tests/AudioFallbackTests/UpdateUIIntegrationTests.swift`. Add a local `AudioHardwareManaging` fake plus temporary `PreferenceStore`, and implement this test exactly:

```swift
@MainActor
@Test func statusMenuDisablesAndTriggersManualUpdateCheck() throws {
    let driver = TestUpdateDriver(canCheckForUpdates: false)
    let updater = UpdaterController(driver: driver)
    let menuController = StatusMenuController(
        controller: try makeUpdateUIAudioController(),
        updaterController: updater
    )

    var item = try #require(menuController.makeMenu().items.first {
        $0.title == L10n.string("menu.checkForUpdates")
    })
    #expect(item.isEnabled == false)

    driver.canCheckForUpdates = true
    driver.sendStateChange()
    item = try #require(menuController.makeMenu().items.first {
        $0.title == L10n.string("menu.checkForUpdates")
    })
    #expect(item.isEnabled == true)

    let action = try #require(item.action)
    #expect(NSApp.sendAction(action, to: item.target, from: item))
    #expect(driver.checkForUpdatesCallCount == 1)
}
```

Extend `SettingsWindowLayoutTests` so the factory receives `UpdaterController(driver: TestUpdateDriver())`. Require a frame for `SettingsAccessibilityID.automaticUpdateChecks` and assert that it lies inside the header frame.

- [ ] **Step 2: Run focused tests and verify red**

Run:

```sh
swift test --filter UpdateLocalizationTests
swift test --filter UpdateUIIntegrationTests
swift test --filter SettingsWindowLayoutTests
```

Expected: failures because the new keys, initializers, menu builder and settings probe do not exist.

- [ ] **Step 3: Wire the updater into app startup and the status menu**

In `AppDelegate`, retain `private var updaterController: UpdaterController?`. Inside `applicationDidFinishLaunching`, create and retain it before constructing the status menu:

```swift
let updaterController = UpdaterController(startAutomatically: true)
self.updaterController = updaterController
statusMenuController = StatusMenuController(
    controller: controller,
    updaterController: updaterController
)
```

Subscribe to both updater publishers:

```swift
updaterController.$canCheckForUpdates
    .removeDuplicates()
    .sink { [weak self] _ in self?.statusMenuController?.rebuildMenu() }
    .store(in: &cancellables)

updaterController.$automaticallyChecksForUpdates
    .removeDuplicates()
    .sink { [weak self] _ in self?.statusMenuController?.rebuildMenu() }
    .store(in: &cancellables)
```

Retain the updater in `StatusMenuController` and change its initializer to:

```swift
init(controller: AudioFallbackController, updaterController: UpdaterController) {
    self.controller = controller
    self.updaterController = updaterController
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    super.init()
    updateStatusItemIcon()
    rebuildMenu()
}
```

Refactor `rebuildMenu()` to assign `statusItem.menu = makeMenu()`. The internal `makeMenu() -> NSMenu` contains all existing construction, preserves the volume item, and adds after „Geräte aktualisieren“:

```swift
let updateItem = NSMenuItem(
    title: L10n.string("menu.checkForUpdates"),
    action: #selector(checkForUpdates),
    keyEquivalent: ""
)
updateItem.target = self
updateItem.isEnabled = updaterController.canCheckForUpdates
menu.addItem(updateItem)
```

Add:

```swift
@objc private func checkForUpdates() {
    updaterController.checkForUpdates()
}
```

Pass the same updater from `openSettingsWindow()` into `SettingsWindowFactory`.

- [ ] **Step 4: Add the settings toggle**

Add `@ObservedObject var updaterController: UpdaterController` to `SettingsView` and its initializer. Below the login-item toggle add:

```swift
Toggle(
    L10n.string("settings.automaticUpdateChecks"),
    isOn: Binding(
        get: { updaterController.automaticallyChecksForUpdates },
        set: { updaterController.setAutomaticallyChecksForUpdates($0) }
    )
)
.accessibilityIdentifier(SettingsAccessibilityID.automaticUpdateChecks)
.layoutProbe(SettingsAccessibilityID.automaticUpdateChecks, observer: layoutObserver)
```

Add `static let automaticUpdateChecks = "settings.automaticUpdateChecks"`. Extend `SettingsWindowFactory.makeWindow` with the required updater parameter, pass it to `SettingsView`, and update every call site.

- [ ] **Step 5: Add all ten translations**

Add normal `.strings` entries with these exact values:

```text
de: Nach Updates suchen … | Automatisch nach Updates suchen
en: Check for Updates… | Automatically check for updates
es: Buscar actualizaciones… | Buscar actualizaciones automáticamente
fr: Rechercher les mises à jour… | Rechercher automatiquement les mises à jour
it: Controlla aggiornamenti… | Controlla automaticamente gli aggiornamenti
ja: アップデートを確認… | アップデートを自動的に確認
ko: 업데이트 확인… | 자동으로 업데이트 확인
nl: Zoek naar updates… | Automatisch zoeken naar updates
pt-BR: Buscar atualizações… | Buscar atualizações automaticamente
zh-Hans: 检查更新… | 自动检查更新
```

The left value belongs to `menu.checkForUpdates`, the right value to `settings.automaticUpdateChecks`.

- [ ] **Step 6: Run focused and full tests, then commit**

Run:

```sh
swift test --filter UpdateLocalizationTests
swift test --filter UpdateUIIntegrationTests
swift test --filter SettingsWindowLayoutTests
swift test
git diff --check
git add Sources/AudioFallback/main.swift Sources/AudioFallback/App/StatusMenuController.swift Sources/AudioFallback/UI/SettingsView.swift Sources/AudioFallback/Resources Tests/AudioFallbackTests/UpdateUIIntegrationTests.swift Tests/AudioFallbackTests/UpdateLocalizationTests.swift Tests/AudioFallbackTests/SettingsWindowLayoutTests.swift
git commit -m "feat: Update-Prüfung in Menü und Einstellungen"
```

Expected: all focused tests and the full suite pass.

---

### Task 3: App-Bundle, Release-Version und Konfigurationsprüfung

**Files:**
- Create: `Tests/AudioFallbackTests/ReleaseConfigurationTests.swift`
- Create: `scripts/validate-release.sh`
- Modify: `scripts/build-app.sh`
- Modify: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 1 Sparkle artifact below `.build/artifacts`.
- Produces: `scripts/build-app.sh --print-version`, `--print-build-version` and `--print-dmg-name`.
- Produces: `scripts/validate-release.sh vX.Y.Z`, exit `0` only for matching metadata.
- Produces: `.build/release/AudioFallback.app` with `Contents/Frameworks/Sparkle.framework` and all Sparkle plist keys.

- [ ] **Step 1: Write failing release-configuration tests**

Create `Tests/AudioFallbackTests/ReleaseConfigurationTests.swift`:

```swift
import Foundation
import Testing

struct ReleaseConfigurationTests {
    @Test func releaseMetadataMatchesVersion030() throws {
        #expect(try run("scripts/build-app.sh", "--print-version").stdout == "0.3.0\n")
        #expect(try run("scripts/build-app.sh", "--print-build-version").stdout == "5\n")
        #expect(try run("scripts/build-app.sh", "--print-dmg-name").stdout == "AudioFallback-0.3.0.dmg\n")
        #expect(try run("scripts/validate-release.sh", "v0.3.0").status == 0)
    }

    @Test func rejectsMismatchedOrMalformedTags() throws {
        #expect(try run("scripts/validate-release.sh", "v0.2.1").status != 0)
        #expect(try run("scripts/validate-release.sh", "0.3.0").status != 0)
        #expect(try run("scripts/validate-release.sh", "v0.3").status != 0)
    }

    @Test func containsSparkleSecurityConfiguration() throws {
        let script = try String(contentsOf: repositoryRoot.appendingPathComponent("scripts/build-app.sh"))
        #expect(script.contains("https://github.com/bekla050/AudioFallback/releases/latest/download/appcast.xml"))
        #expect(script.contains("iAIs1MYTW9kxpXK+DXdhWBFr6geSS14RG0CwZR3DFgs="))
        #expect(script.contains("SUScheduledCheckInterval"))
        #expect(script.contains("86400"))
    }
}

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

private func run(_ relativeExecutable: String, _ arguments: String...) throws -> CommandResult {
    let process = Process()
    let stdout = Pipe()
    let stderr = Pipe()
    process.executableURL = repositoryRoot.appendingPathComponent(relativeExecutable)
    process.arguments = arguments
    process.currentDirectoryURL = repositoryRoot
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    return CommandResult(
        status: process.terminationStatus,
        stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
        stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}
```

- [ ] **Step 2: Run focused tests and verify red**

Run `swift test --filter ReleaseConfigurationTests`.

Expected: failure because the print modes, validation script and new metadata do not exist.

- [ ] **Step 3: Make build metadata queryable and embed Sparkle**

At the top of `scripts/build-app.sh`, before build work, add:

```zsh
APP_VERSION="0.3.0"
BUILD_VERSION="5"
DMG_NAME="AudioFallback-${APP_VERSION}.dmg"

case "${1:-}" in
    --print-version)
        echo "$APP_VERSION"
        exit 0
        ;;
    --print-build-version)
        echo "$BUILD_VERSION"
        exit 0
        ;;
    --print-dmg-name)
        echo "$DMG_NAME"
        exit 0
        ;;
    "")
        ;;
    *)
        echo "Unbekannte Option: $1" >&2
        exit 64
        ;;
esac
```

Create `Contents/Frameworks`, locate only the resolved SPM artifact, and copy it:

```zsh
FRAMEWORKS="$CONTENTS/Frameworks"
mkdir -p "$FRAMEWORKS"

SPARKLE_FRAMEWORK="$(find "$ROOT/.build/artifacts" \
    -type d \
    -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' \
    -print -quit)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "Sparkle.framework wurde unter .build/artifacts nicht gefunden" >&2
    exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS/Sparkle.framework"
```

Change the plist heredoc so variables expand. Use `$APP_VERSION` and `$BUILD_VERSION` for the two bundle version values and add:

```xml
    <key>SUFeedURL</key>
    <string>https://github.com/bekla050/AudioFallback/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>iAIs1MYTW9kxpXK+DXdhWBFr6geSS14RG0CwZR3DFgs=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
```

- [ ] **Step 4: Add strict tag validation and public release metadata**

Create executable `scripts/validate-release.sh`:

```zsh
#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-}"

if [[ ! "$TAG" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "Release-Tag muss dem Format vX.Y.Z entsprechen: $TAG" >&2
    exit 1
fi

VERSION="$($ROOT/scripts/build-app.sh --print-version)"
BUILD_VERSION="$($ROOT/scripts/build-app.sh --print-build-version)"
DMG_NAME="$($ROOT/scripts/build-app.sh --print-dmg-name)"
EXPECTED_URL="https://github.com/bekla050/AudioFallback/releases/download/$TAG/$DMG_NAME"

if [[ "${TAG#v}" != "$VERSION" ]]; then
    echo "Tag $TAG passt nicht zur App-Version $VERSION" >&2
    exit 1
fi
if [[ ! "$BUILD_VERSION" =~ '^[1-9][0-9]*$' ]]; then
    echo "CFBundleVersion muss eine positive Ganzzahl sein: $BUILD_VERSION" >&2
    exit 1
fi
if ! grep -Fq "[$DMG_NAME]($EXPECTED_URL)" "$ROOT/README.md"; then
    echo "README-Download-Link passt nicht zu $TAG und $DMG_NAME" >&2
    exit 1
fi

echo "Release-Konfiguration gültig: $TAG (Build $BUILD_VERSION)"
```

Run `chmod +x scripts/validate-release.sh`. Change the README download link to:

```markdown
[AudioFallback-0.3.0.dmg](https://github.com/bekla050/AudioFallback/releases/download/v0.3.0/AudioFallback-0.3.0.dmg)
```

Add `/dist/AudioFallback-*.dmg` to `.gitignore`. Existing tracked historical DMGs remain tracked; future generated DMGs do not enter commits.

- [ ] **Step 5: Test and inspect the app bundle**

Run:

```sh
swift test --filter ReleaseConfigurationTests
swift test
scripts/build-app.sh
test -d .build/release/AudioFallback.app/Contents/Frameworks/Sparkle.framework
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' .build/release/AudioFallback.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' .build/release/AudioFallback.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' .build/release/AudioFallback.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' .build/release/AudioFallback.app/Contents/Info.plist
otool -L .build/release/AudioFallback.app/Contents/MacOS/AudioFallback | grep Sparkle
```

Expected: tests pass; the framework exists; plist values are `0.3.0`, `5`, the exact feed and key; linkage uses `@rpath`.

- [ ] **Step 6: Commit**

Run:

```sh
git diff --check
git add .gitignore README.md scripts/build-app.sh scripts/validate-release.sh Tests/AudioFallbackTests/ReleaseConfigurationTests.swift
git commit -m "build: Sparkle-App-Bundle für Version 0.3.0"
```

---

### Task 4: Tag-gesteuerte GitHub-Release-Pipeline und Betriebsdokumentation

**Files:**
- Create: `Tests/AudioFallbackTests/ReleaseWorkflowTests.swift`
- Create: `scripts/build-dmg.sh`
- Create: `.github/workflows/release.yml`
- Create: `docs/sparkle-release.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: Task 3 metadata, validation, app bundle and Sparkle tools below `.build/artifacts`.
- Produces: `scripts/build-dmg.sh APP_PATH DMG_PATH`.
- Produces: workflow `Release`, triggered by `v*.*.*`.
- Produces: assets `AudioFallback-0.3.0.dmg` and `appcast.xml`.
- External state: sets repository secret `SPARKLE_PRIVATE_KEY` from Keychain account `app.audiofallback` without printing it.

- [ ] **Step 1: Write a failing workflow contract test**

Create `Tests/AudioFallbackTests/ReleaseWorkflowTests.swift`:

```swift
import Foundation
import Testing

struct ReleaseWorkflowTests {
    @Test func hasTagTriggerSecurityGatesAndDraftPublication() throws {
        let workflow = try String(contentsOf: repositoryRoot.appendingPathComponent(".github/workflows/release.yml"))
        for required in [
            "v*.*.*", "contents: write", "scripts/validate-release.sh", "swift test",
            "scripts/build-app.sh", "codesign --verify --strict", "notarytool submit",
            "stapler staple", "generate_appcast", "--ed-key-file -", "gh release create",
            "--draft", "gh release edit", "--draft=false", "MACOS_CERT_P12",
            "MACOS_CERT_PASSWORD", "MACOS_SIGN_IDENTITY", "NOTARY_APPLE_ID",
            "NOTARY_TEAM_ID", "NOTARY_PASSWORD", "SPARKLE_PRIVATE_KEY",
            "Erforderliches Secret fehlt"
        ] {
            #expect(workflow.contains(required))
        }
    }
}

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
```

- [ ] **Step 2: Run the workflow test and verify red**

Run `swift test --filter ReleaseWorkflowTests`.

Expected: failure because `.github/workflows/release.yml` does not exist.

- [ ] **Step 3: Add a deterministic DMG builder**

Create executable `scripts/build-dmg.sh`:

```zsh
#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Verwendung: scripts/build-dmg.sh APP_PATH DMG_PATH" >&2
    exit 64
fi

APP_PATH="$1"
DMG_PATH="$2"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

if [[ ! -d "$APP_PATH" ]]; then
    echo "App-Bundle nicht gefunden: $APP_PATH" >&2
    exit 1
fi

mkdir -p "$(dirname "$DMG_PATH")"
ditto "$APP_PATH" "$STAGING/AudioFallback.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "AudioFallback" -srcfolder "$STAGING" -format UDZO -ov "$DMG_PATH"
```

Run `chmod +x scripts/build-dmg.sh` and `zsh -n scripts/build-dmg.sh`.

- [ ] **Step 4: Add the complete release workflow**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - "v*.*.*"

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-26
    env:
      SIGN_IDENTITY: ${{ secrets.MACOS_SIGN_IDENTITY }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Release-Konfiguration prüfen
        run: scripts/validate-release.sh "$GITHUB_REF_NAME"

      - name: Secrets prüfen
        env:
          MACOS_CERT_P12: ${{ secrets.MACOS_CERT_P12 }}
          MACOS_CERT_PASSWORD: ${{ secrets.MACOS_CERT_PASSWORD }}
          MACOS_SIGN_IDENTITY: ${{ secrets.MACOS_SIGN_IDENTITY }}
          NOTARY_APPLE_ID: ${{ secrets.NOTARY_APPLE_ID }}
          NOTARY_TEAM_ID: ${{ secrets.NOTARY_TEAM_ID }}
          NOTARY_PASSWORD: ${{ secrets.NOTARY_PASSWORD }}
          SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
        run: |
          set -euo pipefail
          for name in MACOS_CERT_P12 MACOS_CERT_PASSWORD MACOS_SIGN_IDENTITY \
            NOTARY_APPLE_ID NOTARY_TEAM_ID NOTARY_PASSWORD SPARKLE_PRIVATE_KEY; do
            if [[ -z "${!name:-}" ]]; then
              echo "Erforderliches Secret fehlt: $name" >&2
              exit 1
            fi
          done

      - name: Tests
        run: swift test

      - name: Release-App bauen
        run: scripts/build-app.sh

      - name: Release-Metadaten setzen
        run: |
          echo "APP_VERSION=$(scripts/build-app.sh --print-version)" >> "$GITHUB_ENV"
          echo "BUILD_VERSION=$(scripts/build-app.sh --print-build-version)" >> "$GITHUB_ENV"
          echo "DMG_NAME=$(scripts/build-app.sh --print-dmg-name)" >> "$GITHUB_ENV"
          echo "APP_PATH=$GITHUB_WORKSPACE/.build/release/AudioFallback.app" >> "$GITHUB_ENV"

      - name: Signing-Zertifikat importieren
        env:
          MACOS_CERT_P12: ${{ secrets.MACOS_CERT_P12 }}
          MACOS_CERT_PASSWORD: ${{ secrets.MACOS_CERT_PASSWORD }}
        run: |
          set -euo pipefail
          KEYCHAIN="$RUNNER_TEMP/build.keychain-db"
          KEYCHAIN_PASSWORD="$(openssl rand -hex 16)"
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
          security set-keychain-settings -lut 3600 "$KEYCHAIN"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
          printf '%s' "$MACOS_CERT_P12" | base64 --decode > "$RUNNER_TEMP/certificate.p12"
          security import "$RUNNER_TEMP/certificate.p12" -k "$KEYCHAIN" \
            -P "$MACOS_CERT_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: -s \
            -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
          security list-keychains -d user -s "$KEYCHAIN"
          rm -f "$RUNNER_TEMP/certificate.p12"

      - name: App von innen nach außen signieren
        run: |
          set -euo pipefail
          sign() {
            codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$1"
          }
          {
            find "$APP_PATH/Contents" -type d \( -name '*.app' -o -name '*.xpc' -o -name '*.framework' \)
            find "$APP_PATH/Contents" -type f \
              -exec sh -c 'file -b "$1" | grep -q "Mach-O"' _ {} \; -print
          } | awk -F/ '{ print NF "\t" $0 }' | sort -rn | cut -f2- | \
            while IFS= read -r item; do sign "$item"; done
          sign "$APP_PATH"
          codesign --verify --strict --verbose=2 "$APP_PATH"

      - name: DMG bauen und signieren
        run: |
          set -euo pipefail
          DMG_PATH="$GITHUB_WORKSPACE/dist/$DMG_NAME"
          scripts/build-dmg.sh "$APP_PATH" "$DMG_PATH"
          codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
          echo "DMG_PATH=$DMG_PATH" >> "$GITHUB_ENV"

      - name: Notarisieren und stapeln
        run: |
          xcrun notarytool submit "$DMG_PATH" \
            --apple-id "${{ secrets.NOTARY_APPLE_ID }}" \
            --team-id "${{ secrets.NOTARY_TEAM_ID }}" \
            --password "${{ secrets.NOTARY_PASSWORD }}" --wait
          xcrun stapler staple "$DMG_PATH"
          xcrun stapler validate "$DMG_PATH"

      - name: Signierten Appcast erzeugen
        env:
          SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
        run: |
          set -euo pipefail
          ARCHIVES="$RUNNER_TEMP/appcast"
          mkdir -p "$ARCHIVES"
          cp "$DMG_PATH" "$ARCHIVES/$DMG_NAME"
          GENERATE_APPCAST="$(find .build/artifacts -type f \
            -path '*/Sparkle/bin/generate_appcast' -print -quit)"
          if [[ -z "$GENERATE_APPCAST" ]]; then
            echo "generate_appcast wurde nicht gefunden" >&2
            exit 1
          fi
          printf '%s' "$SPARKLE_PRIVATE_KEY" | "$GENERATE_APPCAST" \
            --ed-key-file - \
            --download-url-prefix "https://github.com/$GITHUB_REPOSITORY/releases/download/$GITHUB_REF_NAME/" \
            --full-release-notes-url "https://github.com/$GITHUB_REPOSITORY/releases/tag/$GITHUB_REF_NAME" \
            --maximum-deltas 0 \
            -o "$GITHUB_WORKSPACE/appcast.xml" "$ARCHIVES"
          xmllint --noout "$GITHUB_WORKSPACE/appcast.xml"
          grep -Fq "sparkle:edSignature" "$GITHUB_WORKSPACE/appcast.xml"
          grep -Fq "releases/download/$GITHUB_REF_NAME/$DMG_NAME" "$GITHUB_WORKSPACE/appcast.xml"

      - name: Release-Entwurf mit Assets anlegen
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "$GITHUB_REF_NAME" "$DMG_PATH" "$GITHUB_WORKSPACE/appcast.xml" \
            --verify-tag --draft --generate-notes --title "AudioFallback $APP_VERSION"

      - name: Release veröffentlichen
        env:
          GH_TOKEN: ${{ github.token }}
        run: gh release edit "$GITHUB_REF_NAME" --draft=false --latest
```

Parse it locally:

```sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml", aliases: true); puts "workflow yaml ok"'
```

- [ ] **Step 5: Document exact setup and future releases**

Create `docs/sparkle-release.md` listing these exact secrets:

```text
MACOS_CERT_P12
MACOS_CERT_PASSWORD
MACOS_SIGN_IDENTITY = Developer ID Application: Jens Walter (Q7HS294VFS)
NOTARY_APPLE_ID
NOTARY_TEAM_ID = Q7HS294VFS
NOTARY_PASSWORD
SPARKLE_PRIVATE_KEY
```

Document that private values never enter files or logs. Document the required joint version bump in `scripts/build-app.sh`, README and `dist/`, the local commands `swift test`, `scripts/build-app.sh`, `scripts/validate-release.sh v0.3.0`, and the release commands:

```sh
git tag v0.3.0
git push origin v0.3.0
```

Add a short `Release` section in `README.md` linking to `docs/sparkle-release.md` and stating that version tags drive releases.

- [ ] **Step 6: Export the existing Sparkle key directly into the repository secret**

Run without printing file contents:

```sh
set -euo pipefail
KEY_FILE="$(mktemp)"
chmod 600 "$KEY_FILE"
/Users/Jeans/projects/voiceblade/macapp/build/ReleaseArm64DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account app.audiofallback -x "$KEY_FILE"
gh secret set SPARKLE_PRIVATE_KEY --repo bekla050/AudioFallback < "$KEY_FILE"
rm -f "$KEY_FILE"
gh secret list --repo bekla050/AudioFallback
```

Expected: `SPARKLE_PRIVATE_KEY` appears by name. Report missing Apple secret names; GitHub does not expose the existing VoiceBlade values and no value may be fabricated.

- [ ] **Step 7: Run focused, full, bundle and script verification**

Run:

```sh
swift test --filter ReleaseWorkflowTests
swift test
swift build -c release
scripts/build-app.sh
zsh -n scripts/build-app.sh
zsh -n scripts/validate-release.sh
zsh -n scripts/build-dmg.sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml", aliases: true); puts "workflow yaml ok"'
scripts/validate-release.sh v0.3.0
git diff --check
```

Expected: all tests pass, both builds succeed, scripts and YAML parse, and release validation accepts `v0.3.0`.

- [ ] **Step 8: Commit**

Run:

```sh
git add .github/workflows/release.yml README.md docs/sparkle-release.md scripts/build-dmg.sh Tests/AudioFallbackTests/ReleaseWorkflowTests.swift
git commit -m "ci: signierte GitHub-Releases aus Versionstags"
```

Do not create or push `v0.3.0`: all Apple secrets must exist, and the reviewed release commit must first be pushed.

---

## Final Verification

After all task reviews are clean, the coordinating agent runs:

```sh
swift test
swift build -c release
scripts/build-app.sh
scripts/validate-release.sh v0.3.0
test -d .build/release/AudioFallback.app/Contents/Frameworks/Sparkle.framework
git diff --check
git status --short
gh secret list --repo bekla050/AudioFallback
```

The local bundle is intentionally not Developer-ID-signed. The first true end-to-end verification therefore happens only after the reviewed commit and every required secret are on `origin`, followed by a deliberate `v0.3.0` tag push.
