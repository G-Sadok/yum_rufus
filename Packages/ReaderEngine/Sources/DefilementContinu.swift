import Core
import Foundation

//
// DefilementContinu
//
// Geometrie de la pile de pages du mode Defilement continu, section 7.1 du
// cahier de developpement.
//
// Quatre choix structurent ce type.
//
// La pile est une valeur calculee une fois par chapitre. Les debuts de page
// sont cumules a la construction, une recherche par decalage coute donc un
// logarithme et non un parcours. C est ce qui separe un defilement tenu d un
// defilement qui ralentit sur les chapitres longs, la ou le calcul retombe a
// chaque image.
//
// Le decalage se mesure en points de la pile, la position de reprise en
// fraction de la page courante. La conversion vit ici et nulle part ailleurs :
// la section 7.5 sauvegarde une fraction justement pour qu une reprise sur un
// autre appareil retombe au meme endroit du dessin.
//
// L interstice qui separe deux pages est un parametre, jamais une valeur ecrite
// ici. C est lui qui donne la transition nette du mode continu, mais sa valeur
// est un jeton d espacement : elle appartient a DesignSystem, et la couche vue
// la passe au moteur.
//
// Le sens de lecture n entre pas dans ce calcul. Le mode continu impose deja le
// sens vertical, voir MiseEnPage.sensImpose, et une pile verticale s empile du
// haut vers le bas dans les trois sens.
//

/// Endroit atteint dans une pile de pages qui defile verticalement.
public struct PositionDansLeDefilement: Sendable, Equatable, Hashable {
    /// Page qui touche le bord haut de la fenetre, indexee a partir de zero.
    public let page: Int

    /// Part de cette page deja depassee par le defilement, entre zero et un.
    public let fraction: Double

    /// Construit une position, bornee.
    public init(page: Int, fraction: Double) {
        self.page = max(0, page)
        self.fraction = min(max(fraction, 0), 1)
    }
}

/// Pile verticale des pages d un chapitre lu en defilement continu.
public struct DefilementContinu: Sendable, Equatable {
    /// Hauteur retenue de chaque page, dans l ordre narratif.
    public let hauteurs: [Double]

    /// Espace laisse entre deux pages, jamais avant la premiere ni apres la
    /// derniere.
    public let interstice: Double

    /// Hauteur de la pile entiere, interstices compris.
    public let hauteurTotale: Double

    /// Debut de chaque page dans la pile, cumule une fois pour toutes.
    private let debuts: [Double]

    /// Hauteur minimale accordee a une page.
    ///
    /// Une page de hauteur nulle rendrait deux debuts identiques et une
    /// fraction indefinie. Une source annonce parfois une page avant d en
    /// connaitre les dimensions, ce plancher garde la pile coherente jusqu a ce
    /// que la vraie hauteur arrive.
    private static let hauteurPlancher: Double = 1

    /// Recul applique au bord bas d une fenetre avant de chercher la page qui
    /// s y trouve. Une fenetre qui s arrete pile sur le debut d une page ne
    /// montre pas cette page.
    private static let bordExclusif: Double = 1e-6

    /// Empile les pages d un chapitre.
    ///
    /// - Parameters:
    ///   - hauteurs: hauteur de chaque page une fois ajustee a la largeur de la
    ///     fenetre, dans l ordre narratif.
    ///   - interstice: espace entre deux pages, en points. La valeur vient du
    ///     jeton d espacement choisi par la couche vue.
    public init(hauteurs: [Double], interstice: Double = 0) {
        let retenues = hauteurs.map { max($0, Self.hauteurPlancher) }
        let separation = max(0, interstice)

        var cumules: [Double] = []
        cumules.reserveCapacity(retenues.count)

        var curseur: Double = 0
        for hauteur in retenues {
            cumules.append(curseur)
            curseur += hauteur + separation
        }

        self.hauteurs = retenues
        self.interstice = separation
        debuts = cumules
        hauteurTotale = retenues.isEmpty ? 0 : curseur - separation
    }

    /// Nombre de pages empilees.
    public var nombreDePages: Int {
        hauteurs.count
    }

    /// Vrai quand le chapitre ne contient aucune page.
    public var estVide: Bool {
        hauteurs.isEmpty
    }

    /// Hauteur d une page, nulle hors du chapitre.
    public func hauteur(dePage page: Int) -> Double {
        guard hauteurs.indices.contains(page) else { return 0 }

        return hauteurs[page]
    }

    /// Debut d une page dans la pile, nul hors du chapitre.
    public func debut(dePage page: Int) -> Double {
        guard debuts.indices.contains(page) else { return 0 }

        return debuts[page]
    }

    /// Position atteinte pour un decalage donne.
    ///
    /// Un decalage tombe dans l interstice rend la page qui precede, a la
    /// fraction un. La transition appartient a la page que l utilisateur vient
    /// de finir, pas a celle qu il n a pas encore commencee.
    public func position(auDecalage decalage: Double) -> PositionDansLeDefilement {
        guard estVide == false else {
            return PositionDansLeDefilement(page: 0, fraction: 0)
        }

        let bornee = min(max(decalage, 0), hauteurTotale)
        let page = pageCommencantAvant(bornee)

        return PositionDansLeDefilement(
            page: page,
            fraction: (bornee - debuts[page]) / hauteurs[page]
        )
    }

    /// Decalage correspondant a une position dans la pile.
    ///
    /// Reciproque exacte de `position(auDecalage:)` pour toute position que
    /// cette derniere peut rendre.
    public func decalage(pour position: PositionDansLeDefilement) -> Double {
        guard estVide == false else { return 0 }

        let page = min(position.page, nombreDePages - 1)

        return debuts[page] + position.fraction * hauteurs[page]
    }

    /// Position de reprise a enregistrer pour ce decalage.
    ///
    /// La section 7.5 demande un couple chapitre et index de page, plus un
    /// decalage de defilement. Le decalage retenu est la fraction de la page
    /// courante et non un nombre de points : reprise sur un telephone apres une
    /// tablette, un nombre de points tomberait ailleurs dans le dessin.
    public func positionDeLecture(chapitreId: UUID, auDecalage decalage: Double) -> PositionDeLecture {
        let dansLaPile = position(auDecalage: decalage)

        return PositionDeLecture(
            chapitreId: chapitreId,
            pageIndex: dansLaPile.page,
            decalageDeDefilement: dansLaPile.fraction
        )
    }

    /// Decalage a restituer pour rouvrir le chapitre a cette position.
    public func decalage(pourReprise position: PositionDeLecture) -> Double {
        let normalisee = position.normalisee(nombreDePages: nombreDePages)

        return decalage(
            pour: PositionDansLeDefilement(
                page: normalisee.pageIndex,
                fraction: normalisee.decalageDeDefilement
            )
        )
    }

    /// Pages qui touchent la fenetre affichee.
    ///
    /// - Parameters:
    ///   - decalage: position du bord haut de la fenetre dans la pile.
    ///   - hauteurDeLaFenetre: hauteur visible, en points.
    public func pagesVisibles(auDecalage decalage: Double, hauteurDeLaFenetre: Double) -> Range<Int> {
        guard estVide == false else { return 0..<0 }

        let haut = min(max(decalage, 0), hauteurTotale)
        let bas = max(haut, haut + max(0, hauteurDeLaFenetre) - Self.bordExclusif)

        let premiere = position(auDecalage: haut).page
        let derniere = max(premiere, position(auDecalage: bas).page)

        return premiere..<(derniere + 1)
    }

    /// Nombre de vues a garder vivantes pour ce chapitre.
    ///
    /// C est le plus grand nombre de pages simultanement visibles, augmente de
    /// la fenetre de precharge de la section 6.2. En dessous, le recyclage
    /// devrait creer une vue de plus au pire moment, celui ou le doigt defile.
    ///
    /// Le pire cas d une premiere page donnee n est pas la fenetre calee sur son
    /// debut, mais la fenetre qui n en montre plus qu un filet : elle descend
    /// alors aussi loin que possible dans la pile. C est ce cas qui est mesure.
    public func capaciteDeRecyclage(
        hauteurDeLaFenetre: Double,
        plan: PlanDePrecharge = .parDefaut
    ) -> Int {
        guard estVide == false else { return 0 }

        let fenetre = max(0, hauteurDeLaFenetre)
        var maximum = 1
        var derniere = 0

        for premiere in hauteurs.indices {
            let limite = debuts[premiere] + hauteurs[premiere] + fenetre

            derniere = max(derniere, premiere)
            while derniere + 1 < nombreDePages, debuts[derniere + 1] < limite {
                derniere += 1
            }

            maximum = max(maximum, derniere - premiere + 1)
        }

        return maximum + plan.enAvant + plan.enArriere
    }

    /// Fenetre de pages a garder montees pour ce decalage.
    ///
    /// La fenetre porte toujours le meme nombre de pages, tant que le chapitre
    /// en compte assez. C est ce qui rend le nombre de vues vivantes constant :
    /// le pool ne voit jamais la fenetre grandir, donc n a jamais a creer une
    /// vue de plus.
    ///
    /// Les pages en trop se repartissent devant et derriere selon le meme
    /// rapport que la precharge, deux tiers devant et un tiers derriere : un
    /// retour en arriere est plus rare et moins urgent qu une descente.
    public func fenetreDeRecyclage(
        auDecalage decalage: Double,
        hauteurDeLaFenetre: Double,
        capacite: Int,
        plan: PlanDePrecharge = .parDefaut
    ) -> Range<Int> {
        guard estVide == false, capacite > 0 else { return 0..<0 }

        let largeur = min(capacite, nombreDePages)
        let visibles = pagesVisibles(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre)

        guard visibles.count < largeur else {
            return visibles.lowerBound..<(visibles.lowerBound + largeur)
        }

        let marge = largeur - visibles.count
        let total = plan.enAvant + plan.enArriere
        let enArriere = total > 0 ? marge * plan.enArriere / total : 0
        let debut = min(max(visibles.lowerBound - enArriere, 0), nombreDePages - largeur)

        return debut..<(debut + largeur)
    }

    /// Derniere page dont le debut precede ce decalage, par dichotomie.
    private func pageCommencantAvant(_ decalage: Double) -> Int {
        var bas = 0
        var haut = nombreDePages - 1

        while bas < haut {
            let milieu = (bas + haut + 1) / 2

            if debuts[milieu] <= decalage {
                bas = milieu
            } else {
                haut = milieu - 1
            }
        }

        return bas
    }
}
