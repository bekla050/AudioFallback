import AppKit
import OSLog
import SwiftUI

@MainActor
final class StatusMenuController: NSObject {
    private let controller: AudioFallbackController
    private let updaterController: UpdaterController
    private let statusItem: NSStatusItem
    private let logger = Logger(subsystem: "app.audiofallback", category: "StatusMenu")
    private let statusIconHeight: CGFloat = 21.6
    private let statusIconMarkerSpeakerGap: CGFloat = 0.4
    private let statusIconTrailingPadding: CGFloat = 1.6
    private let statusIconSpeakerPointSize: CGFloat = 19.2
    private let statusIconMarkerPointSize: CGFloat = 10.35
    private let statusIconMarkerY: CGFloat = 5.3
    private var settingsWindow: NSWindow?
    // The status item keeps this one menu for its whole lifetime. Replacing it or
    // changing its items while it is tracking can close it, e.g. after the slider was used.
    private let menu = NSMenu()
    private var isMenuOpen = false
    private var volumeView: VolumeMenuItemView?

    var statusItemMenu: NSMenu? {
        statusItem.menu
    }

    init(controller: AudioFallbackController, updaterController: UpdaterController) {
        self.controller = controller
        self.updaterController = updaterController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    /// Updates icon and menu content. While the menu is open only the icon and the
    /// slider value follow; the item structure is rebuilt in `menuNeedsUpdate(_:)`.
    func rebuildMenu() {
        updateStatusItemIcon()
        guard !isMenuOpen else {
            volumeView?.updateVolume(controller.currentOutputVolume)
            return
        }
        rebuildMenuItems()
    }

    func makeMenu() -> NSMenu {
        rebuildMenu()
        return menu
    }

    private func rebuildMenuItems() {
        menu.removeAllItems()

        menu.addItem(Self.sectionHeaderItem(title: L10n.string("menu.volume")))
        menu.addItem(volumeMenuItem())
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

        let updateItem = NSMenuItem(
            title: L10n.string("menu.checkForUpdates"),
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.isEnabled = updaterController.canCheckForUpdates
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.string("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    private func updateStatusItemIcon() {
        statusItem.button?.image = statusItemImage(for: controller.currentOutputLevel)
        statusItem.button?.imagePosition = .imageLeading
    }

    private func volumeMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let view = VolumeMenuItemView(volume: controller.currentOutputVolume) { [weak self] volume in
            self?.controller.setOutputVolume(volume)
            self?.updateStatusItemIcon()
        }
        volumeView = view
        item.view = view
        return item
    }

    private func statusItemImage(for level: OutputLevel?) -> NSImage? {
        let symbolName = volumeSymbolName(for: level)
        guard let speakerImage = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "AudioFallback"
        ) else {
            return nil
        }

        let speakerConfiguration = NSImage.SymbolConfiguration(pointSize: statusIconSpeakerPointSize, weight: .regular)
        let configuredSpeaker = speakerImage.withSymbolConfiguration(speakerConfiguration) ?? speakerImage

        let marker = NSString(string: "A")
        let markerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: statusIconMarkerPointSize, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        let markerSize = marker.size(withAttributes: markerAttributes)
        let speakerSize = configuredSpeaker.size
        let speakerX = markerSize.width + statusIconMarkerSpeakerGap
        let imageSize = NSSize(
            width: ceil(speakerX + speakerSize.width + statusIconTrailingPadding),
            height: statusIconHeight
        )

        let image = NSImage(size: imageSize)
        image.isTemplate = true
        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        marker.draw(at: NSPoint(x: 0, y: statusIconMarkerY), withAttributes: markerAttributes)

        configuredSpeaker.draw(
            in: NSRect(
                x: speakerX,
                y: (imageSize.height - speakerSize.height) / 2,
                width: speakerSize.width,
                height: speakerSize.height
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        return image
    }

    private func volumeSymbolName(for level: OutputLevel?) -> String {
        guard let level else {
            return "speaker.wave.2"
        }

        if level.isSilent {
            return "speaker.slash"
        }

        guard let volume = level.volume else {
            return "speaker.wave.2"
        }

        switch volume {
        case ..<0.34:
            return "speaker.wave.1"
        case ..<0.67:
            return "speaker.wave.2"
        default:
            return "speaker.wave.3"
        }
    }

    static let sectionHeaderIdentifier = NSUserInterfaceItemIdentifier("app.audiofallback.menu.sectionHeader")
    /// Left inset of view-based labels. AppKit offers no API for the title column of
    /// standard items, so this matches it as measured on macOS 26.
    private static let menuTitleLeadingInset: CGFloat = 24

    /// Section header like Apple's menu bar modules: semibold, menu font size, primary
    /// label color. Neither `NSMenuItem.sectionHeader` (small gray text) nor a disabled
    /// item with an attributed title (dimmed by AppKit) is readable on the translucent
    /// menu background, so the title is drawn by a label view.
    static func sectionHeaderItem(title: String) -> NSMenuItem {
        let item = labelMenuItem(
            title: title,
            font: .systemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize, weight: .semibold),
            topInset: 8,
            bottomInset: 4
        )
        item.identifier = sectionHeaderIdentifier
        return item
    }

    /// Non-interactive menu item whose text AppKit does not dim.
    private static func labelMenuItem(title: String, font: NSFont, topInset: CGFloat, bottomInset: CGFloat) -> NSMenuItem {
        let label = NSTextField(labelWithString: title)
        label.font = font
        label.textColor = .labelColor
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let labelSize = label.fittingSize
        let view = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: menuTitleLeadingInset + ceil(labelSize.width) + 14,
            height: topInset + ceil(labelSize.height) + bottomInset
        ))
        view.autoresizingMask = [.width]
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: menuTitleLeadingInset),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: topInset)
        ])

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.view = view
        item.isEnabled = false
        return item
    }

    private func addDeviceSection(to menu: NSMenu, title: String, kind: DeviceKind) {
        menu.addItem(Self.sectionHeaderItem(title: title))

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

            addManualOverrideItems(to: menu, kind: kind)

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

    private func addManualOverrideItems(to menu: NSMenu, kind: DeviceKind) {
        guard controller.manualOverrideDevice(for: kind) != nil,
              let priorityDevice = controller.priorityDevice(for: kind) else {
            return
        }

        let hint = L10n.string("menu.manualOverrideHint")
        menu.addItem(Self.labelMenuItem(
            title: hint,
            font: .menuFont(ofSize: NSFont.smallSystemFontSize),
            topInset: 2,
            bottomInset: 4
        ))

        let returnItem = NSMenuItem(
            title: L10n.format("menu.returnToPriority", priorityDevice.name),
            action: #selector(returnToPriority(_:)),
            keyEquivalent: ""
        )
        returnItem.target = self
        returnItem.representedObject = kind.rawValue
        menu.addItem(returnItem)
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

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates()
    }

    @objc private func activateFromMenu(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? MenuSelection else {
            return
        }

        controller.activateDeviceFromMenu(kind: selection.kind, uid: selection.uid)
        rebuildMenu()
    }

    @objc private func returnToPriority(_ sender: NSMenuItem) {
        guard let rawKind = sender.representedObject as? String,
              let kind = DeviceKind(rawValue: rawKind) else {
            return
        }

        controller.clearManualOverride(for: kind)
        rebuildMenu()
    }

    @objc private func showSettings() {
        openSettingsWindow()
    }

    private func openSettingsWindow() {
        if let settingsWindow {
            logSettingsWindowEvent("Showing existing settings window")
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = SettingsWindowFactory.makeWindow(
            controller: controller,
            updaterController: updaterController
        )
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
        updaterController: UpdaterController,
        layoutObserver: SettingsLayoutObserver? = nil
    ) -> NSWindow {
        let contentRect = NSRect(origin: .zero, size: contentSize)
        let window = SettingsWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let hostingView = SettingsHostingView(rootView: SettingsView(
            controller: controller,
            updaterController: updaterController,
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

private final class SettingsHostingView<Content: View>: NSHostingView<Content> {
    private lazy var zeroSafeAreaLayoutGuide = NSLayoutGuide()

    required init(rootView: Content) {
        super.init(rootView: rootView)
        configureSafeAreaLayoutGuide()
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSafeAreaLayoutGuide()
    }

    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsetsZero
    }

    override var safeAreaRect: NSRect {
        bounds
    }

    override var safeAreaLayoutGuide: NSLayoutGuide {
        zeroSafeAreaLayoutGuide
    }

    override var additionalSafeAreaInsets: NSEdgeInsets {
        get {
            NSEdgeInsetsZero
        }
        set {}
    }

    private func configureSafeAreaLayoutGuide() {
        addLayoutGuide(zeroSafeAreaLayoutGuide)
        NSLayoutConstraint.activate([
            zeroSafeAreaLayoutGuide.leadingAnchor.constraint(equalTo: leadingAnchor),
            zeroSafeAreaLayoutGuide.topAnchor.constraint(equalTo: topAnchor),
            zeroSafeAreaLayoutGuide.trailingAnchor.constraint(equalTo: trailingAnchor),
            zeroSafeAreaLayoutGuide.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
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
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu, !isMenuOpen else {
            return
        }

        controller.refresh()
        rebuildMenuItems()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else {
            return
        }

        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === self.menu else {
            return
        }

        isMenuOpen = false
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

private final class VolumeMenuItemView: NSView {
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let lowButton = NSButton()
    private let highButton = NSButton()
    private let onChange: (Float) -> Void

    init(volume: Float?, onChange: @escaping (Float) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 38))
        configure(volume: volume)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Follows external volume changes, but not while the user is dragging the slider.
    func updateVolume(_ volume: Float?) {
        guard NSEvent.pressedMouseButtons & 1 == 0 else {
            return
        }

        showVolume(volume)
    }

    private func configure(volume: Float?) {
        configureIconButton(lowButton, symbolName: "speaker.fill", action: #selector(decreaseVolume))
        configureIconButton(highButton, symbolName: "speaker.wave.3.fill", action: #selector(increaseVolume))

        showVolume(volume)
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.isContinuous = true
        slider.controlSize = .small
        slider.translatesAutoresizingMaskIntoConstraints = false

        addSubview(lowButton)
        addSubview(slider)
        addSubview(highButton)

        NSLayoutConstraint.activate([
            lowButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            lowButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            lowButton.widthAnchor.constraint(equalToConstant: 24),
            lowButton.heightAnchor.constraint(equalToConstant: 24),

            slider.leadingAnchor.constraint(equalTo: lowButton.trailingAnchor, constant: 8),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),

            highButton.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 8),
            highButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            highButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            highButton.widthAnchor.constraint(equalToConstant: 28),
            highButton.heightAnchor.constraint(equalToConstant: 24),

            heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    private func showVolume(_ volume: Float?) {
        let isVolumeAvailable = volume != nil
        lowButton.isEnabled = isVolumeAvailable
        highButton.isEnabled = isVolumeAvailable

        slider.doubleValue = Double(volume ?? 0)
        slider.isEnabled = isVolumeAvailable
    }

    private func configureIconButton(_ button: NSButton, symbolName: String, action: Selector) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        button.image = image?.withSymbolConfiguration(configuration) ?? image
        button.contentTintColor = .secondaryLabelColor
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.refusesFirstResponder = true
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        applyVolume(Float(sender.doubleValue))
    }

    @objc private func decreaseVolume() {
        applyVolume(Float(slider.doubleValue) - 0.1)
    }

    @objc private func increaseVolume() {
        applyVolume(Float(slider.doubleValue) + 0.1)
    }

    private func applyVolume(_ volume: Float) {
        let clampedVolume = min(1, max(0, volume))
        slider.doubleValue = Double(clampedVolume)
        onChange(clampedVolume)
    }
}
