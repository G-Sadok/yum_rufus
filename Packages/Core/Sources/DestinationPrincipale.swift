//
// DestinationPrincipale
//
// Les cinq destinations de la navigation principale. L ordre est celui de
// `allCases`, et il est impose par la section 2.2 de DESIGN-SPEC.md. Aucune vue
// ne redefinit cet ordre de son cote, sous peine de le voir diverger d un
// gabarit a l autre.
//

/// Une des cinq destinations de la navigation principale.
///
/// La destination est une donnee du domaine, pas un detail de la couche vue :
/// la barre laterale de macOS, la barre laterale repliee d iPad portrait et la
/// barre d onglets d iPhone presentent toutes les trois la meme liste, dans le
/// meme ordre.
public enum DestinationPrincipale: String, CaseIterable, Sendable, Codable, Hashable {
    /// Grille des series suivies.
    case bibliotheque
    /// Chapitres lus, regroupes par jour.
    case historique
    /// Sources installees et catalogues.
    case parcourir
    /// Recherche dans toutes les sources installees.
    case rechercher
    /// Reglages de l application.
    case reglages

    /// Destination ouverte au lancement.
    public static let defaut = DestinationPrincipale.bibliotheque

    /// Rang de l entree dans la navigation, de 1 a 5.
    ///
    /// Le rang sert au raccourci clavier de la destination, et a rien d autre.
    public var rang: Int {
        (Self.allCases.firstIndex(of: self) ?? 0) + 1
    }

    /// Destination qui suit, ou `nil` sur la derniere.
    ///
    /// La navigation par fleches ne boucle pas : arrivee sur Reglages, la
    /// fleche vers le bas ne renvoie pas sur Bibliotheque, comme dans toute
    /// liste du systeme.
    public var suivante: DestinationPrincipale? {
        Self.allCases.first { $0.rang == rang + 1 }
    }

    /// Destination qui precede, ou `nil` sur la premiere.
    public var precedente: DestinationPrincipale? {
        Self.allCases.first { $0.rang == rang - 1 }
    }
}
