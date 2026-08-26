import Core
import Foundation
import Testing
@testable import Sources

/// Couvre le deuxieme et le quatrieme critere de la fonctionnalite : toute
/// requete hors liste blanche est bloquee et journalisee, et le delai maximal
/// de quinze secondes par requete est applique.
///
/// Chaque test de blocage verifie **trois** choses, et pas seulement la
/// premiere. Que l appel leve. Que le refus a ete journalise, avec son motif et
/// le domaine vise. Et que le transport interne n a rien recu du tout, ce qui
/// est le seul moyen de prouver que la requete a ete bloquee et non simplement
/// echouee apres coup.
struct TransportDExtensionTests {
    private static let instant = Date(timeIntervalSince1970: 1_700_000_000)

    /// Delai court, pour que le test d une requete trop lente dure des
    /// millisecondes et non quinze secondes.
    private static let delaiCourt: Duration = .milliseconds(60)

    // MARK: Ce qui passe

    @Test("Une requete vers un domaine declare passe")
    func requeteAutorisee() async throws {
        let espion = TransportEspion([.json("https://api.exemple.net", "{}")])
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal)
        let reponse = try await transport.executer(requeteDeTest("https://api.exemple.net/serie/12"))

        #expect(reponse.code == 200)
        #expect(await espion.hotesJoints == ["api.exemple.net"])
        #expect(await journal.consignes.isEmpty)
    }

    @Test("Un sous domaine declare avec une etoile passe")
    func sousDomaineAutorise() async throws {
        let espion = TransportEspion([.json("https://images.exemple.net", "{}")])
        let journal = JournalDExtensionsEnMemoire()
        let transport = try TransportDExtension(
            interne: espion,
            listeBlanche: listeBlancheDeTest("*.exemple.net"),
            identifiantDExtension: "exemple.catalogue",
            journal: journal,
            maintenant: { Self.instant }
        )

        _ = try await transport.executer(requeteDeTest("https://images.exemple.net/1.jpg"))

        #expect(await espion.hotesJoints == ["images.exemple.net"])
    }

    // MARK: Ce qui est bloque

    @Test("Une requete hors liste blanche est bloquee, journalisee, et jamais envoyee")
    func requeteHorsListe() async throws {
        let espion = TransportEspion([.json("https://attaquant.org", "{}")])
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal)

        await #expect(throws: ErreurReseau.domaineNonAutorise(domaine: "attaquant.org")) {
            try await transport.executer(requeteDeTest("https://attaquant.org/collecte"))
        }

        let consignes = await journal.consignes

        #expect(consignes.count == 1)
        #expect(consignes.first?.motif == .domaineHorsListe)
        #expect(consignes.first?.domaine == "attaquant.org")
        #expect(consignes.first?.extensionVisee == "exemple.catalogue")
        #expect(consignes.first?.instant == Self.instant)
        #expect(await espion.adressesDemandees.isEmpty)
    }

    @Test("Un domaine voisin du domaine declare est bloque")
    func domaineVoisin() async throws {
        let espion = TransportEspion()
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal)

        for piege in ["https://api.exemple.net.attaquant.org/x", "https://faux-api.exemple.net/x"] {
            await #expect(throws: ErreurReseau.self) {
                try await transport.executer(requeteDeTest(piege))
            }
        }

        #expect(await journal.nombreDeRefus(pour: "exemple.catalogue") == 2)
        #expect(await espion.adressesDemandees.isEmpty)
    }

    @Test("Une adresse en clair est bloquee, avec son propre motif")
    func adresseEnClair() async throws {
        let espion = TransportEspion([.json("http://api.exemple.net", "{}")])
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal)

        await #expect(throws: ErreurReseau.transportNonChiffre) {
            try await transport.executer(requeteDeTest("http://api.exemple.net/serie"))
        }

        #expect(await journal.consignes.first?.motif == .transportNonChiffre)
        #expect(await espion.adressesDemandees.isEmpty)
    }

    // MARK: Redirections

    /// Le contournement le plus simple d une liste blanche verifiee une seule
    /// fois : un serveur autorise repond 302 vers un domaine interdit.
    @Test("Une redirection hors liste est bloquee et journalisee")
    func redirectionHorsListe() async throws {
        let espion = TransportEspion([
            .redirection(de: "https://api.exemple.net", vers: "https://attaquant.org/collecte"),
            .json("https://attaquant.org", "{}"),
        ])
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal)

        await #expect(throws: ErreurReseau.domaineNonAutorise(domaine: "attaquant.org")) {
            try await transport.executer(requeteDeTest("https://api.exemple.net/serie"))
        }

        #expect(await journal.consignes.first?.motif == .redirectionHorsListe)
        #expect(await journal.consignes.first?.domaine == "attaquant.org")
        #expect(await espion.hotesJoints == ["api.exemple.net"])
    }

    @Test("Une redirection relative vers un domaine declare est suivie")
    func redirectionAutorisee() async throws {
        // La regle la plus precise est en tete : l espion sert la premiere qui
        // correspond, et le prefixe de la redirection couvre aussi sa cible.
        let espion = TransportEspion([
            .json("https://api.exemple.net/serie/12", "{\"id\":12}"),
            .redirection(de: "https://api.exemple.net/serie", vers: "/serie/12"),
        ])
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal)
        let reponse = try await transport.executer(requeteDeTest("https://api.exemple.net/serie"))

        #expect(reponse.code == 200)
        #expect(await espion.adressesDemandees.map(\.path) == ["/serie", "/serie/12"])
        #expect(await journal.consignes.isEmpty)
    }

    @Test("Une boucle de redirections est arretee et journalisee")
    func boucleDeRedirections() async throws {
        let espion = TransportEspion([
            .redirection(de: "https://api.exemple.net", vers: "https://api.exemple.net/encore"),
        ])
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal)

        await #expect(throws: ErreurReseau.self) {
            try await transport.executer(requeteDeTest("https://api.exemple.net/serie"))
        }

        #expect(await journal.consignes.last?.motif == .tropDeRedirections)
        #expect(await espion.adressesDemandees.count == TransportDExtension.redirectionsMaximales + 1)
    }

    @Test("Une redirection sans destination est refusee")
    func redirectionSansDestination() async throws {
        let espion = TransportEspion([.init("https://api.exemple.net", ReponseHttp(code: 302))])
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal)

        await #expect(throws: ErreurReseau.reponseIllisible) {
            try await transport.executer(requeteDeTest("https://api.exemple.net/serie"))
        }
    }

    // MARK: Delai

    @Test("Le delai applique par defaut est celui de la section 4.3")
    func delaiParDefaut() throws {
        let transport = try barriere(espion: TransportEspion(), journal: JournalDExtensionsEnMemoire())

        #expect(TransportDExtension.delaiParDefaut == .seconds(15))
        #expect(transport.delaiMaximal == .seconds(15))
    }

    @Test("Une requete plus lente que le delai est abandonnee et journalisee")
    func delaiDepasse() async throws {
        let espion = TransportEspion(
            [.json("https://api.exemple.net", "{}")],
            attente: .seconds(30)
        )
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal, delai: Self.delaiCourt)

        await #expect(throws: ErreurReseau.delaiDepasse) {
            try await transport.executer(requeteDeTest("https://api.exemple.net/serie"))
        }

        #expect(await journal.consignes.contains { $0.motif == .delaiDepasse })
    }

    /// Le delai porte sur la requete telle que l extension la demande,
    /// redirections comprises. Une chaine de sauts dont chacun tient dans le
    /// delai le depasserait sinon sans jamais le franchir.
    @Test("Le delai couvre la chaine de redirections entiere")
    func delaiCouvreLesRedirections() async throws {
        let espion = TransportEspion(
            [.redirection(de: "https://api.exemple.net", vers: "https://api.exemple.net/encore")],
            attente: Self.delaiCourt
        )
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal, delai: Self.delaiCourt * 2)

        await #expect(throws: ErreurReseau.delaiDepasse) {
            try await transport.executer(requeteDeTest("https://api.exemple.net/serie"))
        }

        #expect(await espion.adressesDemandees.count < TransportDExtension.redirectionsMaximales + 1)
    }

    @Test("Un delai leve par le transport interne est journalise aussi")
    func delaiDuTransportInterne() async throws {
        let espion = TransportEspion([.init("https://api.exemple.net", ReponseHttp(code: 200))])
        let journal = JournalDExtensionsEnMemoire()
        let transport = try TransportDExtension(
            interne: TransportQuiExpire(),
            listeBlanche: listeBlancheDeTest("api.exemple.net"),
            identifiantDExtension: "exemple.catalogue",
            journal: journal,
            maintenant: { Self.instant }
        )

        _ = espion

        await #expect(throws: ErreurReseau.delaiDepasse) {
            try await transport.executer(requeteDeTest("https://api.exemple.net/serie"))
        }

        #expect(await journal.consignes.first?.motif == .delaiDepasse)
        #expect(await journal.consignes.first?.domaine == "api.exemple.net")
    }

    // MARK: Journal

    @Test("Le journal ne garde que les refus les plus recents, et compte tous")
    func plafondDuJournal() async {
        let journal = JournalDExtensionsEnMemoire(plafond: 2)

        for rang in 0..<5 {
            await journal.consigner(
                RefusDExtension(
                    extensionVisee: "exemple.catalogue",
                    domaine: "hote\(rang).exemple.org",
                    motif: .domaineHorsListe,
                    instant: Self.instant
                )
            )
        }

        #expect(await journal.consignes.count == 2)
        #expect(await journal.nombreDeRefus(pour: "exemple.catalogue") == 5)
        #expect(await journal.domainesRefuses(pour: "exemple.catalogue") == [
            "hote3.exemple.org",
            "hote4.exemple.org",
        ])
    }

    /// La regle de journalisation de la section 11 interdit d ecrire autre
    /// chose que le domaine : ni chemin, ni parametre, ni titre de serie.
    @Test("La ligne de journal ne porte que le motif, l extension et le domaine")
    func ligneSansDonneePersonnelle() async throws {
        let espion = TransportEspion()
        let journal = JournalDExtensionsEnMemoire()
        let transport = try barriere(espion: espion, journal: journal)

        await #expect(throws: ErreurReseau.self) {
            try await transport.executer(
                requeteDeTest("https://attaquant.org/collecte?serie=Titre+Secret&compte=moi")
            )
        }

        let ligne = try #require(await journal.consignes.first?.ligneDeJournal)

        #expect(ligne == "extension.refus domaineHorsListe exemple.catalogue attaquant.org")
        #expect(ligne.contains("Titre") == false)
        #expect(ligne.contains("collecte") == false)
    }

    // MARK: Outils

    /// La barriere de test, posee sur un seul domaine autorise.
    private func barriere(
        espion: TransportEspion,
        journal: JournalDExtensionsEnMemoire,
        delai: Duration = TransportDExtension.delaiParDefaut
    ) throws -> TransportDExtension {
        try TransportDExtension(
            interne: espion,
            listeBlanche: listeBlancheDeTest("api.exemple.net"),
            identifiantDExtension: "exemple.catalogue",
            journal: journal,
            delaiMaximal: delai,
            maintenant: { Self.instant }
        )
    }
}

/// Transport qui leve toujours un delai depasse, comme URLSession le ferait.
struct TransportQuiExpire: TransportHttp {
    func executer(_ requete: URLRequest) async throws -> ReponseHttp {
        throw ErreurReseau.delaiDepasse
    }
}
