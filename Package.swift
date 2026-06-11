// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AudioFallback",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AudioFallback", targets: ["AudioFallback"])
    ],
    targets: [
        .executableTarget(
            name: "AudioFallback",
            path: "Sources/AudioFallback"
        ),
        .testTarget(
            name: "AudioFallbackTests",
            dependencies: ["AudioFallback"],
            path: "Tests/AudioFallbackTests"
        )
    ]
)
