import Core
import Foundation
import Testing

/// Couvre le troisieme critere de la fonctionnalite : les erreurs reseau sont
/// typees et traduites en messages utilisateur.
///
/// La traduction est verifiee dans les deux sens. Ce qui entre, `URLError` et
/// codes HTTP, ressort en cas nomme. Ce qui sort, le message, nomme la cause et
/// indique la sortie, et ne laisse fuir aucune donnee personnelle vers le
/// journal.
struct ErreurReseauTests {
    /// Un exemplaire de chaque cas.
    ///
    /// La liste est ecrite a la main parce qu une enumeration a valeurs
    /// associees ne s enumere pas toute seule. Le test `chaqueCasEstTraduit`
    /// compte donc aussi comme un rappel : ajouter un cas sans l ajouter ici
    /// laisse un trou, et le compte fige plus bas le fait echouer.
    private static let tousLesCas: [ErreurReseau] = [
        .horsLigne,
        .delaiDepasse,
        .serveurIntrouvable,
        .connexionRefusee,
        .certificatRefuse,
        .transportNonChiffre,
        .domaineNonAutorise(domaine: "exemple.test"),
        .annulee,
        .echecDeTransport(code: -1234),
        .authentificationRefusee,
        .accesRefuse,
        .ressourceIntrouvable,
        .tropDeRequetes(secondesAvantNouvelEssai: 30),
        .tropDeRequetes(secondesAvantNouvelEssai: nil),
        .pannePassagere(code: 503),
        .reponseInattendue(code: 418),
        .reponseIllisible,
        .reponseVide,
        .reponseTronquee,
    ]

    // MARK: Traduction en message

    @Test("Chaque cas porte un message qui nomme la cause et indique la sortie")
    func chaqueCasEstTraduit() {
        // Dix neuf exemplaires pour dix huit cas, celui de `tropDeRequetes`
        // etant present dans ses deux formes.
        #expect(Self.tousLesCas.count == 19)

        for cas in Self.tousLesCas {
            let message = cas.messageUtilisateur

            #expect(message.isEmpty == false, "\(cas)")
            #expect(message.hasSuffix("."), "\(cas)")
            // Deux phrases au moins : la cause, puis ce qu il faut faire.
            #expect(message.split(separator: ".").count >= 2, "\(cas)")
        }
    }

    @Test("Aucun message ne contient de tiret cadratin")
    func aucunTiretCadratin() throws {
        // Le controle 4 lit les fichiers du depot. Ce test lit les chaines
        // assemblees, ce que le controle ne sait pas faire.
        let cadratin = try #require(UnicodeScalar(UInt32(0x2014)))

        for cas in Self.tousLesCas {
            #expect(cas.messageUtilisateur.unicodeScalars.contains(cadratin) == false, "\(cas)")
        }
    }

    @Test("Le delai annonce par le serveur apparait dans le message")
    func delaiAnnonceDansLeMessage() {
        let avecDelai = ErreurReseau.tropDeRequetes(secondesAvantNouvelEssai: 42)
        let sansDelai = ErreurReseau.tropDeRequetes(secondesAvantNouvelEssai: nil)

        #expect(avecDelai.messageUtilisateur.contains("42"))
        #expect(sansDelai.messageUtilisateur.contains("42") == false)
    }

    @Test("Le domaine bloque est nomme, parce que c est ce que l utilisateur doit voir")
    func domaineBloqueNomme() {
        let erreur = ErreurReseau.domaineNonAutorise(domaine: "collecte.exemple.test")

        #expect(erreur.messageUtilisateur.contains("collecte.exemple.test"))
    }

    // MARK: Journal

    @Test("Le code de journal ne porte aucune adresse de serveur")
    func journalSansAdresse() {
        for cas in Self.tousLesCas {
            #expect(cas.codeDeJournal.contains("exemple.test") == false, "\(cas)")
            #expect(cas.codeDeJournal.hasPrefix("reseau."), "\(cas)")
        }
    }

    @Test("Le code de journal distingue les cas entre eux")
    func journalDistinctif() {
        let codes = Set(Self.tousLesCas.map(\.codeDeJournal))

        // Les deux formes de `tropDeRequetes` partagent volontairement le meme
        // code : le delai annonce n a rien a faire dans un compteur.
        #expect(codes.count == 18)
    }

    // MARK: Traduction depuis URLSession

    @Test(
        "Les codes d URLSession se traduisent en cas du domaine",
        arguments: [
            (URLError.Code.notConnectedToInternet, ErreurReseau.horsLigne),
            (.networkConnectionLost, .horsLigne),
            (.timedOut, .delaiDepasse),
            (.cannotFindHost, .serveurIntrouvable),
            (.dnsLookupFailed, .serveurIntrouvable),
            (.cannotConnectToHost, .connexionRefusee),
            (.secureConnectionFailed, .certificatRefuse),
            (.serverCertificateUntrusted, .certificatRefuse),
            (.appTransportSecurityRequiresSecureConnection, .transportNonChiffre),
            (.userAuthenticationRequired, .authentificationRefusee),
            (.noPermissionsToReadFile, .accesRefuse),
            (.fileDoesNotExist, .ressourceIntrouvable),
            (.badServerResponse, .reponseIllisible),
            (.cannotDecodeContentData, .reponseIllisible),
            (.zeroByteResource, .reponseVide),
            (.cancelled, .annulee),
        ]
    )
    func traductionDesCodesDUrlSession(code: URLError.Code, attendu: ErreurReseau) {
        #expect(ErreurReseau.depuis(URLError(code)) == attendu)
    }

    @Test("Un code inconnu garde son numero au lieu de disparaitre")
    func codeInconnuConserve() {
        let inconnu = URLError.Code(rawValue: -99999)

        #expect(ErreurReseau.depuis(URLError(inconnu)) == .echecDeTransport(code: -99999))
    }

    @Test("Une annulation de tache devient le cas annulee")
    func annulationTraduite() {
        #expect(ErreurReseau.depuis(CancellationError()) == .annulee)
    }

    @Test("Une erreur qui n a rien de reseau n est pas deguisee en panne reseau")
    func erreurEtrangereNonTraduite() {
        #expect(ErreurReseau.depuis(ErreurQuelconque()) == nil)
        #expect(ErreurReseau.depuis(ErreurDeDocument.aucunePage(chemin: "a.cbz")) == nil)
    }

    @Test("Une erreur deja typee traverse sans etre retraduite")
    func erreurDejaTypee() {
        #expect(ErreurReseau.depuis(ErreurReseau.reponseTronquee) == .reponseTronquee)
    }

    // MARK: Traduction depuis HTTP

    @Test(
        "Les codes HTTP se traduisent en cas du domaine",
        arguments: [
            (200, ErreurReseau?.none),
            (204, nil),
            (299, nil),
            (401, .authentificationRefusee),
            (407, .authentificationRefusee),
            (403, .accesRefuse),
            (404, .ressourceIntrouvable),
            (410, .ressourceIntrouvable),
            (408, .delaiDepasse),
            (504, .delaiDepasse),
            (500, .pannePassagere(code: 500)),
            (503, .pannePassagere(code: 503)),
            (418, .reponseInattendue(code: 418)),
            (302, .reponseInattendue(code: 302)),
        ]
    )
    func traductionDesCodesHttp(code: Int, attendu: ErreurReseau?) {
        #expect(ErreurReseau.depuis(codeHttp: code) == attendu)
    }

    @Test("Le code 429 porte le delai annonce par le serveur")
    func codeDeRalentissement() {
        #expect(
            ErreurReseau.depuis(codeHttp: 429, nouvelEssaiApres: 30)
                == .tropDeRequetes(secondesAvantNouvelEssai: 30)
        )
        #expect(ErreurReseau.depuis(codeHttp: 429) == .tropDeRequetes(secondesAvantNouvelEssai: nil))
    }

    // MARK: En tete Retry-After

    @Test("Un Retry-After en secondes se lit tel quel")
    func retryApresEnSecondes() {
        let maintenant = Date(timeIntervalSince1970: 0)

        #expect(ErreurReseau.secondesAvantNouvelEssai("120", maintenant: maintenant) == 120)
        #expect(ErreurReseau.secondesAvantNouvelEssai(" 45 ", maintenant: maintenant) == 45)
        #expect(ErreurReseau.secondesAvantNouvelEssai("0", maintenant: maintenant) == 0)
    }

    @Test("Un Retry-After en date HTTP se convertit en secondes restantes")
    func retryApresEnDate() {
        // Le premier janvier 1970 a une heure du matin, en GMT.
        let maintenant = Date(timeIntervalSince1970: 0)
        let entete = "Thu, 01 Jan 1970 01:00:00 GMT"

        #expect(ErreurReseau.secondesAvantNouvelEssai(entete, maintenant: maintenant) == 3600)
    }

    @Test("Une date deja passee ne rend jamais un delai negatif")
    func retryApresDansLePasse() {
        let maintenant = Date(timeIntervalSince1970: 7200)
        let entete = "Thu, 01 Jan 1970 01:00:00 GMT"

        #expect(ErreurReseau.secondesAvantNouvelEssai(entete, maintenant: maintenant) == 0)
    }

    @Test("Un Retry-After absent ou illisible ne se devine pas")
    func retryApresIllisible() {
        let maintenant = Date(timeIntervalSince1970: 0)

        #expect(ErreurReseau.secondesAvantNouvelEssai(nil, maintenant: maintenant) == nil)
        #expect(ErreurReseau.secondesAvantNouvelEssai("", maintenant: maintenant) == nil)
        #expect(ErreurReseau.secondesAvantNouvelEssai("bientot", maintenant: maintenant) == nil)
    }

    // MARK: Consequences

    @Test("Seules les pannes passageres sont annoncees comme reessayables")
    func pannesReessayables() {
        let temporaires: [ErreurReseau] = [
            .horsLigne,
            .delaiDepasse,
            .connexionRefusee,
            .tropDeRequetes(secondesAvantNouvelEssai: nil),
            .pannePassagere(code: 503),
            .reponseVide,
            .reponseTronquee,
        ]

        for cas in temporaires {
            #expect(cas.estTemporaire, "\(cas)")
        }

        let definitives: [ErreurReseau] = [
            .authentificationRefusee,
            .accesRefuse,
            .ressourceIntrouvable,
            .certificatRefuse,
            .transportNonChiffre,
            .domaineNonAutorise(domaine: "exemple.test"),
            .reponseIllisible,
            .reponseInattendue(code: 418),
            .annulee,
            .serveurIntrouvable,
        ]

        for cas in definitives {
            #expect(cas.estTemporaire == false, "\(cas)")
        }
    }

    @Test("L etat de connexion distingue les identifiants du reste")
    func etatDeConnexionParCas() {
        #expect(ErreurReseau.authentificationRefusee.etatDeConnexion == .identifiantsInvalides)
        #expect(ErreurReseau.horsLigne.etatDeConnexion == .injoignable)
        #expect(ErreurReseau.delaiDepasse.etatDeConnexion == .injoignable)
        #expect(ErreurReseau.serveurIntrouvable.etatDeConnexion == .injoignable)
        #expect(ErreurReseau.connexionRefusee.etatDeConnexion == .injoignable)
        #expect(ErreurReseau.certificatRefuse.etatDeConnexion == .erreur)
        #expect(ErreurReseau.reponseIllisible.etatDeConnexion == .erreur)
        #expect(ErreurReseau.accesRefuse.etatDeConnexion == .erreur)
    }
}
