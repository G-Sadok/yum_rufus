import Foundation

//
// MagasinDeJetonDuPont
//
// Ou vit le jeton du pont navigateur, et les trois seules choses qu on lui
// fait : le lire, le remplacer, le revoquer.
//
// Le protocole est distinct de `MagasinDIdentifiants` et de
// `MagasinDeJetonsDeSuivi` pour la raison qui les separait deja l un de
// l autre : la cle. Il n existe qu un pont, donc qu une ligne, et la faire
// passer par un identifiant de source obligerait a inventer un UUID stable et
// a le persister ailleurs. La ligne est rangee sous un service de trousseau qui
// lui est propre, pour qu une purge des sources ou une deconnexion des suivis
// ne revoque pas le pont, et reciproquement.
//
// La revocation est immediate parce qu elle passe par ici et nulle part
// ailleurs. Le serveur relit le magasin a chaque requete et ne garde jamais de
// copie du jeton : effacer la ligne suffit donc a faire refuser la requete
// suivante, sans redemarrage, sans expiration a attendre, et sans qu une
// connexion deja ouverte continue d etre servie.
//

/// Ou vit le jeton du pont navigateur.
///
/// L implementation livree est `TrousseauDuPont`. Les tests en fournissent une
/// autre, en memoire, parce qu un binaire de test non signe ne dispose d aucun
/// droit de trousseau.
public protocol MagasinDeJetonDuPont: Sendable {
    /// Relit le jeton, ou nul quand le pont n en a pas.
    ///
    /// L absence de jeton est un etat normal, celui d un pont jamais active ou
    /// dont le jeton vient d etre revoque, et non une erreur.
    func jeton() async throws -> JetonDuPont?

    /// Range le jeton, en remplacant celui qui y etait.
    func enregistrer(_ jeton: JetonDuPont) async throws

    /// Efface le jeton.
    ///
    /// Ne leve pas quand il n y en avait pas : la revocation est idempotente, et
    /// la desactivation du pont l appelle sans savoir si un jeton avait ete
    /// tire.
    func revoquer() async throws
}

extension MagasinDeJetonDuPont {
    /// Tire un jeton neuf, le range, et le rend.
    ///
    /// Le precedent cesse d etre reconnu par le meme mouvement : il n y a qu une
    /// ligne, et elle est remplacee. C est la forme que prend le renouvellement
    /// depuis les reglages, ou l utilisateur qui soupconne une fuite veut un
    /// jeton neuf sans avoir a desactiver puis reactiver le pont.
    @discardableResult
    public func renouveler() async throws -> JetonDuPont {
        let neuf = JetonDuPont.tire()

        try await enregistrer(neuf)

        return neuf
    }

    /// Rend le jeton en place, ou en tire un et le range s il n y en a pas.
    ///
    /// Sert a l activation du pont : un pont actif a toujours un jeton, sans
    /// quoi aucune extension ne pourrait s y annoncer, et un pont reactive
    /// garde celui deja colle dans l extension.
    @discardableResult
    public func jetonOuNouveau() async throws -> JetonDuPont {
        if let existant = try await jeton() {
            return existant
        }

        return try await renouveler()
    }
}

/// Range le jeton du pont dans le trousseau du systeme.
///
/// Une ligne de classe mot de passe generique, accessible apres premier
/// deverrouillage, comme l impose la section 11. La charge rangee est
/// `IdentifiantsDeSource.jeton`, reutilisee telle quelle : elle est deja privee
/// de `Codable`, deja caviardee a l affichage, et deja ecrite et relue par
/// `LigneDeTrousseau`.
public struct TrousseauDuPont: MagasinDeJetonDuPont {
    /// Cle de la ligne dans le service du pont.
    ///
    /// Elle est constante parce qu il n existe qu un pont. La nommer plutot que
    /// laisser la ligne sans compte evite qu une future seconde ligne dans le
    /// meme service la recouvre.
    static let cle = "pont.navigateur"

    private let requetes: RequeteDeTrousseau

    public init(requetes: RequeteDeTrousseau = RequeteDeTrousseau(service: RequeteDeTrousseau.serviceDuPont)) {
        self.requetes = requetes
    }

    public func jeton() throws -> JetonDuPont? {
        guard case let .jeton(acces, _, _) = try ligne().lire() else {
            return nil
        }

        return JetonDuPont(acces)
    }

    public func enregistrer(_ jeton: JetonDuPont) throws {
        try ligne().ecrire(.jeton(acces: jeton.valeur))
    }

    public func revoquer() throws {
        try ligne().effacer()
    }

    private func ligne() -> LigneDeTrousseau {
        LigneDeTrousseau(requetes: requetes, cle: Self.cle)
    }
}

/// Jeton volatil, pour les tests et les apercus.
///
/// Rien de ce qui y est ecrit ne survit au processus, pour la meme raison que
/// `MagasinDeJetonsDeSuiviEnMemoire` : un binaire de test lance par SwiftPM
/// n est pas signe et ne porte aucun droit de trousseau.
public actor MagasinDeJetonDuPontEnMemoire: MagasinDeJetonDuPont {
    private var range: JetonDuPont?

    /// Nombre de revocations vues, pour les verifications.
    public private(set) var revocations = 0

    public init(jeton: JetonDuPont? = nil) {
        range = jeton
    }

    public func jeton() -> JetonDuPont? {
        range
    }

    public func enregistrer(_ jeton: JetonDuPont) {
        range = jeton
    }

    public func revoquer() {
        range = nil
        revocations += 1
    }
}
