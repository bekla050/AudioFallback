import CoreAudio
import Foundation
import OSLog

protocol AudioHardwareManaging {
    func devices() throws -> [ManagedAudioDevice]
    func defaultDevice(for kind: DeviceKind) throws -> ManagedAudioDevice?
    func setDefaultDevice(uid: String, for kind: DeviceKind) throws
    func observeHardwareChanges(_ callback: @escaping @Sendable () -> Void)
}

final class AudioHardware {
    enum HardwareError: Error {
        case coreAudio(OSStatus)
        case missingDevice(String)
    }

    private let logger = Logger(subsystem: "app.audiofallback", category: "AudioHardware")
    private var installedListenerSelectors: Set<AudioObjectPropertySelector> = []

    func devices() throws -> [ManagedAudioDevice] {
        let deviceIDs = try deviceIDs()

        return deviceIDs.compactMap { deviceID in
            do {
                let name = try stringProperty(deviceID, selector: kAudioObjectPropertyName)
                let uid = try stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)
                let supportsInput = try hasStreams(deviceID, scope: kAudioDevicePropertyScopeInput)
                let supportsOutput = try hasStreams(deviceID, scope: kAudioDevicePropertyScopeOutput)

                guard supportsInput || supportsOutput else {
                    return nil
                }

                return ManagedAudioDevice(
                    id: UInt32(deviceID),
                    uid: uid,
                    name: name,
                    supportsInput: supportsInput,
                    supportsOutput: supportsOutput
                )
            } catch {
                logger.debug("Skipping device \(deviceID, privacy: .public): \(String(describing: error), privacy: .public)")
                return nil
            }
        }
        .sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    func defaultDevice(for kind: DeviceKind) throws -> ManagedAudioDevice? {
        let selector = switch kind {
        case .input:
            kAudioHardwarePropertyDefaultInputDevice
        case .output:
            kAudioHardwarePropertyDefaultOutputDevice
        }

        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        ))

        return try devices().first { $0.id == UInt32(deviceID) }
    }

    func setDefaultDevice(uid: String, for kind: DeviceKind) throws {
        guard let deviceID = try devices().first(where: { $0.uid == uid && $0.supports(kind) })?.id else {
            throw HardwareError.missingDevice(uid)
        }

        let selectors: [AudioObjectPropertySelector] = switch kind {
        case .input:
            [kAudioHardwarePropertyDefaultInputDevice]
        case .output:
            [
                kAudioHardwarePropertyDefaultOutputDevice,
                kAudioHardwarePropertyDefaultSystemOutputDevice
            ]
        }

        for selector in selectors {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var mutableID = AudioDeviceID(deviceID)
            try check(AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &mutableID
            ))
        }
    }

    func observeHardwareChanges(_ callback: @escaping @Sendable () -> Void) {
        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultSystemOutputDevice
        ]

        for selector in selectors where !installedListenerSelectors.contains(selector) {
            installedListenerSelectors.insert(selector)
            installSystemObjectListener(selector: selector, callback: callback)
        }
    }

    private func hasStreams(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) throws -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard status == noErr else {
            return false
        }
        return dataSize >= MemoryLayout<AudioStreamID>.size
    }

    private func stringProperty(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let pointer = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
        pointer.initialize(to: nil)
        defer {
            pointer.deinitialize(count: 1)
            pointer.deallocate()
        }

        var dataSize = UInt32(MemoryLayout<CFString>.size)
        try check(AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, pointer))

        guard let value = pointer.pointee else {
            return ""
        }

        return value as String
    }

    private func deviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ))

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else {
            return []
        }

        var values = [AudioDeviceID](repeating: 0, count: count)
        try values.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return
            }

            try check(AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            ))
        }
        return values
    }

    private func installSystemObjectListener(
        selector: AudioObjectPropertySelector,
        callback: @escaping @Sendable () -> Void
    ) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { _, _ in
            callback()
        }

        if status != noErr {
            logger.error("Could not install hardware listener \(selector): \(status)")
        }
    }

    private func check(_ status: OSStatus) throws {
        guard status == noErr else {
            throw HardwareError.coreAudio(status)
        }
    }
}

extension AudioHardware: AudioHardwareManaging {}
