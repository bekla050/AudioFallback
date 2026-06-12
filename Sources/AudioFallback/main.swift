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

        controller.$devices
            .sink { [weak self] _ in
                self?.statusMenuController?.rebuildMenu()
            }
            .store(in: &cancellables)

        controller.$preferences
            .sink { [weak self] _ in
                self?.statusMenuController?.rebuildMenu()
            }
            .store(in: &cancellables)

        controller.$currentInput
            .sink { [weak self] _ in
                self?.statusMenuController?.rebuildMenu()
            }
            .store(in: &cancellables)

        controller.$currentOutput
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
