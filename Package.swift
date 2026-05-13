// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "after-midnight",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AfterMidnightCore", targets: ["AfterMidnightCore"]),
    ],
    targets: [
        .target(
            name: "AfterMidnightCore",
            path: "Sources/AfterMidnightCore"
        ),
        .executableTarget(
            name: "am",
            dependencies: ["AfterMidnightCore"],
            path: "Sources/am"
        ),
        .testTarget(
            name: "AfterMidnightCoreTests",
            dependencies: ["AfterMidnightCore"],
            path: "Tests/AfterMidnightCoreTests"
        )
    ]
)
