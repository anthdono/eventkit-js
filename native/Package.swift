// swift-tools-version: 5.7

import PackageDescription

let package = Package(
        name: "native",
        products: [
            .library(
                    name: "native",
                    type: .dynamic,
                    targets: ["native"]
            ),
        ],
        dependencies: [
        ],
        targets: [
            .target(
                    name: "native",
                    dependencies: []
            )
        ]
)


