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
        /* .library( */
        /*     name: "native", */
        /*     type: .dynamic, */
        /*     targets: ["native"] */
        /* ), */
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
