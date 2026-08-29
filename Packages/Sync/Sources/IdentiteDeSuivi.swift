import Core
import Foundation
import Sources

//
// IdentiteDeSuivi
//
// La preuve d identite des requetes d un service de suivi, et son
// renouvellement.
//
// Elle se pose sur `IdentiteHttp`, le protocole ecrit pour Kavita, parce que le
// probleme est exactement le meme : un jeton qui expire au milieu d une
// operation, et dix requetes qui se font refuser ensemble. Le parametre
// `apres` du renouvellement fait la difference. La premiere requete refusee
// renouvelle, les neuf autres constatent que la preuve courante n est deja plus
// celle qu on leur a refusee et reprennent la nouvelle.
//
// Le jeton n est pas garde en memoire par cet objet. Il est relu du trousseau a
// chaque preuve demandee. C est un peu plus cher et beaucoup plus sur : le
// trousseau reste la seule verite, et une deconnexion faite ailleurs prend
// effet immediatement au lieu d attendre que le cache soit invalide.
//

/// Preuve d identite d un service de suivi, avec renouvellement.
actor IdentiteDeSuivi: IdentiteHttp {
    /// Marge appliquee a l echeance avant de considerer un jeton perime.
    ///
    /// La requete part apres la verification, pas pendant. Sans marge, un jeton
    /// valable une demi seconde passerait le controle et se ferait refuser sur
    /// le fil.
    static let marge: TimeInterval = 30

    private let service: ServiceDeSuivi
    private let magasin: any MagasinDeJetonsDeSuivi
    private let configuration: ConfigurationDesSuivis
    private let echange: EchangeDeJeton
    private let maintenant: @Sendable () -> Date

    init(
        service: ServiceDeSuivi,
        magasin: any MagasinDeJetonsDeSuivi,
        configuration: ConfigurationDesSuivis,
        echange: EchangeDeJeton,
        maintenant: @escaping @Sendable () -> Date
    ) {
        self.service = service
        self.magasin = magasin
        self.configuration = configuration
        self.echange = echange
        self.maintenant = maintenant
    }

    func entete() async throws -> EnteteDIdentite? {
        let identifiants = try await magasin.identifiants(pour: service)

        guard case let .jeton(acces, rafraichissement, expiration) = identifiants else {
            return nil
        }

        guard estPerime(expiration) else {
            return Self.entete(pour: acces)
        }

        guard let rafraichissement, let renouveles = try? await rafraichir(avec: rafraichissement) else {
            // Le jeton est perime et ne peut pas etre renouvele. Il part quand
            // meme : le service tranche mieux que notre horloge, et son refus
            // produit une erreur nommee plutot qu une requete jamais envoyee.
            return Self.entete(pour: acces)
        }

        return renouveles
    }

    func renouveler(apres refusee: EnteteDIdentite?) async -> EnteteDIdentite? {
        let identifiants = try? await magasin.identifiants(pour: service)

        guard case let .jeton(acces, rafraichissement, _) = identifiants else {
            return nil
        }

        // Une autre tache a deja renouvele pendant que celle ci attendait.
        if let refusee, Self.entete(pour: acces) != refusee {
            return Self.entete(pour: acces)
        }

        guard let rafraichissement else {
            return nil
        }

        return try? await rafraichir(avec: rafraichissement)
    }

    /// Echange le jeton de rafraichissement contre un jeton neuf, et le range.
    private func rafraichir(avec jetonDeRafraichissement: String) async throws -> EnteteDIdentite {
        let champs = try AutorisationOAuth.champsDeRafraichissement(
            pour: service,
            jetonDeRafraichissement: jetonDeRafraichissement,
            configuration: configuration
        )

        let renouveles = try await echange.executer(champs: champs)

        guard case let .jeton(acces, _, _) = renouveles else {
            throw ErreurDeSuivi.reponseIllisible(service: service)
        }

        try await magasin.enregistrer(renouveles, pour: service)

        return Self.entete(pour: acces)
    }

    /// Vrai quand l echeance est passee, marge comprise.
    ///
    /// Un jeton sans echeance n est jamais declare perime : le service ne
    /// publie rien, et le supposer expire ferait une requete de renouvellement
    /// avant chaque appel.
    private func estPerime(_ expiration: Date?) -> Bool {
        guard let expiration else {
            return false
        }

        return expiration.timeIntervalSince(maintenant()) <= Self.marge
    }

    /// Entete que porte un jeton d acces.
    ///
    /// Les quatre services attendent la meme forme, y compris celui qui ne
    /// passe pas par OAuth : son jeton de session se presente aussi en porteur.
    static func entete(pour acces: String) -> EnteteDIdentite {
        EnteteDIdentite(nom: "Authorization", valeur: "Bearer " + acces)
    }
}
