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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.8.1")
    ],
    targets: [
        .target(name: "CatCompanionCore"),
        .executableTarget(
            name: "CatCompanionApp",
            dependencies: ["CatCompanionCore", .product(name: "Sparkle", package: "Sparkle")]
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
