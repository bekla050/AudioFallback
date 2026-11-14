import AppKit
import Foundation
import Testing
@testable import AudioFallback

@MainActor
struct StatusMenuControllerTests {
    private let preferredMic = menuTestDevice(uid: "preferred-mic", name: "Preferred Mic", input: true, output: false)
    private let manualMic = menuTestDevice(uid: "manual-mic", name: "Manual Mic", input: true, output: false)
    private let speakers = menuTestDevice(uid: "speakers", name: "Speakers", input: false, output: true)

    @Test func menuUsesSectionHeadersForVolumeAndDeviceLists() throws {
        let (_, menuController) = try makeMenuController(manualInputUID: nil)

        let headers = menuController.makeMenu().items.filter(\.isSectionHeader).map(\.title)

        #expect(headers == [
            L10n.string("menu.volume"),
            L10n.string("devices.input"),
            L10n.string("devices.output")
        ])
    }

    @Test func manualOverrideShowsHintAndReturnItemInAffectedSectionOnly() throws {
        let (_, menuController) = try makeMenuController(manualInputUID: manualMic.uid)

        let items = menuController.makeMenu().items
        let hintIndexes = items.indices.filter { items[$0].title == L10n.string("menu.manualOverrideHint") }
        let returnTitle = L10n.format("menu.returnToPriority", preferredMic.name)
        let returnIndexes = items.indices.filter { items[$0].title == returnTitle }
        let outputHeaderIndex = try #require(items.firstIndex {
            $0.isSectionHeader && $0.title == L10n.string("devices.output")
        })
        let lastInputDeviceIndex = try #require(items.lastIndex { $0.title == "2. \(manualMic.name)" })

        #expect(hintIndexes.count == 1)
        #expect(returnIndexes.count == 1)
        let hintIndex = try #require(hintIndexes.first)
        let returnIndex = try #require(returnIndexes.first)
        #expect(items[hintIndex].isEnabled == false)
        #expect(hintIndex == lastInputDeviceIndex + 1)
        #expect(returnIndex == hintIndex + 1)
        #expect(returnIndex < outputHeaderIndex)
    }

    @Test func menuWithoutManualOverrideHasNoHintOrReturnItem() throws {
        let (_, menuController) = try makeMenuController(manualInputUID: nil)

        let titles = menuController.makeMenu().items.map(\.title)

        #expect(!titles.contains(L10n.string("menu.manualOverrideHint")))
        #expect(!titles.contains(L10n.format("menu.returnToPriority", preferredMic.name)))
    }

    @Test func returnItemClearsManualOverride() throws {
        let (audioController, menuController) = try makeMenuController(manualInputUID: manualMic.uid)
        let returnTitle = L10n.format("menu.returnToPriority", preferredMic.name)

        let item = try #require(menuController.makeMenu().items.first { $0.title == returnTitle })
        let action = try #require(item.action)
        #expect(NSApp.sendAction(action, to: item.target, from: item))

        #expect(audioController.preferences.manualInputUID == nil)
        #expect(audioController.currentInput == preferredMic)
    }

    @Test func rebuildKeepsMenuInstanceAndStructureWhileMenuIsOpen() throws {
        let (audioController, menuController) = try makeMenuController(manualInputUID: nil)
        let menu = try #require(menuController.statusItemMenu)
        menuController.menuNeedsUpdate(menu)
        menuController.menuWillOpen(menu)
        let openItems = menu.items

        audioController.activateDeviceFromMenu(kind: .input, uid: manualMic.uid)
        menuController.rebuildMenu()

        #expect(menuController.statusItemMenu === menu)
        #expect(menu.items.count == openItems.count)
        #expect(zip(menu.items, openItems).allSatisfy { $0 === $1 })

        menuController.menuDidClose(menu)
        menuController.menuNeedsUpdate(menu)

        #expect(menuController.statusItemMenu === menu)
        #expect(menu.items.contains { $0.title == L10n.string("menu.manualOverrideHint") })
    }

    private func makeMenuController(
        manualInputUID: String?
    ) throws -> (audioController: AudioFallbackController, menuController: StatusMenuController) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = PreferenceStore(fileURL: directory.appendingPathComponent("preferences.json"))
        try store.save(AudioFallbackPreferences(
            inputPriorityUIDs: [preferredMic.uid, manualMic.uid],
            outputPriorityUIDs: [speakers.uid],
            manualInputUID: manualInputUID
        ))
        let audioController = AudioFallbackController(
            hardware: MenuTestAudioHardware(devices: [preferredMic, manualMic, speakers]),
            preferenceStore: store
        )
        audioController.refresh()
        let menuController = StatusMenuController(
            controller: audioController,
            updaterController: UpdaterController(driver: TestUpdateDriver())
        )
        return (audioController, menuController)
    }
}

private func menuTestDevice(uid: String, name: String, input: Bool, output: Bool) -> ManagedAudioDevice {
    ManagedAudioDevice(
        id: UInt32(abs(uid.hashValue % Int(UInt32.max))),
        uid: uid,
        name: name,
        supportsInput: input,
        supportsOutput: output
    )
}

private final class MenuTestAudioHardware: AudioHardwareManaging {
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
