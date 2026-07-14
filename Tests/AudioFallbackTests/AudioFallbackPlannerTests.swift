import Testing
import Foundation
@testable import AudioFallback

struct AudioFallbackPlannerTests {
    @Test func choosesFirstAvailableInputFromPriorityList() {
        let unavailableUID = "studio-mic"
        let fallback = ManagedAudioDevice(
            id: 1,
            uid: "macbook-mic",
            name: "MacBook Microphone",
            supportsInput: true,
            supportsOutput: false
        )
        let preferences = AudioFallbackPreferences(
            inputPriorityUIDs: [unavailableUID, fallback.uid],
            outputPriorityUIDs: []
        )

        let selected = AudioFallbackPlanner.preferredDevice(
            for: .input,
            preferences: preferences,
            availableDevices: [fallback]
        )

        #expect(selected == fallback)
    }

    @Test func inputAndOutputPriorityListsAreIndependent() {
        let headset = ManagedAudioDevice(
            id: 1,
            uid: "headset",
            name: "Bluetooth Headset",
            supportsInput: true,
            supportsOutput: true
        )
        let microphone = ManagedAudioDevice(
            id: 2,
            uid: "usb-mic",
            name: "USB Microphone",
            supportsInput: true,
            supportsOutput: false
        )
        let speakers = ManagedAudioDevice(
            id: 3,
            uid: "desk-speakers",
            name: "Desk Speakers",
            supportsInput: false,
            supportsOutput: true
        )
        let preferences = AudioFallbackPreferences(
            inputPriorityUIDs: [microphone.uid, headset.uid],
            outputPriorityUIDs: [speakers.uid, headset.uid]
        )

        #expect(AudioFallbackPlanner.preferredDevice(
            for: .input,
            preferences: preferences,
            availableDevices: [headset, microphone, speakers]
        ) == microphone)

        #expect(AudioFallbackPlanner.preferredDevice(
            for: .output,
            preferences: preferences,
            availableDevices: [headset, microphone, speakers]
        ) == speakers)
    }

    @Test func mergesDiscoveredDevicesAtTheEnd() {
        let known = ManagedAudioDevice(
            id: 1,
            uid: "known",
            name: "Known",
            supportsInput: false,
            supportsOutput: true
        )
        let discovered = ManagedAudioDevice(
            id: 2,
            uid: "discovered",
            name: "Discovered",
            supportsInput: false,
            supportsOutput: true
        )
        let inputOnly = ManagedAudioDevice(
            id: 3,
            uid: "input-only",
            name: "Input Only",
            supportsInput: true,
            supportsOutput: false
        )
        let preferences = AudioFallbackPreferences(outputPriorityUIDs: [known.uid])

        let merged = AudioFallbackPlanner.mergedPriorityUIDs(
            for: .output,
            preferences: preferences,
            availableDevices: [known, discovered, inputOnly]
        )

        #expect(merged == [known.uid, discovered.uid])
    }

    @Test func seedsEmptyPriorityListWithCurrentDevice() {
        let current = ManagedAudioDevice(
            id: 1,
            uid: "current-speakers",
            name: "Current Speakers",
            supportsInput: false,
            supportsOutput: true
        )
        let other = ManagedAudioDevice(
            id: 2,
            uid: "other-speakers",
            name: "Other Speakers",
            supportsInput: false,
            supportsOutput: true
        )

        let merged = AudioFallbackPlanner.mergedPriorityUIDs(
            for: .output,
            preferences: AudioFallbackPreferences(),
            availableDevices: [other, current],
            preferredFirstUID: current.uid
        )

        #expect(merged == [current.uid, other.uid])
    }

    @Test func keepsExistingPriorityAheadOfCurrentSystemDevice() {
        let preferred = ManagedAudioDevice(
            id: 1,
            uid: "preferred-mic",
            name: "Preferred Microphone",
            supportsInput: true,
            supportsOutput: false
        )
        let systemSelected = ManagedAudioDevice(
            id: 2,
            uid: "bluetooth-headset",
            name: "Bluetooth Headset",
            supportsInput: true,
            supportsOutput: true
        )
        let preferences = AudioFallbackPreferences(inputPriorityUIDs: [preferred.uid, systemSelected.uid])

        let merged = AudioFallbackPlanner.mergedPriorityUIDs(
            for: .input,
            preferences: preferences,
            availableDevices: [systemSelected, preferred],
            preferredFirstUID: systemSelected.uid
        )

        #expect(merged == [preferred.uid, systemSelected.uid])
    }

    @Test func decodesLegacyPreferencesWithoutNewFields() throws {
        let data = """
        {
          "autoSwitchEnabled": false,
          "inputPriorityUIDs": ["legacy-mic"],
          "outputPriorityUIDs": ["legacy-speakers"]
        }
        """.data(using: .utf8)!

        let preferences = try JSONDecoder().decode(AudioFallbackPreferences.self, from: data)

        #expect(preferences.autoSwitchEnabled == false)
        #expect(preferences.inputPriorityUIDs == ["legacy-mic"])
        #expect(preferences.outputPriorityUIDs == ["legacy-speakers"])
        #expect(preferences.knownDevicesByUID.isEmpty)
        #expect(preferences.manualInputUID == nil)
        #expect(preferences.manualOutputUID == nil)
    }

    @Test func remembersLatestDiscoveredDeviceName() {
        let original = device(uid: "usb-mic", name: "Old Name", input: true, output: false)
        let renamed = device(uid: "usb-mic", name: "New Name", input: true, output: false)
        var preferences = AudioFallbackPreferences()

        preferences.remember([original])
        preferences.remember([renamed])

        #expect(preferences.knownDevicesByUID["usb-mic"]?.name == "New Name")
    }

    @Test func orderedListItemsIncludeUnavailableKnownDevices() {
        let known = device(uid: "studio-mic", name: "Studio Mic", input: true, output: false)
        let available = device(uid: "macbook-mic", name: "MacBook Mic", input: true, output: false)
        let preferences = AudioFallbackPreferences(
            inputPriorityUIDs: [known.uid, available.uid],
            knownDevicesByUID: [known.uid: known, available.uid: available]
        )

        let items = AudioFallbackPlanner.orderedListItems(
            for: .input,
            preferences: preferences,
            availableDevices: [available]
        )

        #expect(items.map { $0.device.uid } == [known.uid, available.uid])
        #expect(items.map(\.isAvailable) == [false, true])
    }

    @Test func manualMenuDeviceWinsWithoutReorderingPriorities() {
        let preferred = device(uid: "preferred-mic", name: "Preferred Mic", input: true, output: false)
        let manual = device(uid: "manual-mic", name: "Manual Mic", input: true, output: false)
        let preferences = AudioFallbackPreferences(
            inputPriorityUIDs: [preferred.uid, manual.uid],
            manualInputUID: manual.uid
        )

        let selected = AudioFallbackPlanner.preferredDevice(
            for: .input,
            preferences: preferences,
            availableDevices: [preferred, manual]
        )

        #expect(selected == manual)
        #expect(preferences.inputPriorityUIDs == [preferred.uid, manual.uid])
    }

    @Test func staleManualDeviceFallsBackToPriorityList() {
        let preferred = device(uid: "preferred-speakers", name: "Preferred Speakers", input: false, output: true)
        let preferences = AudioFallbackPreferences(
            outputPriorityUIDs: [preferred.uid],
            manualOutputUID: "missing-speakers"
        )

        let selected = AudioFallbackPlanner.preferredDevice(
            for: .output,
            preferences: preferences,
            availableDevices: [preferred]
        )

        #expect(selected == preferred)
    }

    @Test func duplicateAvailableDeviceUIDsDoNotCrashPlanner() {
        let staleDuplicate = device(uid: "shared-uid", name: "Stale Duplicate", input: false, output: true)
        let usableDuplicate = device(uid: "shared-uid", name: "Usable Duplicate", input: true, output: false)
        let preferences = AudioFallbackPreferences(inputPriorityUIDs: ["shared-uid"])

        let selected = AudioFallbackPlanner.preferredDevice(
            for: .input,
            preferences: preferences,
            availableDevices: [staleDuplicate, usableDuplicate]
        )

        #expect(selected == usableDuplicate)
    }

    @Test func duplicatePriorityUIDsOnlyCreateOneVisibleListItem() {
        let microphone = device(uid: "studio-mic", name: "Studio Mic", input: true, output: false)
        let preferences = AudioFallbackPreferences(
            inputPriorityUIDs: [microphone.uid, microphone.uid],
            knownDevicesByUID: [microphone.uid: microphone]
        )

        let items = AudioFallbackPlanner.orderedListItems(
            for: .input,
            preferences: preferences,
            availableDevices: [microphone]
        )

        #expect(items.map { $0.device.uid } == [microphone.uid])
    }

    @Test func identifiesStaleManualDeviceKinds() {
        let available = device(uid: "available-mic", name: "Available Mic", input: true, output: false)
        let preferences = AudioFallbackPreferences(
            manualInputUID: available.uid,
            manualOutputUID: "missing-speakers"
        )

        let staleKinds = AudioFallbackPlanner.staleManualUIDs(
            preferences: preferences,
            availableDevices: [available]
        )

        #expect(staleKinds == [.output])
    }

    @MainActor
    @Test func removesUnavailableDeviceFromControllerPreferences() throws {
        let unavailable = device(uid: "missing-mic", name: "Missing Mic", input: true, output: false)
        let store = try preferenceStore(
            AudioFallbackPreferences(
                inputPriorityUIDs: [unavailable.uid],
                knownDevicesByUID: [unavailable.uid: unavailable],
                manualInputUID: unavailable.uid
            )
        )
        let controller = AudioFallbackController(
            hardware: MockAudioHardware(devices: []),
            preferenceStore: store
        )

        controller.removeUnavailableDevice(kind: .input, uid: unavailable.uid)

        #expect(controller.preferences.inputPriorityUIDs.isEmpty)
        #expect(controller.preferences.knownDevicesByUID[unavailable.uid] == nil)
        #expect(controller.preferences.manualInputUID == nil)
    }

    @MainActor
    @Test func removingUnavailableDeviceFromOneListKeepsKnownDataForOtherList() throws {
        let headset = device(uid: "headset", name: "Headset", input: true, output: true)
        let store = try preferenceStore(
            AudioFallbackPreferences(
                inputPriorityUIDs: [headset.uid],
                outputPriorityUIDs: [headset.uid],
                knownDevicesByUID: [headset.uid: headset]
            )
        )
        let controller = AudioFallbackController(
            hardware: MockAudioHardware(devices: []),
            preferenceStore: store
        )

        controller.removeUnavailableDevice(kind: .input, uid: headset.uid)

        #expect(controller.preferences.inputPriorityUIDs.isEmpty)
        #expect(controller.preferences.outputPriorityUIDs == [headset.uid])
        #expect(controller.preferences.knownDevicesByUID[headset.uid] == headset)
    }

    @MainActor
    @Test func reordersVisibleDevicesUsingDragIndexes() throws {
        let first = device(uid: "first", name: "First", input: false, output: true)
        let second = device(uid: "second", name: "Second", input: false, output: true)
        let third = device(uid: "third", name: "Third", input: false, output: true)
        let store = try preferenceStore(
            AudioFallbackPreferences(
                outputPriorityUIDs: [first.uid, second.uid, third.uid],
                knownDevicesByUID: [
                    first.uid: first,
                    second.uid: second,
                    third.uid: third
                ]
            )
        )
        let controller = AudioFallbackController(
            hardware: MockAudioHardware(devices: [first, second, third]),
            preferenceStore: store
        )
        controller.refresh()

        controller.moveDevice(kind: .output, from: IndexSet(integer: 2), to: 0)

        #expect(controller.preferences.outputPriorityUIDs == [third.uid, first.uid, second.uid])
    }

    @MainActor
    @Test func reorderingClearsManualMenuSelection() throws {
        let first = device(uid: "first", name: "First", input: true, output: false)
        let second = device(uid: "second", name: "Second", input: true, output: false)
        let third = device(uid: "third", name: "Third", input: true, output: false)
        let store = try preferenceStore(
            AudioFallbackPreferences(
                inputPriorityUIDs: [first.uid, second.uid, third.uid],
                knownDevicesByUID: [
                    first.uid: first,
                    second.uid: second,
                    third.uid: third
                ],
                manualInputUID: first.uid
            )
        )
        let controller = AudioFallbackController(
            hardware: MockAudioHardware(devices: [first, second, third]),
            preferenceStore: store
        )
        controller.refresh()

        controller.moveDevice(kind: .input, from: IndexSet(integer: 0), to: 3)

        #expect(controller.preferences.inputPriorityUIDs == [second.uid, third.uid, first.uid])
        #expect(controller.preferences.manualInputUID == nil)
    }

    @MainActor
    @Test func menuActivationPersistsManualDeviceWithoutReordering() throws {
        let preferred = device(uid: "preferred-mic", name: "Preferred Mic", input: true, output: false)
        let manual = device(uid: "manual-mic", name: "Manual Mic", input: true, output: false)
        let hardware = MockAudioHardware(devices: [preferred, manual])
        let store = try preferenceStore(
            AudioFallbackPreferences(inputPriorityUIDs: [preferred.uid, manual.uid])
        )
        let controller = AudioFallbackController(
            hardware: hardware,
            preferenceStore: store
        )
        controller.refresh()

        controller.activateDeviceFromMenu(kind: .input, uid: manual.uid)

        #expect(hardware.setDefaultCalls == [SetDefaultCall(uid: manual.uid, kind: .input)])
        #expect(controller.preferences.manualInputUID == manual.uid)
        #expect(controller.preferences.inputPriorityUIDs == [preferred.uid, manual.uid])
    }

    @MainActor
    @Test func outputVolumePassesThroughControllerAndClampsInHardwareLayer() throws {
        let speakers = device(uid: "speakers", name: "Speakers", input: false, output: true)
        let hardware = MockAudioHardware(devices: [speakers])
        hardware.outputLevelValue = OutputLevel(volume: 0.4, isMuted: false)
        let controller = AudioFallbackController(
            hardware: hardware,
            preferenceStore: try preferenceStore(AudioFallbackPreferences())
        )

        #expect(controller.outputVolume() == 0.4)
        #expect(controller.currentOutputVolume == 0.4)

        controller.setOutputVolume(0.75)

        #expect(hardware.setOutputVolumeCalls == [0.75])
        #expect(controller.currentOutputVolume == 0.75)
        #expect(controller.currentOutputLevel == OutputLevel(volume: 0.75, isMuted: false))
    }

    @MainActor
    @Test func outputLevelTreatsZeroVolumeAndMuteAsSilent() throws {
        let speakers = device(uid: "speakers", name: "Speakers", input: false, output: true)
        let hardware = MockAudioHardware(devices: [speakers])
        hardware.outputLevelValue = OutputLevel(volume: 0, isMuted: false)
        let controller = AudioFallbackController(
            hardware: hardware,
            preferenceStore: try preferenceStore(AudioFallbackPreferences())
        )

        #expect(controller.outputVolume() == 0)
        #expect(controller.currentOutputLevel?.isSilent == true)

        hardware.outputLevelValue = OutputLevel(volume: 0.1, isMuted: true)

        #expect(controller.outputVolume() == 0.1)
        #expect(controller.currentOutputLevel?.isSilent == true)

        controller.setOutputVolume(0.1)

        #expect(controller.currentOutputLevel == OutputLevel(volume: 0.1, isMuted: false))
    }
}

private func device(uid: String, name: String, input: Bool, output: Bool) -> ManagedAudioDevice {
    ManagedAudioDevice(
        id: UInt32(abs(uid.hashValue % Int(UInt32.max))),
        uid: uid,
        name: name,
        supportsInput: input,
        supportsOutput: output
    )
}

private func preferenceStore(_ preferences: AudioFallbackPreferences) throws -> PreferenceStore {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PreferenceStore(fileURL: directory.appendingPathComponent("preferences.json"))
    try store.save(preferences)
    return store
}

private struct SetDefaultCall: Equatable {
    let uid: String
    let kind: DeviceKind
}

private final class MockAudioHardware: AudioHardwareManaging {
    var storedDevices: [ManagedAudioDevice]
    var setDefaultCalls: [SetDefaultCall] = []
    var outputLevelValue: OutputLevel?
    var setOutputVolumeCalls: [Float] = []

    init(devices: [ManagedAudioDevice]) {
        self.storedDevices = devices
    }

    func devices() throws -> [ManagedAudioDevice] {
        storedDevices
    }

    func defaultDevice(for kind: DeviceKind) throws -> ManagedAudioDevice? {
        storedDevices.first { $0.supports(kind) }
    }

    func setDefaultDevice(uid: String, for kind: DeviceKind) throws {
        setDefaultCalls.append(SetDefaultCall(uid: uid, kind: kind))
    }

    func outputLevel() throws -> OutputLevel? {
        outputLevelValue
    }

    func setOutputVolume(_ volume: Float) throws {
        setOutputVolumeCalls.append(volume)
    }

    func observeHardwareChanges(_ callback: @escaping @Sendable () -> Void) {}
}
