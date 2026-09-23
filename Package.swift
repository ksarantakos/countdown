// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WoWCountdown",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CountdownCore"),
        .executableTarget(
            name: "WoWCountdown",
            dependencies: ["CountdownCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "CountdownCoreTests", dependencies: ["CountdownCore"]),
    ]
)
