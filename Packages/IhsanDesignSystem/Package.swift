// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanDesignSystem",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(
            name: "IhsanDesignSystem",
            targets: ["IhsanDesignSystem"]
        )
    ],
    dependencies: [
        .package(path: "../IhsanCore")
    ],
    targets: [
        .target(
            name: "IhsanDesignSystem",
            dependencies: [
                "IhsanCore"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "IhsanDesignSystemTests",
            dependencies: ["IhsanDesignSystem"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
