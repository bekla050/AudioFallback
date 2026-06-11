import Foundation

enum L10n {
    private static let bundle: Bundle = {
        let bundleName = "AudioFallback_AudioFallback.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName)
        ]

        for candidate in candidates {
            guard let candidate, let bundle = Bundle(url: candidate) else {
                continue
            }

            return bundle
        }

        return .main
    }()

    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: .current, arguments: arguments)
    }
}
