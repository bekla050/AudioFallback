enum UpdateHostConfiguration {
    private static let requiredKeys = [
        "CFBundleIdentifier",
        "CFBundleVersion",
        "SUFeedURL",
        "SUPublicEDKey"
    ]

    static func canStartUpdater(infoDictionary: [String: Any]?) -> Bool {
        guard let infoDictionary else { return false }

        return requiredKeys.allSatisfy { key in
            guard let value = infoDictionary[key] as? String else { return false }
            return !value.isEmpty
        }
    }
}
