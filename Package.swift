// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Countdown",
    products: [
        .library(
            name: "Countdown",
            targets: ["Countdown"]
        ),
    ],
    targets: [
        .target(
            name: "Countdown"
        ),
        .testTarget(
            name: "CountdownTests",
            dependencies: ["Countdown"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
