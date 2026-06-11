import Foundation

struct AudioFallbackPreferences: Codable, Equatable {
    var autoSwitchEnabled: Bool
    var inputPriorityUIDs: [String]
    var outputPriorityUIDs: [String]

    init(
        autoSwitchEnabled: Bool = true,
        inputPriorityUIDs: [String] = [],
        outputPriorityUIDs: [String] = []
    ) {
        self.autoSwitchEnabled = autoSwitchEnabled
        self.inputPriorityUIDs = inputPriorityUIDs
        self.outputPriorityUIDs = outputPriorityUIDs
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
}
