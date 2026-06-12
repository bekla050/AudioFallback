import Foundation

struct AudioDeviceListItem: Identifiable, Equatable {
    let device: ManagedAudioDevice
    let isAvailable: Bool

    var id: String {
        device.uid
    }
}
