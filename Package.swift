// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatCompanion",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CatCompanionCore", targets: ["CatCompanionCore"]),
        .executable(name: "CatCompanionApp", targets: ["CatCompanionApp"]),
        .executable(name: "CatCompanionAgent", targets: ["CatCompanionAgent"])
    ],
    targets: [
        .target(name: "CatCompanionCore"),
        .executableTarget(
            name: "CatCompanionApp",
            dependencies: ["CatCompanionCore"]
        ),
        .executableTarget(
            name: "CatCompanionAgent",
            dependencies: []
        ),
        .testTarget(
            name: "CatCompanionCoreTests",
            dependencies: ["CatCompanionCore"]
        )
    ]
)
