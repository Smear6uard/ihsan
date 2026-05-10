// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanFiqhConfig",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "IhsanFiqhConfig",
            targets: ["IhsanFiqhConfig"]
        )
    ],
    dependencies: [
        .package(path: "../IhsanCore")
    ],
    targets: [
        .target(
            name: "IhsanFiqhConfig",
            dependencies: ["IhsanCore"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "IhsanFiqhConfigTests",
            dependencies: ["IhsanFiqhConfig", "IhsanCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
