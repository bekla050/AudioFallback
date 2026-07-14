import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = AudioFallbackController()
    private var updaterController: UpdaterController?
    private var statusMenuController: StatusMenuController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller.start()
        let updaterController = UpdaterController(
            startAutomatically: UpdateHostConfiguration.canStartUpdater(
                infoDictionary: Bundle.main.infoDictionary
            )
        )
        self.updaterController = updaterController
        statusMenuController = StatusMenuController(
            controller: controller,
            updaterController: updaterController
        )

        updaterController.$canCheckForUpdates
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.statusMenuController?.rebuildMenu() }
            .store(in: &cancellables)

        updaterController.$automaticallyChecksForUpdates
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.statusMenuController?.rebuildMenu() }
            .store(in: &cancellables)

        // @Published emits in willSet, before the stored property is updated.
        // rebuildMenu() reads the controller state back, so deliver on the next
        // main-queue tick to ensure it observes the committed value, not the
        // previous one (otherwise the menu/icon lags one change behind).
        controller.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusMenuController?.rebuildMenu()
            }
            .store(in: &cancellables)

        controller.$preferences
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusMenuController?.rebuildMenu()
            }
            .store(in: &cancellables)

        controller.$currentInput
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusMenuController?.rebuildMenu()
            }
            .store(in: &cancellables)

        controller.$currentOutput
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusMenuController?.rebuildMenu()
            }
            .store(in: &cancellables)

        controller.$currentOutputLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusMenuController?.rebuildMenu()
            }
            .store(in: &cancellables)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
