import Foundation
import Testing

struct UpdateLocalizationTests {
    @Test func everySupportedLocalizationContainsUpdateStrings() throws {
        let locales = ["de", "en", "es", "fr", "it", "ja", "ko", "nl", "pt-BR", "zh-Hans"]
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for locale in locales {
            let file = root
                .appendingPathComponent("Sources/AudioFallback/Resources")
                .appendingPathComponent("\(locale).lproj/Localizable.strings")
            let contents = try String(contentsOf: file, encoding: .utf8)
            #expect(contents.components(separatedBy: "\"menu.checkForUpdates\"").count == 2)
            #expect(contents.components(separatedBy: "\"settings.automaticUpdateChecks\"").count == 2)
        }
    }

    @Test func everySupportedLocalizationContainsManualOverrideMenuStrings() throws {
        let locales = ["de", "en", "es", "fr", "it", "ja", "ko", "nl", "pt-BR", "zh-Hans"]
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for locale in locales {
            let file = root
                .appendingPathComponent("Sources/AudioFallback/Resources")
                .appendingPathComponent("\(locale).lproj/Localizable.strings")
            let contents = try String(contentsOf: file, encoding: .utf8)
            for key in ["menu.manualOverrideHint", "menu.returnToPriority", "menu.volume"] {
                #expect(contents.components(separatedBy: "\"\(key)\"").count == 2, "\(locale): \(key)")
            }
        }
    }

    @Test func everySupportedLocalizationContainsSettingsPriorityStrings() throws {
        let locales = ["de", "en", "es", "fr", "it", "ja", "ko", "nl", "pt-BR", "zh-Hans"]
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let keys = [
            "devices.manual",
            "settings.applyPriority",
            "settings.manualOverrideBanner",
            "settings.priorityExplanation",
            "settings.priorityTitle"
        ]

        for locale in locales {
            let file = root
                .appendingPathComponent("Sources/AudioFallback/Resources")
                .appendingPathComponent("\(locale).lproj/Localizable.strings")
            let contents = try String(contentsOf: file, encoding: .utf8)
            for key in keys {
                #expect(contents.components(separatedBy: "\"\(key)\"").count == 2, "\(locale): \(key)")
            }
        }
    }
}
