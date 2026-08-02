// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "IhsanCore",
            targets: ["IhsanCore"]
        )
    ],
    targets: [
        .target(
            name: "IhsanCore",
            resources: [
                // The bundled remembrance content — the ONE file any
                // Arabic text, translation, or citation may come from.
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "IhsanCoreTests",
            dependencies: ["IhsanCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
