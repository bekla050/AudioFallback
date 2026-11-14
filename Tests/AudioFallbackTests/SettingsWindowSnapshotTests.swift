import AppKit
import Testing
@testable import AudioFallback

/// Renders the settings window as PNG files for visual review.
/// Runs only when `AUDIOFALLBACK_SNAPSHOT_DIR` is set, otherwise it returns immediately.
@MainActor
struct SettingsWindowSnapshotTests {
    @Test func rendersSettingsWindowInLightAndDarkAppearance() throws {
        guard let path = ProcessInfo.processInfo.environment["AUDIOFALLBACK_SNAPSHOT_DIR"], !path.isEmpty else {
            return
        }

        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        SnapshotLocalization.useGermanResources()
        defer { SnapshotLocalization.restore() }

        let appearances: [(name: String, appearance: NSAppearance.Name)] = [
            ("light", .aqua),
            ("dark", .darkAqua)
        ]
        for (name, appearanceName) in appearances {
            try renderVariants(named: name, appearance: appearanceName, to: directory)
        }

        // "Show scroll bars: Always" in System Settings means legacy scrollers that take their own space.
        SnapshotScrollerStyle.forceLegacy(true)
        defer { SnapshotScrollerStyle.forceLegacy(false) }
        try renderVariants(named: "light-legacy-scroller", appearance: .aqua, to: directory)
    }

    private func renderVariants(named name: String, appearance: NSAppearance.Name, to directory: URL) throws {
        let window = SettingsWindowFactory.makeWindow(
            controller: try makeSnapshotController(),
            updaterController: UpdaterController(driver: TestUpdateDriver())
        )
        defer { window.close() }
        window.appearance = NSAppearance(named: appearance)
        settle(window)

        try writePNG(of: window, to: directory.appendingPathComponent("settings-\(name).png"))

        scrollDeviceLists(in: window, to: 0.5)
        try writePNG(of: window, to: directory.appendingPathComponent("settings-\(name)-scrolled.png"))

        scrollDeviceLists(in: window, to: 1)
        try writePNG(of: window, to: directory.appendingPathComponent("settings-\(name)-scrolled-end.png"))
    }

    /// Scrolls both device lists to a relative position (0 = top, 1 = end).
    private func scrollDeviceLists(in window: NSWindow, to position: CGFloat) {
        let scrollViews = deviceScrollViews(in: window)
        #expect(scrollViews.count == 2)
        for scrollView in scrollViews {
            let clipView = scrollView.contentView
            let documentHeight = scrollView.documentView?.frame.height ?? 0
            let offset = max(0, documentHeight - clipView.bounds.height) * position
            clipView.scroll(to: NSPoint(x: clipView.bounds.minX, y: offset))
            scrollView.reflectScrolledClipView(clipView)
        }
        settle(window)
    }

    private func settle(_ window: NSWindow) {
        for _ in 0..<5 {
            window.contentView?.layoutSubtreeIfNeeded()
            window.contentView?.displayIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func deviceScrollViews(in window: NSWindow) -> [NSScrollView] {
        var result: [NSScrollView] = []
        var pending: [NSView] = window.contentView.map { [$0] } ?? []
        while let view = pending.popLast() {
            if let scrollView = view as? NSScrollView {
                result.append(scrollView)
            }
            pending.append(contentsOf: view.subviews)
        }
        return result
    }

    private func writePNG(of window: NSWindow, to url: URL) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url)
    }

    private func makeSnapshotController() throws -> AudioFallbackController {
        let microphoneNames = [
            "MacBook Pro-Mikrofon",
            "Shure MV7+",
            "AirPods Pro",
            "Studio Display-Mikrofon",
            "Elgato Wave:3",
            "Rode NT-USB Mini",
            "Logitech BRIO",
            "iPhone-Mikrofon",
            "Blue Yeti",
            "Zoom-Audiogerät",
            "Microsoft Teams Audio",
            "Sehr langer Gerätename eines USB-Audio-Interfaces mit vielen Kanälen"
        ]
        let speakerNames = [
            "MacBook Pro-Lautsprecher",
            "Studio Display-Lautsprecher",
            "AirPods Pro",
            "HomePod mini",
            "Sonos Era 100",
            "Bose QuietComfort Ultra",
            "LG UltraFine Display Audio",
            "Kopfhöreranschluss",
            "Focusrite Scarlett 2i2",
            "BlackHole 2ch",
            "Microsoft Teams Audio",
            "Sehr langer Gerätename eines Bluetooth-Lautsprechers im Wohnzimmer"
        ]
        let microphones = microphoneNames.enumerated().map { index, name in
            snapshotDevice(uid: "mic-\(index)", name: name, input: true, output: false)
        }
        let speakers = speakerNames.enumerated().map { index, name in
            snapshotDevice(uid: "speaker-\(index)", name: name, input: false, output: true)
        }
        let unavailableMicrophone = microphones[3]
        let unavailableSpeaker = speakers[5]
        let manualSpeaker = speakers[2]

        let preferences = AudioFallbackPreferences(
            inputPriorityUIDs: microphones.map(\.uid),
            outputPriorityUIDs: speakers.map(\.uid),
            knownDevicesByUID: Dictionary(
                uniqueKeysWithValues: (microphones + speakers).map { ($0.uid, $0) }
            ),
            manualOutputUID: manualSpeaker.uid
        )
        let availableDevices = (microphones + speakers).filter {
            $0.uid != unavailableMicrophone.uid && $0.uid != unavailableSpeaker.uid
        }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = PreferenceStore(fileURL: directory.appendingPathComponent("preferences.json"))
        try store.save(preferences)
        let controller = AudioFallbackController(
            hardware: SnapshotMockAudioHardware(devices: availableDevices),
            preferenceStore: store
        )
        controller.refresh()
        return controller
    }
}

private func snapshotDevice(uid: String, name: String, input: Bool, output: Bool) -> ManagedAudioDevice {
    ManagedAudioDevice(
        id: UInt32(abs(uid.hashValue % Int(UInt32.max))),
        uid: uid,
        name: name,
        supportsInput: input,
        supportsOutput: output
    )
}

private final class SnapshotMockAudioHardware: AudioHardwareManaging {
    private let storedDevices: [ManagedAudioDevice]

    init(devices: [ManagedAudioDevice]) {
        self.storedDevices = devices
    }

    func devices() throws -> [ManagedAudioDevice] {
        storedDevices
    }

    func defaultDevice(for kind: DeviceKind) throws -> ManagedAudioDevice? {
        storedDevices.first { $0.supports(kind) }
    }

    func setDefaultDevice(uid: String, for kind: DeviceKind) throws {}

    func outputLevel() throws -> OutputLevel? {
        OutputLevel(volume: 0.5, isMuted: false)
    }

    func setOutputVolume(_ volume: Float) throws {}

    func observeHardwareChanges(_ callback: @escaping @Sendable () -> Void) {}
}

/// Snapshot runs only: `L10n` looks for the resource bundle next to the app executable, which the
/// test runner does not have, so it would show raw keys. Redirect lookups on the main bundle to the
/// German strings of the SwiftPM resource bundle that sits next to the test bundle.
@MainActor
private enum SnapshotLocalization {
    private static var isInstalled = false

    /// The exchanged method falls through to the original once the bundle is cleared.
    static func restore() {
        snapshotGermanBundle = nil
    }

    static func useGermanResources() {
        let resourceURL = Bundle(for: SnapshotBundleToken.self).bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("AudioFallback_AudioFallback.bundle")
            .appendingPathComponent("de.lproj")
        guard let germanBundle = Bundle(url: resourceURL) else {
            return
        }

        snapshotGermanBundle = germanBundle
        guard !isInstalled,
              let original = class_getInstanceMethod(Bundle.self, #selector(Bundle.localizedString(forKey:value:table:))),
              let replacement = class_getInstanceMethod(Bundle.self, #selector(Bundle.snapshotLocalizedString(forKey:value:table:))) else {
            return
        }

        method_exchangeImplementations(original, replacement)
        isInstalled = true
    }
}

private final class SnapshotBundleToken {}

nonisolated(unsafe) private var snapshotGermanBundle: Bundle?

private extension Bundle {
    /// After the exchange, calling `snapshotLocalizedString` runs the original implementation.
    @objc func snapshotLocalizedString(forKey key: String, value: String?, table: String?) -> String {
        if self == Bundle.main, let germanBundle = snapshotGermanBundle {
            return germanBundle.snapshotLocalizedString(forKey: key, value: value, table: table)
        }
        return snapshotLocalizedString(forKey: key, value: value, table: table)
    }
}

/// Snapshot runs only: the scroller preference cannot be changed per process through user defaults,
/// so `NSScroller.preferredScrollerStyle` is swapped for one that reports legacy scrollers.
@MainActor
private enum SnapshotScrollerStyle {
    private static var isLegacyForced = false

    static func forceLegacy(_ forced: Bool) {
        guard forced != isLegacyForced,
              let original = class_getClassMethod(NSScroller.self, #selector(getter: NSScroller.preferredScrollerStyle)),
              let replacement = class_getClassMethod(NSScroller.self, #selector(NSScroller.snapshotLegacyScrollerStyle)) else {
            return
        }

        method_exchangeImplementations(original, replacement)
        isLegacyForced = forced
        NotificationCenter.default.post(name: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil)
    }
}

private extension NSScroller {
    @objc class func snapshotLegacyScrollerStyle() -> NSScroller.Style {
        .legacy
    }
}
