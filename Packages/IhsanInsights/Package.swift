// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanInsights",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "IhsanInsights",
            targets: ["IhsanInsights"]
        )
    ],
    dependencies: [
        .package(path: "../IhsanCore")
    ],
    targets: [
        .target(
            name: "IhsanInsights",
            dependencies: [
                "IhsanCore"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "IhsanInsightsTests",
            dependencies: ["IhsanInsights"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
