import Core
import Foundation

//
// SessionKavita
//
// Ce qui tient le jeton d une source Kavita et le renouvelle avant que le
// serveur ne le refuse. C est le coeur de la fonctionnalite, et la seule partie
// dont la correction ne se voit pas a la lecture d une trace reseau reussie.
//
// Trois choses s y jouent, et il faut les trois pour qu une lecture ne
// s interrompe pas.
//
// La premiere est l anticipation. L echeance est lue dans le jeton, et un jeton
// trop proche de la sienne est renouvele avant de partir plutot qu apres avoir
// ete refuse. C est ce qui evite qu une tourne de page paie un aller retour
// perdu toutes les quinze minutes.
//
// La deuxieme est l unicite. Une lecture precharge plusieurs pages a la fois.
// Si le jeton expire pendant ce paquet, toutes les requetes le decouvrent en
// meme temps. Le renouvellement est donc porte par une tache unique retenue
// dans l acteur : la premiere qui arrive la cree, les suivantes l attendent, et
// une seule connexion part. Sans cela le serveur recevrait dix connexions
// simultanees pour le meme compte, et Kavita en refuse une partie.
//
// La troisieme est le repli. Un jeton de rafraichissement expire lui aussi. La
// session tente donc le rafraichissement, et se reconnecte avec ce que le
// trousseau porte quand il echoue. Sans ce repli, une application laissee de
// cote quelques semaines demanderait a l utilisateur de ressaisir son mot de
// passe alors qu il est deja range.
//
// Ce qui est ecrit dans le trousseau merite d etre dit. La session n y ecrit un
// jeton que quand elle en a lu un, jamais quand elle a lu un compte et un mot
// de passe. `IdentifiantsDeSource` est une enumeration fermee : y ranger le
// jeton effacerait le mot de passe, et le jour ou le rafraichissement cesse de
// valoir plus rien ne permettrait de se reconnecter. Une connexion de plus au
// lancement coute une requete, la perte du mot de passe coute une ressaisie.
//

/// Le jeton d une source Kavita, tenu a jour pour toutes ses requetes.
actor SessionKavita: IdentiteHttp {
    /// Duree pendant laquelle un jeton encore valable est deja considere perime.
    ///
    /// Trente secondes couvrent largement l aller retour d une requete et un
    /// decalage d horloge modeste entre l appareil et le serveur.
    static let margeAvantExpiration: TimeInterval = 30

    private let id: SourceID
    private let base: URL
    private let magasin: any MagasinDIdentifiants
    private let transport: any TransportHttp
    private let accepteLeHttpEnClair: Bool
    private let maintenant: @Sendable () -> Date

    private var jeton: JetonKavita?
    private var identifiantsRetenus: IdentifiantsDeSource?
    private var renouvellementEnCours: Task<JetonKavita, any Error>?

    /// La preuve que le serveur vient de refuser.
    ///
    /// Elle est retenue pour que le jeton range dans le trousseau ne soit pas
    /// represente apres avoir ete refuse. Sans elle, un jeton sans echeance
    /// lisible serait repris a chaque tentative, et la session tournerait entre
    /// le meme refus et la meme reprise.
    private var enteteRefusee: EnteteDIdentite?

    init(
        id: SourceID,
        base: URL,
        magasin: any MagasinDIdentifiants,
        transport: any TransportHttp,
        accepteLeHttpEnClair: Bool,
        maintenant: @escaping @Sendable () -> Date
    ) {
        self.id = id
        self.base = base
        self.magasin = magasin
        self.transport = transport
        self.accepteLeHttpEnClair = accepteLeHttpEnClair
        self.maintenant = maintenant
    }

    // MARK: Identite

    func entete() async throws -> EnteteDIdentite? {
        try await jetonUtilisable().entete
    }

    func renouveler(apres refusee: EnteteDIdentite?) async -> EnteteDIdentite? {
        if let jeton, jeton.entete != refusee, jeton.estUtilisable(a: maintenant(), marge: 0) {
            // Une autre tache a deja renouvele pendant que celle ci attendait
            // sa reponse. Repartir avec le jeton en place suffit, et refaire
            // une connexion pour la meme expiration ferait exactement ce que le
            // serveur compte comme une rafale.
            return jeton.entete
        }

        enteteRefusee = refusee
        jeton = nil

        return try? await jetonUtilisable().entete
    }

    // MARK: Etat

    /// La cle d API du compte, quand la session en connait une.
    ///
    /// Simple lecture : elle ne declenche aucune connexion. Une adresse
    /// d image demandee avant la premiere requete authentifiee partirait donc
    /// sans cle, ce qui n arrive pas dans l ordre reel des appels, ou la liste
    /// des pages precede toujours leur affichage.
    func cleDApi() -> String? {
        jeton?.cleDApi
    }

    /// Oublie le jeton et les identifiants retenus.
    ///
    /// A appeler quand l utilisateur enregistre une nouvelle configuration,
    /// sans quoi la session continuerait a presenter le jeton de l ancien
    /// compte jusqu au prochain lancement.
    func oublier() {
        jeton = nil
        identifiantsRetenus = nil
        enteteRefusee = nil
    }

    // MARK: Obtention du jeton

    /// Le jeton courant, renouvele quand il approche de son echeance.
    private func jetonUtilisable() async throws -> JetonKavita {
        if let jeton, jeton.estUtilisable(a: maintenant(), marge: Self.margeAvantExpiration) {
            return jeton
        }

        return try await renouvellementUnique()
    }

    /// Lance un renouvellement, ou rejoint celui qui est deja en cours.
    private func renouvellementUnique() async throws -> JetonKavita {
        if let renouvellementEnCours {
            return try await renouvellementEnCours.value
        }

        let tache = Task { try await self.produire() }
        renouvellementEnCours = tache

        defer { renouvellementEnCours = nil }

        return try await tache.value
    }

    /// Fabrique un jeton utilisable, par adoption, rafraichissement ou connexion.
    private func produire() async throws -> JetonKavita {
        let ranges = try await identifiants()

        if let adopte = jetonRange(ranges) {
            return adopte
        }
        if let rafraichi = try await parRafraichissement(depuis: ranges) {
            return await retenir(rafraichi, forme: ranges)
        }

        return try await retenir(parConnexion(depuis: ranges), forme: ranges)
    }

    /// Le jeton du trousseau, quand il vaut encore et n a pas ete refuse.
    ///
    /// L adoption evite un aller retour a chaque lancement : un jeton range
    /// hier et valable une heure vaut encore, et le rafraichir sans raison
    /// ferait tourner le jeton de rafraichissement pour rien. Elle n a pas lieu
    /// quand le serveur vient de refuser exactement ce jeton la, sans quoi la
    /// session le representerait indefiniment.
    private func jetonRange(_ identifiants: IdentifiantsDeSource) -> JetonKavita? {
        guard
            let range = JetonKavita(identifiants),
            range.entete != enteteRefusee,
            range.estUtilisable(a: maintenant(), marge: Self.margeAvantExpiration)
        else {
            return nil
        }

        jeton = range

        return range
    }

    /// Rafraichit le jeton en place, ou rend nul quand ce n est pas possible.
    ///
    /// Un echec du rafraichissement n est pas remonte : un jeton de
    /// rafraichissement perime est le cas normal apres une longue absence, et
    /// la sortie est la reconnexion, pas un message d erreur. Seule
    /// l annulation traverse, parce qu elle ne dit rien sur le jeton.
    private func parRafraichissement(depuis ranges: IdentifiantsDeSource) async throws -> JetonKavita? {
        guard
            let courant = jeton ?? JetonKavita(ranges),
            let rafraichissement = courant.rafraichissement
        else {
            return nil
        }

        let charge = try JSONEncoder().encode(
            DemandeDeRafraichissementKavita(token: courant.acces, refreshToken: rafraichissement)
        )

        do {
            let reponse = try await clientDAuthentification().lire(
                JetonDeKavita.self,
                chemin: CheminsKavita.rafraichissement,
                methode: .post,
                corpsJson: charge
            )

            return try JetonKavita(reponse, cleDApi: courant.cleDApi)
        } catch {
            try Task.checkCancellation()

            return nil
        }
    }

    /// Ouvre une session neuve avec ce que le trousseau porte.
    private func parConnexion(depuis ranges: IdentifiantsDeSource) async throws -> JetonKavita {
        let client = try clientDAuthentification()

        switch ranges {
        case let .basique(compte, motDePasse):
            let charge = try JSONEncoder().encode(
                DemandeDeConnexionKavita(username: compte, password: motDePasse)
            )
            let reponse = try await client.lire(
                JetonDeKavita.self,
                chemin: CheminsKavita.connexion,
                methode: .post,
                corpsJson: charge
            )

            return try JetonKavita(reponse, cleDApi: nil)
        case let .cleDApi(cle):
            let reponse = try await client.lire(
                JetonDeKavita.self,
                chemin: CheminsKavita.authentificationParCle,
                parametres: ParametresKavita.authentificationParCle(cle),
                methode: .post
            )

            return try JetonKavita(reponse, cleDApi: cle)
        case .jeton, .aucun:
            // Un jeton sans rafraichissement valable ne se repare pas ici : le
            // serveur n en emet un que contre un mot de passe ou une cle, et
            // Kavita ne sert rien a un client anonyme. La sortie est la feuille
            // de configuration, et c est ce que ce refus la ouvre.
            throw ErreurReseau.authentificationRefusee
        }
    }

    /// Retient le jeton, et le range dans le trousseau quand c est sa place.
    ///
    /// L ecriture est faite sans propager son echec : un trousseau qui refuse
    /// l ecriture ne doit pas interrompre la lecture en cours. La session garde
    /// alors le jeton en memoire, et le prochain lancement se reconnectera.
    private func retenir(_ neuf: JetonKavita, forme ranges: IdentifiantsDeSource) async -> JetonKavita {
        jeton = neuf

        guard case .jeton = ranges else {
            return neuf
        }

        identifiantsRetenus = neuf.identifiants
        try? await magasin.enregistrer(neuf.identifiants, pour: id)

        return neuf
    }

    // MARK: Trousseau et transport

    /// Les identifiants de la source, lus une fois puis retenus.
    ///
    /// Un refus du trousseau devient un refus d identifiants : les deux se
    /// reparent au meme endroit, la feuille de configuration, et remonter le
    /// code brut du systeme donnerait un echec que rien ne sait traiter.
    private func identifiants() async throws -> IdentifiantsDeSource {
        if let identifiantsRetenus {
            return identifiantsRetenus
        }

        do {
            let lus = try await magasin.identifiants(pour: id)
            identifiantsRetenus = lus

            return lus
        } catch {
            throw ErreurReseau.authentificationRefusee
        }
    }

    /// Le client des points d entree d authentification.
    ///
    /// Il est distinct de celui de la source et ne porte aucune identite, ce
    /// qui n est pas un raccourci : la connexion et le rafraichissement portent
    /// leur preuve dans leur corps, et leur donner cette session comme identite
    /// ferait qu obtenir un jeton demanderait d en avoir deja un.
    private func clientDAuthentification() throws -> ClientHttp {
        try ClientHttp(
            base: base,
            transport: transport,
            authentification: .aucune,
            accepteLeHttpEnClair: accepteLeHttpEnClair,
            maintenant: maintenant
        )
    }
}
