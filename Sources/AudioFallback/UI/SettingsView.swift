import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AudioFallbackController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Automatisch auf das beste verfügbare Gerät umschalten", isOn: Binding(
                get: { controller.preferences.autoSwitchEnabled },
                set: { controller.preferences.autoSwitchEnabled = $0 }
            ))

            HStack(alignment: .top, spacing: 24) {
                PriorityListView(
                    title: "Mikrofone",
                    kind: .input,
                    currentUID: controller.currentInput?.uid,
                    controller: controller
                )

                PriorityListView(
                    title: "Lautsprecher",
                    kind: .output,
                    currentUID: controller.currentOutput?.uid,
                    controller: controller
                )
            }

            HStack {
                Button("Geräte aktualisieren", systemImage: "arrow.clockwise") {
                    controller.refresh()
                }

                Spacer()

                Text("Höher platzierte Geräte werden bevorzugt.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 420)
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
                                Text("Aktiv")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }

                        Spacer()

                        Button("Nach oben", systemImage: "chevron.up") {
                            controller.moveDevice(kind: kind, uid: device.uid, direction: -1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(index == 0)
                        .help("In der Priorität nach oben verschieben")

                        Button("Nach unten", systemImage: "chevron.down") {
                            controller.moveDevice(kind: kind, uid: device.uid, direction: 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(index == controller.orderedDevices(for: kind).count - 1)
                        .help("In der Priorität nach unten verschieben")
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(minWidth: 340, minHeight: 300)
        }
    }
}
