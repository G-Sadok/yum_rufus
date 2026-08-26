import Core
import Foundation

//
// TransportDExtension
//
// La barriere par laquelle passe toute requete d une extension. Elle tient deux
// des quatre criteres de la section 4.3 : toute requete hors liste blanche est
// bloquee et journalisee, et le delai maximal de quinze secondes par requete
// est applique.
//
// Elle est posee sur `TransportHttp` et non a cote, pour que la source
// d extension n ait aucun moyen d atteindre le reseau autrement. Une source qui
// recevrait le transport reel et la liste blanche cote a cote pourrait oublier
// de consulter la seconde ; ici il n y a rien a oublier, la liste est du cote
// du fil.
//
// Les redirections sont suivies ici, une par une, et non laissees a URLSession.
// C est le point qui compte le plus dans ce fichier. Un serveur autorise qui
// repond 302 vers un domaine interdit contourne une liste blanche verifiee
// seulement sur la premiere requete, et le contournement est invisible :
// URLSession suit la redirection sans rien dire, et la reponse rendue semble
// venir du domaine de depart. Chaque saut est donc verifie comme une requete
// neuve, et le transport interne doit refuser de suivre quoi que ce soit, ce
// que fait `TransportURLSessionSansRedirection`.
//

/// Transport reserve aux extensions, derriere leur liste blanche et leur delai.
public struct TransportDExtension: TransportHttp {
    /// Delai maximal accorde a une requete d extension, section 4.3.
    ///
    /// Quinze secondes, la meme valeur que `RegistreDeSources.delaiParDefaut`
    /// et que `TransportURLSession.delaiParDefaut`. Le delai couvre la requete
    /// entiere, redirections comprises : une chaine de sauts dont chacun tient
    /// dans le delai depasserait sinon la limite sans jamais la franchir.
    public static let delaiParDefaut: Duration = .seconds(15)

    /// Nombre de redirections suivies avant abandon.
    ///
    /// Cinq, comme la limite usuelle des clients HTTP. Une boucle de
    /// redirections est un moyen simple d occuper le transport jusqu au delai,
    /// et l arreter plus tot rend la panne lisible.
    public static let redirectionsMaximales = 5

    private let interne: any TransportHttp
    private let listeBlanche: ListeBlancheDeDomaines
    private let identifiantDExtension: String
    private let journal: any JournalDExtensions
    private let maintenant: @Sendable () -> Date

    /// Delai applique, lisible par l interface et par les tests.
    public let delaiMaximal: Duration

    public init(
        interne: any TransportHttp,
        listeBlanche: ListeBlancheDeDomaines,
        identifiantDExtension: String,
        journal: any JournalDExtensions,
        delaiMaximal: Duration = TransportDExtension.delaiParDefaut,
        maintenant: @escaping @Sendable () -> Date = Date.init
    ) {
        self.interne = interne
        self.listeBlanche = listeBlanche
        self.identifiantDExtension = identifiantDExtension
        self.journal = journal
        self.delaiMaximal = delaiMaximal
        self.maintenant = maintenant
    }

    /// Le transport d une extension installee.
    public init(
        interne: any TransportHttp,
        extensionInstallee: ExtensionInstallee,
        journal: any JournalDExtensions,
        delaiMaximal: Duration = TransportDExtension.delaiParDefaut,
        maintenant: @escaping @Sendable () -> Date = Date.init
    ) {
        self.init(
            interne: interne,
            listeBlanche: extensionInstallee.listeBlanche,
            identifiantDExtension: extensionInstallee.manifeste.identifiant,
            journal: journal,
            delaiMaximal: delaiMaximal,
            maintenant: maintenant
        )
    }

    // MARK: Execution

    public func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        try Task.checkCancellation()

        return try await sousLeDelai {
            try await suivre(requete)
        }
    }

    /// Verifie une adresse avant de partir, puis chaque redirection recue.
    private func suivre(_ requete: URLRequest) async throws -> ReponseHttp {
        var courante = requete
        var motif = MotifDeRefus.domaineHorsListe

        for _ in 0...Self.redirectionsMaximales {
            try await verifier(courante.url, motif: motif)

            let reponse = try await executerEnJournalisantLeDelai(courante)

            guard let destination = try await destination(de: reponse, depuis: courante.url) else {
                return reponse
            }

            courante = Self.requeteDeSuivi(vers: destination, depuis: requete)
            motif = .redirectionHorsListe
        }

        await consigner(hote: courante.url.flatMap(ListeBlancheDeDomaines.hote), motif: .tropDeRedirections)

        throw ErreurReseau.echecDeTransport(code: 0)
    }

    /// Leve et journalise quand l adresse sort de ce que l extension a declare.
    ///
    /// Les deux refus sont distincts parce que la sortie l est aussi : une
    /// adresse en clair se corrige dans le manifeste, un domaine hors liste
    /// veut dire que l extension cherche a joindre autre chose que ce que
    /// l utilisateur a accepte.
    private func verifier(_ adresse: URL?, motif: MotifDeRefus) async throws {
        guard let adresse else {
            await consigner(hote: nil, motif: motif)

            throw ErreurReseau.serveurIntrouvable
        }

        let hote = ListeBlancheDeDomaines.hote(de: adresse)

        guard adresse.scheme?.lowercased() == "https" else {
            await consigner(hote: hote, motif: .transportNonChiffre)

            throw ErreurReseau.transportNonChiffre
        }
        guard listeBlanche.autorise(adresse) else {
            await consigner(hote: hote, motif: motif)

            throw ErreurReseau.domaineNonAutorise(domaine: hote ?? "")
        }
    }

    /// Passe la requete au transport interne, en journalisant un delai depasse.
    ///
    /// Le delai peut expirer a deux endroits, ici et dans la course de
    /// `sousLeDelai(_:)`, selon lequel du transport interne ou de notre horloge
    /// arrive le premier. Les deux journalisent, sans quoi la trace dependrait
    /// de la configuration du transport interne.
    private func executerEnJournalisantLeDelai(_ requete: URLRequest) async throws -> ReponseHttp {
        do {
            return try await interne.executer(requete)
        } catch ErreurReseau.delaiDepasse {
            await consigner(hote: requete.url.flatMap(ListeBlancheDeDomaines.hote), motif: .delaiDepasse)

            throw ErreurReseau.delaiDepasse
        }
    }

    /// L adresse vers laquelle la reponse redirige, ou nul quand elle n en est
    /// pas une.
    ///
    /// Une redirection sans entete `Location`, ou vers une adresse qui ne
    /// s assemble pas, est traitee comme une reponse illisible plutot que comme
    /// une reponse finale : rendre le corps d un 302 ferait analyser une page
    /// de redirection comme si c etait un catalogue.
    private func destination(de reponse: ReponseHttp, depuis origine: URL?) async throws -> URL? {
        guard (300..<400).contains(reponse.code) else {
            return nil
        }
        guard
            let lieu = reponse.entete("Location"),
            let destination = URL(string: lieu, relativeTo: origine)?.absoluteURL
        else {
            throw ErreurReseau.reponseIllisible
        }

        return destination
    }

    /// La requete du saut suivant, reduite a une lecture.
    ///
    /// Le corps et les entetes de la requete d origine ne sont pas repris. Une
    /// extension n envoie que des `GET`, et recopier des entetes vers un
    /// domaine qui vient de changer est exactement la facon dont une preuve
    /// d identite fuit chez un tiers.
    private static func requeteDeSuivi(vers destination: URL, depuis origine: URLRequest) -> URLRequest {
        var suivante = URLRequest(url: destination)
        suivante.httpMethod = MethodeHttp.get.rawValue
        suivante.setValue(origine.value(forHTTPHeaderField: "Accept"), forHTTPHeaderField: "Accept")

        return suivante
    }

    /// Consigne un refus, sans jamais y ecrire autre chose que le domaine.
    private func consigner(hote: String?, motif: MotifDeRefus) async {
        await journal.consigner(
            RefusDExtension(
                extensionVisee: identifiantDExtension,
                domaine: hote ?? "",
                motif: motif,
                instant: maintenant()
            )
        )
    }

    // MARK: Delai

    /// Fait courir le travail contre l horloge, et abandonne au dela du delai.
    ///
    /// La course est ici et non dans le transport interne parce que le delai de
    /// la section 4.3 porte sur la requete telle que l extension la demande,
    /// redirections comprises, pas sur chaque aller retour.
    private func sousLeDelai(
        _ travail: @escaping @Sendable () async throws -> ReponseHttp
    ) async throws -> ReponseHttp {
        try await withThrowingTaskGroup(of: ReponseHttp?.self) { groupe in
            groupe.addTask { try await travail() }
            groupe.addTask {
                // `try?` et non `try` : l annulation du sommeil est le cas
                // normal, celui ou le travail a gagne la course.
                try? await Task.sleep(for: delaiMaximal)

                return nil
            }

            defer { groupe.cancelAll() }

            while let resultat = try await groupe.next() {
                guard let reponse = resultat else {
                    try Task.checkCancellation()
                    await consigner(hote: nil, motif: .delaiDepasse)

                    throw ErreurReseau.delaiDepasse
                }

                return reponse
            }

            throw ErreurReseau.delaiDepasse
        }
    }
}

//
// TransportURLSessionSansRedirection
//
// Le transport reel des extensions. Il ne differe de `TransportURLSession` que
// sur un point, et ce point est une regle de securite : il ne suit aucune
// redirection. C est ce qui laisse `TransportDExtension` verifier chaque saut
// contre la liste blanche au lieu de decouvrir apres coup ou la requete a fini.
//

/// Transport HTTP qui rend la redirection au lieu de la suivre.
public struct TransportURLSessionSansRedirection: TransportHttp {
    private let session: URLSession

    /// Construit le transport sur une session ephemere et sans cache.
    ///
    /// Le delai de la session vaut celui de la section 4.3. Il double celui de
    /// `TransportDExtension` plutot que de le remplacer : une connexion qui
    /// n aboutit jamais doit tomber meme si la course de l appelant a ete
    /// contournee.
    public init(delai: TimeInterval = 15) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = delai
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false

        session = URLSession(
            configuration: configuration,
            delegate: RefusDeRedirection(),
            delegateQueue: nil
        )
    }

    public func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        let recue: (Data, URLResponse)

        do {
            recue = try await session.data(for: requete)
        } catch {
            throw ErreurReseau.depuis(error) ?? .echecDeTransport(code: 0)
        }

        guard let http = recue.1 as? HTTPURLResponse else {
            throw ErreurReseau.reponseIllisible
        }

        return ReponseHttp(code: http.statusCode, entetes: Self.entetes(de: http), corps: recue.0)
    }

    /// Ramene les entetes d une reponse dans un dictionnaire de chaines.
    private static func entetes(de reponse: HTTPURLResponse) -> [String: String] {
        reponse.allHeaderFields.reduce(into: [:]) { table, entete in
            guard let nom = entete.key as? String, let valeur = entete.value as? String else {
                return
            }

            table[nom] = valeur
        }
    }
}

/// Delegue qui refuse toute redirection automatique.
///
/// `@unchecked Sendable` est sur ici parce que le type n a aucun etat : il
/// repond toujours la meme chose, et deux appels concurrents ne partagent rien.
private final class RefusDeRedirection: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Rendre nul fait remonter la reponse de redirection telle quelle, ce
        // qui est exactement ce que `TransportDExtension` attend pour verifier
        // la destination avant de la joindre.
        completionHandler(nil)
    }
}
