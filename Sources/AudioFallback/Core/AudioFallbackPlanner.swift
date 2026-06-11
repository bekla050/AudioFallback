import Foundation

struct AudioFallbackPlanner {
    static func preferredDevice(
        for kind: DeviceKind,
        preferences: AudioFallbackPreferences,
        availableDevices: [ManagedAudioDevice]
    ) -> ManagedAudioDevice? {
        let devicesByUID = Dictionary(uniqueKeysWithValues: availableDevices.map { ($0.uid, $0) })

        return preferences.priorityUIDs(for: kind)
            .lazy
            .compactMap { devicesByUID[$0] }
            .first { $0.supports(kind) }
    }

    static func mergedPriorityUIDs(
        for kind: DeviceKind,
        preferences: AudioFallbackPreferences,
        availableDevices: [ManagedAudioDevice],
        preferredFirstUID: String? = nil
    ) -> [String] {
        let current = preferences.priorityUIDs(for: kind)
        let seededCurrent: [String]
        if current.isEmpty, let preferredFirstUID {
            seededCurrent = [preferredFirstUID]
        } else {
            seededCurrent = current
        }

        let currentSet = Set(seededCurrent)
        let discovered = availableDevices
            .filter { $0.supports(kind) }
            .map(\.uid)
            .filter { !currentSet.contains($0) }

        return seededCurrent + discovered
    }
}
