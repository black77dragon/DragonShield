// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DragonShield",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Database", targets: ["Database"]),
        .library(name: "Allocation", targets: ["Allocation"])
    ],
    targets: [
        .target(
            name: "Database",
            path: "Sources/Database",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(name: "Allocation", dependencies: ["Database"], path: "Sources/Allocation"),
        .testTarget(name: "Validation", dependencies: ["Database"], path: "Tests/Validation")
    ]
)
