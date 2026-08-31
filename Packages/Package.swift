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

        // Campagne de mesure des sept budgets de la section 12. C est un
        // executable et non une suite de tests parce que deux des sept budgets
        // sont des budgets memoire : les mesurer dans le processus de `swift
        // test`, ou deux cent cinquante suites vivent de front, reviendrait a
        // mesurer l empreinte des autres suites. Chaque budget est donc mesure
        // dans un processus qui ne fait que cela.
        .executable(name: "mesurer-budgets", targets: ["MesureDesBudgets"]),
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
        // ImagePipeline apparait avec le PDF : une page de PDF n existe qu une
        // fois rasterisee, son lecteur vit donc dans la chaine d images, et la
        // source locale a besoin de lui pour enumerer les pages d un chapitre
        // range en PDF comme elle le fait pour un CBZ.
        .target(
            name: "Sources",
            dependencies: ["Core", "Archive", "ImagePipeline"],
            path: "Sources/Sources"
        ),
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
        // Sources apparait avec les services de suivi. Sync est la couche qui
        // pousse l etat local vers un service distant, et les quatre suivis de
        // la section 9 en font partie autant que CloudKit. Ils parlent en HTTP,
        // et le projet n a qu une seule couture reseau, `TransportHttp`, posee
        // dans Sources avec le client REST qui verifie les reponses. La
        // recopier dans Sync aurait donne deux traitements du corps tronque et
        // du jeton refuse, qui divergeraient au premier correctif.
        .target(name: "Sync", dependencies: ["Core", "Storage", "Sources"], path: "Sync/Sources"),

        // Seul paquet autorise a importer SwiftUI.
        .target(name: "DesignSystem", dependencies: ["Core"], path: "DesignSystem/Sources"),

        // Budgets de la section 12, generateur du jeu de test volumineux et
        // campagne de mesure. Cette cible n est volontairement exposee par
        // aucun produit de bibliotheque : rien de ce qu elle contient n a de
        // raison d entrer dans l application livree, et un jour ou l autre
        // quelqu un importerait le generateur depuis une vue.
        .target(
            name: "BudgetsDePerformance",
            dependencies: ["Core", "Storage", "Archive", "ImagePipeline", "ReaderEngine"],
            path: "Performance/Sources"
        ),
        .executableTarget(
            name: "MesureDesBudgets",
            dependencies: ["BudgetsDePerformance"],
            path: "Performance/Mesure"
        ),

        // Le dossier Fichiers porte le jeu de ComicInfo.xml et de commentaires
        // ComicBookInfo reels de la section 5.3, dont deux ne sont pas en
        // UTF-8. Copie et non traite, pour la meme raison que celui des formats
        // d image : un traitement par les outils de Xcode reecrirait les
        // fichiers, et un test d encodage lirait alors autre chose que ce que
        // le depot suit.
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Core/Tests",
            resources: [.copy("Fichiers")]
        ),
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
            dependencies: ["Sources", "Core", "Archive", "ImagePipeline"],
            path: "Sources/Tests"
        ),
        // Le dossier Fichiers porte le jeu de fichiers de test des formats de la
        // section 5.2. Il est copie tel quel et non traite : une ressource
        // traitee passerait par les outils d image de Xcode, qui recompressent,
        // et un test de format lirait alors autre chose que le fichier suivi.
        .testTarget(
            name: "ImagePipelineTests",
            dependencies: ["ImagePipeline", "Core"],
            path: "ImagePipeline/Tests",
            resources: [.copy("Fichiers")]
        ),
        // ImagePipeline apparait ici avec la precharge : les tests du moteur
        // manipulent des pages decodees et le cache memoire, tous deux definis
        // par ce paquet.
        .testTarget(
            name: "ReaderEngineTests",
            dependencies: ["ReaderEngine", "Core", "ImagePipeline"],
            path: "ReaderEngine/Tests"
        ),
        // ImagePipeline apparait ici parce que la surelevation entre et sort en
        // ImageDePage et se met en cache sous une ClePage, deux types que la
        // chaine d images definit et que les tests manipulent directement.
        .testTarget(
            name: "IntelligenceTests",
            dependencies: ["Intelligence", "Core", "ImagePipeline"],
            path: "Intelligence/Tests"
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem", "Core"],
            path: "DesignSystem/Tests"
        ),
        .testTarget(
            name: "SyncTests",
            dependencies: ["Sync", "Core", "Sources"],
            path: "Sync/Tests"
        ),
        // Cette suite ne mesure aucun budget, elle verifie l outil qui les
        // mesure : que les sept valeurs de la section 12 sont bien celles du
        // cahier, que l arbitre vire au rouge quand une mesure deborde, et que
        // le generateur du jeu de test rend deux fois le meme corpus.
        .testTarget(
            name: "BudgetsDePerformanceTests",
            dependencies: ["BudgetsDePerformance", "Core", "Storage", "Archive", "ImagePipeline"],
            path: "Performance/Tests"
        ),
    ]
)
