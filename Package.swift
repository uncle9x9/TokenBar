// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TokenBarCore",
            targets: ["TokenBarCore"]
        ),
        .executable(
            name: "TokenBar",
            targets: ["TokenBar"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TokenBarCore",
            dependencies: [],
            path: "Sources/TokenBarCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "TokenBar",
            dependencies: ["TokenBarCore"],
            path: "Sources/TokenBar"
        ),
        .executableTarget(
            name: "TokenBarVerify",
            dependencies: ["TokenBarCore"],
            path: "Sources/TokenBarVerify"
        ),
        .testTarget(
            name: "TokenBarTests",
            dependencies: ["TokenBarCore"],
            path: "Tests/TokenBarTests"
        )
    ]
)
