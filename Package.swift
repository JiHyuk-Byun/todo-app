// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Planner",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Planner",
            path: "Sources/Planner"
        )
    ]
)
