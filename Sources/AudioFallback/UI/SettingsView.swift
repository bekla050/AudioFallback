import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var controller: AudioFallbackController
    @ObservedObject var updaterController: UpdaterController
    let layoutObserver: SettingsLayoutObserver?
    @State private var launchAtLoginEnabled = LoginItemManager.isEnabled
    @State private var loginItemError: String?

    init(
        controller: AudioFallbackController,
        updaterController: UpdaterController,
        layoutObserver: SettingsLayoutObserver? = nil
    ) {
        self.controller = controller
        self.updaterController = updaterController
        self.layoutObserver = layoutObserver
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerOptions
                .padding(.top, SettingsMetrics.outerPadding)

            priorityHeader
                .padding(.top, SettingsMetrics.sectionSpacing)

            deviceLists
                .padding(.top, SettingsMetrics.sectionSpacing - 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, SettingsMetrics.outerPadding)
        .frame(
            minWidth: 800,
            maxWidth: .infinity,
            minHeight: 500,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(.container, edges: .bottom)
        .accessibilityIdentifier(SettingsAccessibilityID.root)
        .layoutProbe(SettingsAccessibilityID.root, observer: layoutObserver)
        .onAppear {
            launchAtLoginEnabled = LoginItemManager.isEnabled
        }
        .alert(L10n.string("loginItem.errorTitle"), isPresented: Binding(
            get: { loginItemError != nil },
            set: { isPresented in
                if !isPresented {
                    loginItemError = nil
                }
            }
        )) {
            Button(L10n.string("button.ok"), role: .cancel) {}
        } message: {
            Text(loginItemError ?? "")
        }
    }

    private var headerOptions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: SettingsMetrics.itemSpacing) {
                Toggle(L10n.string("settings.autoSwitch"), isOn: Binding(
                    get: { controller.preferences.autoSwitchEnabled },
                    set: { controller.preferences.autoSwitchEnabled = $0 }
                ))

                Toggle(L10n.string("settings.launchAtLogin"), isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: { newValue in
                        setLaunchAtLogin(newValue)
                    }
                ))

                Toggle(
                    L10n.string("settings.automaticUpdateChecks"),
                    isOn: Binding(
                        get: { updaterController.automaticallyChecksForUpdates },
                        set: { updaterController.setAutomaticallyChecksForUpdates($0) }
                    )
                )
                .accessibilityIdentifier(SettingsAccessibilityID.automaticUpdateChecks)
                .layoutProbe(SettingsAccessibilityID.automaticUpdateChecks, observer: layoutObserver)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityIdentifier(SettingsAccessibilityID.headerOptions)
        .layoutProbe(SettingsAccessibilityID.headerOptions, observer: layoutObserver)
    }

    private var priorityHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("settings.priorityTitle"))
                    .font(.headline)

                Text(L10n.string("settings.priorityExplanation"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(L10n.string("settings.refreshDevices"), systemImage: "arrow.clockwise") {
                controller.refresh()
            }
            .fixedSize()
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(SettingsAccessibilityID.priorityHeader)
        .layoutProbe(SettingsAccessibilityID.priorityHeader, observer: layoutObserver)
    }

    private var deviceLists: some View {
        HStack(alignment: .top, spacing: SettingsMetrics.sectionSpacing) {
            PriorityListView(
                title: L10n.string("devices.input"),
                systemImage: "mic",
                kind: .input,
                currentUID: controller.currentInput?.uid,
                controller: controller,
                layoutObserver: layoutObserver
            )

            PriorityListView(
                title: L10n.string("devices.output"),
                systemImage: "speaker.wave.2",
                kind: .output,
                currentUID: controller.currentOutput?.uid,
                controller: controller,
                layoutObserver: layoutObserver
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier(SettingsAccessibilityID.deviceLists)
        .layoutProbe(SettingsAccessibilityID.deviceLists, observer: layoutObserver)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemManager.setEnabled(enabled)
            launchAtLoginEnabled = LoginItemManager.isEnabled
        } catch {
            launchAtLoginEnabled = LoginItemManager.isEnabled
            loginItemError = L10n.format("loginItem.errorMessage", String(describing: error))
        }
    }
}

enum SettingsAccessibilityID {
    static let root = "settings.root"
    static let headerOptions = "settings.headerOptions"
    static let automaticUpdateChecks = "settings.automaticUpdateChecks"
    static let priorityHeader = "settings.priorityHeader"
    static let deviceLists = "settings.deviceLists"

    static func deviceScrollView(for kind: DeviceKind) -> String {
        switch kind {
        case .input:
            "settings.inputDeviceScrollView"
        case .output:
            "settings.outputDeviceScrollView"
        }
    }

    static func manualOverrideBanner(for kind: DeviceKind) -> String {
        switch kind {
        case .input:
            "settings.inputManualOverrideBanner"
        case .output:
            "settings.outputManualOverrideBanner"
        }
    }
}

@MainActor
final class SettingsLayoutObserver {
    private(set) var frames: [String: NSRect] = [:]

    func record(_ frame: NSRect, for identifier: String) {
        frames[identifier] = frame
    }

    func frame(for identifier: String) -> NSRect? {
        frames[identifier]
    }
}

private struct LayoutProbeModifier: ViewModifier {
    let identifier: String
    let observer: SettingsLayoutObserver?

    func body(content: Content) -> some View {
        content.background(SettingsLayoutProbeView(identifier: identifier, observer: observer))
    }
}

private extension View {
    func layoutProbe(_ identifier: String, observer: SettingsLayoutObserver?) -> some View {
        modifier(LayoutProbeModifier(identifier: identifier, observer: observer))
    }
}

private struct SettingsLayoutProbeView: NSViewRepresentable {
    let identifier: String
    let observer: SettingsLayoutObserver?

    func makeNSView(context: Context) -> SettingsLayoutProbeNSView {
        SettingsLayoutProbeNSView(identifier: identifier, observer: observer)
    }

    func updateNSView(_ nsView: SettingsLayoutProbeNSView, context: Context) {
        nsView.probeIdentifier = identifier
        nsView.observer = observer
        nsView.recordFrame()
    }
}

private final class SettingsLayoutProbeNSView: NSView {
    var probeIdentifier: String
    weak var observer: SettingsLayoutObserver?

    init(identifier: String, observer: SettingsLayoutObserver?) {
        self.probeIdentifier = identifier
        self.observer = observer
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        self.probeIdentifier = ""
        self.observer = nil
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        recordFrame()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        recordFrame()
    }

    func recordFrame() {
        guard let contentView = window?.contentView else {
            return
        }
        observer?.record(convert(bounds, to: contentView), for: probeIdentifier)
    }
}

private enum SettingsMetrics {
    static let outerPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let itemSpacing: CGFloat = 8
    static let rowSpacing: CGFloat = 6
    static let rowHeight: CGFloat = 36
    static let cornerRadius: CGFloat = 8
    /// Height of the soft fade at the top and bottom of a device list. The list content gets
    /// the same inset so the first and last row are fully visible at rest.
    static let edgeFade: CGFloat = 12
    /// Room for an overlay scroller, which is drawn on top of the content. The scroll view reaches
    /// this far into the gutter between the columns and the window edge (`sectionSpacing`, `outerPadding`).
    @MainActor static var overlayScrollerInset: CGFloat {
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: .overlay) + 1
    }
    /// Gap between rows and a legacy scroller, which already takes its own space.
    static let legacyScrollerInset: CGFloat = 4
}

private enum DeviceRowStatus {
    case active
    case manual
    case unavailable

    init?(item: AudioDeviceListItem, currentUID: String?, manualUID: String?) {
        if !item.isAvailable {
            self = .unavailable
        } else if item.device.uid == manualUID {
            self = .manual
        } else if item.device.uid == currentUID {
            self = .active
        } else {
            return nil
        }
    }
}

private struct PriorityListView: View {
    let title: String
    let systemImage: String
    let kind: DeviceKind
    let currentUID: String?
    @ObservedObject var controller: AudioFallbackController
    let layoutObserver: SettingsLayoutObserver?
    @State private var draggingUID: String?
    @State private var rowWidth: CGFloat = 0
    @State private var dragPreviewWidth: CGFloat?
    @State private var scrollerStyle = NSScroller.preferredScrollerStyle

    var body: some View {
        let items = controller.orderedDeviceListItems(for: kind)
        let manualDevice = controller.manualOverrideDevice(for: kind)

        let scrollerInset = scrollerStyle == .overlay
            ? SettingsMetrics.overlayScrollerInset
            : SettingsMetrics.legacyScrollerInset

        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            .font(.headline)

            if let manualDevice {
                ManualOverrideBanner(deviceName: manualDevice.name) {
                    controller.clearManualOverride(for: kind)
                }
                .padding(.top, SettingsMetrics.itemSpacing)
                .accessibilityIdentifier(SettingsAccessibilityID.manualOverrideBanner(for: kind))
                .layoutProbe(SettingsAccessibilityID.manualOverrideBanner(for: kind), observer: layoutObserver)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: SettingsMetrics.rowSpacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let status = DeviceRowStatus(
                            item: item,
                            currentUID: currentUID,
                            manualUID: manualDevice?.uid
                        )

                        DeviceRowContent(index: index, item: item, status: status) {
                            controller.removeUnavailableDevice(kind: kind, uid: item.device.uid)
                        }
                        .onDrag {
                            draggingUID = item.id
                            dragPreviewWidth = rowWidth
                            NSCursor.closedHand.set()
                            return NSItemProvider(object: item.id as NSString)
                        } preview: {
                            DeviceRowContent(
                                index: index,
                                item: item,
                                status: status,
                                removeAction: nil,
                                fixedWidth: dragPreviewWidth ?? rowWidth
                            )
                        }
                        .onDrop(
                            of: [.text],
                            delegate: DeviceReorderDropDelegate(
                                item: item,
                                items: items,
                                kind: kind,
                                controller: controller,
                                draggingUID: $draggingUID,
                                dragPreviewWidth: $dragPreviewWidth
                            )
                        )
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newWidth in
                    rowWidth = newWidth
                }
                .padding(.vertical, SettingsMetrics.edgeFade)
                .padding(.trailing, scrollerInset)
                .overlay(alignment: .bottom) {
                    Color.clear
                        .frame(height: SettingsMetrics.edgeFade)
                        .contentShape(Rectangle())
                        .onDrop(
                            of: [.text],
                            delegate: DeviceListEndDropDelegate(
                                items: items,
                                kind: kind,
                                controller: controller,
                                draggingUID: $draggingUID,
                                dragPreviewWidth: $dragPreviewWidth
                            )
                        )
                }
            }
            .contentMargins(.vertical, SettingsMetrics.edgeFade, for: .scrollIndicators)
            .mask(EdgeFadeMask(fadeHeight: SettingsMetrics.edgeFade))
            // An overlay scroller floats above the content: let the scroll view reach into the
            // gutter so rows stay aligned with the column while the scroller sits beside them.
            .padding(.trailing, scrollerStyle == .overlay ? -scrollerInset : 0)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .accessibilityIdentifier(SettingsAccessibilityID.deviceScrollView(for: kind))
            .layoutProbe(SettingsAccessibilityID.deviceScrollView(for: kind), observer: layoutObserver)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: NSScroller.preferredScrollerStyleDidChangeNotification)) { _ in
            scrollerStyle = NSScroller.preferredScrollerStyle
        }
    }
}

private struct EdgeFadeMask: View {
    let fadeHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: fadeHeight)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: fadeHeight)
        }
    }
}

private struct ManualOverrideBanner: View {
    let deviceName: String
    let applyAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)

            Text(L10n.format("settings.manualOverrideBanner", deviceName))
                .font(.callout)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(L10n.string("settings.applyPriority"), action: applyAction)
                .controlSize(.small)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: SettingsMetrics.cornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SettingsMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct DeviceRowContent: View {
    let index: Int
    let item: AudioDeviceListItem
    let status: DeviceRowStatus?
    let removeAction: (() -> Void)?
    let fixedWidth: CGFloat?

    init(
        index: Int,
        item: AudioDeviceListItem,
        status: DeviceRowStatus?,
        removeAction: (() -> Void)? = nil,
        fixedWidth: CGFloat? = nil
    ) {
        self.index = index
        self.item = item
        self.status = status
        self.removeAction = removeAction
        self.fixedWidth = fixedWidth
    }

    var body: some View {
        HStack(spacing: SettingsMetrics.itemSpacing) {
            DragHandleView()
                .foregroundStyle(.tertiary)
                .help(L10n.string("devices.dragHandleHelp"))

            Text("\(index + 1)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 18, alignment: .trailing)

            Text(item.device.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(item.isAvailable ? .primary : .secondary)

            if let status {
                DeviceStatusTag(status: status)
            }

            if !item.isAvailable {
                Button(L10n.string("devices.removeUnavailable"), systemImage: "trash") {
                    removeAction?()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(L10n.string("devices.removeUnavailableHelp"))
                .disabled(removeAction == nil)
                .arrowCursor()
            }
        }
        .padding(.horizontal, 10)
        .rowChrome(fixedWidth: fixedWidth)
        .contentShape(Rectangle())
        .contentShape(
            .dragPreview,
            RoundedRectangle(cornerRadius: SettingsMetrics.cornerRadius, style: .continuous)
        )
        .handCursor()
    }
}

private struct DeviceStatusTag: View {
    let status: DeviceRowStatus

    var body: some View {
        HStack(spacing: 5) {
            if let tint {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
            }

            Text(title)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(status == .unavailable ? .secondary : .primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(tint.map { $0.opacity(0.14) } ?? Color.secondary.opacity(0.12))
        )
        .fixedSize()
    }

    private var title: String {
        switch status {
        case .active:
            L10n.string("devices.active")
        case .manual:
            L10n.string("devices.manual")
        case .unavailable:
            L10n.string("devices.unavailable")
        }
    }

    private var tint: Color? {
        switch status {
        case .active:
            .green
        case .manual:
            .orange
        case .unavailable:
            nil
        }
    }
}

private struct RowChromeModifier: ViewModifier {
    let fixedWidth: CGFloat?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: SettingsMetrics.cornerRadius, style: .continuous)

        Group {
            if let fixedWidth {
                content
                    .frame(width: fixedWidth, height: SettingsMetrics.rowHeight, alignment: .leading)
            } else {
                content
                    .frame(maxWidth: .infinity, minHeight: SettingsMetrics.rowHeight, alignment: .leading)
            }
        }
        .background(shape.fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}

private extension View {
    func rowChrome(fixedWidth: CGFloat?) -> some View {
        modifier(RowChromeModifier(fixedWidth: fixedWidth))
    }
}

private struct DragHandleView: View {
    private let columns = Array(repeating: GridItem(.fixed(3), spacing: 3), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(0..<6, id: \.self) { _ in
                Circle()
                    .frame(width: 3, height: 3)
            }
        }
        .frame(width: 9, height: 15)
    }
}

private struct DeviceReorderDropDelegate: DropDelegate {
    let item: AudioDeviceListItem
    let items: [AudioDeviceListItem]
    let kind: DeviceKind
    let controller: AudioFallbackController
    @Binding var draggingUID: String?
    @Binding var dragPreviewWidth: CGFloat?

    func dropEntered(info: DropInfo) {
        guard let draggingUID,
              draggingUID != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == draggingUID }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            controller.moveDevice(
                kind: kind,
                from: IndexSet(integer: fromIndex),
                to: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingUID = nil
        dragPreviewWidth = nil
        NSCursor.openHand.set()
        return true
    }

    func dropExited(info: DropInfo) {
        NSCursor.openHand.set()
    }
}

private struct DeviceListEndDropDelegate: DropDelegate {
    let items: [AudioDeviceListItem]
    let kind: DeviceKind
    let controller: AudioFallbackController
    @Binding var draggingUID: String?
    @Binding var dragPreviewWidth: CGFloat?

    func dropEntered(info: DropInfo) {
        guard let draggingUID,
              let fromIndex = items.firstIndex(where: { $0.id == draggingUID }),
              fromIndex != items.count - 1 else {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            controller.moveDevice(
                kind: kind,
                from: IndexSet(integer: fromIndex),
                to: items.count
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingUID = nil
        dragPreviewWidth = nil
        NSCursor.openHand.set()
        return true
    }
}

private struct HandCursorModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

private struct ArrowCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    NSCursor.arrow.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

private extension View {
    func handCursor() -> some View {
        modifier(HandCursorModifier())
    }

    func arrowCursor() -> some View {
        modifier(ArrowCursorModifier())
    }
}
