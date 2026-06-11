import Foundation

enum DeviceKind: String, CaseIterable, Codable, Hashable {
    case input
    case output

    var title: String {
        switch self {
        case .input:
            "Input"
        case .output:
            "Output"
        }
    }
}
