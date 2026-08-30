import Foundation
@testable import Intelligence

//
// ModelesDeTest
//
// Modeles de surelevation synthetiques, dont la sortie exacte est connue.
//
// Aucune assertion utile ne peut porter sur un reseau entraine : personne ne
// sait dire ce que devrait valoir un pixel de sa sortie, et le fichier ne vit
// pas dans le depot. Les proprietes que la fonctionnalite promet ne portent
// pourtant pas sur le reseau, elles portent sur ce qui l entoure, le decoupage,
// la refonte, la serialisation et le cache. Ces modeles rendent ces proprietes
// mesurables.
//
// Deux modeles, deux roles.
//
// La recopie n a aucun voisinage : la valeur d un pixel de sortie ne depend que
// d un pixel d entree. Un tel modele rend exactement la meme chose qu il voie la
// page entiere ou une tuile, ce qui permet d exiger l egalite au pixel pres
// entre la page tuilee et la page traitee d un seul tenant. Toute erreur propre
// a la recomposition apparait alors comme un ecart.
//
// Le flou, lui, regarde ses voisins et n en a pas au bord de son entree, ou il
// recopie le dernier pixel connu. C est exactement ce que fait un reseau de
// convolution au bord de sa fenetre, et c est la cause du raccord visible que le
// recouvrement existe pour effacer.
//

/// Agrandissement par recopie, sans aucun voisinage.
struct ModeleDeRecopie: ModeleDeSurelevation {
    let identifiant: String
    let facteur: Int
    let coteDeTuile: Int

    init(
        identifiant: String = "recopie",
        facteur: Int = 2,
        coteDeTuile: Int = TuilageDeTraitement.coteDeTuile
    ) {
        self.identifiant = identifiant
        self.facteur = facteur
        self.coteDeTuile = coteDeTuile
    }

    func surelever(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
        guard let agrandie = OperationsDeTest.agrandir(tuile, facteur: facteur) else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        return agrandie
    }
}

/// Agrandissement suivi d un flou horizontal, qui extrapole a ses bords.
struct ModeleDeFlou: ModeleDeSurelevation {
    let identifiant = "flou"
    let facteur = 2
    let coteDeTuile = TuilageDeTraitement.coteDeTuile

    /// Nombre de pixels regardes de chaque cote.
    let rayon: Int

    init(rayon: Int = 4) {
        self.rayon = rayon
    }

    func surelever(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
        guard let agrandie = OperationsDeTest.agrandir(tuile, facteur: facteur),
              let floutee = OperationsDeTest.flouter(agrandie, rayon: rayon)
        else {
            throw ErreurDeTraitementIA.pageIllisible
        }

        return floutee
    }
}

/// Compte les appels au modele et surveille leur recouvrement dans le temps.
///
/// Le marqueur non verifie est sur : le journal ne detient que des entiers,
/// proteges par un verrou pris a chaque acces, et n expose aucune reference.
final class JournalDeModele: @unchecked Sendable {
    private let verrou = NSLock()
    private var appelsInternes = 0
    private var enCours = 0
    private var maximumInterne = 0
    private var taillesInternes: Set<String> = []

    /// Nombre total d appels au modele.
    var appels: Int {
        verrou.lock()
        defer { verrou.unlock() }

        return appelsInternes
    }

    /// Plus grand nombre d appels observes en meme temps.
    ///
    /// C est la mesure de la promesse de la section 8. Elle vaut un sur une file
    /// serialisee, et davantage des que deux traitements se chevauchent.
    var maximumSimultane: Int {
        verrou.lock()
        defer { verrou.unlock() }

        return maximumInterne
    }

    /// Dimensions distinctes des tuiles reellement recues, en largeur par
    /// hauteur.
    ///
    /// C est la mesure du premier critere : le traitement se fait par tuiles de
    /// 256, ce qui se verifie sur ce que le modele recoit et non sur ce que la
    /// geometrie annonce.
    var taillesObservees: Set<String> {
        verrou.lock()
        defer { verrou.unlock() }

        return taillesInternes
    }

    func entrer(largeur: Int, hauteur: Int) {
        verrou.lock()
        appelsInternes += 1
        enCours += 1
        maximumInterne = max(maximumInterne, enCours)
        taillesInternes.insert("\(largeur)x\(hauteur)")
        verrou.unlock()
    }

    func sortir() {
        verrou.lock()
        enCours -= 1
        verrou.unlock()
    }
}

/// Modele qui journalise ses appels et peut prendre son temps.
struct ModeleSurveille: ModeleDeSurelevation {
    let base: any ModeleDeSurelevation
    let journal: JournalDeModele

    /// Duree tenue par chaque tuile, pour laisser le temps a deux traitements
    /// de se chevaucher si rien ne les en empeche.
    let attente: TimeInterval

    init(base: any ModeleDeSurelevation, journal: JournalDeModele, attente: TimeInterval = 0) {
        self.base = base
        self.journal = journal
        self.attente = attente
    }

    var identifiant: String {
        base.identifiant
    }

    var facteur: Int {
        base.facteur
    }

    var coteDeTuile: Int {
        base.coteDeTuile
    }

    func surelever(_ tuile: MatriceDePixels) throws -> MatriceDePixels {
        journal.entrer(largeur: tuile.largeur, hauteur: tuile.hauteur)

        defer { journal.sortir() }

        if attente > 0 {
            Thread.sleep(forTimeInterval: attente)
        }

        return try base.surelever(tuile)
    }
}

//
// OperationsDeTest
//
// Les deux traitements de pixels dont les modeles de test sont faits.
//

enum OperationsDeTest {
    /// Agrandit par recopie du pixel le plus proche.
    static func agrandir(_ matrice: MatriceDePixels, facteur: Int) -> MatriceDePixels? {
        guard facteur >= 1 else { return nil }

        let parPixel = MatriceDePixels.octetsParPixel
        let largeur = matrice.largeur * facteur
        let hauteur = matrice.hauteur * facteur
        var octets = [UInt8](repeating: 0, count: largeur * hauteur * parPixel)

        for ligne in 0..<hauteur {
            for colonne in 0..<largeur {
                let depart = (ligne * largeur + colonne) * parPixel
                let source = ((ligne / facteur) * matrice.largeur + colonne / facteur) * parPixel

                for canal in 0..<parPixel {
                    octets[depart + canal] = matrice.octets[source + canal]
                }
            }
        }

        return MatriceDePixels(largeur: largeur, hauteur: hauteur, octets: octets)
    }

    /// Moyenne horizontale sur un rayon, bord recopie faute de voisin.
    static func flouter(_ matrice: MatriceDePixels, rayon: Int) -> MatriceDePixels? {
        guard rayon >= 0 else { return nil }

        let parPixel = MatriceDePixels.octetsParPixel
        var octets = matrice.octets

        for ligne in 0..<matrice.hauteur {
            for colonne in 0..<matrice.largeur {
                let depart = (ligne * matrice.largeur + colonne) * parPixel

                for canal in 0..<3 {
                    var somme = 0

                    for decalage in -rayon...rayon {
                        let voisine = min(max(0, colonne + decalage), matrice.largeur - 1)

                        somme += Int(matrice.canal(canal, colonne: voisine, ligne: ligne))
                    }

                    octets[depart + canal] = UInt8(somme / (2 * rayon + 1))
                }
            }
        }

        return MatriceDePixels(largeur: matrice.largeur, hauteur: matrice.hauteur, octets: octets)
    }
}
