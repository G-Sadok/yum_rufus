import Core
import Foundation
import Sources

//
// RegistreDesSuivis
//
// Le point unique par lequel l application parle aux services de suivi.
//
// Il existe pour la meme raison que le registre de sources : sans lui, chaque
// ecran connaitrait les quatre clients, et la question de savoir si une
// progression a le droit de partir serait posee a quatre endroits, donc oubliee
// au moins une fois. Ici elle est posee une fois, avant tout appel, et la
// reponse est une valeur nommee que l appelant peut afficher.
//
// L ordre entre la decision et l appel est la garantie du troisieme critere. La
// decision est prise avant que quoi que ce soit ne parte, et un refus rend la
// main sans avoir ouvert la moindre connexion. Un test peut donc verifier que
// le transport n a rien vu, ce qui est une preuve, la ou une verification de
// l absence d effet visible n en serait pas une.
//

/// Ce qu une tentative de synchronisation a produit.
public struct ResultatDeSynchronisation: Sendable, Equatable {
    /// Ce que la regle a decide.
    public let decision: DecisionDeSynchronisation

    /// Liaison mise a jour, nulle quand rien n est parti.
    public let liaison: LiaisonSuivi?

    public init(decision: DecisionDeSynchronisation, liaison: LiaisonSuivi? = nil) {
        self.decision = decision
        self.liaison = liaison
    }
}

/// Les quatre services de suivi, et la regle qui decide de ce qui part.
public actor RegistreDesSuivis {
    private let clients: [ServiceDeSuivi: ClientDeSuivi]
    private let incognito: RegistreDIncognito
    private let maintenant: @Sendable () -> Date
    private var etats = EtatDesSuivis.aucun

    /// Construit le registre sur les clients fournis.
    ///
    /// Les clients sont injectes plutot que fabriques ici. La fabrique demande
    /// un transport, une configuration et un magasin de jetons, trois choses
    /// que la couche applicative assemble deja pour les sources, et qu un
    /// registre qui les redemanderait dupliquerait.
    public init(
        clients: [ClientDeSuivi],
        incognito: RegistreDIncognito,
        maintenant: @escaping @Sendable () -> Date = Date.init
    ) {
        self.clients = Dictionary(
            clients.map { ($0.service, $0) },
            uniquingKeysWith: { premier, _ in premier }
        )
        self.incognito = incognito
        self.maintenant = maintenant
    }

    /// Etat de connexion des quatre services, sans rien demander au reseau.
    public var etatDesServices: EtatDesSuivis {
        etats
    }

    /// Redemande a chaque service connecte quel compte il ouvre.
    ///
    /// Appele au lancement. Un service qui refuse passe en expire au lieu de
    /// faire echouer les trois autres : une session morte chez l un ne dit rien
    /// des autres.
    @discardableResult
    public func rafraichir() async -> EtatDesSuivis {
        for service in ServiceDeSuivi.allCases {
            guard let client = clients[service] else {
                continue
            }

            await appliquer(client.rafraichirLEtat(), a: service)
        }

        return etats
    }

    // MARK: Connexion

    /// Prepare la demande d autorisation d un service.
    public nonisolated func demandeDAutorisation(
        pour service: ServiceDeSuivi,
        configuration: ConfigurationDesSuivis,
        tirage: TirageAleatoire = TirageAleatoireDuSysteme()
    ) throws -> DemandeDAutorisation {
        try AutorisationOAuth.demande(pour: service, configuration: configuration, tirage: tirage)
    }

    /// Termine une connexion OAuth au retour du navigateur.
    @discardableResult
    public func connecter(
        _ service: ServiceDeSuivi,
        redirection: URL,
        pour demande: DemandeDAutorisation
    ) async throws -> CompteDeSuivi {
        let client = try exiger(service)
        let compte = try await client.connecter(redirection: redirection, pour: demande)
        etats.connecter(service, compte: compte)

        return compte
    }

    /// Connecte le service qui demande un compte et un mot de passe.
    @discardableResult
    public func connecter(
        _ service: ServiceDeSuivi,
        compte: String,
        motDePasse: String
    ) async throws -> CompteDeSuivi {
        let client = try exiger(service)
        let connecte = try await client.connecter(compte: compte, motDePasse: motDePasse)
        etats.connecter(service, compte: connecte)

        return connecte
    }

    /// Deconnecte un service et efface son jeton.
    public func deconnecter(_ service: ServiceDeSuivi) async throws {
        try await exiger(service).deconnecter()
        etats.deconnecter(service)
    }

    /// Deconnecte les quatre services.
    ///
    /// Sert a la remise a zero de l application. La boucle passe par tous les
    /// services et non par les seuls services connectes : un jeton range sans
    /// que l etat en memoire le sache doit disparaitre lui aussi.
    public func deconnecterTout() async throws {
        for service in ServiceDeSuivi.allCases where clients[service] != nil {
            try await deconnecter(service)
        }
    }

    // MARK: Liaison

    /// Propose des entrees de ce service pour une serie de la bibliotheque.
    ///
    /// La proposition classe et dit si elle est sure d elle. Elle ne pose rien :
    /// c est `lier(_:vers:aupresDe:)` qui pose, avec l entree que l appelant a
    /// retenue, proposee ou corrigee a la main.
    public func proposerUneLiaison(
        pourTitre titre: String,
        annee: Int? = nil,
        aupresDe service: ServiceDeSuivi
    ) async throws -> PropositionDeLiaison {
        let entrees = try await exiger(service).rechercher(titre)

        return CorrespondanceDeSuivi.proposer(pourTitre: titre, annee: annee, parmi: entrees)
    }

    /// Pose la liaison d une serie vers l entree choisie.
    ///
    /// L entree n a pas a venir de la proposition. C est la correction manuelle
    /// du deuxieme critere : l utilisateur peut avoir cherche lui meme, avec un
    /// autre titre, et retenu une entree que la proposition n avait pas vue.
    public nonisolated func lier(
        _ mangaId: UUID,
        vers entree: SerieDeSuivi,
        aupresDe service: ServiceDeSuivi,
        statut: StatutDeSuivi = .enLecture,
        chapitreVu: Double = 0
    ) -> LiaisonSuivi {
        CorrespondanceDeSuivi.liaison(
            pour: mangaId,
            service: service,
            vers: entree,
            statut: statut,
            chapitreVu: chapitreVu
        )
    }

    // MARK: Synchronisation

    /// Envoie la progression d une serie vers un service, si elle a le droit de
    /// partir.
    ///
    /// - Parameters:
    ///   - liaison: liaison de la serie avec le service, nulle quand la serie
    ///     n est liee a rien.
    ///   - chapitreLu: dernier chapitre lu localement.
    ///   - service: service vise.
    ///   - conditions: reglages, abonnement et confirmation apportes par
    ///     l ecran qui declenche l envoi.
    ///
    /// L etat de connexion et la session incognito ne sont pas des parametres :
    /// le registre les tient lui meme, et les faire passer par l appelant
    /// ouvrirait la porte a un envoi decide sur une session deja fermee.
    public func synchroniser(
        _ liaison: LiaisonSuivi?,
        chapitreLu: Double,
        aupresDe service: ServiceDeSuivi,
        selon conditions: ConditionsDEnvoi
    ) async throws -> ResultatDeSynchronisation {
        let decision = SynchronisationDesSuivis.decision(
            liaison: liaison,
            chapitreLu: chapitreLu,
            contexte: ContexteDeSynchronisation(
                conditions,
                etat: etats[service],
                session: incognito.sessionCourante
            )
        )

        // Rien ne part avant cette ligne, et rien ne part apres elle quand la
        // decision est un refus. C est ce qui rend le troisieme critere
        // verifiable au transport.
        guard decision.envoie else {
            return ResultatDeSynchronisation(decision: decision)
        }

        guard
            let liaison,
            let partante = SynchronisationDesSuivis.liaisonAEnvoyer(
                liaison,
                chapitreLu: chapitreLu,
                le: maintenant()
            )
        else {
            return ResultatDeSynchronisation(decision: .dejaAJour)
        }

        do {
            let publiee = try await exiger(service).publier(partante)

            return ResultatDeSynchronisation(decision: .envoyer, liaison: publiee)
        } catch let erreur as ErreurDeSuivi {
            // Une session morte se voit ici avant de se voir a l ecran. L etat
            // passe en expire pour que la ligne des reglages propose la
            // reconnexion, et l erreur remonte quand meme.
            if case .reconnexionNecessaire = erreur {
                etats.marquerExpire(service)
            }

            throw erreur
        }
    }

    // MARK: Interne

    /// Client de ce service.
    ///
    /// - Throws: `ErreurDeSuivi.serviceNonConfigure` quand la version installee
    ///   n a pas construit ce client, faute de cles.
    private func exiger(_ service: ServiceDeSuivi) throws -> ClientDeSuivi {
        guard let client = clients[service] else {
            throw ErreurDeSuivi.serviceNonConfigure(service: service)
        }

        return client
    }

    /// Reporte l etat rendu par un client dans la table.
    private func appliquer(_ etat: EtatDeConnexionDeSuivi, a service: ServiceDeSuivi) {
        switch etat {
        case .deconnecte:
            etats.deconnecter(service)
        case let .connecte(compte):
            etats.connecter(service, compte: compte)
        case let .expire(compte):
            etats.connecter(service, compte: compte)
            etats.marquerExpire(service)
        }
    }
}
