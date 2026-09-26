// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalLens",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "LocalLensCore", targets: ["LocalLensCore"]),
        .executable(name: "LocalLensApp", targets: ["LocalLensApp"]),
        .executable(name: "LocalLensLive", targets: ["LocalLensLive"])
    ],
    targets: [
        .target(name: "LocalLensCore"),
        .executableTarget(
            name: "LocalLensApp",
            dependencies: ["LocalLensCore"]
        ),
        .executableTarget(
            name: "LocalLensLive",
            dependencies: ["LocalLensCore"]
        ),
        .testTarget(
            name: "LocalLensCoreTests",
            dependencies: ["LocalLensCore"]
        )
    ]
)
