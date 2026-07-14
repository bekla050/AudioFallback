import AudioToolbox
import CoreAudio
import Foundation
import OSLog

protocol AudioHardwareManaging {
    func devices() throws -> [ManagedAudioDevice]
    func defaultDevice(for kind: DeviceKind) throws -> ManagedAudioDevice?
    func setDefaultDevice(uid: String, for kind: DeviceKind) throws
    func outputLevel() throws -> OutputLevel?
    func setOutputVolume(_ volume: Float) throws
    func observeHardwareChanges(_ callback: @escaping @Sendable () -> Void)
}

final class AudioHardware {
    enum HardwareError: Error {
        case coreAudio(OSStatus)
        case missingDevice(String)
    }

    private let logger = Logger(subsystem: "app.audiofallback", category: "AudioHardware")
    private var installedListenerSelectors: Set<AudioObjectPropertySelector> = []
    private var installedOutputLevelListenerKeys: Set<OutputLevelListenerKey> = []

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

    func outputLevel() throws -> OutputLevel? {
        guard let deviceID = try defaultDevice(for: .output)?.id else {
            return nil
        }

        let objectID = AudioObjectID(deviceID)
        let volume = try outputVolume(deviceID: objectID)
        let muted = try outputMuted(deviceID: objectID)
        guard volume != nil || muted != nil else {
            return nil
        }

        return OutputLevel(volume: volume, isMuted: muted ?? false)
    }

    func outputVolume() throws -> Float? {
        try outputLevel()?.volume
    }

    private func outputVolume(deviceID: AudioObjectID) throws -> Float? {
        guard var address = supportedVolumeAddress(deviceID: deviceID) else {
            return nil
        }

        var volume = Float32(0)
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        try check(AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &volume
        ))
        return min(1, max(0, Float(volume)))
    }

    private func outputMuted(deviceID: AudioObjectID) throws -> Bool? {
        var address = muteAddress()
        guard AudioObjectHasProperty(deviceID, &address) else {
            return nil
        }

        var muteValue: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        try check(AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &muteValue
        ))
        return muteValue != 0
    }

    func setOutputVolume(_ volume: Float) throws {
        guard let deviceID = try defaultDevice(for: .output)?.id else {
            return
        }

        var clampedVolume = Float32(min(1, max(0, volume)))
        var didSetVolume = false

        for address in volumeAddresses() {
            var mutableAddress = address
            guard AudioObjectHasProperty(AudioObjectID(deviceID), &mutableAddress) else {
                continue
            }

            var isSettable = DarwinBoolean(false)
            try check(AudioObjectIsPropertySettable(AudioObjectID(deviceID), &mutableAddress, &isSettable))
            guard isSettable.boolValue else {
                continue
            }

            try check(AudioObjectSetPropertyData(
                AudioObjectID(deviceID),
                &mutableAddress,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &clampedVolume
            ))
            didSetVolume = true
        }

        guard didSetVolume else {
            return
        }

        try setOutputMuted(clampedVolume <= 0, deviceID: AudioObjectID(deviceID))
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

        installCurrentOutputVolumeListener(callback: callback)
    }

    private func volumeAddresses() -> [AudioObjectPropertyAddress] {
        [
            AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
        ]
    }

    private func supportedVolumeAddress(deviceID: AudioObjectID) -> AudioObjectPropertyAddress? {
        volumeAddresses().first { address in
            var mutableAddress = address
            return AudioObjectHasProperty(deviceID, &mutableAddress)
        }
    }

    private func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func setOutputMuted(_ muted: Bool, deviceID: AudioObjectID) throws {
        var address = muteAddress()
        guard AudioObjectHasProperty(deviceID, &address) else {
            return
        }

        var isSettable = DarwinBoolean(false)
        try check(AudioObjectIsPropertySettable(deviceID, &address, &isSettable))
        guard isSettable.boolValue else {
            return
        }

        var muteValue: UInt32 = muted ? 1 : 0
        try check(AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &muteValue
        ))
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
        ) { [weak self] _, _ in
            self?.installCurrentOutputVolumeListener(callback: callback)
            callback()
        }

        if status != noErr {
            logger.error("Could not install hardware listener \(selector): \(status)")
        }
    }

    private func installCurrentOutputVolumeListener(callback: @escaping @Sendable () -> Void) {
        do {
            guard let deviceID = try defaultDevice(for: .output)?.id else {
                return
            }

            let objectID = AudioObjectID(deviceID)
            for address in volumeAddresses() {
                installCurrentOutputLevelListener(
                    objectID: objectID,
                    address: address,
                    callback: callback
                )
            }
            installCurrentOutputLevelListener(
                objectID: objectID,
                address: muteAddress(),
                callback: callback
            )
        } catch {
            logger.error("Could not install output volume listener: \(String(describing: error), privacy: .public)")
        }
    }

    private func installCurrentOutputLevelListener(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        callback: @escaping @Sendable () -> Void
    ) {
        var mutableAddress = address
        guard AudioObjectHasProperty(objectID, &mutableAddress) else {
            return
        }

        let key = OutputLevelListenerKey(objectID: objectID, selector: address.mSelector)
        guard !installedOutputLevelListenerKeys.contains(key) else {
            return
        }

        let status = AudioObjectAddPropertyListenerBlock(
            objectID,
            &mutableAddress,
            DispatchQueue.main
        ) { _, _ in
            callback()
        }

        if status == noErr {
            installedOutputLevelListenerKeys.insert(key)
        } else {
            logger.error("Could not install output level listener \(objectID) \(address.mSelector): \(status)")
        }
    }

    private func check(_ status: OSStatus) throws {
        guard status == noErr else {
            throw HardwareError.coreAudio(status)
        }
    }
}

extension AudioHardware: AudioHardwareManaging {}

private struct OutputLevelListenerKey: Hashable {
    let objectID: AudioObjectID
    let selector: AudioObjectPropertySelector
}
