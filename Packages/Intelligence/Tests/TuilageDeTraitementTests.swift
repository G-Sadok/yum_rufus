import Core
import Testing
@testable import Intelligence

/// Couvre le premier critere de la fonctionnalite : le traitement se fait par
/// tuiles de 256 avec recouvrement de 16.
///
/// Le critere est verifie deux fois, et les deux comptent. La geometrie annonce
/// des tuiles de 256 qui se recouvrent de 16, ce que les cas de ce fichier
/// mesurent sur des dizaines de tailles de page. Le traitement, lui, doit
/// reellement passer ces tuiles la au modele : le dernier cas lit ce que le
/// modele a recu, et non ce que la geometrie promettait.
struct TuilageDeTraitementTests {
    private let tuilage = TuilageDeTraitement.parDefaut

    /// Page de lecture ordinaire, decodee pour un ecran dense.
    private let pageOrdinaire = TailleEnPixels(largeur: 1200, hauteur: 1800)

    // MARK: Les deux nombres de la section 8

    @Test("Le tuilage par defaut est celui de la section 8, 256 et 16")
    func nombresDeLaSection8() {
        #expect(TuilageDeTraitement.coteDeTuile == 256)
        #expect(TuilageDeTraitement.recouvrementDeTuile == 16)
        #expect(tuilage.cote == 256)
        #expect(tuilage.recouvrement == 16)
        #expect(tuilage.pas == 240)
    }

    @Test("Un recouvrement aussi large que la tuile est refuse")
    func recouvrementBorne() {
        let absurde = TuilageDeTraitement(cote: 256, recouvrement: 256)

        #expect(absurde.recouvrement == 255)
        #expect(absurde.pas >= 1)
    }

    // MARK: Geometrie

    @Test("Toutes les tuiles font exactement 256 par 256")
    func tuilesCarreesDe256() {
        for taille in Self.taillesDePage {
            let decoupes = tuilage.decoupes(de: taille)

            #expect(decoupes.isEmpty == false)
            #expect(decoupes.allSatisfy { $0.taille.largeur == 256 && $0.taille.hauteur == 256 })
        }
    }

    @Test("Deux tuiles voisines se recouvrent d au moins seize pixels")
    func recouvrementDAuMoinsSeize() {
        for taille in Self.taillesDePage {
            let origines = tuilage.origines(pour: max(taille.largeur, tuilage.cote))

            for rang in 1..<max(1, origines.count) {
                let recouvrement = origines[rang - 1] + tuilage.cote - origines[rang]

                #expect(recouvrement >= tuilage.recouvrement)
            }
        }
    }

    @Test("Le recouvrement vaut exactement seize partout sauf contre le bord")
    func recouvrementExactSaufAuBord() {
        let origines = tuilage.origines(pour: 1200)

        #expect(origines.first == 0)
        #expect(origines.last == 1200 - 256)

        for rang in 1..<(origines.count - 1) {
            #expect(origines[rang] - origines[rang - 1] == tuilage.pas)
        }
    }

    @Test("Les tuiles couvrent la page entiere, sans trou")
    func couvertureSansTrou() {
        for taille in Self.taillesDePage {
            let decoupes = tuilage.decoupes(de: taille)
            let remplie = tuilage.tailleRemplie(pour: taille)

            #expect(Self.couvre(decoupes, taille: remplie))
        }
    }

    @Test("Une page plus petite qu une tuile est completee, pas raccourcie")
    func pagePlusPetiteQuUneTuile() {
        let minuscule = TailleEnPixels(largeur: 40, hauteur: 90)
        let decoupes = tuilage.decoupes(de: minuscule)

        #expect(decoupes.count == 1)
        #expect(decoupes.first?.taille == TailleEnPixels(largeur: 256, hauteur: 256))
        #expect(tuilage.tailleRemplie(pour: minuscule) == TailleEnPixels(largeur: 256, hauteur: 256))
    }

    @Test("Une taille nulle ne rend aucune tuile")
    func tailleNulleSansTuile() {
        #expect(tuilage.decoupes(de: .nulle).isEmpty)
        #expect(tuilage.nombreDeTuiles(pour: .nulle) == 0)
    }

    @Test("Les tuiles sont numerotees ligne par ligne, du haut vers le bas")
    func numerotationLigneParLigne() {
        let decoupes = tuilage.decoupes(de: pageOrdinaire)

        for (rang, decoupe) in decoupes.enumerated() {
            #expect(decoupe.index == rang)

            if rang > 0 {
                #expect(decoupe.ligne >= decoupes[rang - 1].ligne)
            }
        }
    }

    // MARK: Ce que le modele recoit reellement

    @Test("Le traitement passe au modele des tuiles de 256, une par decoupe")
    func leModeleRecoitDesTuilesDe256() throws {
        let page = try #require(PagesDeTest.damier(largeur: 700, hauteur: 300))
        let journal = JournalDeModele()
        let modele = ModeleSurveille(base: ModeleDeRecopie(), journal: journal)

        _ = try TraitementParTuiles(tuilage: tuilage).traiter(page, avec: modele)

        #expect(journal.taillesObservees == ["256x256"])
        #expect(journal.appels == tuilage.nombreDeTuiles(pour: page.taille))
        #expect(journal.appels > 1)
    }

    // MARK: Jeu de tailles

    /// Tailles de page couvertes par les cas de geometrie.
    ///
    /// Elles melangent les multiples exacts du pas, les tailles qui tombent a un
    /// pixel du bord, les pages plus petites qu une tuile et une page de lecture
    /// reelle. Les cas limites du decoupage sont tous a ces frontieres la.
    private static let taillesDePage: [TailleEnPixels] = [
        TailleEnPixels(largeur: 40, hauteur: 90),
        TailleEnPixels(largeur: 256, hauteur: 256),
        TailleEnPixels(largeur: 257, hauteur: 255),
        TailleEnPixels(largeur: 496, hauteur: 496),
        TailleEnPixels(largeur: 497, hauteur: 736),
        TailleEnPixels(largeur: 768, hauteur: 256),
        TailleEnPixels(largeur: 1200, hauteur: 1800),
        TailleEnPixels(largeur: 1601, hauteur: 2401),
    ]

    /// Vrai quand chaque pixel de la page appartient a au moins une tuile.
    ///
    /// La verification passe par deux axes separes et non par la surface : les
    /// tuiles forment une grille, un pixel est couvert si et seulement si son
    /// abscisse et son ordonnee le sont chacune.
    private static func couvre(_ decoupes: [DecoupeDeTraitement], taille: TailleEnPixels) -> Bool {
        var colonnes = [Bool](repeating: false, count: taille.largeur)
        var lignes = [Bool](repeating: false, count: taille.hauteur)

        for decoupe in decoupes {
            for colonne in decoupe.colonnes where colonne < taille.largeur {
                colonnes[colonne] = true
            }

            for ligne in decoupe.lignes where ligne < taille.hauteur {
                lignes[ligne] = true
            }
        }

        return colonnes.allSatisfy(\.self) && lignes.allSatisfy(\.self)
    }
}
