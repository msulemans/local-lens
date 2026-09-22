// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalLens",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "LocalLensCore", targets: ["LocalLensCore"]),
        .executable(name: "LocalLensApp", targets: ["LocalLensApp"])
    ],
    targets: [
        .target(name: "LocalLensCore"),
        .executableTarget(
            name: "LocalLensApp",
            dependencies: ["LocalLensCore"]
        ),
        .testTarget(
            name: "LocalLensCoreTests",
            dependencies: ["LocalLensCore"]
        )
    ]
)
