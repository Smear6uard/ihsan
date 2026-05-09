// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanLocation",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(
            name: "IhsanLocation",
            targets: ["IhsanLocation"]
        )
    ],
    dependencies: [
        .package(path: "../IhsanCore"),
        .package(path: "../IhsanPrayerTimes")
    ],
    targets: [
        .target(
            name: "IhsanLocation",
            dependencies: [
                "IhsanCore",
                "IhsanPrayerTimes"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "IhsanLocationTests",
            dependencies: ["IhsanLocation"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
