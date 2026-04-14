// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Tracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Tracker", targets: ["Tracker"])
    ],
    targets: [
        .executableTarget(
            name: "Tracker",
            path: "Sources/Tracker"
        )
    ]
)
