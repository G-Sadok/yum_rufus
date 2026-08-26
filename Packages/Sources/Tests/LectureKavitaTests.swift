import Core
import Foundation
import Testing
@testable import Sources

//
// LectureKavitaTests
//
// Seconde moitie du second critere : de la fiche de serie jusqu a la requete
// qui rapporte les octets d une page.
//
// Le dernier test refait la chaine entiere sans fabriquer aucun etat
// intermediaire, et le fait avec un jeton deja perime au depart. C est la
// jonction des deux criteres : chaque etape ne consomme que ce que la
// precedente a reellement rendu, et le renouvellement se produit au milieu sans
// qu aucun appel ne leve.
//

struct LectureKavitaTests {
    // MARK: Fiche

    @Test("La fiche reunit la serie et ses metadonnees")
    func ficheComplete() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let fiche = try await source.detailsManga(String(ReponsesFigeesDeKavita.identifiantDeSerie))

        #expect(fiche.identifiant == String(ReponsesFigeesDeKavita.identifiantDeSerie))
        #expect(fiche.titre == "Berserk")
        #expect(fiche.statut == .enCours)
        #expect(fiche.langue == "ja")
        #expect(fiche.resume == "Un mercenaire marque poursuit ceux qui l ont trahi.")
        // Le genre vide est ecarte, il ferait une puce sans texte sur la fiche.
        #expect(fiche.genres == ["Seinen", "Dark Fantasy"])
        // Le scenariste est cite comme auteur et comme dessinateur, il ne
        // compte qu une fois. L illustrateur de couverture n est pas un auteur
        // tant qu il y en a d autres.
        #expect(fiche.auteurs == ["Kentaro Miura"])
    }

    @Test("Une fiche dont les metadonnees sont refusees reste ouvrable")
    func ficheSansMetadonnees() async throws {
        var regles = ServeurKavitaDeTest.reglesCompletes
        regles.insert(.statut(CheminsKavita.metadonneesDeSerie, 403), at: 0)

        let serveur = ServeurKavitaDeTest(regles)
        let source = try await serveur.source()
        let fiche = try await source.detailsManga(String(ReponsesFigeesDeKavita.identifiantDeSerie))

        // Un serveur qui refuse les metadonnees au compte courant laisse quand
        // meme lire la serie. Une fiche sans resume vaut mieux qu une serie qui
        // ne s ouvre pas.
        #expect(fiche.titre == "Berserk")
        #expect(fiche.resume == nil)
        #expect(fiche.genres.isEmpty)
        #expect(fiche.statut == .inconnu)
    }

    @Test("Un statut de publication inconnu ne fait pas echouer la serie")
    func statutInconnu() async throws {
        var regles = ServeurKavitaDeTest.reglesCompletes
        regles.insert(
            .json(.get, CheminsKavita.metadonneesDeSerie, ReponsesFigeesDeKavita.metadonneesInconnues),
            at: 0
        )

        let serveur = ServeurKavitaDeTest(regles)
        let source = try await serveur.source()
        let fiche = try await source.detailsManga(String(ReponsesFigeesDeKavita.identifiantDeSerie))

        #expect(fiche.statut == .inconnu)
        #expect(fiche.resume == nil)
        #expect(fiche.langue == nil)
    }

    @Test("Une serie absente nomme la serie, pas le code HTTP")
    func serieIntrouvable() async throws {
        let serveur = ServeurKavitaDeTest([
            .json(.post, CheminsKavita.connexion, ReponsesFigeesDeKavita.connexion(
                jeton: ServeurKavitaDeTest.jetonValable
            )),
            .statut(CheminsKavita.serie(999), 404),
        ])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.mangaIntrouvable(identifiant: "999")) {
            _ = try await source.detailsManga("999")
        }
    }

    @Test("Un identifiant qui n est pas un nombre ne part pas en requete")
    func identifiantNonNumerique() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.mangaIntrouvable(identifiant: "berserk")) {
            _ = try await source.detailsManga("berserk")
        }
        // Kavita numerote ses series. Une requete partie ici reviendrait de
        // toute facon en 404, apres un aller retour perdu.
        #expect(await serveur.transport.journal.isEmpty)
    }

    // MARK: Chapitres

    @Test("Les chapitres suivent l ordre des volumes, hors volume en dernier")
    func ordreDesChapitres() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let serie = String(ReponsesFigeesDeKavita.identifiantDeSerie)
        let chapitres = try await source.chapitres(pour: serie)

        #expect(chapitres.count == 4)
        #expect(chapitres.map(\.ordre) == [0, 1, 2, 3])
        // Le serveur a rendu le volume deux avant le volume un, et le paquet
        // hors volume au milieu. Trie sur le seul numero de chapitre, le
        // chapitre cinq passerait avant le trois.
        #expect(chapitres.map(\.identifiant) == ["401", "402", "403", "404"])
        #expect(chapitres.map(\.identifiantManga).allSatisfy { $0 == serie })
    }

    @Test("Un chapitre qui n a que son intervalle prend le debut pour numero")
    func numeroDepuisLIntervalle() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let chapitres = try await source.chapitres(
            pour: String(ReponsesFigeesDeKavita.identifiantDeSerie)
        )

        // Un chapitre qui couvre les tomes trois a quatre annonce `3-4` et se
        // lit a la place du trois.
        #expect(chapitres.map(\.numero) == [1, 2, 3, 5])
    }

    @Test("Un titre qui recopie le numero n est pas affiche")
    func titreRecopieEcarte() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let chapitres = try await source.chapitres(
            pour: String(ReponsesFigeesDeKavita.identifiantDeSerie)
        )

        // Le deuxieme chapitre porte `2` en titre, le troisieme `3-4` : les
        // afficher donnerait une liste ou chaque ligne repete son numero.
        #expect(chapitres.map(\.titre) == ["L oeuf du roi", nil, nil, "Hors volume"])
    }

    @Test("La date minimale du serveur est traitee comme une absence de date")
    func dateNulleEcartee() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let chapitres = try await source.chapitres(
            pour: String(ReponsesFigeesDeKavita.identifiantDeSerie)
        )

        #expect(chapitres.map(\.datePublication) == [
            DatesDeTest.jour(1990, 11, 26),
            DatesDeTest.jour(1991, 3, 8),
            // Le serveur ecrit la date minimale de sa plateforme quand il ne
            // connait rien. Elle se decode parfaitement et afficherait une
            // parution de l an un.
            nil,
            nil,
        ])
    }

    @Test("Zero page veut dire inconnu, jamais vide")
    func nombreDePagesInconnu() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let chapitres = try await source.chapitres(
            pour: String(ReponsesFigeesDeKavita.identifiantDeSerie)
        )

        // Le laisser passer marquerait le chapitre lu des son ouverture, la
        // part lue etant calculee sur un total nul.
        #expect(chapitres.map(\.nombrePages) == [3, 20, 12, nil])
    }
}

//
// PagesKavitaTests
//
// La seconde moitie de la lecture : les pages d un chapitre, la requete qui
// rapporte leurs octets, et la chaine complete.
//
// Elle est separee de la fiche et des chapitres parce que ce qui s y verifie
// n est plus une traduction de metadonnees mais une adresse. Une page mal
// numerotee ou privee de sa cle d API se voit a l ecran, pas dans un decodage.
//

struct PagesKavitaTests {
    // MARK: Pages

    @Test("Les pages sont indexees a partir de zero, comme les adresses du serveur")
    func pagesIndexeesAPartirDeZero() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let chapitre = String(ReponsesFigeesDeKavita.identifiantDuPremierChapitre)
        let pages = try await source.pages(pour: chapitre)

        #expect(pages.map(\.index) == [0, 1, 2])
        #expect(pages.allSatisfy { $0.identifiantChapitre == chapitre })
        #expect(pages.allSatisfy { $0.estDansUnConteneur == false })

        // Kavita indexe ses pages a partir de zero, contrairement a Komga.
        // Recopier la conversion de Komga decalerait tout le chapitre.
        let premiere = try #require(pages.first)
        let composants = try #require(
            URLComponents(url: premiere.emplacement, resolvingAgainstBaseURL: false)
        )

        #expect(composants.path.hasSuffix("/api/Reader/image"))
        #expect(composants.queryItems?.first { $0.name == "page" }?.value == "0")
        #expect(composants.queryItems?.first { $0.name == "chapterId" }?.value == chapitre)
    }

    @Test("L adresse d une page porte la cle d API, que la chaine d images ne sait pas poser")
    func pagesPortentLaCleDApi() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let pages = try await source.pages(
            pour: String(ReponsesFigeesDeKavita.identifiantDuPremierChapitre)
        )
        let premiere = try #require(pages.first)

        // C est cette cle, et non le jeton, qui fait qu une page continue de
        // s afficher pendant qu une session se renouvelle.
        #expect(premiere.emplacement.absoluteString.contains("apiKey=\(ServeurKavitaDeTest.cleDApi)"))
    }

    @Test("Un chapitre que le serveur n a pas analyse ne rend aucune page")
    func chapitreSansPage() async throws {
        var regles = ServeurKavitaDeTest.reglesCompletes
        regles.insert(
            .json(.get, CheminsKavita.infoDeChapitre, #"{"pages": 0, "seriesId": 17, "volumeId": 91}"#),
            at: 0
        )

        let serveur = ServeurKavitaDeTest(regles)
        let source = try await serveur.source()
        let pages = try await source.pages(pour: "401")

        // Inventer des pages ferait une lecture ou chaque page rend une erreur.
        #expect(pages.isEmpty)
    }

    @Test("Un chapitre absent nomme le chapitre, pas le code HTTP")
    func chapitreIntrouvable() async throws {
        let serveur = ServeurKavitaDeTest([
            .json(.post, CheminsKavita.connexion, ReponsesFigeesDeKavita.connexion(
                jeton: ServeurKavitaDeTest.jetonValable
            )),
            .statut(CheminsKavita.infoDeChapitre, 404),
        ])
        let source = try await serveur.source()

        await #expect(throws: ErreurDeSource.chapitreIntrouvable(identifiant: "777")) {
            _ = try await source.pages(pour: "777")
        }
    }

    @Test("Le repere d un chapitre n est demande qu une fois")
    func repereRetenu() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let chapitre = String(ReponsesFigeesDeKavita.identifiantDuPremierChapitre)

        _ = try await source.pages(pour: chapitre)
        _ = try await source.pages(pour: chapitre)
        _ = try await source.progression(pour: chapitre)

        // Les identifiants d un chapitre ne changent jamais. Les redemander a
        // chaque tourne de page doublerait le nombre de requetes d une lecture.
        #expect(await serveur.requetesVers(CheminsKavita.infoDeChapitre) == 1)
    }

    // MARK: Requete d image

    @Test("La requete d image porte l identite de la source")
    func requeteImageAuthentifiee() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let pages = try await source.pages(
            pour: String(ReponsesFigeesDeKavita.identifiantDuPremierChapitre)
        )
        let page = try #require(pages.first)
        let requete = try await source.requeteImage(pour: page)

        #expect(requete.url == page.emplacement)
        #expect(requete.value(forHTTPHeaderField: "Authorization") == "Bearer " + ServeurKavitaDeTest.jetonValable)
    }

    @Test("Une page rangee dans un conteneur n est pas adressable par requete")
    func requeteImageRefuseeSurUnConteneur() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()
        let page = try PageDistante(
            identifiantChapitre: "401",
            index: 0,
            emplacement: #require(ReponsesFigeesDeKavita.adresse),
            entree: "001.jpg"
        )

        await #expect(throws: ErreurDeSource.pageNonAdressableParRequete(entree: "001.jpg")) {
            _ = try await source.requeteImage(pour: page)
        }
    }

    // MARK: De bout en bout

    @Test("Connexion, parcours puis lecture s enchainent sans etat fabrique")
    func chaineComplete() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .connecte)

        let catalogue = try await source.parcourir(.tout, page: 0)
        let premiere = try #require(catalogue.elements.first)
        let fiche = try await source.detailsManga(premiere.identifiant)
        let chapitres = try await source.chapitres(pour: fiche.identifiant)
        let premierChapitre = try #require(chapitres.first)
        let pages = try await source.pages(pour: premierChapitre.identifiant)
        let premierePage = try #require(pages.first)
        let requete = try await source.requeteImage(pour: premierePage)

        #expect(fiche.titre == "Berserk")
        #expect(chapitres.count == 4)
        #expect(pages.count == 3)
        #expect(premierChapitre.nombrePages == pages.count)
        #expect(requete.url?.absoluteString.contains("chapterId=401") == true)
    }

    @Test("La meme chaine part d un jeton perime et ne leve nulle part")
    func chaineCompleteAvecJetonPerime() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source(
            identifiants: .jeton(
                acces: ServeurKavitaDeTest.jetonPerime,
                rafraichissement: "rafraichissement-range"
            )
        )

        let catalogue = try await source.parcourir(.tout, page: 0)
        let premiere = try #require(catalogue.elements.first)
        let chapitres = try await source.chapitres(pour: premiere.identifiant)
        let premierChapitre = try #require(chapitres.first)
        let pages = try await source.pages(pour: premierChapitre.identifiant)
        let premierePage = try #require(pages.first)
        let requete = try await source.requeteImage(pour: premierePage)

        #expect(pages.count == 3)
        // Un seul renouvellement pour toute la chaine, et aucune interruption :
        // la lecture ne sait meme pas que le jeton a change.
        #expect(await serveur.requetesVers(CheminsKavita.rafraichissement) == 1)
        #expect(requete.value(forHTTPHeaderField: "Authorization") == "Bearer " + ServeurKavitaDeTest.jetonValable)
    }

    @Test("Un serveur publie derriere un sous chemin garde ce sous chemin")
    func sousCheminDeProxyConserve() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let identite = SourceID()

        await serveur.magasin.enregistrer(
            .basique(compte: ServeurKavitaDeTest.compte, motDePasse: ServeurKavitaDeTest.motDePasse),
            pour: identite
        )

        let source = try SourceKavita(
            id: identite,
            nom: serveur.nom,
            configuration: ConfigurationDeSource(
                adresse: ReponsesFigeesDeKavita.adresse,
                chemin: "kavita",
                authentification: .basique
            ),
            magasin: serveur.magasin,
            transport: serveur.transport,
            maintenant: { ServeurKavitaDeTest.maintenant }
        )

        #expect(await source.verifierConnexion() == .connecte)

        let journal = await serveur.transport.journal

        #expect(journal.first?.chemin == "/kavita/api/Account/login")
        #expect(journal.last?.chemin == "/kavita/api/Series/all-v2")
    }
}
