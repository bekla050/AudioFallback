import Combine
import Foundation
import OSLog

@MainActor
final class AudioFallbackController: ObservableObject {
    @Published private(set) var devices: [ManagedAudioDevice] = []
    @Published private(set) var currentInput: ManagedAudioDevice?
    @Published private(set) var currentOutput: ManagedAudioDevice?
    @Published private(set) var currentOutputLevel: OutputLevel?
    var currentOutputVolume: Float? {
        currentOutputLevel?.volume
    }
    @Published var preferences: AudioFallbackPreferences {
        didSet {
            savePreferences()
            applyIfNeeded()
        }
    }

    private let hardware: AudioHardwareManaging
    private let preferenceStore: PreferenceStore
    private let logger = Logger(subsystem: "app.audiofallback", category: "Controller")
    private var refreshTask: Task<Void, Never>?
    private var startupRefreshTask: Task<Void, Never>?

    init(hardware: AudioHardwareManaging = AudioHardware(), preferenceStore: PreferenceStore = PreferenceStore()) {
        self.hardware = hardware
        self.preferenceStore = preferenceStore
        self.preferences = preferenceStore.load()
    }

    func start() {
        refresh()
        scheduleStartupRefreshes()
        hardware.observeHardwareChanges { [weak self] in
            Task { @MainActor in
                self?.scheduleRefresh()
            }
        }
    }

    func refresh() {
        do {
            devices = try hardware.devices()
            currentInput = try hardware.defaultDevice(for: .input)
            currentOutput = try hardware.defaultDevice(for: .output)
            updateCurrentOutputLevel(try hardware.outputLevel())
            mergeDiscoveredDevicesIntoPreferences()
            applyIfNeeded()
        } catch {
            logger.error("Refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    func moveDevice(kind: DeviceKind, from source: IndexSet, to destination: Int) {
        guard !source.isEmpty else {
            return
        }

        var visibleUIDs = orderedDeviceListItems(for: kind).map { $0.device.uid }
        let indexes = source.sorted()
        guard indexes.allSatisfy({ visibleUIDs.indices.contains($0) }) else {
            return
        }

        let movedUIDs = indexes.map { visibleUIDs[$0] }
        for index in indexes.reversed() {
            visibleUIDs.remove(at: index)
        }

        let removedBeforeDestination = indexes.filter { $0 < destination }.count
        let insertionIndex = max(0, min(visibleUIDs.count, destination - removedBeforeDestination))
        visibleUIDs.insert(contentsOf: movedUIDs, at: insertionIndex)

        let hiddenUIDs = preferences.priorityUIDs(for: kind).filter { !visibleUIDs.contains($0) }
        let reorderedUIDs = visibleUIDs + hiddenUIDs
        guard reorderedUIDs != preferences.priorityUIDs(for: kind) else {
            return
        }

        var updated = preferences
        updated.setPriorityUIDs(reorderedUIDs, for: kind)
        updated.setManualUID(nil, for: kind)
        preferences = updated
    }

    func removeUnavailableDevice(kind: DeviceKind, uid: String) {
        guard !devices.contains(where: { $0.uid == uid && $0.supports(kind) }) else {
            return
        }

        var updated = preferences
        let uids = updated.priorityUIDs(for: kind).filter { $0 != uid }
        updated.setPriorityUIDs(uids, for: kind)
        if !updated.inputPriorityUIDs.contains(uid), !updated.outputPriorityUIDs.contains(uid) {
            updated.knownDevicesByUID[uid] = nil
        }
        if updated.manualUID(for: kind) == uid {
            updated.setManualUID(nil, for: kind)
        }
        preferences = updated
    }

    func activateDeviceFromMenu(kind: DeviceKind, uid: String) {
        guard let device = devices.first(where: { $0.uid == uid && $0.supports(kind) }) else {
            return
        }

        do {
            try hardware.setDefaultDevice(uid: uid, for: kind)
            switch kind {
            case .input:
                currentInput = device
            case .output:
                currentOutput = device
                updateCurrentOutputLevel(try hardware.outputLevel())
            }

            var updated = preferences
            updated.setManualUID(uid, for: kind)
            if updated != preferences {
                preferences = updated
            }
            logger.info("Set \(kind.title, privacy: .public) device to \(device.name, privacy: .public)")
        } catch {
            logger.error("Could not set \(kind.title, privacy: .public) device: \(String(describing: error), privacy: .public)")
        }
    }

    func orderedDevices(for kind: DeviceKind) -> [ManagedAudioDevice] {
        orderedDeviceListItems(for: kind)
            .filter(\.isAvailable)
            .map(\.device)
    }

    func orderedDeviceListItems(for kind: DeviceKind) -> [AudioDeviceListItem] {
        AudioFallbackPlanner.orderedListItems(
            for: kind,
            preferences: preferences,
            availableDevices: devices
        )
    }

    func moreMenuDevices(for kind: DeviceKind) -> [ManagedAudioDevice] {
        Array(orderedDevices(for: kind).dropFirst(5))
    }

    func outputVolume() -> Float? {
        do {
            let level = try hardware.outputLevel()
            updateCurrentOutputLevel(level)
            return level?.volume
        } catch {
            logger.error("Could not read output volume: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func setOutputVolume(_ volume: Float) {
        do {
            let clampedVolume = min(1, max(0, volume))
            try hardware.setOutputVolume(clampedVolume)
            updateCurrentOutputLevel(OutputLevel(volume: clampedVolume, isMuted: clampedVolume <= 0))
        } catch {
            logger.error("Could not set output volume: \(String(describing: error), privacy: .public)")
        }
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
                updateCurrentOutputLevel(try hardware.outputLevel())
            }
            logger.info("Set \(kind.title, privacy: .public) device to \(target.name, privacy: .public)")
        } catch {
            logger.error("Could not set \(kind.title, privacy: .public) device: \(String(describing: error), privacy: .public)")
        }
    }

    private func updateCurrentOutputLevel(_ level: OutputLevel?) {
        guard currentOutputLevel != level else {
            return
        }
        currentOutputLevel = level
    }

    private func mergeDiscoveredDevicesIntoPreferences() {
        var updated = preferences
        updated.remember(devices)

        for kind in AudioFallbackPlanner.staleManualUIDs(preferences: updated, availableDevices: devices) {
            updated.setManualUID(nil, for: kind)
        }

        updated.setPriorityUIDs(
            AudioFallbackPlanner.mergedPriorityUIDs(
                for: .input,
                preferences: updated,
                availableDevices: devices,
                preferredFirstUID: currentInput?.uid
            ),
            for: .input
        )
        updated.setPriorityUIDs(
            AudioFallbackPlanner.mergedPriorityUIDs(
                for: .output,
                preferences: updated,
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

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else {
                return
            }
            refresh()
        }
    }

    private func scheduleStartupRefreshes() {
        startupRefreshTask?.cancel()
        startupRefreshTask = Task { @MainActor in
            for _ in 0..<15 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }
                refresh()
            }
        }
    }
}
