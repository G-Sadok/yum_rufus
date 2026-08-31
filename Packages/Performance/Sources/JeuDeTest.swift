import Foundation

//
// JeuDeTest
//
// Ou vit le corpus de 5000 series et 200000 chapitres, et de quoi il est fait.
//
// Le corpus est suivi par le depot sous sa forme de definition, pas sous sa
// forme materialisee. La base de 200000 chapitres pese une quarantaine de mega
// octets et changerait a chaque regeneration ; la suivre en binaire alourdirait
// chaque clone du depot sans rien apporter, puisqu elle se reconstruit a
// l identique depuis sa graine. Ce qui est suivi est donc le manifeste, qui fige
// les nombres et la graine, et le generateur, qui est deterministe. La suite
// `GenerateurDeJeuDeTestTests` verifie que deux generations depuis la meme
// graine rendent le meme corpus, ce qui est la seule chose qu un fichier
// binaire suivi apporterait de plus.
//

/// Ce que le manifeste suivi par le depot fige.
///
/// Il est lu par le generateur et par les tests. Changer un nombre ici change
/// le corpus de tout le monde, ce qui est le but : le jeu de test est une
/// donnee du projet, pas un argument de ligne de commande oublie dans un script.
public struct ManifesteDuJeuDeTest: Sendable, Hashable, Codable {
    /// Nombre de series de la bibliotheque.
    public let series: Int

    /// Nombre total de chapitres, reparti sur les series.
    public let chapitres: Int

    /// Graine du generateur pseudo aleatoire. Elle rend le corpus reproductible.
    public let graine: UInt64

    /// Nombre de chapitres reellement poses sur le disque en CBZ.
    ///
    /// Les 200000 chapitres du corpus sont des lignes de base : c est ce que la
    /// bibliotheque manipule au lancement et pendant le defilement de la grille.
    /// Les budgets d ouverture, de tourne de page et de memoire en lecture ont
    /// besoin d octets reels, mais de quelques chapitres seulement, puisqu ils
    /// ne mesurent jamais qu un chapitre a la fois.
    public let chapitresSurDisque: Int

    /// Nombre de pages de chacun de ces chapitres.
    public let pagesParChapitreSurDisque: Int

    /// Largeur en pixels des pages posees sur le disque.
    public let largeurDePage: Int

    /// Hauteur en pixels des pages posees sur le disque.
    public let hauteurDePage: Int

    public init(
        series: Int,
        chapitres: Int,
        graine: UInt64,
        chapitresSurDisque: Int,
        pagesParChapitreSurDisque: Int,
        largeurDePage: Int,
        hauteurDePage: Int
    ) {
        self.series = series
        self.chapitres = chapitres
        self.graine = graine
        self.chapitresSurDisque = chapitresSurDisque
        self.pagesParChapitreSurDisque = pagesParChapitreSurDisque
        self.largeurDePage = largeurDePage
        self.hauteurDePage = hauteurDePage
    }

    /// Le corpus que la section 12 exige, tel que le manifeste du depot le fige.
    public static let section12 = ManifesteDuJeuDeTest(
        series: 5000,
        chapitres: 200_000,
        graine: 1_234_567_890_123_456_789,
        chapitresSurDisque: 2,
        pagesParChapitreSurDisque: 30,
        largeurDePage: 2400,
        hauteurDePage: 3600
    )
}

/// Emplacements du corpus sur le disque.
public struct EmplacementDuJeuDeTest: Sendable, Hashable {
    /// Dossier suivi par le depot, celui qui porte le manifeste.
    public let dossier: URL

    public init(dossier: URL) {
        self.dossier = dossier
    }

    /// Emplacement par defaut, deduit de la racine du depot.
    public static func parDefaut(racineDuDepot: URL) -> EmplacementDuJeuDeTest {
        EmplacementDuJeuDeTest(
            dossier: racineDuDepot
                .appendingPathComponent("Tests", isDirectory: true)
                .appendingPathComponent("JeuDeDonnees", isDirectory: true)
        )
    }

    /// Le manifeste suivi par le depot.
    public var manifeste: URL {
        dossier.appendingPathComponent("manifeste.json")
    }

    /// Dossier des artefacts produits par le generateur, ignore par git.
    public var genere: URL {
        dossier.appendingPathComponent("genere", isDirectory: true)
    }

    /// Base de donnees de la bibliotheque de 5000 series.
    public var bibliotheque: URL {
        genere.appendingPathComponent("bibliotheque.sqlite")
    }

    /// Dossier des chapitres poses en CBZ.
    public var chapitres: URL {
        genere.appendingPathComponent("chapitres", isDirectory: true)
    }

    /// Le CBZ du rang demande.
    public func chapitre(rang: Int) -> URL {
        chapitres.appendingPathComponent(String(format: "chapitre-%03d.cbz", rang))
    }

    /// Vrai quand le corpus est deja materialise.
    public var estMaterialise: Bool {
        let fichiers = FileManager.default

        return fichiers.fileExists(atPath: bibliotheque.path)
            && fichiers.fileExists(atPath: chapitre(rang: 0).path)
    }

    /// Lit le manifeste suivi par le depot.
    ///
    /// - Throws: `ErreurDeMesure.jeuDeTestAbsent` quand le fichier manque.
    public func lireLeManifeste() throws -> ManifesteDuJeuDeTest {
        guard let octets = FileManager.default.contents(atPath: manifeste.path) else {
            throw ErreurDeMesure.jeuDeTestAbsent(chemin: manifeste.path)
        }

        return try JSONDecoder().decode(ManifesteDuJeuDeTest.self, from: octets)
    }
}
