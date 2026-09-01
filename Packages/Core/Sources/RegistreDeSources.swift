import Foundation

//
// RegistreDeSources
//
// Le registre de sources de la section 4. Il tient les sources configurees dans
// l ordre choisi par l utilisateur, et sert de point d entree unique quand une
// question s adresse a toutes.
//
// Il vit dans Core, a cote du protocole et non a cote des implementations. Il
// ne depend que de `SourceProvider`, donc le mettre dans Sources obligerait
// toute couche qui interroge les sources a dependre de leurs implementations,
// ce qui est precisement ce que le protocole existe pour eviter.
//
// C est un acteur parce que la liste des sources est un etat mutable partage :
// l ecran Parcourir en ajoute, la feuille de configuration en remplace, et une
// analyse de fond en interroge pendant ce temps.
//
// La regle qui gouverne tout ce fichier : une source en echec n empeche jamais
// les autres de fonctionner. Elle a deux consequences. Chaque source est
// interrogee dans sa propre tache, et son erreur est capturee dans son propre
// resultat au lieu de remonter. Et chaque interrogation porte un delai maximal,
// parce qu une source qui ne repond jamais bloquerait l attente commune tout
// aussi surement qu une source qui leve.
//

/// Ce qu une source a rendu, ou ce qui l en a empechee.
///
/// Le nom est recopie a cote de l identifiant : l appelant affiche un echec
/// sans avoir a redemander la source au registre, ce qui lui eviterait
/// justement de dependre de sources qui viennent d etre retirees.
public struct ResultatDeSource<Valeur: Sendable>: Sendable {
    public let source: SourceID
    public let nom: String
    public let resultat: Result<Valeur, ErreurDeSource>

    public init(source: SourceID, nom: String, resultat: Result<Valeur, ErreurDeSource>) {
        self.source = source
        self.nom = nom
        self.resultat = resultat
    }

    /// La valeur rendue, ou nul quand la source a echoue.
    public var valeur: Valeur? {
        try? resultat.get()
    }

    /// L erreur, ou nul quand la source a repondu.
    public var erreur: ErreurDeSource? {
        guard case let .failure(erreur) = resultat else {
            return nil
        }

        return erreur
    }

    public var aReussi: Bool {
        erreur == nil
    }
}

/// Les sources configurees, et les questions posees a toutes a la fois.
public actor RegistreDeSources {
    /// Delai au dela duquel une source est declaree muette.
    ///
    /// Quinze secondes, comme la limite imposee aux extensions par la section
    /// 4.3. Une meme valeur pour toutes les sources, parce qu un utilisateur qui
    /// attend ne fait pas la difference entre une extension lente et un serveur
    /// lent.
    public static let delaiParDefaut: Duration = .seconds(15)

    private var inscrites: [any SourceProvider] = []

    /// Delai accorde a une source avant qu elle soit declaree muette.
    ///
    /// Public et lisible sans attente : l ecran Rechercher l ecrit dans la ligne
    /// d erreur d une source qui n a pas repondu, comme le demande le tableau
    /// 6.4, et un message qui annoncerait un delai different de celui applique
    /// serait pire que pas de message du tout.
    public nonisolated let delaiMaximal: Duration

    public init(delaiMaximal: Duration = RegistreDeSources.delaiParDefaut) {
        self.delaiMaximal = delaiMaximal
    }

    // MARK: Contenu du registre

    /// Les sources, dans l ordre d inscription.
    public var toutes: [any SourceProvider] {
        inscrites
    }

    public var nombreDeSources: Int {
        inscrites.count
    }

    /// Inscrit une source, ou remplace celle qui portait deja cet identifiant.
    ///
    /// Le remplacement conserve la position : reconfigurer une source ne doit
    /// pas la faire sauter en fin de liste sous les yeux de l utilisateur.
    public func inscrire(_ source: any SourceProvider) {
        if let position = inscrites.firstIndex(where: { $0.id == source.id }) {
            inscrites[position] = source
        } else {
            inscrites.append(source)
        }
    }

    /// Remplace toutes les sources inscrites par celles ci.
    ///
    /// C est ce qu appelle la couche qui reconstruit les sources depuis la
    /// base : elle connait la liste complete, et l inscrire source par source
    /// laisserait dans le registre celles qui viennent d etre supprimees.
    public func remplacerPar(_ sources: [any SourceProvider]) {
        inscrites = sources
    }

    /// Retire une source, et rend vrai quand elle y etait.
    @discardableResult
    public func retirer(_ id: SourceID) -> Bool {
        guard let position = inscrites.firstIndex(where: { $0.id == id }) else {
            return false
        }

        inscrites.remove(at: position)

        return true
    }

    public func source(_ id: SourceID) -> (any SourceProvider)? {
        inscrites.first { $0.id == id }
    }

    /// Les sources qui declarent toutes les capacites demandees.
    ///
    /// C est ce que le registre interroge quand la question suppose une
    /// capacite. Interroger les autres pour recolter leurs refus produirait une
    /// liste d erreurs a afficher alors que rien n a echoue.
    public func sourcesDeclarant(_ capacites: SourceCapacites) -> [any SourceProvider] {
        inscrites.filter { $0.capacites.contains(capacites) }
    }

    // MARK: Interrogation de toutes les sources

    /// Pose la meme question a toutes les sources, chacune isolee des autres.
    ///
    /// Les resultats reviennent dans l ordre d inscription et non dans l ordre
    /// des reponses : une liste dont l ordre depend de la latence du reseau
    /// changerait a chaque actualisation.
    public func interroger<Valeur: Sendable>(
        _ travail: @Sendable @escaping (any SourceProvider) async throws -> Valeur
    ) async -> [ResultatDeSource<Valeur>] {
        await interroger(inscrites, travail)
    }

    /// Pose la question aux seules sources qui declarent les capacites voulues.
    public func interroger<Valeur: Sendable>(
        declarant capacites: SourceCapacites,
        _ travail: @Sendable @escaping (any SourceProvider) async throws -> Valeur
    ) async -> [ResultatDeSource<Valeur>] {
        await interroger(sourcesDeclarant(capacites), travail)
    }

    /// Verifie la connexion de toutes les sources.
    ///
    /// `verifierConnexion` ne leve pas, mais elle peut ne jamais rendre. Le
    /// delai maximal s applique donc ici aussi, et une source muette devient un
    /// echec au lieu de figer la pastille d etat des autres.
    public func verifierToutes() async -> [ResultatDeSource<EtatConnexion>] {
        await interroger { await $0.verifierConnexion() }
    }

    /// Cherche dans toutes les sources qui declarent la recherche.
    public func rechercher(_ requete: RequeteRecherche) async -> [ResultatDeSource<PageResultats<MangaDistant>>] {
        await interroger(declarant: .recherche) { try await $0.rechercher(requete) }
    }

    /// Interroge une seule source, avec la meme isolation que les autres.
    ///
    /// Rend nul quand la source n est plus inscrite, ce qui arrive si elle a ete
    /// retiree entre l affichage de sa ligne d erreur et le clic sur Reessayer.
    public func interroger<Valeur: Sendable>(
        _ identifiant: SourceID,
        _ travail: @Sendable @escaping (any SourceProvider) async throws -> Valeur
    ) async -> ResultatDeSource<Valeur>? {
        guard let source = source(identifiant) else {
            return nil
        }

        return await Self.executer(source, delai: delaiMaximal, travail)
    }

    /// Relance la recherche dans une seule source, lien Reessayer de la 5.4.
    public func rechercher(
        _ requete: RequeteRecherche,
        dans identifiant: SourceID
    ) async -> ResultatDeSource<PageResultats<MangaDistant>>? {
        await interroger(identifiant) { try await $0.rechercher(requete) }
    }

    /// Parcourt une section dans toutes les sources.
    public func parcourir(
        _ section: SectionCatalogue,
        page: Int = 0
    ) async -> [ResultatDeSource<PageResultats<MangaDistant>>] {
        await interroger { try await $0.parcourir(section, page: page) }
    }

    // MARK: Interrogation au fil de l eau

    /// Pose la meme question a toutes les sources, et rend chaque reponse des
    /// qu elle arrive.
    ///
    /// C est la difference avec `interroger` : celui la attend la derniere
    /// source pour rendre la liste complete, dans l ordre d inscription. Ici
    /// l ordre est celui des reponses, ce qui est exactement ce que demande
    /// l ecran Rechercher de la section 5.4. Une source lente ne retient plus
    /// l affichage des autres, elle ne retient que sa propre rangee.
    ///
    /// Le flux se termine quand la derniere source a repondu. Abandonner le flux
    /// annule les taches encore en cours, une recherche relancee ne laisse donc
    /// pas la precedente consommer du reseau.
    public func interrogerAuFilDeLEau<Valeur: Sendable>(
        _ travail: @Sendable @escaping (any SourceProvider) async throws -> Valeur
    ) -> AsyncStream<ResultatDeSource<Valeur>> {
        flux(inscrites, travail)
    }

    /// Interroge au fil de l eau les seules sources qui declarent les capacites.
    public func interrogerAuFilDeLEau<Valeur: Sendable>(
        declarant capacites: SourceCapacites,
        _ travail: @Sendable @escaping (any SourceProvider) async throws -> Valeur
    ) -> AsyncStream<ResultatDeSource<Valeur>> {
        flux(sourcesDeclarant(capacites), travail)
    }

    /// Cherche dans toutes les sources, une rangee affichable a chaque reponse.
    public func rechercherAuFilDeLEau(
        _ requete: RequeteRecherche
    ) -> AsyncStream<ResultatDeSource<PageResultats<MangaDistant>>> {
        interrogerAuFilDeLEau(declarant: .recherche) { try await $0.rechercher(requete) }
    }

    /// Les sources qui seront interrogees par une recherche, dans leur ordre.
    ///
    /// L ecran s en sert pour poser ses rangees en chargement avant meme la
    /// premiere reponse : une rangee qui apparaitrait au moment de la reponse
    /// ferait sauter la mise en page a chaque source qui repond.
    public func sourcesInterrogeesParUneRecherche() -> [SourceInterrogee] {
        sourcesDeclarant(.recherche).map { SourceInterrogee(source: $0.id, nom: $0.nom) }
    }

    // MARK: Isolation

    /// Lance une tache par source et rend les resultats dans l ordre d arrivee.
    private func flux<Valeur: Sendable>(
        _ sources: [any SourceProvider],
        _ travail: @Sendable @escaping (any SourceProvider) async throws -> Valeur
    ) -> AsyncStream<ResultatDeSource<Valeur>> {
        let delai = delaiMaximal

        return AsyncStream { suite in
            let tache = Task {
                await withTaskGroup(of: ResultatDeSource<Valeur>.self) { groupe in
                    for source in sources {
                        groupe.addTask { await Self.executer(source, delai: delai, travail) }
                    }

                    for await resultat in groupe {
                        suite.yield(resultat)
                    }
                }

                suite.finish()
            }

            suite.onTermination = { _ in tache.cancel() }
        }
    }

    /// Lance une tache par source et recolte les resultats dans l ordre donne.
    private func interroger<Valeur: Sendable>(
        _ sources: [any SourceProvider],
        _ travail: @Sendable @escaping (any SourceProvider) async throws -> Valeur
    ) async -> [ResultatDeSource<Valeur>] {
        let delai = delaiMaximal

        return await withTaskGroup(of: (Int, ResultatDeSource<Valeur>).self) { groupe in
            for (rang, source) in sources.enumerated() {
                groupe.addTask {
                    let resultat = await Self.executer(source, delai: delai, travail)

                    return (rang, resultat)
                }
            }

            var recoltes: [(Int, ResultatDeSource<Valeur>)] = []
            recoltes.reserveCapacity(sources.count)

            for await resultat in groupe {
                recoltes.append(resultat)
            }

            return recoltes.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// Interroge une source, et transforme tout echec en resultat.
    ///
    /// Rien ne leve depuis cette fonction. C est ce qui garantit qu une source
    /// en echec ne fait pas tomber la recolte des autres, parce qu une erreur
    /// levee dans un groupe de taches annule le groupe entier.
    private static func executer<Valeur: Sendable>(
        _ source: any SourceProvider,
        delai: Duration,
        _ travail: @Sendable @escaping (any SourceProvider) async throws -> Valeur
    ) async -> ResultatDeSource<Valeur> {
        do {
            let valeur = try await avantLeDelai(delai, source: source.nom) {
                try await travail(source)
            }

            return ResultatDeSource(source: source.id, nom: source.nom, resultat: .success(valeur))
        } catch {
            return ResultatDeSource(
                source: source.id,
                nom: source.nom,
                resultat: .failure(ErreurDeSource.depuis(error, source: source.nom))
            )
        }
    }

    /// Rend le resultat du travail, ou leve quand le delai expire avant lui.
    ///
    /// Le travail et le compte a rebours courent en parallele, et le premier qui
    /// finit fait annuler l autre. L annulation de la source est reelle : le
    /// groupe la propage, et une source qui respecte les points de suspension
    /// s arrete au lieu de continuer a consommer du reseau pour rien.
    private static func avantLeDelai<Valeur: Sendable>(
        _ delai: Duration,
        source: String,
        _ travail: @Sendable @escaping () async throws -> Valeur
    ) async throws -> Valeur {
        try await withThrowingTaskGroup(of: Valeur?.self) { groupe in
            groupe.addTask { try await travail() }
            groupe.addTask {
                try await Task.sleep(for: delai)

                return nil
            }

            while let premier = try await groupe.next() {
                groupe.cancelAll()

                guard let valeur = premier else {
                    throw ErreurDeSource.reseau(.delaiDepasse, source: source)
                }

                return valeur
            }

            throw ErreurDeSource.reseau(.delaiDepasse, source: source)
        }
    }
}
