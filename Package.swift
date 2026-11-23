// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Spot-Terminal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Spot-Terminal", targets: ["MiniTerminal"])
    ],
    targets: [
        .executableTarget(
            name: "MiniTerminal",
            path: "Sources/MiniTerminal"
        ),
        .testTarget(
            name: "MiniTerminalTests",
            dependencies: ["MiniTerminal"],
            path: "Tests/MiniTerminalTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
