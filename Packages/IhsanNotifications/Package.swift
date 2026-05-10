// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanNotifications",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "IhsanNotifications",
            targets: ["IhsanNotifications"]
        )
    ],
    dependencies: [
        .package(path: "../IhsanCore"),
        .package(path: "../IhsanPrayerTimes"),
        .package(path: "../IhsanLocation")
    ],
    targets: [
        .target(
            name: "IhsanNotifications",
            dependencies: [
                "IhsanCore",
                "IhsanPrayerTimes",
                "IhsanLocation"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "IhsanNotificationsTests",
            dependencies: ["IhsanNotifications"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
