import Testing
@testable import AudioFallback

@MainActor
struct UpdaterControllerTests {
    @Test func mirrorsInitialDriverState() {
        let driver = TestUpdateDriver(canCheckForUpdates: false, automaticallyChecksForUpdates: true)
        let controller = UpdaterController(driver: driver)

        #expect(controller.canCheckForUpdates == false)
        #expect(controller.automaticallyChecksForUpdates == true)
    }

    @Test func forwardsManualChecks() {
        let driver = TestUpdateDriver()
        let controller = UpdaterController(driver: driver)

        controller.checkForUpdates()

        #expect(driver.checkForUpdatesCallCount == 1)
    }

    @Test func persistsAndMirrorsAutomaticCheckChanges() {
        let driver = TestUpdateDriver(automaticallyChecksForUpdates: true)
        let controller = UpdaterController(driver: driver)

        controller.setAutomaticallyChecksForUpdates(false)

        #expect(driver.automaticallyChecksForUpdates == false)
        #expect(controller.automaticallyChecksForUpdates == false)
    }

    @Test func refreshesWhenDriverStateChanges() {
        let driver = TestUpdateDriver(canCheckForUpdates: false, automaticallyChecksForUpdates: true)
        let controller = UpdaterController(driver: driver)
        driver.canCheckForUpdates = true
        driver.automaticallyChecksForUpdates = false

        driver.sendStateChange()

        #expect(controller.canCheckForUpdates == true)
        #expect(controller.automaticallyChecksForUpdates == false)
    }
}
