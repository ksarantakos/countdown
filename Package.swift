// swift-tools-version: 6.0
import PackageDescription

// CountdownCore is shared by the app and the widget extension (built via project.yml / XcodeGen).
let package = Package(
    name: "CountdownCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CountdownCore", targets: ["CountdownCore"]),
    ],
    targets: [
        .target(name: "CountdownCore"),
        .testTarget(name: "CountdownCoreTests", dependencies: ["CountdownCore"]),
    ]
)
