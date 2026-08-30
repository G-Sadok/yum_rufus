import Core
import Foundation
import Testing
@testable import Sources

//
// RevocationDuJetonDuPontTests
//
// Le troisieme critere, la revocation immediate, et les refus que le serveur
// oppose a un envoi qu il ne peut pas prendre en charge.
//
// La revocation est prouvee sur la meme requete, envoyee deux fois, sans rien
// redemarrer entre les deux. C est ce qui distingue une revocation immediate
// d une revocation au prochain lancement : un serveur qui garderait une copie
// du jeton en memoire passerait le premier envoi et passerait le second aussi,
// et seule la seconde requete le revele.
//
// Le serveur est interroge directement dans une partie de ces tests, sans
// passer par l ecoute. C est la seule facon de prouver ce qu il repond quand il
// est ferme : a travers l ecoute, un pont desactive ne repond rien du tout,
// puisque personne n ecoute plus.
//

struct RevocationDuJetonDuPontTests {
    // MARK: La revocation du jeton est immediate

    @Test("Le jeton revoque est refuse des la requete suivante")
    func revocationRefuseLaRequeteSuivante() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let requete = RequeteDuPontDeTest.envoi(jeton: atelier.jetonPresente)

        let avant = try await atelier.ecoute.envoyer(requete)

        #expect(avant.code == 202)

        try await atelier.pont.revoquer()

        let apres = try await atelier.ecoute.envoyer(requete)

        #expect(apres.code == 401)
        #expect(apres.corpsContient(ErreurDuPont.jetonAbsent.codeDeJournal))
        #expect(await atelier.reception.recus.count == 1)
    }

    @Test("La revocation ne demande ni redemarrage ni fermeture du pont")
    func revocationSansRedemarrage() async throws {
        let atelier = try await AtelierDuPont.ouvert()

        try await atelier.pont.revoquer()

        #expect(await atelier.pont.estActif)
        #expect(await atelier.ecoute.enEcoute)
        #expect(await atelier.ecoute.arrets == 0)
        #expect(await atelier.ecoute.demarrages == 1)
    }

    @Test("Le jeton revoque disparait du magasin et de ce que le pont partage")
    func leJetonRevoqueDisparait() async throws {
        let atelier = try await AtelierDuPont.ouvert()

        try await atelier.pont.revoquer()

        let partage = try await atelier.pont.jetonAPartager()

        #expect(await atelier.jetons.jeton() == nil)
        #expect(partage == nil)
        #expect(await atelier.jetons.revocations == 1)
    }

    @Test("Le renouvellement refuse l ancien jeton et accepte le neuf")
    func renouvellementRefuseLAncienJeton() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let neuf = try await atelier.pont.renouvelerLeJeton()

        let ancien = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(jeton: atelier.jetonPresente)
        )
        let recent = try await atelier.ecoute.envoyer(RequeteDuPontDeTest.envoi(jeton: neuf.valeur))

        #expect(ancien.code == 401)
        #expect(ancien.corpsContient(ErreurDuPont.jetonRefuse.codeDeJournal))
        #expect(recent.code == 202)
        #expect(await atelier.reception.recus.count == 1)
    }

    @Test("Deux renouvellements de suite ne rendent jamais le meme jeton")
    func deuxRenouvellementsDonnentDeuxJetons() async throws {
        let atelier = try await AtelierDuPont.ouvert()

        let premier = try await atelier.pont.renouvelerLeJeton()
        let second = try await atelier.pont.renouvelerLeJeton()

        #expect(premier != second)
        #expect(premier.valeur.count == JetonDuPont.nombreDeChiffres)
    }

    // MARK: Le serveur ferme ne sert rien

    @Test("Un serveur jamais ouvert refuse tout, meme avec le bon jeton")
    func serveurJamaisOuvertRefuseTout() async throws {
        let jeton = try #require(JetonDuPont(MaterielDuPont.jeton()))
        let serveur = ServeurDuPontNavigateur(
            jetons: MagasinDeJetonDuPontEnMemoire(jeton: jeton),
            reception: ReceptionDuNavigateurSimulee()
        )

        let reponse = try await ReponseDeTest.lire(
            serveur.repondre(
                auxOctets: RequeteDuPontDeTest.envoi(jeton: jeton.valeur),
                depuis: .bouclageIPv4
            )
        )

        #expect(reponse.code == 503)
        #expect(reponse.corpsContient(ErreurDuPont.pontDesactive.codeDeJournal))
    }

    @Test("Un serveur referme cesse de servir")
    func serveurRefermeCesseDeServir() async throws {
        let jeton = try #require(JetonDuPont(MaterielDuPont.jeton()))
        let serveur = ServeurDuPontNavigateur(
            jetons: MagasinDeJetonDuPontEnMemoire(jeton: jeton),
            reception: ReceptionDuNavigateurSimulee()
        )

        await serveur.ouvrir()

        let requete = RequeteDuPontDeTest.envoi(jeton: jeton.valeur)
        let avant = try await ReponseDeTest.lire(serveur.repondre(auxOctets: requete, depuis: .bouclageIPv6))

        #expect(avant.code == 202)

        await serveur.fermer()

        let apres = try await ReponseDeTest.lire(serveur.repondre(auxOctets: requete, depuis: .bouclageIPv6))

        #expect(apres.code == 503)
    }

    @Test("Un trousseau qui refuse de repondre n est pas annonce comme un jeton faux")
    func trousseauEnPanneNEstPasUnJetonFaux() async throws {
        let serveur = ServeurDuPontNavigateur(
            jetons: MagasinDeJetonEnPanne(),
            reception: ReceptionDuNavigateurSimulee()
        )

        await serveur.ouvrir()

        let reponse = try await ReponseDeTest.lire(
            serveur.repondre(
                auxOctets: RequeteDuPontDeTest.envoi(jeton: MaterielDuPont.jeton()),
                depuis: .bouclageIPv4
            )
        )

        #expect(reponse.code == 500)
        #expect(reponse.corpsContient(ErreurDuPont.receptionImpossible.codeDeJournal))
    }

    // MARK: Ce que le pont refuse de transmettre

    @Test("Une requete qui n est pas du JSON est refusee")
    func requeteQuiNEstPasDuJsonRefusee() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(
                jeton: atelier.jetonPresente,
                typeDeContenu: "application/x-www-form-urlencoded"
            )
        )

        #expect(reponse.code == 400)
        #expect(await atelier.reception.recus.isEmpty)
    }

    @Test("Un corps illisible est refuse")
    func corpsIllisibleRefuse() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi("{ceci n est pas du json", jeton: atelier.jetonPresente)
        )

        #expect(reponse.code == 400)
        #expect(reponse.corpsContient(ErreurDuPont.envoiIllisible.codeDeJournal))
    }

    @Test(
        "Une adresse qui n est pas en HTTPS est refusee",
        arguments: [
            "http://catalogue.exemple.net/serie/4217",
            "file:///Users/lecteur/Documents/serie.cbz",
            "javascript:alert(1)",
        ]
    )
    func adresseHorsHttpsRefusee(adresse: String) async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(
                RequeteDuPontDeTest.corpsDUnEnvoi(adresse: adresse),
                jeton: atelier.jetonPresente
            )
        )

        #expect(reponse.code == 400, "\(adresse)")
        #expect(reponse.corpsContient(ErreurDuPont.adresseRefusee.codeDeJournal), "\(adresse)")
        #expect(await atelier.reception.recus.isEmpty, "\(adresse)")
    }

    @Test("Un envoi sans titre est refuse")
    func envoiSansTitreRefuse() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(
                RequeteDuPontDeTest.corpsDUnEnvoi(titre: "   "),
                jeton: atelier.jetonPresente
            )
        )

        #expect(reponse.code == 400)
        #expect(reponse.corpsContient(ErreurDuPont.envoiIllisible.codeDeJournal))
    }

    @Test("Une reception qui refuse l envoi ne fait pas passer la requete pour reussie")
    func receptionQuiRefuseNeFaitPasPasserPourReussie() async throws {
        let atelier = try await AtelierDuPont.ouvert()

        await atelier.reception.opposer(.receptionImpossible)

        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(jeton: atelier.jetonPresente)
        )

        #expect(reponse.code == 500)
        #expect(await atelier.reception.recus.isEmpty)
    }
}
