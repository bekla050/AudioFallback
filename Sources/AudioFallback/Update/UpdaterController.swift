import Combine

@MainActor
final class UpdaterController: ObservableObject {
    @Published private(set) var canCheckForUpdates: Bool
    @Published private(set) var automaticallyChecksForUpdates: Bool

    private let driver: any UpdateDriver

    convenience init(startAutomatically: Bool) {
        self.init(driver: SparkleUpdateDriver(startAutomatically: startAutomatically))
    }

    init(driver: any UpdateDriver) {
        self.driver = driver
        canCheckForUpdates = driver.canCheckForUpdates
        automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates
        driver.stateDidChange = { [weak self] in self?.refreshState() }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        driver.checkForUpdates()
        refreshState()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        driver.automaticallyChecksForUpdates = enabled
        refreshState()
    }

    private func refreshState() {
        canCheckForUpdates = driver.canCheckForUpdates
        automaticallyChecksForUpdates = driver.automaticallyChecksForUpdates
    }
}
