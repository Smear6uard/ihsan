// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanCore",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26)
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
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
