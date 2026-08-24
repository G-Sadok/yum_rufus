// swift-tools-version: 6.0
//
// Manifeste unique des paquets metier du projet.
//
// Un seul manifeste plutot qu un manifeste par module, pour deux raisons.
// D abord le jeu de verifications compile la couche metier avec
// `swift build --package-path Packages`, ce qui suppose un manifeste a cette
// racine. Ensuite les neuf modules partagent les memes plateformes minimales
// et le meme mode de langage, les dupliquer neuf fois n apporterait rien.
//
// L arborescence sur disque reste celle de la section 2.3 du cahier de
// developpement : un dossier par module, avec ses propres Sources.

import PackageDescription

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
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        // Core ne depend de rien. Tout le reste peut dependre de Core.
        .target(name: "Core", path: "Core/Sources"),

        .target(
            name: "Storage",
            dependencies: ["Core", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Storage/Sources"
        ),
        // Sources depend d Archive pour compter les pages d un chapitre range
        // dans un conteneur, sans redupliquer la lecture d index central.
        .target(name: "Sources", dependencies: ["Core", "Archive"], path: "Sources/Sources"),
        .target(name: "Archive", dependencies: ["Core"], path: "Archive/Sources"),
        .target(name: "ImagePipeline", dependencies: ["Core"], path: "ImagePipeline/Sources"),
        .target(
            name: "ReaderEngine",
            dependencies: ["Core", "ImagePipeline"],
            path: "ReaderEngine/Sources"
        ),
        .target(
            name: "Intelligence",
            dependencies: ["Core", "ImagePipeline"],
            path: "Intelligence/Sources"
        ),
        .target(name: "Sync", dependencies: ["Core", "Storage"], path: "Sync/Sources"),

        // Seul paquet autorise a importer SwiftUI.
        .target(name: "DesignSystem", dependencies: ["Core"], path: "DesignSystem/Sources"),

        .testTarget(name: "CoreTests", dependencies: ["Core"], path: "Core/Tests"),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage", "Core"],
            path: "Storage/Tests"
        ),
        .testTarget(
            name: "ArchiveTests",
            dependencies: ["Archive", "Core"],
            path: "Archive/Tests"
        ),
        .testTarget(
            name: "SourcesTests",
            dependencies: ["Sources", "Core", "Archive"],
            path: "Sources/Tests"
        ),
        .testTarget(
            name: "ReaderEngineTests",
            dependencies: ["ReaderEngine", "Core"],
            path: "ReaderEngine/Tests"
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem", "Core"],
            path: "DesignSystem/Tests"
        ),
    ]
)
