struct OutputLevel: Equatable {
    let volume: Float?
    let isMuted: Bool

    var isSilent: Bool {
        isMuted || (volume.map { $0 <= 0 } ?? false)
    }
}
