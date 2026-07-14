import AppKit
import Testing
@testable import AudioFallback

@MainActor
struct SettingsWindowLayoutTests {
    @Test func settingsWindowUsesFixedContentMinimumAndKeepsHeaderTopPinned() throws {
        let controller = try makeController()
        let updaterController = UpdaterController(driver: TestUpdateDriver())
        let layoutObserver = SettingsLayoutObserver()
        let window = SettingsWindowFactory.makeWindow(
            controller: controller,
            updaterController: updaterController,
            layoutObserver: layoutObserver
        )
        defer { window.close() }

        window.setFrameOrigin(NSPoint(x: 100, y: 100))
        forceLayout(window)

        let initialContentSize = try #require(window.contentView?.bounds.size)
        #expect(initialContentSize == SettingsWindowFactory.contentSize)
        #expect(window.contentMinSize == SettingsWindowFactory.contentSize)
        #expect(window.minSize == window.frameRect(forContentRect: NSRect(origin: .zero, size: SettingsWindowFactory.contentSize)).size)
        let contentView = try #require(window.contentView)
        #expect(contentView.safeAreaInsets.top == 0)
        #expect(contentView.safeAreaInsets.bottom == 0)
        #expect(contentView.safeAreaRect == contentView.bounds)

        let initialRootFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.root))
        let initialHeaderFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.headerOptions))
        let automaticUpdateChecksFrame = try #require(
            layoutObserver.frame(for: SettingsAccessibilityID.automaticUpdateChecks)
        )
        let initialListsFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceLists))
        let initialInputScrollFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceScrollView(for: .input)))
        let initialOutputScrollFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceScrollView(for: .output)))
        #expect(abs(initialRootFrame.maxY - initialContentSize.height) < 0.5)
        #expect(automaticUpdateChecksFrame.minY >= initialHeaderFrame.minY)
        #expect(automaticUpdateChecksFrame.maxY <= initialHeaderFrame.maxY)
        #expect(abs(initialListsFrame.maxY - initialContentSize.height) < 0.5)
        #expect(abs(initialInputScrollFrame.maxY - initialContentSize.height) < 0.5)
        #expect(abs(initialOutputScrollFrame.maxY - initialContentSize.height) < 0.5)

        window.setContentSize(NSSize(width: 800, height: 700))
        forceLayout(window)

        let expandedContentSize = try #require(window.contentView?.bounds.size)
        let expandedRootFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.root))
        let expandedHeaderFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.headerOptions))
        let expandedListsFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceLists))
        let expandedInputScrollFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceScrollView(for: .input)))
        let expandedOutputScrollFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceScrollView(for: .output)))

        #expect(expandedContentSize == NSSize(width: 800, height: 700))
        #expect(abs(expandedRootFrame.maxY - expandedContentSize.height) < 0.5)
        #expect(abs(expandedHeaderFrame.minY - initialHeaderFrame.minY) < 0.5)
        #expect(abs(expandedListsFrame.minY - initialListsFrame.minY) < 0.5)
        #expect(abs(expandedListsFrame.maxY - expandedContentSize.height) < 0.5)
        #expect(abs(expandedInputScrollFrame.maxY - expandedContentSize.height) < 0.5)
        #expect(abs(expandedOutputScrollFrame.maxY - expandedContentSize.height) < 0.5)
        #expect(expandedListsFrame.height > initialListsFrame.height)

        window.setContentSize(SettingsWindowFactory.contentSize)
        forceLayout(window)

        let minimumContentSize = try #require(window.contentView?.bounds.size)
        #expect(minimumContentSize == SettingsWindowFactory.contentSize)

        let minimumRootFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.root))
        let minimumHeaderFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.headerOptions))
        let minimumListsFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceLists))
        let minimumInputScrollFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceScrollView(for: .input)))
        let minimumOutputScrollFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceScrollView(for: .output)))

        #expect(abs(minimumRootFrame.maxY - minimumContentSize.height) < 0.5)
        #expect(abs(minimumHeaderFrame.minY - initialHeaderFrame.minY) < 0.5)
        #expect(abs(minimumListsFrame.minY - initialListsFrame.minY) < 0.5)
        #expect(abs(minimumListsFrame.maxY - minimumContentSize.height) < 0.5)
        #expect(abs(minimumInputScrollFrame.maxY - minimumContentSize.height) < 0.5)
        #expect(abs(minimumOutputScrollFrame.maxY - minimumContentSize.height) < 0.5)
        #expect(minimumListsFrame.height <= initialListsFrame.height + 0.5)

    }

    private func makeController() throws -> AudioFallbackController {
        let microphone = layoutDevice(uid: "mic-1", name: "Microphone 1", input: true, output: false)
        let inputFallback = layoutDevice(uid: "mic-2", name: "Microphone 2", input: true, output: false)
        let speakers = layoutDevice(uid: "speaker-1", name: "Speakers 1", input: false, output: true)
        let outputFallback = layoutDevice(uid: "speaker-2", name: "Speakers 2", input: false, output: true)
        let preferences = AudioFallbackPreferences(
            inputPriorityUIDs: [microphone.uid, inputFallback.uid],
            outputPriorityUIDs: [speakers.uid, outputFallback.uid]
        )
        let controller = AudioFallbackController(
            hardware: LayoutMockAudioHardware(devices: [microphone, inputFallback, speakers, outputFallback]),
            preferenceStore: try layoutPreferenceStore(preferences)
        )
        controller.refresh()
        return controller
    }
}

@MainActor
private func forceLayout(_ window: NSWindow) {
    window.contentView?.layoutSubtreeIfNeeded()
    window.contentView?.displayIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    window.contentView?.layoutSubtreeIfNeeded()
}

private func layoutDevice(uid: String, name: String, input: Bool, output: Bool) -> ManagedAudioDevice {
    ManagedAudioDevice(
        id: UInt32(abs(uid.hashValue % Int(UInt32.max))),
        uid: uid,
        name: name,
        supportsInput: input,
        supportsOutput: output
    )
}

private func layoutPreferenceStore(_ preferences: AudioFallbackPreferences) throws -> PreferenceStore {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PreferenceStore(fileURL: directory.appendingPathComponent("preferences.json"))
    try store.save(preferences)
    return store
}

private final class LayoutMockAudioHardware: AudioHardwareManaging {
    let storedDevices: [ManagedAudioDevice]

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
        nil
    }

    func setOutputVolume(_ volume: Float) throws {}

    func observeHardwareChanges(_ callback: @escaping @Sendable () -> Void) {}
}
