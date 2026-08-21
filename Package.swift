// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MicTrigger",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MicTrigger", targets: ["MicTrigger"]),
    ],
    targets: [
        .executableTarget(
            name: "MicTrigger",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MicTriggerTests",
            dependencies: ["MicTrigger"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
