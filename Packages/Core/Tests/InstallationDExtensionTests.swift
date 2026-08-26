import CryptoKit
import Foundation
import Testing
@testable import Core

/// Couvre le troisieme critere de la fonctionnalite : l utilisateur voit et
/// confirme la liste des domaines avant installation.
///
/// Le critere est tenu par la forme des types, ces tests verifient que la forme
/// tient reellement. Trois facons de le contourner sont exercees : installer
/// sans confirmation, installer avec la confirmation d une autre extension, et
/// installer un manifeste dont la liste a change depuis l affichage.
struct InstallationDExtensionTests {
    private static let instant = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: Ce que l utilisateur lit

    @Test("L avertissement montre les domaines declares, tries")
    func avertissementCompletEtTrie() throws {
        let manifeste = try ManifesteDeTest.manifeste()
        let avertissement = AvertissementDInstallation(manifeste: manifeste)

        #expect(avertissement.nomDeLExtension == "Catalogue Exemple")
        #expect(avertissement.version == VersionDExtension(majeure: 1, mineure: 4))
        #expect(avertissement.langue == "fr")
        #expect(avertissement.domainesAffiches == ["*.images.exemple.net", "api.exemple.net"])
        #expect(avertissement.couvreDesSousDomaines)
        #expect(avertissement.capacites == manifeste.capacites)
    }

    @Test("L empreinte ne depend pas de l ordre d ecriture des domaines")
    func empreinteIndependanteDeLOrdre() throws {
        let inverse = ManifesteDeTest.enRemplacant(
            "[\"api.exemple.net\", \"*.images.exemple.net\"]",
            par: "[\"*.images.exemple.net\", \"api.exemple.net\"]"
        )
        let attendue = try AvertissementDInstallation(manifeste: ManifesteDeTest.manifeste())
        let observee = try AvertissementDInstallation(manifeste: ManifesteDExtension.lire(inverse))

        #expect(observee.empreinteDesDomaines == attendue.empreinteDesDomaines)
    }

    @Test("L empreinte change des qu un domaine est ajoute")
    func empreinteSensibleAUnAjout() throws {
        let elargi = ManifesteDeTest.enRemplacant(
            "[\"api.exemple.net\", \"*.images.exemple.net\"]",
            par: "[\"api.exemple.net\", \"*.images.exemple.net\", \"suivi.exemple.net\"]"
        )
        let attendue = try AvertissementDInstallation(manifeste: ManifesteDeTest.manifeste())
        let observee = try AvertissementDInstallation(manifeste: ManifesteDExtension.lire(elargi))

        #expect(observee.empreinteDesDomaines != attendue.empreinteDesDomaines)
    }

    // MARK: La porte d installation

    @Test("Installer sans confirmation est refuse")
    func installationSansConfirmation() throws {
        let manifeste = try ManifesteDeTest.manifeste()

        #expect(throws: ErreurDExtension.domainesNonConfirmes) {
            try InstallateurDExtensions().installer(manifeste, confirmation: nil)
        }
    }

    @Test("Installer avec la confirmation lue passe")
    func installationConfirmee() throws {
        let manifeste = try ManifesteDeTest.manifeste()
        let avertissement = AvertissementDInstallation(manifeste: manifeste)
        let confirmation = ConfirmationDesDomaines(avertissement: avertissement, instant: Self.instant)
        let installee = try InstallateurDExtensions().installer(manifeste, confirmation: confirmation)

        #expect(installee.manifeste.identifiant == manifeste.identifiant)
        #expect(installee.confirmation.instant == Self.instant)
        #expect(installee.listeBlanche.autorise("api.exemple.net"))
    }

    /// Le cas qui compte vraiment. Le paquet est telecharge, et rien n oblige
    /// un depot a rendre deux fois le meme document : la liste montree et la
    /// liste installee doivent etre la meme, sans quoi la confirmation ne vaut
    /// rien.
    @Test("Une confirmation obtenue sur une autre liste est refusee")
    func confirmationSurUneAutreListe() throws {
        let montre = try ManifesteDeTest.manifeste()
        let elargi = try ManifesteDExtension.lire(
            ManifesteDeTest.enRemplacant(
                "[\"api.exemple.net\", \"*.images.exemple.net\"]",
                par: "[\"api.exemple.net\", \"*.images.exemple.net\", \"suivi.exemple.net\"]"
            )
        )
        let confirmation = ConfirmationDesDomaines(
            avertissement: AvertissementDInstallation(manifeste: montre),
            instant: Self.instant
        )

        #expect(throws: ErreurDExtension.confirmationNeCorrespondPas) {
            try InstallateurDExtensions().installer(elargi, confirmation: confirmation)
        }
    }

    @Test("Une confirmation donnee pour une autre extension est refusee")
    func confirmationDUneAutreExtension() throws {
        let autre = try ManifesteDExtension.lire(
            ManifesteDeTest.enRemplacant("\"exemple.catalogue\"", par: "\"autre.catalogue\"")
        )
        let confirmation = ConfirmationDesDomaines(
            avertissement: AvertissementDInstallation(manifeste: autre),
            instant: Self.instant
        )

        #expect(throws: ErreurDExtension.confirmationNeCorrespondPas) {
            try InstallateurDExtensions().installer(ManifesteDeTest.manifeste(), confirmation: confirmation)
        }
    }

    // MARK: Signature

    @Test("Un paquet signe par une cle de confiance est accepte")
    func paquetSigne() throws {
        let signataire = SignataireDeTest()
        let enveloppe = try signataire.enveloppe(de: ManifesteDeTest.donnees)
        let installateur = InstallateurDExtensions(
            verificateur: VerificateurDeSignature(trousseau: signataire.trousseau)
        )
        let pret = try installateur.preparer(enveloppe: enveloppe)

        #expect(pret.manifeste.identifiant == "exemple.catalogue")
        #expect(pret.avertissement.domainesAffiches.count == 2)
    }

    @Test("Un paquet modifie apres signature est refuse")
    func paquetModifieApresSignature() throws {
        let signataire = SignataireDeTest()
        let signe = try PaquetDExtensionSigne.lire(signataire.enveloppe(de: ManifesteDeTest.donnees))
        let falsifie = PaquetDExtensionSigne(
            manifeste: ManifesteDeTest.enRemplacant(
                "\"api.exemple.net\"",
                par: "\"api.exemple.net\", \"attaquant.org\""
            ),
            signature: signe.signature,
            clePublique: signe.clePublique
        )
        let verificateur = VerificateurDeSignature(trousseau: signataire.trousseau)

        #expect(throws: ErreurDExtension.signatureInvalide) {
            try verificateur.verifier(falsifie)
        }
    }

    @Test("Un paquet signe par une cle inconnue est refuse")
    func cleInconnue() throws {
        let signataire = SignataireDeTest()
        let enveloppe = try signataire.enveloppe(de: ManifesteDeTest.donnees)
        let verificateur = VerificateurDeSignature(trousseau: SignataireDeTest().trousseau)

        #expect(throws: ErreurDExtension.cleDePublicationInconnue) {
            try verificateur.verifier(enveloppe: enveloppe)
        }
    }

    /// Le trousseau livre est vide tant qu aucune cle de publication n existe.
    /// Un trousseau vide refuse tout, ce qui est le seul defaut acceptable :
    /// aucune installation ne passe avant que la cle existe.
    @Test("Le trousseau livre refuse tout tant qu il est vide")
    func trousseauLivreVide() throws {
        let signataire = SignataireDeTest()
        let enveloppe = try signataire.enveloppe(de: ManifesteDeTest.donnees)

        #expect(TrousseauDeClesDePublication.livre.estVide)
        #expect(throws: ErreurDExtension.cleDePublicationInconnue) {
            try VerificateurDeSignature().verifier(enveloppe: enveloppe)
        }
    }

    @Test("Une enveloppe sans signature est refusee")
    func enveloppeSansSignature() {
        let sansSignature = Data(
            """
            { "manifeste": "e30=", "signature": "", "cle": "" }
            """.utf8
        )

        #expect(throws: ErreurDExtension.signatureAbsente) {
            try PaquetDExtensionSigne.lire(sansSignature)
        }
        #expect(throws: ErreurDExtension.manifesteIllisible) {
            try PaquetDExtensionSigne.lire(Data("{}".utf8))
        }
    }

    /// La signature est verifiee avant que le manifeste ne soit analyse. Un
    /// paquet non signe dont le manifeste est par ailleurs illisible doit etre
    /// refuse pour sa signature, pas pour sa forme.
    @Test("La signature est verifiee avant l analyse du manifeste")
    func ordreDeVerification() throws {
        let signataire = SignataireDeTest()
        let paquet = PaquetDExtensionSigne(
            manifeste: Data("ceci n est pas du json".utf8),
            signature: Data(repeating: 0, count: 64),
            clePublique: signataire.clePublique
        )
        let verificateur = VerificateurDeSignature(trousseau: signataire.trousseau)

        #expect(throws: ErreurDExtension.signatureInvalide) {
            try verificateur.verifier(paquet)
        }
    }

    // MARK: Registre

    @Test("Le registre remplace une extension sans la deplacer")
    func registreRemplaceSurPlace() async throws {
        let registre = RegistreDExtensions()
        let premiere = try installee(identifiant: "premiere.catalogue")
        let seconde = try installee(identifiant: "seconde.catalogue")

        await registre.inscrire(premiere)
        await registre.inscrire(seconde)
        await registre.inscrire(premiere)

        #expect(await registre.nombre == 2)
        #expect(await registre.toutes.map(\.manifeste.identifiant) == ["premiere.catalogue", "seconde.catalogue"])
        #expect(await registre.desinstaller("premiere.catalogue"))
        #expect(await registre.desinstaller("premiere.catalogue") == false)
        #expect(await registre.installee("seconde.catalogue") != nil)
    }

    /// Une extension installee, sous un identifiant choisi par le test.
    private func installee(identifiant: String) throws -> ExtensionInstallee {
        let manifeste = try ManifesteDExtension.lire(
            ManifesteDeTest.enRemplacant("\"exemple.catalogue\"", par: "\"\(identifiant)\"")
        )
        let confirmation = ConfirmationDesDomaines(
            avertissement: AvertissementDInstallation(manifeste: manifeste),
            instant: Self.instant
        )

        return try InstallateurDExtensions().installer(manifeste, confirmation: confirmation)
    }
}

/// Couvre le depot d extensions du tableau 4.2 et l avertissement de
/// responsabilite exige par la fin de la section 4.3.
struct DepotDExtensionsTests {
    private static let catalogue = """
    {
      "format": 1,
      "nom": "Depot Exemple",
      "extensions": [
        {
          "identifiant": "exemple.catalogue",
          "nom": "Catalogue Exemple",
          "version": "1.4",
          "langue": "fr",
          "resume": "Un catalogue de demonstration",
          "paquet": "https://depot.exemple.net/exemple-1.4.json",
          "domaines": ["api.exemple.net"]
        },
        {
          "identifiant": "clair.catalogue",
          "nom": "Catalogue en clair",
          "version": "1.0",
          "langue": "fr",
          "paquet": "http://depot.exemple.net/clair-1.0.json",
          "domaines": []
        }
      ]
    }
    """

    @Test("Le catalogue se lit et ecarte les entrees inutilisables")
    func lectureDuCatalogue() throws {
        let lu = try CatalogueDeDepot.lire(Data(Self.catalogue.utf8))

        #expect(lu.nom == "Depot Exemple")
        #expect(lu.extensions.map(\.identifiant) == ["exemple.catalogue"])
        #expect(lu.extensions.first?.resume == "Un catalogue de demonstration")
    }

    @Test("Un catalogue ecrit pour une version plus recente est refuse")
    func catalogueTropRecent() {
        let trop = Data(Self.catalogue.replacingOccurrences(of: "\"format\": 1", with: "\"format\": 2").utf8)

        #expect(throws: ErreurDExtension.formatNonPrisEnCharge(annoncee: 2, appliquee: 1)) {
            try CatalogueDeDepot.lire(trop)
        }
    }

    @Test("Un depot en clair est refuse")
    func depotEnClair() throws {
        #expect(throws: ErreurReseau.transportNonChiffre) {
            try DepotConfigure(adresse: #require(URL(string: "http://depot.exemple.net/catalogue.json")))
        }

        let depot = try DepotConfigure(adresse: #require(URL(string: "https://depot.exemple.net/index.json")))

        #expect(depot.nom == "depot.exemple.net")
    }

    @Test("La responsabilite n est rappelee qu au premier depot")
    func avertissementDeResponsabilite() throws {
        let depot = try DepotConfigure(adresse: #require(URL(string: "https://depot.exemple.net/index.json")))

        #expect(AvertissementDeDepot(depot: depot, depotsDejaAjoutes: 0).afficheLaResponsabilite)
        #expect(AvertissementDeDepot(depot: depot, depotsDejaAjoutes: 1).afficheLaResponsabilite == false)
        #expect(AvertissementDeDepot(depot: depot, depotsDejaAjoutes: 0).hote == "depot.exemple.net")
    }
}
