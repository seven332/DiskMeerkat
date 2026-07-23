// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "DiskMeerkatApp",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "DiskMeerkatApp",
            targets: ["DiskMeerkatApp"]
        )
    ],
    targets: [
        .target(
            name: "DiskMeerkatApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DiskMeerkatAppTests",
            dependencies: ["DiskMeerkatApp"]
        ),
    ]
)
