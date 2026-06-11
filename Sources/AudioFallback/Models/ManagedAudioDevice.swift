import Foundation

struct ManagedAudioDevice: Identifiable, Codable, Equatable, Hashable {
    let id: UInt32
    let uid: String
    let name: String
    let supportsInput: Bool
    let supportsOutput: Bool

    func supports(_ kind: DeviceKind) -> Bool {
        switch kind {
        case .input:
            supportsInput
        case .output:
            supportsOutput
        }
    }
}
