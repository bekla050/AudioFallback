import Foundation
import Sparkle

@MainActor
protocol UpdateDriver: AnyObject {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    var stateDidChange: (() -> Void)? { get set }

    func checkForUpdates()
}

@MainActor
final class SparkleUpdateDriver: UpdateDriver {
    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var stateDidChange: (() -> Void)?

    private let controller: SPUStandardUpdaterController
    private var canCheckObservation: NSKeyValueObservation?
    private var automaticChecksObservation: NSKeyValueObservation?

    init(startAutomatically: Bool) {
        controller = SPUStandardUpdaterController(
            startingUpdater: startAutomatically,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) {
            [weak self] _, _ in
            Task { @MainActor in self?.stateDidChange?() }
        }
        automaticChecksObservation = controller.updater.observe(
            \.automaticallyChecksForUpdates,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor in self?.stateDidChange?() }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
