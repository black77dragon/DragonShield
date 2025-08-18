// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DragonShield",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "App", targets: ["App"]),
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Infra", targets: ["Infra"])
    ],
    targets: [
        .target(name: "App", dependencies: ["Core", "Infra"], path: "Sources/App"),
        .target(name: "Core", dependencies: ["Infra"], path: "Sources/Core"),
        .target(name: "Infra", path: "Sources/Infra"),
        .testTarget(name: "AppTests", dependencies: ["App"], path: "Tests/AppTests"),
        .testTarget(name: "CoreTests", dependencies: ["Core"], path: "Tests/CoreTests"),
        .testTarget(name: "InfraTests", dependencies: ["Infra"], path: "Tests/InfraTests"),
    ]
)
