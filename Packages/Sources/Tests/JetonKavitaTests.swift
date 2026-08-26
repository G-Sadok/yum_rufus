import Core
import Foundation
import Testing
@testable import Sources

//
// JetonKavitaTests
//
// Le premier critere de la fonctionnalite : le jeton expire est rafraichi sans
// interruption de lecture.
//
// La phrase porte deux exigences distinctes, et les deux sont couvertes ici
// separement.
//
// Rafraichi, d abord. Deux chemins y menent et les deux existent : l echeance
// lue dans le jeton, qui declenche le renouvellement avant le depart de la
// requete, et le refus du serveur, qui le declenche apres. Le second est le
// filet du premier, pour les serveurs dont l horloge derive.
//
// Sans interruption, ensuite. Ce n est pas la meme chose que rafraichi. Une
// session qui renouvelle correctement mais laisse remonter le refus, ou qui
// lance dix connexions pour dix pages prechargees, rafraichit et interrompt
// quand meme. Les tests de rafale et de chaine de lecture couvrent cela.
//

struct JetonKavitaTests {
    // MARK: Lecture de l echeance

    @Test("L echeance est lue dans le jeton lui meme")
    func echeanceLueDansLeJeton() throws {
        let echeance = Date(timeIntervalSince1970: 1_800_003_600)
        let lue = try #require(LecteurDeJetonJwt.expiration(de: JetonDeTest.jwt(expirantA: echeance)))

        #expect(abs(lue.timeIntervalSince(echeance)) < 1)
    }

    @Test("Un jeton qui n est pas un JWT n a pas d echeance lisible")
    func echeanceAbsente() {
        #expect(LecteurDeJetonJwt.expiration(de: JetonDeTest.opaque) == nil)
        #expect(LecteurDeJetonJwt.expiration(de: "a.b") == nil)
        #expect(LecteurDeJetonJwt.expiration(de: "a.!!!.c") == nil)
        // Trois segments bien formes, mais aucune revendication d echeance.
        #expect(LecteurDeJetonJwt.expiration(de: JetonDeTest.sansEcheance) == nil)
    }

    @Test("Un jeton sans echeance lisible est employe jusqu au premier refus")
    func jetonSansEcheanceUtilisable() {
        let jeton = try? JetonKavita(
            JetonDeKavita(token: JetonDeTest.opaque, refreshToken: nil, apiKey: nil),
            cleDApi: nil
        )

        #expect(jeton?.expiration == nil)
        #expect(jeton?.estUtilisable(a: ServeurKavitaDeTest.maintenant, marge: 30) == true)
    }

    @Test("La marge fait declarer perime un jeton encore valable une seconde")
    func margeAvantExpiration() throws {
        let maintenant = ServeurKavitaDeTest.maintenant
        let jeton = try JetonKavita(
            JetonDeKavita(
                token: JetonDeTest.jwt(expirantA: maintenant.addingTimeInterval(1)),
                refreshToken: nil,
                apiKey: nil
            ),
            cleDApi: nil
        )

        // Sans marge il passerait : la requete partirait, et se ferait refuser
        // sur le fil pendant que le jeton expire en vol.
        #expect(jeton.estUtilisable(a: maintenant, marge: 0))
        #expect(jeton.estUtilisable(a: maintenant, marge: SessionKavita.margeAvantExpiration) == false)
    }

    // MARK: Rafraichissement anticipe

    @Test("Un jeton range deja perime est rafraichi avant que la requete parte")
    func rafraichissementAnticipe() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source(
            identifiants: .jeton(
                acces: ServeurKavitaDeTest.jetonPerime,
                rafraichissement: "rafraichissement-range"
            )
        )

        let catalogue = try await source.parcourir(.tout, page: 0)

        #expect(catalogue.elements.isEmpty == false)
        // Le rafraichissement a eu lieu, la reconnexion non : le trousseau ne
        // porte aucun mot de passe, et une connexion partie ici voudrait dire
        // que le jeton de rafraichissement a ete ignore.
        #expect(await serveur.requetesVers(CheminsKavita.rafraichissement) == 1)
        #expect(await serveur.requetesVers(CheminsKavita.connexion) == 0)
        // Le catalogue n a ete demande qu une fois : la requete n a pas eu a
        // etre rejouee, puisqu elle n est jamais partie avec le jeton perime.
        #expect(await serveur.requetesVers(CheminsKavita.toutesLesSeries) == 1)
    }

    @Test("Un jeton range encore valable est employe tel quel, sans rafraichissement")
    func jetonRangeAdopte() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source(
            identifiants: .jeton(
                acces: ServeurKavitaDeTest.jetonValable,
                rafraichissement: "rafraichissement-range"
            )
        )

        let catalogue = try await source.parcourir(.tout, page: 0)

        #expect(catalogue.elements.isEmpty == false)
        // Un jeton range hier et valable une heure vaut encore. Le rafraichir
        // sans raison coute un aller retour a chaque lancement et fait tourner
        // le jeton de rafraichissement pour rien.
        #expect(await serveur.requetesVers(CheminsKavita.rafraichissement) == 0)
        #expect(await serveur.requetesVers(CheminsKavita.connexion) == 0)
        #expect(
            await serveur.transport.derniere?.entete("Authorization")
                == "Bearer " + ServeurKavitaDeTest.jetonValable
        )
    }

    @Test("Le jeton rafraichi remplace celui du trousseau")
    func jetonRafraichiRange() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source(
            identifiants: .jeton(
                acces: ServeurKavitaDeTest.jetonPerime,
                rafraichissement: "rafraichissement-range"
            )
        )

        _ = try await source.parcourir(.tout, page: 0)

        guard case let .jeton(acces, rafraichissement, expiration) =
            await serveur.magasin.identifiants(pour: serveur.id)
        else {
            Issue.record("Le trousseau ne porte plus un jeton")

            return
        }

        #expect(acces == ServeurKavitaDeTest.jetonValable)
        #expect(rafraichissement == "rafraichissement-suivant")
        #expect(expiration == LecteurDeJetonJwt.expiration(de: ServeurKavitaDeTest.jetonValable))
    }

    @Test("Un compte et un mot de passe restent dans le trousseau, jamais remplaces")
    func motDePasseJamaisRemplace() async throws {
        let serveur = ServeurKavitaDeTest(ServeurKavitaDeTest.reglesCompletes)
        let source = try await serveur.source()

        _ = try await source.parcourir(.tout, page: 0)

        // Ranger le jeton a la place effacerait le mot de passe :
        // `IdentifiantsDeSource` est ferme et ne porte pas les deux. Le jour ou
        // le rafraichissement cesserait de valoir, plus rien ne permettrait de
        // se reconnecter.
        #expect(
            await serveur.magasin.identifiants(pour: serveur.id)
                == .basique(compte: ServeurKavitaDeTest.compte, motDePasse: ServeurKavitaDeTest.motDePasse)
        )
    }

    // MARK: Rafraichissement apres refus

    @Test("Un jeton refuse par le serveur est renouvele et la requete rejouee")
    func rafraichissementApresRefus() async throws {
        let serveur = ServeurKavitaDeTest(Self.reglesAvecJetonRefuse)
        let source = try await serveur.source(
            identifiants: .jeton(acces: JetonDeTest.opaque, rafraichissement: "rafraichissement-range")
        )

        // L appelant ne voit aucune erreur : c est cela, sans interruption.
        let catalogue = try await source.parcourir(.tout, page: 0)

        #expect(catalogue.elements.map(\.titre) == ["Berserk", "vagabond"])
        #expect(await serveur.requetesVers(CheminsKavita.rafraichissement) == 1)
        // Deux passages sur le catalogue : le refus, puis la reprise.
        #expect(await serveur.requetesVers(CheminsKavita.toutesLesSeries) == 2)

        let derniere = try #require(await serveur.transport.derniere)

        #expect(derniere.entete("Authorization") == "Bearer " + ServeurKavitaDeTest.jetonValable)
    }

    @Test("Un rafraichissement refuse fait repartir sur le mot de passe range")
    func repliSurLaReconnexion() async throws {
        var regles = Self.reglesAvecJetonRefuse
        // Le jeton de rafraichissement a expire lui aussi, ce qui arrive apres
        // quelques semaines sans ouvrir l application.
        regles.insert(.statut(CheminsKavita.rafraichissement, 401, methode: .post), at: 0)

        let serveur = ServeurKavitaDeTest(regles)
        let source = try await serveur.source(
            identifiants: .basique(
                compte: ServeurKavitaDeTest.compte,
                motDePasse: ServeurKavitaDeTest.motDePasse
            )
        )

        let catalogue = try await source.parcourir(.tout, page: 0)

        #expect(catalogue.elements.isEmpty == false)
        #expect(await serveur.requetesVers(CheminsKavita.connexion) == 1)
    }

    @Test("Des identifiants refuses ne sont pas retentes en boucle")
    func refusDefinitifNonRetente() async throws {
        let serveur = ServeurKavitaDeTest([
            .statut(CheminsKavita.connexion, 401, methode: .post),
        ])
        let source = try await serveur.source()

        #expect(await source.verifierConnexion() == .identifiantsInvalides)
        // Une seule tentative : reessayer en boucle serait la meilleure facon
        // de faire bloquer le compte de l utilisateur par le serveur.
        #expect(await serveur.requetesVers(CheminsKavita.connexion) == 1)
    }

    @Test("Un jeton range sans rafraichissement ne se repare pas tout seul")
    func jetonSansRafraichissementRefuse() async throws {
        let serveur = ServeurKavitaDeTest(Self.reglesAvecJetonRefuse)
        let source = try await serveur.source(
            identifiants: .jeton(acces: JetonDeTest.opaque)
        )

        // Le serveur n emet un jeton que contre un mot de passe ou une cle. La
        // sortie est la feuille de configuration, et c est ce que cet etat la
        // ouvre.
        #expect(await source.verifierConnexion() == .identifiantsInvalides)
        #expect(await serveur.requetesVers(CheminsKavita.rafraichissement) == 0)
    }

    // MARK: Rafale de requetes

    @Test("Dix requetes refusees ensemble ne declenchent qu un seul renouvellement")
    func rafaleNeRenouvelleQuUneFois() async throws {
        let serveur = ServeurKavitaDeTest(Self.reglesAvecJetonRefuse)
        let source = try await serveur.source(
            identifiants: .jeton(acces: JetonDeTest.opaque, rafraichissement: "rafraichissement-range")
        )

        // C est la situation d une precharge : plusieurs requetes partent
        // ensemble, et le jeton expire pendant le paquet.
        await withTaskGroup(of: Void.self) { groupe in
            for _ in 0..<10 {
                groupe.addTask {
                    _ = try? await source.parcourir(.tout, page: 0)
                }
            }
        }

        // Sans la tache de renouvellement partagee, dix connexions partiraient
        // pour la meme expiration, et le serveur en refuserait une partie.
        #expect(await serveur.requetesVers(CheminsKavita.rafraichissement) == 1)
    }

    // MARK: Regles de test

    /// Un serveur qui refuse le jeton opaque et accepte celui qu il vient
    /// d emettre.
    ///
    /// C est la seule facon de prouver que la requete a ete rejouee avec un
    /// jeton neuf, et non simplement rejouee.
    private static var reglesAvecJetonRefuse: [RegleDeTransport] {
        let refus = RegleDeTransport(
            methode: .post,
            chemin: CheminsKavita.toutesLesSeries,
            reponse: ReponseHttp(code: 401, corps: Data("{}".utf8))
        )
        .exigeant(entete: "Authorization", "Bearer " + JetonDeTest.opaque)

        return ServeurKavitaDeTest.reglesSurchargees(par: refus)
    }
}
