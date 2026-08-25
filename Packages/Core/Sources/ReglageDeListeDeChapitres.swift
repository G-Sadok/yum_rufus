import Foundation

//
// ReglageDeListeDeChapitres
//
// Filtre et tri de la liste des chapitres, actions Filtrer et Trier de la
// section 5.6 de DESIGN-SPEC.md.
//
// Le document nomme les deux actions mais ne dessine pas leurs menus, la fiche
// n existant pas dans les captures de reference. Les valeurs retenues ci
// dessous suivent donc les regles d ecriture de la section 6, et surtout la
// realite des donnees de la section 3.1 : un chapitre porte un etat de lecture,
// un etat de telechargement, un numero et une date de publication. Rien d autre
// n est filtrable ni triable sans inventer une colonne.
//
// Le reglage appartient a la serie et non a l ecran. Une liste triee du plus
// recent au plus ancien sur une serie en cours, et du plus ancien au plus
// recent sur une serie qu on rattrape, sont deux choix legitimes qui doivent
// survivre a la fermeture de la fiche. C est le paquet Storage qui les persiste,
// une ligne par serie.
//

/// Chapitres retenus par la liste, action Filtrer de la section 5.6.
public enum FiltreDeChapitres: String, Sendable, Codable, CaseIterable, Hashable {
    /// Aucun filtre, etat par defaut de la liste.
    case tous

    /// Chapitres jamais ouverts ou commences.
    case nonLus

    /// Chapitres termines.
    case lus

    /// Chapitres disponibles hors ligne.
    case telecharges

    /// Vrai quand le chapitre passe le filtre.
    public func retient(_ chapitre: ChapitreDeFiche) -> Bool {
        switch self {
        case .tous: true
        case .nonLus: chapitre.lecture != .lu
        case .lus: chapitre.lecture == .lu
        case .telecharges: chapitre.estTelecharge
        }
    }
}

/// Cle de tri de la liste des chapitres, action Trier de la section 5.6.
public enum CritereDeTriDeChapitres: String, Sendable, Codable, CaseIterable, Hashable {
    /// Numero du chapitre. Le rang dans la serie departage les numeros egaux et
    /// prend le relais quand la source n en donne aucun.
    case numero

    /// Date de publication annoncee par la source.
    case datePublication
}

/// Filtre et tri appliques a la liste des chapitres d une serie.
public struct ReglageDeListeDeChapitres: Sendable, Codable, Equatable, Hashable {
    public var filtre: FiltreDeChapitres
    public var critere: CritereDeTriDeChapitres
    public var ordre: OrdreDeTri

    public init(
        filtre: FiltreDeChapitres = .tous,
        critere: CritereDeTriDeChapitres = .numero,
        ordre: OrdreDeTri = .decroissant
    ) {
        self.filtre = filtre
        self.critere = critere
        self.ordre = ordre
    }

    /// Reglage applique tant que l utilisateur n a rien choisi pour cette serie.
    ///
    /// Le wireframe 04 dessine la liste du chapitre 43 vers le chapitre 40,
    /// donc du plus recent au plus ancien, sans filtre.
    public static let defaut = ReglageDeListeDeChapitres()

    /// Chapitres filtres puis ordonnes.
    ///
    /// Le tri est total : deux chapitres ne peuvent jamais se retrouver dans un
    /// ordre different d une lecture a l autre, meme s ils portent le meme
    /// numero ou la meme date. Le rang dans la serie tranche en dernier ressort,
    /// et il est unique.
    public func appliquer(a chapitres: [ChapitreDeFiche]) -> [ChapitreDeFiche] {
        chapitres
            .filter(filtre.retient)
            .sorted { premier, second in
                let croissant = precede(premier, second)
                return ordre.estCroissant ? croissant : !croissant
            }
    }

    /// Vrai quand le premier chapitre precede le second en ordre croissant.
    private func precede(_ premier: ChapitreDeFiche, _ second: ChapitreDeFiche) -> Bool {
        switch critere {
        case .numero:
            if premier.numero != second.numero {
                return premier.numero < second.numero
            }

        case .datePublication:
            // Un chapitre sans date de publication se range avant les autres en
            // ordre croissant, donc en fin de liste dans l ordre par defaut. La
            // source ne dit pas quand il est paru, elle ne dit pas non plus
            // qu il est recent.
            switch (premier.datePublication, second.datePublication) {
            case let (.some(gauche), .some(droite)) where gauche != droite:
                return gauche < droite
            case (.none, .some):
                return true
            case (.some, .none):
                return false
            default:
                break
            }
        }

        return premier.ordreDansSerie < second.ordreDansSerie
    }
}
