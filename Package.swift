// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FromTheDust",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FromTheDustCore", targets: ["FromTheDustCore"]),
    ],
    targets: [
        .target(
            name: "FromTheDustCore",
            path: ".",
            exclude: ["FromTheDustCoreTests.swift"],
            sources: ["FromTheDustCore.swift"]
        ),
        .testTarget(
            name: "FromTheDustCoreTests",
            dependencies: ["FromTheDustCore"],
            path: ".",
            exclude: ["FromTheDustCore.swift"],
            sources: ["FromTheDustCoreTests.swift"]
        ),
    ]
)
