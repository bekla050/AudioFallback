import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var controller: AudioFallbackController
    let layoutObserver: SettingsLayoutObserver?
    @State private var launchAtLoginEnabled = LoginItemManager.isEnabled
    @State private var loginItemError: String?

    init(controller: AudioFallbackController, layoutObserver: SettingsLayoutObserver? = nil) {
        self.controller = controller
        self.layoutObserver = layoutObserver
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerOptions
                .padding(.top, 16)

            deviceLists
                .padding(.top, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 20)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Toggle(L10n.string("settings.autoSwitch"), isOn: Binding(
                    get: { controller.preferences.autoSwitchEnabled },
                    set: { controller.preferences.autoSwitchEnabled = $0 }
                ))

                Spacer()

                Button(L10n.string("settings.refreshDevices"), systemImage: "arrow.clockwise") {
                    controller.refresh()
                }
            }

            Toggle(L10n.string("settings.launchAtLogin"), isOn: Binding(
                get: { launchAtLoginEnabled },
                set: { newValue in
                    setLaunchAtLogin(newValue)
                }
            ))
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityIdentifier(SettingsAccessibilityID.headerOptions)
        .layoutProbe(SettingsAccessibilityID.headerOptions, observer: layoutObserver)
    }

    private var deviceLists: some View {
        HStack(alignment: .top, spacing: 8) {
            PriorityListView(
                title: L10n.string("devices.input"),
                kind: .input,
                currentUID: controller.currentInput?.uid,
                controller: controller,
                layoutObserver: layoutObserver
            )

            PriorityListView(
                title: L10n.string("devices.output"),
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
    static let deviceLists = "settings.deviceLists"

    static func deviceScrollView(for kind: DeviceKind) -> String {
        switch kind {
        case .input:
            "settings.inputDeviceScrollView"
        case .output:
            "settings.outputDeviceScrollView"
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

private struct PriorityListView: View {
    let title: String
    let kind: DeviceKind
    let currentUID: String?
    @ObservedObject var controller: AudioFallbackController
    let layoutObserver: SettingsLayoutObserver?
    @State private var draggingUID: String?
    @State private var rowWidth: CGFloat = 340
    @State private var dragPreviewWidth: CGFloat?

    var body: some View {
        let items = controller.orderedDeviceListItems(for: kind)
        let scrollbarReservedWidth: CGFloat = 16
        let rowLeadingBleedProtection: CGFloat = 4

        GeometryReader { proxy in
            let measuredRowWidth = max(324, proxy.size.width - scrollbarReservedWidth - rowLeadingBleedProtection)
            let measuredScrollViewWidth = measuredRowWidth + scrollbarReservedWidth

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            DeviceRowView(
                                index: index,
                                item: item,
                                isCurrent: item.device.uid == currentUID,
                                kind: kind,
                                controller: controller,
                                rowWidth: measuredRowWidth
                            )
                            .opacity(draggingUID == item.id ? 0.98 : 1)
                            .onDrag {
                                rowWidth = measuredRowWidth
                                draggingUID = item.id
                                dragPreviewWidth = measuredRowWidth
                                NSCursor.closedHand.set()
                                return NSItemProvider(object: item.id as NSString)
                            } preview: {
                                DeviceRowContent(
                                    index: index,
                                    item: item,
                                    isCurrent: item.device.uid == currentUID,
                                    removeAction: nil,
                                    fixedWidth: dragPreviewWidth ?? measuredRowWidth
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
                    .frame(width: measuredRowWidth, alignment: .topLeading)
                    .overlay(alignment: .bottomLeading) {
                        Color.clear
                            .frame(width: measuredRowWidth, height: 8)
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
                    .padding(.top, 4)
                    .padding(.leading, rowLeadingBleedProtection)
                    .padding(.trailing, scrollbarReservedWidth)
                }
                .frame(width: measuredScrollViewWidth, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .contentMargins(.bottom, 0, for: .scrollContent)
                .contentMargins(.bottom, 0, for: .scrollIndicators)
                .accessibilityIdentifier(SettingsAccessibilityID.deviceScrollView(for: kind))
                .layoutProbe(SettingsAccessibilityID.deviceScrollView(for: kind), observer: layoutObserver)
                .onAppear {
                    rowWidth = measuredRowWidth
                }
                .onChange(of: measuredRowWidth) { _, newWidth in
                    if draggingUID == nil {
                        rowWidth = newWidth
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DeviceRowView: View {
    let index: Int
    let item: AudioDeviceListItem
    let isCurrent: Bool
    let kind: DeviceKind
    @ObservedObject var controller: AudioFallbackController
    let rowWidth: CGFloat

    var body: some View {
        DeviceRowContent(
            index: index,
            item: item,
            isCurrent: isCurrent
        ) {
            controller.removeUnavailableDevice(kind: kind, uid: item.device.uid)
        }
        .frame(width: rowWidth, alignment: .leading)
    }
}

private struct DeviceRowContent: View {
    let index: Int
    let item: AudioDeviceListItem
    let isCurrent: Bool
    let removeAction: (() -> Void)?
    let fixedWidth: CGFloat?

    init(
        index: Int,
        item: AudioDeviceListItem,
        isCurrent: Bool,
        removeAction: (() -> Void)? = nil,
        fixedWidth: CGFloat? = nil
    ) {
        self.index = index
        self.item = item
        self.isCurrent = isCurrent
        self.removeAction = removeAction
        self.fixedWidth = fixedWidth
    }

    var body: some View {
        HStack(spacing: 5) {
            DragHandleView()
                .foregroundStyle(item.isAvailable ? .secondary : .tertiary)
                .frame(width: 9)
                .padding(.leading, 6)
                .help(L10n.string("devices.dragHandleHelp"))

            Text("\(index + 1)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            Text(item.device.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(item.isAvailable ? .primary : .secondary)

            if isCurrent {
                Text(L10n.string("devices.active"))
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
            } else if !item.isAvailable {
                Text(L10n.string("devices.unavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 82, alignment: .trailing)
            }

            if !item.isAvailable {
                Button(L10n.string("devices.removeUnavailable"), systemImage: "trash") {
                    removeAction?()
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
                .help(L10n.string("devices.removeUnavailableHelp"))
                .frame(width: 24)
                .padding(.trailing, 4)
                .disabled(removeAction == nil)
                .arrowCursor()
            }
        }
        .rowChrome(fixedWidth: fixedWidth)
        .contentShape(Rectangle())
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 6))
        .handCursor()
    }
}

private struct RowChromeModifier: ViewModifier {
    let fixedWidth: CGFloat?

    func body(content: Content) -> some View {
        let shapedContent = content
            .padding(.horizontal, 4)
            .frame(minHeight: 38)

        Group {
            if let fixedWidth {
                shapedContent
                    .frame(width: fixedWidth, height: 38, alignment: .leading)
            } else {
                shapedContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .audioFallbackDeviceRowBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .audioFallbackDeviceRowBorder), lineWidth: 1)
        )
        .shadow(
            color: Color(nsColor: .audioFallbackDeviceRowShadow),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

private extension NSColor {
    static var audioFallbackDeviceRowBackground: NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return NSColor(calibratedWhite: 0.145, alpha: 1)
            }
            return NSColor(calibratedWhite: 1, alpha: 1)
        }
    }

    static var audioFallbackDeviceRowBorder: NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return .separatorColor.withAlphaComponent(0.30)
            }
            return NSColor(calibratedWhite: 0.56, alpha: 1)
        }
    }

    static var audioFallbackDeviceRowShadow: NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            if bestMatch == .darkAqua {
                return .clear
            }
            return NSColor(calibratedWhite: 0, alpha: 0.12)
        }
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
