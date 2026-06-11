import Combine
import Foundation
import OSLog

@MainActor
final class AudioFallbackController: ObservableObject {
    @Published private(set) var devices: [ManagedAudioDevice] = []
    @Published private(set) var currentInput: ManagedAudioDevice?
    @Published private(set) var currentOutput: ManagedAudioDevice?
    @Published var preferences: AudioFallbackPreferences {
        didSet {
            savePreferences()
            applyIfNeeded()
        }
    }

    private let hardware: AudioHardware
    private let preferenceStore: PreferenceStore
    private let logger = Logger(subsystem: "app.audiofallback", category: "Controller")

    init(hardware: AudioHardware = AudioHardware(), preferenceStore: PreferenceStore = PreferenceStore()) {
        self.hardware = hardware
        self.preferenceStore = preferenceStore
        self.preferences = preferenceStore.load()
    }

    func start() {
        refresh()
        hardware.observeDeviceChanges { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        do {
            devices = try hardware.devices()
            currentInput = try hardware.defaultDevice(for: .input)
            currentOutput = try hardware.defaultDevice(for: .output)
            mergeDiscoveredDevicesIntoPreferences()
            applyIfNeeded()
        } catch {
            logger.error("Refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    func moveDevice(kind: DeviceKind, uid: String, direction: Int) {
        var uids = preferences.priorityUIDs(for: kind)
        guard let index = uids.firstIndex(of: uid) else {
            return
        }

        let newIndex = max(0, min(uids.count - 1, index + direction))
        guard newIndex != index else {
            return
        }

        uids.swapAt(index, newIndex)
        preferences.setPriorityUIDs(uids, for: kind)
    }

    func promoteDevice(kind: DeviceKind, uid: String) {
        var uids = preferences.priorityUIDs(for: kind).filter { $0 != uid }
        uids.insert(uid, at: 0)
        preferences.setPriorityUIDs(uids, for: kind)
    }

    func orderedDevices(for kind: DeviceKind) -> [ManagedAudioDevice] {
        let devicesByUID = Dictionary(uniqueKeysWithValues: devices.map { ($0.uid, $0) })
        return preferences.priorityUIDs(for: kind)
            .compactMap { devicesByUID[$0] }
            .filter { $0.supports(kind) }
    }

    private func applyIfNeeded() {
        guard preferences.autoSwitchEnabled else {
            return
        }

        applyIfNeeded(for: .input, currentDevice: currentInput)
        applyIfNeeded(for: .output, currentDevice: currentOutput)
    }

    private func applyIfNeeded(for kind: DeviceKind, currentDevice: ManagedAudioDevice?) {
        guard let target = AudioFallbackPlanner.preferredDevice(
            for: kind,
            preferences: preferences,
            availableDevices: devices
        ) else {
            return
        }

        guard currentDevice?.uid != target.uid else {
            return
        }

        do {
            try hardware.setDefaultDevice(uid: target.uid, for: kind)
            switch kind {
            case .input:
                currentInput = target
            case .output:
                currentOutput = target
            }
            logger.info("Set \(kind.title, privacy: .public) device to \(target.name, privacy: .public)")
        } catch {
            logger.error("Could not set \(kind.title, privacy: .public) device: \(String(describing: error), privacy: .public)")
        }
    }

    private func mergeDiscoveredDevicesIntoPreferences() {
        var updated = preferences
        updated.setPriorityUIDs(
            AudioFallbackPlanner.mergedPriorityUIDs(
                for: .input,
                preferences: preferences,
                availableDevices: devices,
                preferredFirstUID: currentInput?.uid
            ),
            for: .input
        )
        updated.setPriorityUIDs(
            AudioFallbackPlanner.mergedPriorityUIDs(
                for: .output,
                preferences: preferences,
                availableDevices: devices,
                preferredFirstUID: currentOutput?.uid
            ),
            for: .output
        )

        if updated != preferences {
            preferences = updated
        }
    }

    private func savePreferences() {
        do {
            try preferenceStore.save(preferences)
        } catch {
            logger.error("Could not save preferences: \(String(describing: error), privacy: .public)")
        }
    }
}
