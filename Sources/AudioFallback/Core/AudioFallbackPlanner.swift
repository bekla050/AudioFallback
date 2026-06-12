import Foundation

struct AudioFallbackPlanner {
    static func preferredDevice(
        for kind: DeviceKind,
        preferences: AudioFallbackPreferences,
        availableDevices: [ManagedAudioDevice]
    ) -> ManagedAudioDevice? {
        let devicesByUID = availableDevicesByUID(for: kind, from: availableDevices)

        if let manualUID = preferences.manualUID(for: kind),
           let manualDevice = devicesByUID[manualUID] {
            return manualDevice
        }

        return uniqueUIDs(preferences.priorityUIDs(for: kind))
            .lazy
            .compactMap { devicesByUID[$0] }
            .first
    }

    static func mergedPriorityUIDs(
        for kind: DeviceKind,
        preferences: AudioFallbackPreferences,
        availableDevices: [ManagedAudioDevice],
        preferredFirstUID: String? = nil
    ) -> [String] {
        let current = uniqueUIDs(preferences.priorityUIDs(for: kind))
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

        return uniqueUIDs(seededCurrent + discovered)
    }

    static func orderedListItems(
        for kind: DeviceKind,
        preferences: AudioFallbackPreferences,
        availableDevices: [ManagedAudioDevice]
    ) -> [AudioDeviceListItem] {
        let availableDevicesByUID = availableDevicesByUID(for: kind, from: availableDevices)

        return uniqueUIDs(preferences.priorityUIDs(for: kind)).compactMap { uid in
            if let availableDevice = availableDevicesByUID[uid] {
                return AudioDeviceListItem(device: availableDevice, isAvailable: true)
            }

            guard let knownDevice = preferences.knownDevicesByUID[uid], knownDevice.supports(kind) else {
                return nil
            }

            return AudioDeviceListItem(device: knownDevice, isAvailable: false)
        }
    }

    static func staleManualUIDs(
        preferences: AudioFallbackPreferences,
        availableDevices: [ManagedAudioDevice]
    ) -> Set<DeviceKind> {
        Set(DeviceKind.allCases.filter { kind in
            guard let manualUID = preferences.manualUID(for: kind) else {
                return false
            }

            return !availableDevices.contains { $0.uid == manualUID && $0.supports(kind) }
        })
    }

    private static func availableDevicesByUID(
        for kind: DeviceKind,
        from availableDevices: [ManagedAudioDevice]
    ) -> [String: ManagedAudioDevice] {
        var devicesByUID: [String: ManagedAudioDevice] = [:]
        for device in availableDevices where device.supports(kind) {
            devicesByUID[device.uid] = device
        }
        return devicesByUID
    }

    private static func uniqueUIDs(_ uids: [String]) -> [String] {
        var seenUIDs: Set<String> = []
        return uids.filter { seenUIDs.insert($0).inserted }
    }
}
