import AppKit
import OSLog
import SwiftUI

@MainActor
final class StatusMenuController: NSObject {
    private let controller: AudioFallbackController
    private let statusItem: NSStatusItem
    private let logger = Logger(subsystem: "app.audiofallback", category: "StatusMenu")
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
        menu.delegate = self

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
        addDeviceSection(to: menu, title: L10n.string("devices.input"), kind: .input)
        menu.addItem(.separator())
        addDeviceSection(to: menu, title: L10n.string("devices.output"), kind: .output)

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

    private func addDeviceSection(to menu: NSMenu, title: String, kind: DeviceKind) {
        let headerItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let devices = controller.orderedDevices(for: kind)
        let currentUID = switch kind {
        case .input:
            controller.currentInput?.uid
        case .output:
            controller.currentOutput?.uid
        }

        if devices.isEmpty {
            let item = NSMenuItem(title: L10n.string("devices.noneFound"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for (index, device) in devices.prefix(5).enumerated() {
                menu.addItem(deviceMenuItem(
                    device: device,
                    kind: kind,
                    currentUID: currentUID,
                    index: index
                ))
            }

            let moreDevices = controller.moreMenuDevices(for: kind)
            if !moreDevices.isEmpty {
                let moreItem = NSMenuItem(title: L10n.string("menu.moreDevices"), action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: L10n.string("menu.moreDevices"))
                for (index, device) in moreDevices.enumerated() {
                    submenu.addItem(deviceMenuItem(
                        device: device,
                        kind: kind,
                        currentUID: currentUID,
                        index: index + 5
                    ))
                }
                moreItem.submenu = submenu
                menu.addItem(moreItem)
            }
        }
    }

    private func deviceMenuItem(
        device: ManagedAudioDevice,
        kind: DeviceKind,
        currentUID: String?,
        index: Int
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: "\(index + 1). \(device.name)",
            action: #selector(activateFromMenu(_:)),
            keyEquivalent: ""
        )
        menuItem.target = self
        menuItem.representedObject = MenuSelection(kind: kind, uid: device.uid)
        menuItem.state = device.uid == currentUID ? .on : .off
        return menuItem
    }

    @objc private func toggleAutoSwitch() {
        controller.preferences.autoSwitchEnabled.toggle()
        rebuildMenu()
    }

    @objc private func refreshDevices() {
        controller.refresh()
        rebuildMenu()
    }

    @objc private func activateFromMenu(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? MenuSelection else {
            return
        }

        controller.activateDeviceFromMenu(kind: selection.kind, uid: selection.uid)
        rebuildMenu()
    }

    @objc private func showSettings() {
        if let settingsWindow {
            logSettingsWindowEvent("Showing existing settings window")
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = SettingsWindowFactory.makeWindow(controller: controller)
        logSettingsWindowEvent("Creating settings window")
        window.center()
        window.delegate = self
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func logSettingsWindowEvent(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        NSLog("AudioFallback SettingsWindow: %@", message)
    }
}

enum SettingsWindowFactory {
    static let contentSize = NSSize(width: 800, height: 500)

    @MainActor
    static func makeWindow(
        controller: AudioFallbackController,
        layoutObserver: SettingsLayoutObserver? = nil
    ) -> NSWindow {
        let contentRect = NSRect(origin: .zero, size: contentSize)
        let window = SettingsWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let hostingView = NSHostingView(rootView: SettingsView(
            controller: controller,
            layoutObserver: layoutObserver
        ))
        hostingView.sizingOptions = []
        hostingView.frame = contentRect
        hostingView.autoresizingMask = [.width, .height]

        window.title = "AudioFallback"
        window.contentView = hostingView
        window.setContentSize(contentSize)
        window.contentMinSize = contentSize
        window.minSize = window.frameRect(forContentRect: contentRect).size
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.canHide = false
        window.hidesOnDeactivate = false
        window.level = .floating
        return window
    }
}

private final class SettingsWindow: NSWindow {
    override var contentMinSize: NSSize {
        get {
            super.contentMinSize
        }
        set {
            super.contentMinSize = NSSize(
                width: max(newValue.width, SettingsWindowFactory.contentSize.width),
                height: max(newValue.height, SettingsWindowFactory.contentSize.height)
            )
        }
    }

    override var minSize: NSSize {
        get {
            super.minSize
        }
        set {
            let minimumFrameSize = frameRect(forContentRect: NSRect(
                origin: .zero,
                size: SettingsWindowFactory.contentSize
            )).size
            super.minSize = NSSize(
                width: max(newValue.width, minimumFrameSize.width),
                height: max(newValue.height, minimumFrameSize.height)
            )
        }
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        controller.refresh()
    }
}

extension StatusMenuController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === settingsWindow else {
            return true
        }

        logSettingsWindowEvent("Settings window should close")
        return true
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else {
            return
        }

        logSettingsWindowEvent("Settings window will close")
        settingsWindow = nil
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else {
            return
        }

        logSettingsWindowEvent("Settings window did become key")
    }

    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else {
            return
        }

        logSettingsWindowEvent("Settings window did resign key")
    }

    func windowDidMiniaturize(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else {
            return
        }

        logSettingsWindowEvent("Settings window did miniaturize")
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
