// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IhsanDesignSystem",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
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
            // The Metal shader sources ship with the package but stay
            // out of the build until the Xcode Metal Toolchain
            // component is installable on the build machine — see the
            // header of CelestialShaders.metal for the enable steps.
            exclude: [
                "Celestial/Shaders"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "IhsanDesignSystemTests",
            dependencies: ["IhsanDesignSystem", "IhsanCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
