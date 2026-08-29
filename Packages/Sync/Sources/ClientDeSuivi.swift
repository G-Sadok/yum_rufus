import Core
import Foundation
import Sources

//
// ClientDeSuivi
//
// Ce qui parle a un service de suivi. Un objet par service, la meme classe pour
// les quatre.
//
// Il fait quatre choses : connecter, deconnecter, chercher, publier. Tout ce
// qui differe d un service a l autre est demande au dialecte, tout ce qui ne
// differe pas est ecrit ici une fois.
//
// La deconnexion merite une phrase, parce que le premier critere de la
// fonctionnalite porte sur elle autant que sur la connexion. Deconnecter, c est
// effacer la ligne du trousseau et oublier le compte. Ce n est pas poser un
// drapeau : un drapeau laisse le jeton en place, et un jeton en place est un
// jeton qui repartira le jour ou quelqu un oubliera de lire le drapeau.
//
// Aucun appel au service n est fait pour deconnecter. Deux des quatre services
// n ont aucun point de revocation, et sur les deux autres il echouerait des que
// le jeton est deja perime, ce qui laisserait l utilisateur connecte a une
// session morte parce que la deconnexion aurait echoue.
//

/// Le client d un service de suivi.
public actor ClientDeSuivi {
    private let dialecte: any DialecteDeSuivi
    private let configuration: ConfigurationDesSuivis
    private let magasin: any MagasinDeJetonsDeSuivi
    private let echange: EchangeDeJeton
    private let client: ClientHttp
    private let maintenant: @Sendable () -> Date

    /// Compte connu, retenu entre deux appels pour que l ecran des reglages ne
    /// demande pas le reseau a chaque affichage.
    private var compteConnu: CompteDeSuivi?

    /// Vrai quand le service a refuse le dernier jeton presente.
    private var jetonRefuse = false

    /// Construit le client d un service.
    ///
    /// - Throws: `ErreurReseau.transportNonChiffre` si l adresse de l API du
    ///   service n est pas en HTTPS, ce qui ne peut arriver que si une adresse
    ///   du descriptif a ete mal ecrite.
    public init(
        dialecte: any DialecteDeSuivi,
        configuration: ConfigurationDesSuivis,
        magasin: any MagasinDeJetonsDeSuivi,
        transport: any TransportHttp,
        maintenant: @escaping @Sendable () -> Date = Date.init
    ) throws {
        self.dialecte = dialecte
        self.configuration = configuration
        self.magasin = magasin
        self.maintenant = maintenant

        echange = EchangeDeJeton(
            service: dialecte.service,
            dialecte: dialecte,
            transport: transport,
            maintenant: maintenant
        )

        client = try ClientHttp(
            base: dialecte.service.descriptif.api,
            transport: transport,
            identite: IdentiteDeSuivi(
                service: dialecte.service,
                magasin: magasin,
                configuration: configuration,
                echange: echange,
                maintenant: maintenant
            ),
            maintenant: maintenant
        )
    }

    /// Service que ce client sert.
    public nonisolated var service: ServiceDeSuivi {
        dialecte.service
    }

    // MARK: Connexion

    /// Termine une connexion OAuth commencee dans le navigateur.
    ///
    /// - Parameters:
    ///   - redirection: adresse par laquelle le navigateur est revenu.
    ///   - demande: demande envoyee avant l ouverture du navigateur.
    public func connecter(redirection: URL, pour demande: DemandeDAutorisation) async throws -> CompteDeSuivi {
        let code = try AutorisationOAuth.code(depuis: redirection, pour: demande)
        let champs = try AutorisationOAuth.champsDEchange(
            pour: demande,
            code: code,
            configuration: configuration
        )

        return try await terminerLaConnexion(avec: echange.executer(champs: champs))
    }

    /// Connecte le service qui demande un compte et un mot de passe.
    public func connecter(compte: String, motDePasse: String) async throws -> CompteDeSuivi {
        let identifiants = try await echange.executer(compte: compte, motDePasse: motDePasse)

        return try await terminerLaConnexion(avec: identifiants)
    }

    /// Range le jeton puis demande au service quel compte il vient d ouvrir.
    ///
    /// L ordre compte. Le jeton est range avant l appel au compte, parce que
    /// c est lui qui authentifie cet appel la. Si l appel echoue, le jeton
    /// reste range : il est valable, et une connexion a moitie faite se
    /// rattrape par un rafraichissement de l etat plutot que par une seconde
    /// visite au navigateur.
    private func terminerLaConnexion(avec identifiants: IdentifiantsDeSource) async throws -> CompteDeSuivi {
        try await magasin.enregistrer(identifiants, pour: service)
        jetonRefuse = false

        let compte = try await demanderLeCompte()
        compteConnu = compte

        return compte
    }

    /// Efface le jeton et oublie le compte.
    public func deconnecter() async throws {
        try await magasin.supprimer(pour: service)
        compteConnu = nil
        jetonRefuse = false
    }

    /// Etat connu sans rien demander au reseau.
    ///
    /// C est ce que lit l ecran des reglages a chaque affichage. Un service
    /// dont le jeton est range mais dont le compte n a jamais ete lu est
    /// annonce deconnecte : mieux vaut une ligne a reconnecter qu une ligne qui
    /// affirme une connexion que personne n a verifiee.
    public func etatConnu() async -> EtatDeConnexionDeSuivi {
        guard let compteConnu else {
            return .deconnecte
        }

        return jetonRefuse ? .expire(compteConnu) : .connecte(compteConnu)
    }

    /// Redemande au service quel compte est connecte, et met l etat a jour.
    ///
    /// Appele au lancement pour les services qui portent un jeton. Un refus ne
    /// leve pas : il rend l etat expire, qui est exactement ce que l ecran doit
    /// montrer.
    public func rafraichirLEtat() async -> EtatDeConnexionDeSuivi {
        let identifiants = try? await magasin.identifiants(pour: service)

        guard let identifiants, identifiants.estVide == false else {
            compteConnu = nil
            jetonRefuse = false

            return .deconnecte
        }

        do {
            let compte = try await demanderLeCompte()
            compteConnu = compte
            jetonRefuse = false

            return .connecte(compte)
        } catch {
            jetonRefuse = true

            return compteConnu.map { .expire($0) } ?? .deconnecte
        }
    }

    // MARK: Liaison

    /// Cherche les entrees du service qui pourraient correspondre a ce titre.
    ///
    /// - Throws: `ErreurDeSuivi.serviceDeconnecte` quand aucun jeton n est
    ///   range, et les erreurs de `ErreurReseau` quand le service repond mal.
    public func rechercher(_ titre: String) async throws -> [SerieDeSuivi] {
        try await exigerUneConnexion()

        let reponse = try await envoyer(dialecte.appelDeRecherche(titre: titre))

        return try dialecte.series(depuis: reponse)
    }

    /// Publie la progression d une liaison et rend la liaison datee.
    ///
    /// - Throws: `ErreurDeSuivi.serviceDeconnecte` quand le service n a pas de
    ///   compte connecte, `ErreurDeSuivi.liaisonAbsente` quand la liaison ne
    ///   designe pas d entree chez ce service.
    public func publier(_ liaison: LiaisonSuivi) async throws -> LiaisonSuivi {
        guard liaison.service == service else {
            throw ErreurDeSuivi.liaisonAbsente(service: service)
        }

        try await exigerUneConnexion()

        guard let compte = compteConnu else {
            throw ErreurDeSuivi.serviceDeconnecte(service: service)
        }

        let existante = try await entreeExistante(pour: liaison, compte: compte)
        let appel = try dialecte.appelDePublication(liaison, compte: compte, entreeExistante: existante)

        _ = try await envoyer(appel)

        var publiee = liaison
        publiee.dateSynchronisation = maintenant()

        return publiee
    }

    /// Identifiant de l entree de bibliotheque deja posee, quand le service en
    /// tient une.
    ///
    /// Une recherche qui echoue ne fait pas echouer la publication : l entree
    /// est alors traitee comme absente, ce qui produit une creation. C est le
    /// bon repli, parce qu un service qui refuse la lecture d une entree refuse
    /// aussi sa modification, et que l erreur remontera de la publication avec
    /// le bon contexte.
    private func entreeExistante(pour liaison: LiaisonSuivi, compte: CompteDeSuivi) async throws -> String? {
        guard let appel = dialecte.appelDeLEntreeExistante(liaison, compte: compte) else {
            return nil
        }

        guard let reponse = try? await envoyer(appel) else {
            return nil
        }

        return try? dialecte.entreeExistante(depuis: reponse)
    }

    // MARK: Envoi

    /// Envoie un appel du dialecte et rend la reponse validee.
    private func envoyer(_ appel: AppelDeSuivi) async throws -> ReponseHttp {
        do {
            return try await client.executer(requete(appel))
        } catch ErreurReseau.authentificationRefusee {
            jetonRefuse = true

            throw ErreurDeSuivi.reconnexionNecessaire(service: service)
        }
    }

    /// Demande au service le compte que le jeton range ouvre.
    private func demanderLeCompte() async throws -> CompteDeSuivi {
        let reponse = try await envoyer(dialecte.appelDuCompte())

        return try dialecte.compte(depuis: reponse)
    }

    /// Leve quand aucun jeton n est range pour ce service.
    ///
    /// La question est posee au trousseau et non a l etat retenu : c est le
    /// trousseau qui decide, et lui seul sait ce qu une autre partie de
    /// l application vient d effacer.
    private func exigerUneConnexion() async throws {
        let identifiants = try? await magasin.identifiants(pour: service)

        guard let identifiants, identifiants.estVide == false else {
            throw ErreurDeSuivi.serviceDeconnecte(service: service)
        }
    }

    /// Requete HTTP correspondant a un appel du dialecte.
    private func requete(_ appel: AppelDeSuivi) throws -> URLRequest {
        let adresse = try ClientHttp.adresse(
            base: service.descriptif.api,
            chemin: appel.chemin,
            parametres: appel.parametres
        )

        var requete = URLRequest(url: adresse)
        requete.httpMethod = appel.methode.rawValue
        requete.setValue("application/json", forHTTPHeaderField: "Accept")

        switch appel.corps {
        case .aucun:
            break
        case let .json(donnees):
            requete.httpBody = donnees
            requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case let .formulaire(champs):
            requete.httpBody = Data(FormulaireEncode.corps(champs).utf8)
            requete.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        return requete
    }
}
