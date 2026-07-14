import AppKit
import Foundation
import Testing
@testable import AudioFallback

@MainActor
struct UpdateUIIntegrationTests {
    @Test func statusMenuDisablesAndTriggersManualUpdateCheck() throws {
        let driver = TestUpdateDriver(canCheckForUpdates: false)
        let updater = UpdaterController(driver: driver)
        let menuController = StatusMenuController(
            controller: try makeUpdateUIAudioController(),
            updaterController: updater
        )

        var item = try #require(menuController.makeMenu().items.first {
            $0.title == L10n.string("menu.checkForUpdates")
        })
        #expect(item.isEnabled == false)

        driver.canCheckForUpdates = true
        driver.sendStateChange()
        item = try #require(menuController.makeMenu().items.first {
            $0.title == L10n.string("menu.checkForUpdates")
        })
        #expect(item.isEnabled == true)

        let action = try #require(item.action)
        #expect(NSApp.sendAction(action, to: item.target, from: item))
        #expect(driver.checkForUpdatesCallCount == 1)
    }

    private func makeUpdateUIAudioController() throws -> AudioFallbackController {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let preferenceStore = PreferenceStore(
            fileURL: directory.appendingPathComponent("preferences.json")
        )
        return AudioFallbackController(
            hardware: UpdateUIMockAudioHardware(),
            preferenceStore: preferenceStore
        )
    }
}

private final class UpdateUIMockAudioHardware: AudioHardwareManaging {
    func devices() throws -> [ManagedAudioDevice] {
        []
    }

    func defaultDevice(for kind: DeviceKind) throws -> ManagedAudioDevice? {
        nil
    }

    func setDefaultDevice(uid: String, for kind: DeviceKind) throws {}

    func outputLevel() throws -> OutputLevel? {
        nil
    }

    func setOutputVolume(_ volume: Float) throws {}

    func observeHardwareChanges(_ callback: @escaping @Sendable () -> Void) {}
}
