// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "native",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "EventStore",
            type: .dynamic,
            targets: ["EventStore"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "EventStore",
            dependencies: [],
            path: "Sources/"
        ),
    ]
)
