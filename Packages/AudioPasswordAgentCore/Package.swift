// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioPasswordAgentCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "AudioPasswordAgentCore",
            targets: ["AudioPasswordAgentCore"]
        ),
    ],
    targets: [
        .target(
            name: "AudioPasswordAgentCore",
            path: "Sources/AudioPasswordAgentCore"
        ),
        .testTarget(
            name: "AudioPasswordAgentCoreTests",
            dependencies: ["AudioPasswordAgentCore"],
            path: "Tests/AudioPasswordAgentCoreTests"
        ),
    ]
)
