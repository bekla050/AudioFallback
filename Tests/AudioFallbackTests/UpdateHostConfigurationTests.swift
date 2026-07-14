import Testing
@testable import AudioFallback

struct UpdateHostConfigurationTests {
    private let completeInfoDictionary: [String: Any] = [
        "CFBundleIdentifier": "app.audiofallback",
        "CFBundleVersion": "5",
        "SUFeedURL": "https://github.com/bekla050/AudioFallback/releases/latest/download/appcast.xml",
        "SUPublicEDKey": "public-key"
    ]

    @Test func acceptsCompleteProductionConfiguration() {
        #expect(UpdateHostConfiguration.canStartUpdater(infoDictionary: completeInfoDictionary))
    }

    @Test(
        "Rejects missing required value",
        arguments: ["CFBundleIdentifier", "CFBundleVersion", "SUFeedURL", "SUPublicEDKey"]
    )
    func rejectsMissingRequiredValue(key: String) {
        var infoDictionary = completeInfoDictionary
        infoDictionary.removeValue(forKey: key)

        #expect(!UpdateHostConfiguration.canStartUpdater(infoDictionary: infoDictionary))
    }

    @Test(
        "Rejects empty required value",
        arguments: ["CFBundleIdentifier", "CFBundleVersion", "SUFeedURL", "SUPublicEDKey"]
    )
    func rejectsEmptyRequiredValue(key: String) {
        var infoDictionary = completeInfoDictionary
        infoDictionary[key] = ""

        #expect(!UpdateHostConfiguration.canStartUpdater(infoDictionary: infoDictionary))
    }
}
