// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LiquidGlassNotes",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "LiquidGlassNotes",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/LiquidGlassNotes"
        )
    ]
)
