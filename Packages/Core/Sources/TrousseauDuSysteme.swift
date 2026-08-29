//
// TrousseauDuSysteme
//
// La seule implementation livree de `MagasinDIdentifiants`. Toutes les
// authentifications de source passent par elle.
//
// Elle vit dans Core et non dans Sources, alors que Core est le paquet sans
// dependance. Security est un framework du systeme, present sur les deux
// plateformes cibles, et non un paquet tiers : la regle de la section 2.3
// porte sur les dependances de paquet, elle n est donc pas entamee. La ranger
// dans Sources aurait un cout reel : la couche vue, qui presente la feuille de
// configuration, et la couche de sauvegarde, qui purge une source supprimee,
// devraient toutes deux dependre des implementations de sources pour atteindre
// le trousseau, ce que le protocole existe precisement pour eviter.
//
// Les fonctions SecItem sont synchrones et sures vis a vis des fils
// d execution. Elles satisfont telles quelles les exigences asynchrones du
// protocole, sans acteur intermediaire : ajouter un acteur serialiserait des
// lectures que le systeme sait deja mener de front.
//

/// Range les identifiants des sources dans le trousseau du systeme.
///
/// Chaque source occupe une ligne de classe mot de passe generique, accessible
/// apres premier deverrouillage, comme l impose la section 11.
public struct TrousseauDuSysteme: MagasinDIdentifiants {
    private let requetes: RequeteDeTrousseau

    public init(requetes: RequeteDeTrousseau = RequeteDeTrousseau()) {
        self.requetes = requetes
    }

    public func enregistrer(_ identifiants: IdentifiantsDeSource, pour source: SourceID) throws {
        try ligne(de: source).ecrire(identifiants)
    }

    public func identifiants(pour source: SourceID) throws -> IdentifiantsDeSource {
        try ligne(de: source).lire()
    }

    public func supprimer(pour source: SourceID) throws {
        try ligne(de: source).effacer()
    }

    /// Ligne du trousseau ou vit cette source.
    ///
    /// Les trois methodes du protocole ne font plus que designer la ligne :
    /// l ordre entre mise a jour et creation, la politique d accessibilite et
    /// le traitement d une ligne absente vivent dans `LigneDeTrousseau`, qui
    /// les partage avec les jetons des services de suivi.
    private func ligne(de source: SourceID) -> LigneDeTrousseau {
        LigneDeTrousseau(requetes: requetes, cle: source.brut.uuidString)
    }
}
