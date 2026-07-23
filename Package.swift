// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VolumeMixer",
    platforms: [.macOS("15.0")],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "VolumeMixerCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "VolumeMixerApp",
            dependencies: [
                "VolumeMixerCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                // Sparkle.framework кладётся в Contents/Frameworks бандла (build.sh)
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(
            name: "VolumeMixerCoreTests",
            dependencies: ["VolumeMixerCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
