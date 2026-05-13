// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UITesting",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "UITestingCore", targets: ["UITestingCore"]),
        .library(name: "UITesting", targets: ["UITesting"])
    ],
    targets: [
        .target(
            name: "UITestingCore",
            path: "Sources/UITestingCore"
        ),
        .target(
            name: "UITesting",
            dependencies: ["UITestingCore"],
            path: "Sources/UITesting"
        ),
        .testTarget(
            name: "UITestingCoreTests",
            dependencies: ["UITestingCore"],
            path: "Tests/UITestingCoreTests"
        ),
        .testTarget(
            name: "UITestingTests",
            dependencies: ["UITesting"],
            path: "Tests/UITestingTests"
        )
    ]
)
