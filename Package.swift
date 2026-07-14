// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AudioFallback",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AudioFallback", targets: ["AudioFallback"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "AudioFallback",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/AudioFallback",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "AudioFallbackTests",
            dependencies: ["AudioFallback"],
            path: "Tests/AudioFallbackTests"
        )
    ]
)
