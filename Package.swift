// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DragonShield",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]
        )
    ],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        )
    ]
)
