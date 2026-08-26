import Core
import Foundation
import Testing
@testable import Sources

//
// TransfertWifiTests
//
// Les trois criteres de la section 4.4, chacun prouve sur le comportement et
// non sur la presence d une fonction.
//
// Le cycle de vie est prouve par une ecoute simulee qui refuse de porter une
// requete quand elle n ecoute plus : apres la fermeture de la feuille, ce n est
// pas le serveur qui repond non, c est qu il n y a plus personne.
//
// Le code obligatoire est prouve dans les deux sens. Aucune reponse servie sans
// code ne contient le champ de fichiers, et un depot envoye directement, sans
// jamais passer par la page, n atteint pas la reception.
//
// L arrivee dans la source Fichiers locaux est prouvee sur un vrai dossier, en
// relisant la source apres la fermeture de la feuille et en y trouvant la serie
// deposee.
//

struct TransfertWifiTests {
    private static let codeAffiche = "428193"

    // MARK: Le serveur ne tourne que pendant que la feuille est ouverte

    @Test("La fermeture de la feuille arrete l ecoute")
    func fermetureArreteLEcoute() async throws {
        let ecoute = EcouteSimulee()
        let session = try SessionDeTransfertWifi(reception: ReceptionSimulee(), ecoute: ecoute, code: code())

        let port = try await session.ouvrir()

        #expect(port == ServeurDeTransfertWifi.portParDefaut)
        #expect(await ecoute.enEcoute)
        #expect(await session.estOuverte)

        await session.fermer()

        #expect(await ecoute.enEcoute == false)
        #expect(await ecoute.arrets == 1)
        #expect(await session.estOuverte == false)
        #expect(await session.port == nil)
    }

    @Test("Plus aucune requete n atteint le serveur apres la fermeture")
    func plusAucuneRequeteApresLaFermeture() async throws {
        let ecoute = EcouteSimulee()
        let reception = ReceptionSimulee()
        let session = try SessionDeTransfertWifi(reception: reception, ecoute: ecoute, code: code())

        try await session.ouvrir()

        let avant = try await ecoute.envoyer(RequeteDeTest.obtenir(CheminsDeLaReception.racine))

        #expect(avant.code == 200)

        await session.fermer()

        await #expect(throws: ErreurDeTransfert.receptionFermee) {
            _ = try await ecoute.envoyer(RequeteDeTest.obtenir(CheminsDeLaReception.racine))
        }
    }

    @Test("La feuille ferme l ecoute meme quand son contenu leve")
    func fermetureMemeSurErreur() async throws {
        let ecoute = EcouteSimulee()

        await #expect(throws: ErreurDeTransfert.requeteMalformee) {
            try await SessionDeTransfertWifi.pendantLaFeuille(
                reception: ReceptionSimulee(),
                ecoute: ecoute,
                code: code()
            ) { _ in
                throw ErreurDeTransfert.requeteMalformee
            }
        }

        #expect(await ecoute.enEcoute == false)
        #expect(await ecoute.demarrages == 1)
        #expect(await ecoute.arrets == 1)
    }

    @Test("La feuille ferme l ecoute a la sortie normale")
    func fermetureALaSortieNormale() async throws {
        let ecoute = EcouteSimulee()

        let port = try await SessionDeTransfertWifi.pendantLaFeuille(
            reception: ReceptionSimulee(),
            ecoute: ecoute,
            code: code()
        ) { session in
            #expect(await session.estOuverte)

            return await session.port
        }

        #expect(port == ServeurDeTransfertWifi.portParDefaut)
        #expect(await ecoute.enEcoute == false)
        #expect(await ecoute.arrets == 1)
    }

    @Test("Une session fermee ne se rouvre pas")
    func sessionFermeeNeSeRouvrePas() async throws {
        let session = try SessionDeTransfertWifi(reception: ReceptionSimulee(), ecoute: EcouteSimulee(), code: code())

        try await session.ouvrir()
        await session.fermer()

        await #expect(throws: ErreurDeTransfert.receptionFermee) {
            _ = try await session.ouvrir()
        }
    }

    @Test("La reception est conclue une fois a la fermeture")
    func receptionConclueALaFermeture() async throws {
        let reception = ReceptionSimulee()
        let session = try SessionDeTransfertWifi(reception: reception, ecoute: EcouteSimulee(), code: code())

        try await session.ouvrir()
        await session.fermer()
        await session.fermer()

        #expect(await reception.conclusions == 1)
    }

    // MARK: Le code a six chiffres est obligatoire

    @Test("Sans code, la page ne contient aucun champ de fichier")
    func sansCodeAucunChampDeFichier() async throws {
        let ecoute = try await receptionOuverte().ecoute
        let page = try await ecoute.envoyer(RequeteDeTest.obtenir(CheminsDeLaReception.racine))

        #expect(page.code == 200)
        #expect(page.corpsContient("name=\"\(PageDeDepot.champDuCode)\""))
        #expect(page.corpsContient("type=\"file\"") == false)
    }

    @Test("Un depot sans code est refuse et n atteint pas la reception")
    func depotSansCodeRefuse() async throws {
        let ouverte = try await receptionOuverte()
        let depot = try await ouverte.ecoute.envoyer(
            RequeteDeTest.deposer([(nom: "Tome 1.cbz", contenu: Data("archive".utf8))])
        )

        #expect(depot.code == 401)
        #expect(depot.corpsContient("type=\"file\"") == false)
        #expect(await ouverte.reception.recus.isEmpty)
    }

    @Test("Un code faux est refuse et n ouvre aucune session")
    func codeFauxRefuse() async throws {
        let ouverte = try await receptionOuverte()
        let refus = try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode("000000"))

        #expect(refus.code == 401)
        #expect(refus.biscuitPose == nil)
        #expect(refus.corpsContient("type=\"file\"") == false)
    }

    @Test("Un code de longueur differente est refuse")
    func codeDeMauvaiseLongueurRefuse() async throws {
        let ouverte = try await receptionOuverte()

        for saisie in ["", "4281", "4281930", "42819a"] {
            let refus = try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode(saisie))

            #expect(refus.code == 401)
            #expect(refus.biscuitPose == nil)
        }
    }

    @Test("Le code juste ouvre la page de depot")
    func codeJusteOuvreLaPageDeDepot() async throws {
        let ouverte = try await receptionOuverte()
        let accepte = try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode(Self.codeAffiche))

        #expect(accepte.code == 303)
        #expect(accepte.entete("location") == CheminsDeLaReception.racine)

        let biscuit = try #require(accepte.biscuitPose)
        let page = try await ouverte.ecoute.envoyer(
            RequeteDeTest.obtenir(CheminsDeLaReception.racine, biscuit: biscuit)
        )

        #expect(page.code == 200)
        #expect(page.corpsContient("type=\"file\""))
    }

    @Test("Un jeton invente ne vaut pas un code")
    func jetonInventeRefuse() async throws {
        let ouverte = try await receptionOuverte()

        _ = try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode(Self.codeAffiche))

        let depot = try await ouverte.ecoute.envoyer(
            RequeteDeTest.deposer(
                [(nom: "Tome 1.cbz", contenu: Data("archive".utf8))],
                biscuit: String(repeating: "a", count: 32)
            )
        )

        #expect(depot.code == 401)
        #expect(await ouverte.reception.recus.isEmpty)
    }

    @Test("Dix codes faux verrouillent la reception, meme pour le bon code")
    func plafondDEssais() async throws {
        let ouverte = try await receptionOuverte()

        for _ in 0..<(ServeurDeTransfertWifi.plafondDEssais - 1) {
            let refus = try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode("000000"))

            #expect(refus.code == 401)
        }

        let dernier = try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode("000000"))

        #expect(dernier.code == 423)

        let apres = try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode(Self.codeAffiche))

        #expect(apres.code == 423)
        #expect(apres.biscuitPose == nil)
    }

    // MARK: Acheminement

    @Test("Un chemin inconnu ne sert rien")
    func cheminInconnu() async throws {
        let ouverte = try await receptionOuverte()
        let reponse = try await ouverte.ecoute.envoyer(RequeteDeTest.obtenir("/.env"))

        #expect(reponse.code == 404)
    }

    @Test("Un formulaire de fichiers vide est refuse sans erreur de format")
    func formulaireVide() async throws {
        let ouverte = try await receptionOuverte()
        let biscuit = try #require(
            try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode(Self.codeAffiche)).biscuitPose
        )
        let depot = try await ouverte.ecoute.envoyer(RequeteDeTest.deposer([], biscuit: biscuit))

        #expect(depot.code == 400)
        #expect(await ouverte.reception.recus.isEmpty)
    }

    @Test("Un depot accepte est annonce comme cree")
    func depotAccepte() async throws {
        let ouverte = try await receptionOuverte()
        let biscuit = try #require(
            try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode(Self.codeAffiche)).biscuitPose
        )
        let depot = try await ouverte.ecoute.envoyer(
            RequeteDeTest.deposer(
                [
                    (nom: "Tome 1.cbz", contenu: Data(repeating: 0x2A, count: 64)),
                    (nom: "Tome 2.cbz", contenu: Data(repeating: 0x2B, count: 32)),
                ],
                biscuit: biscuit
            )
        )

        #expect(depot.code == 201)

        let recus = await ouverte.reception.recus

        #expect(recus.map(\.nom) == ["Tome 1.cbz", "Tome 2.cbz"])
        #expect(recus.map(\.octets) == [64, 32])
    }

    @Test("Un refus de la reception est rendu avec son propre code")
    func refusDeLaReception() async throws {
        let ouverte = try await receptionOuverte()
        let biscuit = try #require(
            try await ouverte.ecoute.envoyer(RequeteDeTest.presenterLeCode(Self.codeAffiche)).biscuitPose
        )

        await ouverte.reception.opposer(.formatNonRecevable(format: "exe"))

        let depot = try await ouverte.ecoute.envoyer(
            RequeteDeTest.deposer([(nom: "outil.exe", contenu: Data("binaire".utf8))], biscuit: biscuit)
        )

        #expect(depot.code == 415)
    }

    // MARK: Details

    private func code() throws -> CodeDeTransfert {
        try #require(CodeDeTransfert(Self.codeAffiche))
    }

    /// Une reception ouverte, avec son ecoute et sa reception simulees.
    private func receptionOuverte() async throws -> ReceptionOuverte {
        let ecoute = EcouteSimulee()
        let reception = ReceptionSimulee()
        let session = try SessionDeTransfertWifi(reception: reception, ecoute: ecoute, code: code())

        try await session.ouvrir()

        return ReceptionOuverte(session: session, ecoute: ecoute, reception: reception)
    }
}

/// Les trois pieces d une reception ouverte pour un test.
///
/// Un type nomme plutot qu un tuple : la session doit rester tenue le temps du
/// test, meme quand celui ci ne parle qu a l ecoute, et trois valeurs anonymes
/// se relisent mal a la troisieme utilisation.
private struct ReceptionOuverte {
    let session: SessionDeTransfertWifi
    let ecoute: EcouteSimulee
    let reception: ReceptionSimulee
}
