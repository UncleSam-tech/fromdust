// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FromTheDust",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FromTheDustCore", targets: ["FromTheDustCore"]),
        .executable(name: "FromTheDustCoreChecks", targets: ["FromTheDustCoreChecks"]),
    ],
    targets: [
        .target(
            name: "FromTheDustCore",
            path: ".",
            exclude: ["FromTheDustCoreTests.swift"],
            sources: ["FromTheDustCore.swift"]
        ),
        .executableTarget(
            name: "FromTheDustCoreChecks",
            dependencies: ["FromTheDustCore"],
            path: ".",
            exclude: ["FromTheDustCore.swift"],
            sources: ["FromTheDustCoreTests.swift"]
        ),
    ]
)
