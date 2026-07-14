import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = AudioFallbackController()
    private var statusMenuController: StatusMenuController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller.start()
        statusMenuController = StatusMenuController(controller: controller)

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
