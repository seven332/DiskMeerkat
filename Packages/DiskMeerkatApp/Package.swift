// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "DiskMeerkatApp",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "DiskMeerkatApp",
            targets: ["DiskMeerkatApp"]
        )
    ],
    targets: [
        .target(name: "DiskMeerkatApp"),
        .testTarget(
            name: "DiskMeerkatAppTests",
            dependencies: ["DiskMeerkatApp"]
        ),
    ]
)
