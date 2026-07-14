@testable import AudioFallback

@MainActor
final class TestUpdateDriver: UpdateDriver {
    var canCheckForUpdates: Bool
    var automaticallyChecksForUpdates: Bool
    var stateDidChange: (() -> Void)?
    private(set) var checkForUpdatesCallCount = 0

    init(canCheckForUpdates: Bool = true, automaticallyChecksForUpdates: Bool = true) {
        self.canCheckForUpdates = canCheckForUpdates
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }

    func sendStateChange() {
        stateDidChange?()
    }
}
