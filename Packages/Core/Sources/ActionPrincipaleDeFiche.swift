import Foundation

//
// ActionPrincipaleDeFiche
//
// Bouton principal de la fiche de serie, tableau des libelles de la section 5.6
// de DESIGN-SPEC.md.
//
// Le libelle ne se choisit pas dans la vue. Il decoule de l etat de lecture de
// la serie, qui est une lecture de la base, et c est ce calcul qui vit ici.
// La vue se contente de demander quel cas s applique, puis de prendre le
// libelle correspondant dans le catalogue de chaines.
//

/// Ce que le bouton principal de la fiche propose de faire, section 5.6.
public enum ActionPrincipaleDeFiche: Sendable, Equatable, Hashable {
    /// Aucun chapitre lu. Libelle `Commencer la lecture`.
    case commencerLaLecture(chapitre: UUID)

    /// Lecture en cours. Libelle `Reprendre ch. N`.
    case reprendre(chapitre: UUID, numero: Double)

    /// Tous les chapitres lus. Libelle `Tout est lu`.
    ///
    /// Le document ne desactive pas ce cas, contrairement au suivant. Le bouton
    /// reste donc actif et rouvre la serie a son premier chapitre : une serie
    /// entierement lue se relit, et un bouton principal inerte au milieu d une
    /// fiche complete serait une impasse.
    case toutEstLu(chapitre: UUID)

    /// Aucun chapitre expose par la source. Libelle `Aucun chapitre`, bouton
    /// desactive.
    case aucunChapitre

    /// Vrai quand le bouton accepte le clic.
    ///
    /// Seul `aucunChapitre` est desactive, c est le seul cas que la section 5.6
    /// marque ainsi.
    public var estActive: Bool {
        self != .aucunChapitre
    }

    /// Chapitre que le bouton ouvre, nul quand il n y a rien a ouvrir.
    public var chapitreAOuvrir: UUID? {
        switch self {
        case let .commencerLaLecture(chapitre): chapitre
        case let .reprendre(chapitre, _): chapitre
        case let .toutEstLu(chapitre): chapitre
        case .aucunChapitre: nil
        }
    }

    /// Numero affiche par le libelle `Reprendre ch. N`, nul pour les autres cas.
    public var numeroAffiche: Double? {
        guard case let .reprendre(_, numero) = self else { return nil }
        return numero
    }

    /// Action deduite de l etat de lecture de la serie.
    ///
    /// L ordre des cas suit celui du tableau de la section 5.6. Le chapitre
    /// repris est celui que l utilisateur a laisse ouvert le plus recemment,
    /// et a defaut le premier chapitre qui lui reste a lire.
    ///
    /// - Parameter chapitres: tous les chapitres de la serie, filtre non
    ///   applique. Un filtre de liste ne change pas ce que la serie propose de
    ///   lire.
    public static func pour(chapitres: [ChapitreDeFiche]) -> ActionPrincipaleDeFiche {
        let parOrdre = chapitres.sorted { $0.ordreDansSerie < $1.ordreDansSerie }

        guard let premier = parOrdre.first else {
            return .aucunChapitre
        }

        guard let premierNonLu = parOrdre.first(where: { !$0.estLu }) else {
            return .toutEstLu(chapitre: premier.id)
        }

        if let repris = chapitreRepris(parmi: parOrdre) {
            return .reprendre(chapitre: repris.id, numero: repris.numero)
        }

        let aucuneLecture = parOrdre.allSatisfy { $0.lecture == .nonLu }

        return aucuneLecture
            ? .commencerLaLecture(chapitre: premierNonLu.id)
            : .reprendre(chapitre: premierNonLu.id, numero: premierNonLu.numero)
    }

    /// Chapitre ouvert et non termine le plus recemment lu.
    ///
    /// Les chapitres sans date de lecture perdent contre ceux qui en portent
    /// une. Deux chapitres sans date sont departages par leur rang, pour que la
    /// reprise ne saute pas d un chapitre a l autre entre deux lancements.
    private static func chapitreRepris(parmi chapitres: [ChapitreDeFiche]) -> ChapitreDeFiche? {
        let enCours = chapitres.filter { $0.lecture == .enCours }

        guard !enCours.isEmpty else { return nil }

        return enCours.max { premier, second in
            switch (premier.dateLecture, second.dateLecture) {
            case let (.some(gauche), .some(droite)):
                gauche < droite
            case (.none, .some):
                true
            case (.some, .none):
                false
            case (.none, .none):
                premier.ordreDansSerie > second.ordreDansSerie
            }
        }
    }
}
