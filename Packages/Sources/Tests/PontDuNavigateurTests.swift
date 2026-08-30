import Core
import Foundation
import Testing
@testable import Sources

//
// PontDuNavigateurTests
//
// Les deux premiers criteres de la fonctionnalite, chacun prouve sur le
// comportement et non sur la presence d une fonction.
//
// Le pont desactive par defaut est prouve deux fois. Le catalogue de reglages
// rend faux sur une installation neuve, et appliquer ces reglages la ne fait
// rien du tout : aucun port demande, aucun jeton tire, aucune ligne de
// trousseau creee. Le second point compte autant que le premier. Un pont qui
// tirerait son jeton a la construction laisserait un secret derriere lui sur
// une installation ou l utilisateur n a jamais rien active.
//
// La socket qui n accepte que les connexions locales authentifiees est prouvee
// sur les deux moities de la phrase, jamais sur une seule. Une requete parfaite
// venue d une machine du reseau est refusee, et une requete venue de cet
// appareil sans le bon jeton l est aussi.
//

struct PontDuNavigateurTests {
    // MARK: Le pont est desactive par defaut

    @Test("Sur une installation neuve, les reglages ne demandent aucun pont")
    func reglageInactifSurUneInstallationNeuve() {
        #expect(CatalogueDeReglages.valeurParDefaut(de: .activerLePontNavigateur) == .booleen(false))
        #expect(ReglagesDeLApplication.parDefaut.booleen(.activerLePontNavigateur) == false)
    }

    @Test("Appliquer les reglages d une installation neuve n ouvre rien")
    func aucuneSocketSurUneInstallationNeuve() async throws {
        let atelier = AtelierDuPont()

        try await atelier.pont.appliquer(.parDefaut)

        #expect(await atelier.pont.estActif == false)
        #expect(await atelier.pont.port == nil)
        #expect(await atelier.ecoute.demarrages == 0)
        #expect(await atelier.ecoute.enEcoute == false)
    }

    @Test("Un pont jamais active ne tire aucun jeton")
    func aucunJetonTantQueLePontEstInactif() async throws {
        // Le magasin part vide, comme le trousseau d une installation neuve :
        // ce qui est verifie ici est qu appliquer les reglages n y ecrit rien.
        let atelier = AtelierDuPont(jeton: nil)

        try await atelier.pont.appliquer(.parDefaut)

        let partage = try await atelier.pont.jetonAPartager()

        #expect(await atelier.jetons.jeton() == nil)
        #expect(partage == nil)
    }

    @Test("Sans reglage actif, il n y a personne au bout du port")
    func personneAuBoutDuPortSansReglage() async throws {
        let atelier = AtelierDuPont()

        try await atelier.pont.appliquer(.parDefaut)

        await #expect(throws: RienNEcoute.portFerme) {
            _ = try await atelier.ecoute.envoyer(RequeteDuPontDeTest.envoi(jeton: MaterielDuPont.jeton()))
        }
    }

    @Test("Le reglage actif ouvre le port du pont et pose un jeton")
    func leReglageActifOuvreLePont() async throws {
        // Le magasin part vide : sans cela, le jeton trouve a la fin serait
        // celui pose par le montage, et le test ne prouverait rien.
        let atelier = AtelierDuPont(jeton: nil)

        try await atelier.pont.appliquer(MaterielDuPont.reglagesAvecPontActif)

        #expect(await atelier.pont.estActif)
        #expect(await atelier.pont.port == PontNavigateur.portParDefaut)
        #expect(await atelier.ecoute.demarrages == 1)
        #expect(await atelier.jetons.jeton() != nil)
    }

    @Test("Le reglage repasse a faux referme le pont")
    func leReglageInactifRefermeLePont() async throws {
        let atelier = AtelierDuPont()

        try await atelier.pont.appliquer(MaterielDuPont.reglagesAvecPontActif)
        try await atelier.pont.appliquer(.parDefaut)

        #expect(await atelier.pont.estActif == false)
        #expect(await atelier.ecoute.arrets == 1)
        #expect(await atelier.ecoute.enEcoute == false)
    }

    @Test("Le pont referme puis rouvert garde le jeton deja colle dans l extension")
    func leJetonSurvitAUneFermeture() async throws {
        let atelier = AtelierDuPont()

        try await atelier.pont.appliquer(MaterielDuPont.reglagesAvecPontActif)

        let avant = await atelier.jetons.jeton()

        try await atelier.pont.appliquer(.parDefaut)
        try await atelier.pont.appliquer(MaterielDuPont.reglagesAvecPontActif)

        #expect(await atelier.jetons.jeton() == avant)
        #expect(await atelier.jetons.revocations == 0)
    }

    // MARK: La socket n accepte que les connexions locales

    @Test("Une requete parfaite venue du reseau est refusee")
    func machineDuReseauRefusee() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(jeton: atelier.jetonPresente),
            depuis: AdresseDuPair(hote: "192.168.1.20")
        )

        #expect(reponse.code == 403)
        #expect(reponse.corpsContient(ErreurDuPont.connexionNonLocale.codeDeJournal))
        #expect(await atelier.reception.recus.isEmpty)
    }

    @Test(
        "Les adresses de cet appareil passent, celles du reseau non",
        arguments: [
            ("127.0.0.1", true),
            ("127.0.0.53", true),
            ("::1", true),
            ("0:0:0:0:0:0:0:1", true),
            ("::ffff:127.0.0.1", true),
            ("192.168.1.20", false),
            ("10.0.0.4", false),
            ("::ffff:192.168.1.20", false),
            ("localhost", false),
            ("127.0.0.1.exemple.net", false),
        ]
    )
    func seulesLesAdressesLocalesPassent(cas: (hote: String, acceptee: Bool)) async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(jeton: atelier.jetonPresente),
            depuis: AdresseDuPair(hote: cas.hote)
        )

        #expect(reponse.code == (cas.acceptee ? 202 : 403), "\(cas.hote)")
    }

    @Test("Une machine du reseau est refusee avant meme que son jeton soit lu")
    func leRefusDuReseauPasseAvantLeJeton() async throws {
        let atelier = try await AtelierDuPont.ouvert()

        let avecMauvaisJeton = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(jeton: MaterielDuPont.jeton("b")),
            depuis: AdresseDuPair(hote: "192.168.1.20")
        )
        let sansJeton = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(),
            depuis: AdresseDuPair(hote: "192.168.1.20")
        )

        // Les deux repondent la meme chose : le pont ne dit pas au reseau si le
        // jeton presente etait bon, ce qui en ferait un oracle a jetons.
        #expect(avecMauvaisJeton.code == 403)
        #expect(sansJeton.code == 403)
    }

    // MARK: La socket n accepte que les connexions authentifiees

    @Test("Une requete locale sans jeton est refusee")
    func requeteLocaleSansJetonRefusee() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(RequeteDuPontDeTest.envoi())

        #expect(reponse.code == 401)
        #expect(reponse.entete("www-authenticate") == "Bearer")
        #expect(reponse.corpsContient(ErreurDuPont.jetonAbsent.codeDeJournal))
        #expect(await atelier.reception.recus.isEmpty)
    }

    @Test("Une requete locale avec un jeton faux est refusee")
    func requeteLocaleAvecJetonFauxRefusee() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(jeton: MaterielDuPont.jeton("b"))
        )

        #expect(reponse.code == 401)
        #expect(reponse.corpsContient(ErreurDuPont.jetonRefuse.codeDeJournal))
        #expect(await atelier.reception.recus.isEmpty)
    }

    @Test("Une requete locale avec le bon jeton porte la serie jusqu a la reception")
    func requeteLocaleAvecLeBonJetonPasse() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(jeton: atelier.jetonPresente)
        )

        #expect(reponse.code == 202)
        #expect(await atelier.reception.recus.count == 1)
        #expect(await atelier.reception.recus.first?.titre == "Le Chant du Cygne")
        #expect(
            await atelier.reception.recus.first?.adresse.absoluteString
                == RequeteDuPontDeTest.adresseDUnCatalogue
        )
    }

    @Test("Le nom du schema d autorisation se lit sans egard a la casse")
    func schemaDAutorisationSansEgardALaCasse() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        var octets = "POST \(CheminsDuPont.serie) HTTP/1.1\r\nHost: 127.0.0.1\r\n"
        octets += "Content-Type: application/json\r\nAuthorization: bearer \(atelier.jetonPresente)\r\n"

        let corps = RequeteDuPontDeTest.corpsDUnEnvoi()
        let requete = Data((octets + "Content-Length: \(corps.utf8.count)\r\n\r\n" + corps).utf8)
        let reponse = try await atelier.ecoute.envoyer(requete)

        #expect(reponse.code == 202)
    }

    @Test("Sans jeton, un chemin inconnu ne se distingue pas d un chemin servi")
    func lesCheminsRestentInvisiblesSansJeton() async throws {
        let atelier = try await AtelierDuPont.ouvert()

        let servi = try await atelier.ecoute.envoyer(RequeteDuPontDeTest.envoi())
        let inconnu = try await atelier.ecoute.envoyer(RequeteDuPontDeTest.envoi(chemin: "/bibliotheque"))

        #expect(servi.code == 401)
        #expect(inconnu.code == 401)
    }

    @Test("Avec le bon jeton, un chemin inconnu se dit inconnu")
    func cheminInconnuAvecLeBonJeton() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(jeton: atelier.jetonPresente, chemin: "/bibliotheque")
        )

        #expect(reponse.code == 404)
    }

    @Test("Le chemin de la serie n accepte que POST")
    func leCheminDeLaSerieNAccepteQuePost() async throws {
        let atelier = try await AtelierDuPont.ouvert()
        let reponse = try await atelier.ecoute.envoyer(
            RequeteDuPontDeTest.envoi(jeton: atelier.jetonPresente, methode: "GET")
        )

        #expect(reponse.code == 405)
        #expect(reponse.entete("allow") == "POST")
    }

    @Test("Plus rien ne repond apres la desactivation")
    func plusRienNeRepondApresLaDesactivation() async throws {
        let atelier = try await AtelierDuPont.ouvert()

        await atelier.pont.desactiver()

        await #expect(throws: RienNEcoute.portFerme) {
            _ = try await atelier.ecoute.envoyer(RequeteDuPontDeTest.envoi(jeton: atelier.jetonPresente))
        }

        #expect(await atelier.pont.estActif == false)
        #expect(await atelier.ecoute.arrets == 1)
    }
}

/// Le pont, son ecoute simulee, son magasin et sa reception, montes ensemble.
///
/// Le montage est un type et non une fonction parce que les tests ont besoin
/// des quatre pieces a la fois : celle qui recoit pour verifier ce qui est
/// arrive, celle qui ecoute pour porter la requete, celle qui range le jeton
/// pour le presenter, et le pont pour le mettre dans l etat voulu.
struct AtelierDuPont {
    let ecoute: EcouteSimulee
    let reception: ReceptionDuNavigateurSimulee
    let jetons: MagasinDeJetonDuPontEnMemoire
    let pont: PontNavigateur

    /// Le jeton que les tests presentent, celui que le magasin porte.
    let jetonPresente: String

    /// Monte un atelier, avec ou sans jeton deja range.
    ///
    /// Le jeton nul est l etat d une installation neuve, ou le trousseau ne
    /// porte aucune ligne pour le pont. Les tests qui veulent prouver que
    /// l activation en pose un partent de la.
    init(jeton: String? = MaterielDuPont.jeton()) {
        let range = jeton.flatMap { JetonDuPont($0) }
        let magasin = MagasinDeJetonDuPontEnMemoire(jeton: range)
        let ecoute = EcouteSimulee(portAnnonce: PontNavigateur.portParDefaut)
        let reception = ReceptionDuNavigateurSimulee()

        self.ecoute = ecoute
        self.reception = reception
        jetons = magasin
        jetonPresente = jeton ?? MaterielDuPont.jeton()
        pont = PontNavigateur(reception: reception, jetons: magasin, ecoute: ecoute)
    }

    /// Un atelier dont le pont est deja actif.
    static func ouvert(jeton: String = MaterielDuPont.jeton()) async throws -> AtelierDuPont {
        let atelier = AtelierDuPont(jeton: jeton)

        try await atelier.pont.appliquer(MaterielDuPont.reglagesAvecPontActif)

        return atelier
    }
}
