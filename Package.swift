// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VisualizerTouchBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "VisualizerTouchBar",
            path: "Sources/VisualizerTouchBar"
        )
    ]
)
