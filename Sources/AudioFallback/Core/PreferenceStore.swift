import Foundation

final class PreferenceStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioFallback", isDirectory: true)
        self.fileURL = fileURL ?? baseURL.appendingPathComponent("preferences.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func load() -> AudioFallbackPreferences {
        guard let data = try? Data(contentsOf: fileURL) else {
            return AudioFallbackPreferences()
        }

        return (try? decoder.decode(AudioFallbackPreferences.self, from: data)) ?? AudioFallbackPreferences()
    }

    func save(_ preferences: AudioFallbackPreferences) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(preferences)
        try data.write(to: fileURL, options: .atomic)
    }
}
