import AppKit
import SwiftUI

@MainActor
final class StatusMenuController: NSObject {
    private let controller: AudioFallbackController
    private let statusItem: NSStatusItem
    private var settingsWindow: NSWindow?

    init(controller: AudioFallbackController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "AudioFallback", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let autoSwitchItem = NSMenuItem(
            title: L10n.string("menu.autoSwitch"),
            action: #selector(toggleAutoSwitch),
            keyEquivalent: ""
        )
        autoSwitchItem.target = self
        autoSwitchItem.state = controller.preferences.autoSwitchEnabled ? .on : .off
        menu.addItem(autoSwitchItem)

        menu.addItem(.separator())
        menu.addItem(submenuItem(title: L10n.string("devices.input"), kind: .input))
        menu.addItem(submenuItem(title: L10n.string("devices.output"), kind: .output))

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: L10n.string("menu.preferences"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let refreshItem = NSMenuItem(title: L10n.string("settings.refreshDevices"), action: #selector(refreshDevices), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.string("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func configureStatusItem() {
        statusItem.button?.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "AudioFallback")
        statusItem.button?.imagePosition = .imageLeading
    }

    private func submenuItem(title: String, kind: DeviceKind) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        let devices = controller.orderedDevices(for: kind)
        let currentUID = switch kind {
        case .input:
            controller.currentInput?.uid
        case .output:
            controller.currentOutput?.uid
        }

        if devices.isEmpty {
            submenu.addItem(NSMenuItem(title: L10n.string("devices.noneFound"), action: nil, keyEquivalent: ""))
        } else {
            for (index, device) in devices.enumerated() {
                let menuItem = NSMenuItem(
                    title: "\(index + 1). \(device.name)",
                    action: #selector(promoteFromMenu(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = MenuSelection(kind: kind, uid: device.uid)
                menuItem.state = device.uid == currentUID ? .on : .off
                submenu.addItem(menuItem)
            }
        }

        item.submenu = submenu
        return item
    }

    @objc private func toggleAutoSwitch() {
        controller.preferences.autoSwitchEnabled.toggle()
        rebuildMenu()
    }

    @objc private func refreshDevices() {
        controller.refresh()
        rebuildMenu()
    }

    @objc private func promoteFromMenu(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? MenuSelection else {
            return
        }

        controller.promoteDevice(kind: selection.kind, uid: selection.uid)
        rebuildMenu()
    }

    @objc private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AudioFallback"
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(controller: controller))
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class MenuSelection: NSObject {
    let kind: DeviceKind
    let uid: String

    init(kind: DeviceKind, uid: String) {
        self.kind = kind
        self.uid = uid
    }
}
