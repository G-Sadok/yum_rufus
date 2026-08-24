// swift-tools-version: 6.0

import PackageDescription

/// Reglages appliques a tous les paquets metier.
///
/// Le mode de langage 6 impose la verification stricte de la concurrence,
/// exigee par la section 2.2 du cahier de developpement.
let reglagesCommuns: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
]

let package = Package(
    name: "YumPackages",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "Sources", targets: ["Sources"]),
        .library(name: "Archive", targets: ["Archive"]),
        .library(name: "ImagePipeline", targets: ["ImagePipeline"]),
        .library(name: "ReaderEngine", targets: ["ReaderEngine"]),
        .library(name: "Intelligence", targets: ["Intelligence"]),
        .library(name: "Sync", targets: ["Sync"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    targets: [
        .target(
            name: "Core",
            path: "Core/Sources",
            swiftSettings: reglagesCommuns
        ),
        .target(
            name: "Storage",
            dependencies: ["Core"],
            path: "Storage/Sources",
            swiftSettings: reglagesCommuns
        ),
        .target(
            name: "Sources",
            dependencies: ["Core"],
            path: "Sources/Sources",
            swiftSettings: reglagesCommuns
        ),
        .target(
            name: "Archive",
            dependencies: ["Core"],
            path: "Archive/Sources",
            swiftSettings: reglagesCommuns
        ),
        .target(
            name: "ImagePipeline",
            dependencies: ["Core"],
            path: "ImagePipeline/Sources",
            swiftSettings: reglagesCommuns
        ),
        .target(
            name: "ReaderEngine",
            dependencies: ["Core"],
            path: "ReaderEngine/Sources",
            swiftSettings: reglagesCommuns
        ),
        .target(
            name: "Intelligence",
            dependencies: ["Core"],
            path: "Intelligence/Sources",
            swiftSettings: reglagesCommuns
        ),
        .target(
            name: "Sync",
            dependencies: ["Core"],
            path: "Sync/Sources",
            swiftSettings: reglagesCommuns
        ),
        .target(
            name: "DesignSystem",
            dependencies: ["Core"],
            path: "DesignSystem/Sources",
            swiftSettings: reglagesCommuns
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Core/Tests",
            swiftSettings: reglagesCommuns
        ),
    ]
)
