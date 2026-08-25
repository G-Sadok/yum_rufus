import Foundation

//
// MagasinDIdentifiants
//
// Le contrat par lequel toute authentification de source passe. Une source qui
// a besoin de prouver qui elle est demande ses identifiants ici, et nulle part
// ailleurs.
//
// Le protocole vit dans Core, a cote de `SourceProvider`, pour la meme raison
// que lui : la couche vue, la bibliotheque et les implementations de sources en
// ont toutes besoin, et aucune ne doit dependre des autres pour cela.
//
// Il est asynchrone parce que la lecture du trousseau peut bloquer. Elle est
// rapide sur un appareil deverrouille, elle ne l est pas quand le systeme
// decide de demander confirmation.
//

/// Ou vivent les identifiants des sources.
///
/// L implementation livree est `TrousseauDuSysteme`. Les tests en fournissent
/// une autre, en memoire, parce qu un binaire de test non signe ne dispose
/// d aucun droit de trousseau.
public protocol MagasinDIdentifiants: Sendable {
    /// Range les identifiants d une source, en remplacant ceux qui y etaient.
    ///
    /// Enregistrer `IdentifiantsDeSource.aucun` efface la ligne : une source qui
    /// cesse de demander une authentification ne doit pas laisser derriere elle
    /// un mot de passe que plus rien ne lit.
    func enregistrer(_ identifiants: IdentifiantsDeSource, pour source: SourceID) async throws

    /// Relit les identifiants d une source.
    ///
    /// Rend `IdentifiantsDeSource.aucun` quand la source n en a pas : une source
    /// sans identifiants est un etat normal, pas une erreur.
    func identifiants(pour source: SourceID) async throws -> IdentifiantsDeSource

    /// Efface les identifiants d une source.
    ///
    /// Ne leve pas quand il n y en avait pas. La suppression est idempotente,
    /// parce que l appelant qui purge une source disparue ne sait pas, et n a
    /// pas a savoir, si elle avait ete configuree avec un mot de passe.
    func supprimer(pour source: SourceID) async throws
}
