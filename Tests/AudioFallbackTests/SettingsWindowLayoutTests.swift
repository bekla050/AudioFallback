import AppKit
import Testing
@testable import AudioFallback

@MainActor
struct SettingsWindowLayoutTests {
    @Test func settingsWindowUsesFixedContentMinimumAndKeepsHeaderTopPinned() throws {
        let controller = try makeController()
        let layoutObserver = SettingsLayoutObserver()
        let window = SettingsWindowFactory.makeWindow(
            controller: controller,
            layoutObserver: layoutObserver
        )
        defer { window.close() }

        window.setFrameOrigin(NSPoint(x: 100, y: 100))
        forceLayout(window)

        let initialContentSize = try #require(window.contentView?.bounds.size)
        #expect(initialContentSize == SettingsWindowFactory.contentSize)
        #expect(window.contentMinSize == SettingsWindowFactory.contentSize)
        #expect(window.minSize == window.frameRect(forContentRect: NSRect(origin: .zero, size: SettingsWindowFactory.contentSize)).size)

        let initialHeaderFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.headerOptions))
        let initialListsFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceLists))

        window.setContentSize(NSSize(width: 800, height: 700))
        forceLayout(window)

        let expandedContentSize = try #require(window.contentView?.bounds.size)
        let expandedHeaderFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.headerOptions))
        let expandedListsFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceLists))

        #expect(expandedContentSize == NSSize(width: 800, height: 700))
        #expect(abs(expandedHeaderFrame.minY - initialHeaderFrame.minY) < 0.5)
        #expect(abs(expandedListsFrame.minY - initialListsFrame.minY) < 0.5)
        #expect(expandedListsFrame.height > initialListsFrame.height)

        window.setContentSize(SettingsWindowFactory.contentSize)
        forceLayout(window)

        let minimumContentSize = try #require(window.contentView?.bounds.size)
        #expect(minimumContentSize == SettingsWindowFactory.contentSize)

        let minimumHeaderFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.headerOptions))
        let minimumListsFrame = try #require(layoutObserver.frame(for: SettingsAccessibilityID.deviceLists))

        #expect(abs(minimumHeaderFrame.minY - initialHeaderFrame.minY) < 0.5)
        #expect(abs(minimumListsFrame.minY - initialListsFrame.minY) < 0.5)
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

    func observeHardwareChanges(_ callback: @escaping @Sendable () -> Void) {}
}
