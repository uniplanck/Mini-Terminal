// swift-tools-version: 6.0
import PackageDescription

// Launch-film capture support (FilmCapture.swift) is compiled into debug builds only.
// Release builds, including scripts/build-app.sh, contain none of it.
let filmCaptureSettings: [SwiftSetting] = [.define("FILM_CAPTURE", .when(configuration: .debug))]

let package = Package(
    name: "Mini-Terminal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Mini-Terminal", targets: ["MiniTerminal"])
    ],
    targets: [
        .executableTarget(
            name: "MiniTerminal",
            path: "Sources/MiniTerminal",
            swiftSettings: filmCaptureSettings
        ),
        .testTarget(
            name: "MiniTerminalTests",
            dependencies: ["MiniTerminal"],
            path: "Tests/MiniTerminalTests",
            swiftSettings: filmCaptureSettings
        )
    ],
    swiftLanguageModes: [.v5]
)
