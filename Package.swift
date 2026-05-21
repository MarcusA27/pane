// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LiquidGlassNotes",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LiquidGlassNotes",
            path: "Sources/LiquidGlassNotes"
        )
    ]
)
