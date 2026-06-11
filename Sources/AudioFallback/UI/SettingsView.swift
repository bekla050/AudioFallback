import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AudioFallbackController
    @State private var launchAtLoginEnabled = LoginItemManager.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

            HStack(alignment: .top, spacing: 24) {
                PriorityListView(
                    title: L10n.string("devices.input"),
                    kind: .input,
                    currentUID: controller.currentInput?.uid,
                    controller: controller
                )

                PriorityListView(
                    title: L10n.string("devices.output"),
                    kind: .output,
                    currentUID: controller.currentOutput?.uid,
                    controller: controller
                )
            }

            HStack {
                Button(L10n.string("settings.refreshDevices"), systemImage: "arrow.clockwise") {
                    controller.refresh()
                }

                Spacer()

                Text(L10n.string("settings.priorityHint"))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 420)
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

private struct PriorityListView: View {
    let title: String
    let kind: DeviceKind
    let currentUID: String?
    @ObservedObject var controller: AudioFallbackController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            List {
                ForEach(Array(controller.orderedDevices(for: kind).enumerated()), id: \.element.uid) { index, device in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .lineLimit(1)
                            if device.uid == currentUID {
                                Text(L10n.string("devices.active"))
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }

                        Spacer()

                        Button(L10n.string("devices.moveUp"), systemImage: "chevron.up") {
                            controller.moveDevice(kind: kind, uid: device.uid, direction: -1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(index == 0)
                        .help(L10n.string("devices.moveUpHelp"))

                        Button(L10n.string("devices.moveDown"), systemImage: "chevron.down") {
                            controller.moveDevice(kind: kind, uid: device.uid, direction: 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(index == controller.orderedDevices(for: kind).count - 1)
                        .help(L10n.string("devices.moveDownHelp"))
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(minWidth: 340, minHeight: 300)
        }
    }
}
