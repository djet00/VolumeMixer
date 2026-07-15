// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VolumeMixer",
    platforms: [.macOS("15.0")],
    targets: [
        .target(
            name: "VolumeMixerCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "VolumeMixerApp",
            dependencies: ["VolumeMixerCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "VolumeMixerCoreTests",
            dependencies: ["VolumeMixerCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
