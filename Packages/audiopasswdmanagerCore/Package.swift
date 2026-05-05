// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "audiopasswdmanagerCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "audiopasswdmanagerCore",
            targets: ["audiopasswdmanagerCore"]
        ),
    ],
    targets: [
        .target(
            name: "audiopasswdmanagerCore",
            path: "Sources/audiopasswdmanagerCore"
        ),
        .testTarget(
            name: "audiopasswdmanagerCoreTests",
            dependencies: ["audiopasswdmanagerCore"],
            path: "Tests/audiopasswdmanagerCoreTests"
        ),
    ]
)
