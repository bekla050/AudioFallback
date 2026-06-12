import Foundation

struct AudioFallbackPreferences: Codable, Equatable {
    var autoSwitchEnabled: Bool
    var inputPriorityUIDs: [String]
    var outputPriorityUIDs: [String]
    var knownDevicesByUID: [String: ManagedAudioDevice]
    var manualInputUID: String?
    var manualOutputUID: String?

    init(
        autoSwitchEnabled: Bool = true,
        inputPriorityUIDs: [String] = [],
        outputPriorityUIDs: [String] = [],
        knownDevicesByUID: [String: ManagedAudioDevice] = [:],
        manualInputUID: String? = nil,
        manualOutputUID: String? = nil
    ) {
        self.autoSwitchEnabled = autoSwitchEnabled
        self.inputPriorityUIDs = inputPriorityUIDs
        self.outputPriorityUIDs = outputPriorityUIDs
        self.knownDevicesByUID = knownDevicesByUID
        self.manualInputUID = manualInputUID
        self.manualOutputUID = manualOutputUID
    }

    enum CodingKeys: String, CodingKey {
        case autoSwitchEnabled
        case inputPriorityUIDs
        case outputPriorityUIDs
        case knownDevicesByUID
        case manualInputUID
        case manualOutputUID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoSwitchEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoSwitchEnabled) ?? true
        inputPriorityUIDs = try container.decodeIfPresent([String].self, forKey: .inputPriorityUIDs) ?? []
        outputPriorityUIDs = try container.decodeIfPresent([String].self, forKey: .outputPriorityUIDs) ?? []
        knownDevicesByUID = try container.decodeIfPresent([String: ManagedAudioDevice].self, forKey: .knownDevicesByUID) ?? [:]
        manualInputUID = try container.decodeIfPresent(String.self, forKey: .manualInputUID)
        manualOutputUID = try container.decodeIfPresent(String.self, forKey: .manualOutputUID)
    }

    func priorityUIDs(for kind: DeviceKind) -> [String] {
        switch kind {
        case .input:
            inputPriorityUIDs
        case .output:
            outputPriorityUIDs
        }
    }

    mutating func setPriorityUIDs(_ uids: [String], for kind: DeviceKind) {
        switch kind {
        case .input:
            inputPriorityUIDs = uids
        case .output:
            outputPriorityUIDs = uids
        }
    }

    func manualUID(for kind: DeviceKind) -> String? {
        switch kind {
        case .input:
            manualInputUID
        case .output:
            manualOutputUID
        }
    }

    mutating func setManualUID(_ uid: String?, for kind: DeviceKind) {
        switch kind {
        case .input:
            manualInputUID = uid
        case .output:
            manualOutputUID = uid
        }
    }

    mutating func remember(_ devices: [ManagedAudioDevice]) {
        for device in devices {
            knownDevicesByUID[device.uid] = device
        }
    }
}
