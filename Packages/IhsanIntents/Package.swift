// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanIntents",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "IhsanIntents",
            targets: ["IhsanIntents"]
        )
    ],
    dependencies: [
        .package(path: "../IhsanCore"),
        .package(path: "../IhsanPrayerTimes")
    ],
    targets: [
        .target(
            name: "IhsanIntents",
            dependencies: [
                "IhsanCore",
                "IhsanPrayerTimes"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "IhsanIntentsTests",
            dependencies: ["IhsanIntents"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
