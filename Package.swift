// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TOCK",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TOCK", targets: ["TOCK"])
    ],
    targets: [
        .executableTarget(
            name: "TOCK",
            path: "Sources/TOCK"
        )
    ]
)
