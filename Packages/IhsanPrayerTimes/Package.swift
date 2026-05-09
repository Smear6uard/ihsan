// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanPrayerTimes",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "IhsanPrayerTimes",
            targets: ["IhsanPrayerTimes"]
        )
    ],
    dependencies: [
        .package(path: "../IhsanCore"),
        .package(url: "https://github.com/batoulapps/adhan-swift", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "IhsanPrayerTimes",
            dependencies: [
                "IhsanCore",
                .product(name: "Adhan", package: "adhan-swift")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "IhsanPrayerTimesTests",
            dependencies: ["IhsanPrayerTimes"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
