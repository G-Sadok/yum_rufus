import Core
import Foundation
import Security
import Testing

/// Couvre la regle de la section 11 : toutes les authentifications de source
/// passent par le trousseau, avec accessibilite apres premier deverrouillage.
///
/// Les tests portent sur ce qui est demande au trousseau et non sur ce que le
/// trousseau en fait. C est volontaire, et la raison est ecrite dans
/// `MagasinDIdentifiantsEnMemoire` : le binaire de test ne porte aucun droit de
/// trousseau. Ce qui doit tenir est justement la forme de la requete, et elle
/// se lit sans ecrire nulle part.
struct TrousseauDIdentifiantsTests {
    static let requetes = RequeteDeTrousseau(service: "test.identifiants-de-source")
    static let source = SourceID(UUID(uuidString: "6C4F0B02-6D6F-4D5E-9A1B-2F3E4D5C6B7A") ?? UUID())

    // MARK: Accessibilite

    @Test("La creation impose l accessibilite apres premier deverrouillage")
    func creationApresPremierDeverrouillage() {
        let requete = Self.requetes.creation(de: Self.source, donnees: Data([0x01]))

        #expect(requete[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlock as String)
    }

    @Test("La mise a jour reecrit l accessibilite au lieu de la laisser en l etat")
    func miseAJourReecritLAccessibilite() {
        let requete = Self.requetes.miseAJour(donnees: Data([0x01]))

        #expect(requete[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlock as String)
    }

    @Test("L accessibilite retenue n est pas celle qui exige un appareil deverrouille")
    func accessibiliteNiTropOuverteNiTropFermee() {
        // Les deux valeurs ecartees ici imposent un appareil deverrouille au
        // moment de la lecture. Elles couperaient toute verification de source
        // en arriere plan, ce que la section 11 ne demande pas. La valeur trop
        // ouverte, elle, ne peut plus etre citee dans ce test : le systeme l a
        // depreciee, et la nommer produirait un avertissement de compilation.
        let retenue = RequeteDeTrousseau.accessibilite

        #expect(retenue != kSecAttrAccessibleWhenUnlocked as String)
        #expect(retenue != kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        #expect(retenue == kSecAttrAccessibleAfterFirstUnlock as String)
    }

    @Test("Les lignes sont rangees dans le trousseau protege, seul a honorer l accessibilite")
    func trousseauProtege() {
        let requete = Self.requetes.designation(de: Self.source)

        #expect(requete[kSecUseDataProtectionKeychain as String] as? Bool == true)
    }

    // MARK: Designation

    @Test("Une source est designee par son identifiant, sous le service du projet")
    func designationParIdentifiantDeSource() {
        let requete = Self.requetes.designation(de: Self.source)

        #expect(requete[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(requete[kSecAttrService as String] as? String == "test.identifiants-de-source")
        #expect(requete[kSecAttrAccount as String] as? String == Self.source.brut.uuidString)
    }

    @Test("Deux sources ne partagent jamais la meme ligne")
    func uneLigneParSource() {
        let autre = SourceID()

        let premiere = Self.requetes.designation(de: Self.source)[kSecAttrAccount as String] as? String
        let seconde = Self.requetes.designation(de: autre)[kSecAttrAccount as String] as? String

        #expect(premiere != seconde)
    }

    @Test("La designation ne porte aucun secret, ce qui rend la suppression possible sans le connaitre")
    func designationSansSecret() {
        let requete = Self.requetes.designation(de: Self.source)

        #expect(requete[kSecValueData as String] == nil)
    }

    @Test("Le service par defaut derive de l identifiant du paquet et nomme le projet")
    func serviceParDefaut() {
        #expect(RequeteDeTrousseau.serviceParDefaut.hasSuffix(".identifiants-de-source"))
    }

    // MARK: Codage

    @Test("Les quatre formes font l aller retour sans rien perdre", arguments: [
        IdentifiantsDeSource.aucun,
        IdentifiantsDeSource.basique(compte: "lecteur", motDePasse: "mot-de-passe-du-serveur"),
        IdentifiantsDeSource.cleDApi("cle-api-jellyfin-0123456789"),
        IdentifiantsDeSource.jeton(
            acces: "jeton-acces-kavita",
            rafraichissement: "jeton-rafraichissement-kavita",
            expiration: Date(timeIntervalSince1970: 1_700_000_000)
        ),
    ])
    func allerRetourDuCodage(_ identifiants: IdentifiantsDeSource) throws {
        let donnees = try CodageDIdentifiants.encoder(identifiants)

        #expect(try CodageDIdentifiants.decoder(donnees) == identifiants)
    }

    @Test("Des octets qui ne viennent pas du projet sont refuses, jamais interpretes")
    func decodageDOctetsEtrangers() {
        #expect(throws: ErreurDeTrousseau.donneeIllisible) {
            try CodageDIdentifiants.decoder(Data([0x00, 0x01, 0x02]))
        }
    }

    @Test("Une ligne dont le secret manque est signalee, jamais rendue a moitie")
    func decodageDUneLigneIncomplete() throws {
        let tronquee = Data(#"{"nature":"basique","compte":"lecteur"}"#.utf8)

        #expect(throws: ErreurDeTrousseau.identifiantsIncomplets(nature: .basique)) {
            try CodageDIdentifiants.decoder(tronquee)
        }
    }

    @Test("Le codage est nomme par la forme et non par la position des cas")
    func codageStableAuRenommage() throws {
        let donnees = try CodageDIdentifiants.encoder(.cleDApi("cle"))
        let texte = try #require(String(bytes: donnees, encoding: .utf8))

        #expect(texte.contains("\"nature\":\"cleDApi\""))
    }

    // MARK: Journalisation

    @Test("Un identifiant interpole dans une chaine ne rend jamais son secret")
    func descriptionCaviardee() {
        let identifiants = IdentifiantsDeSource.basique(compte: "lecteur", motDePasse: "mot-de-passe-du-serveur")

        #expect("\(identifiants)".contains("mot-de-passe-du-serveur") == false)
        #expect(String(reflecting: identifiants).contains("mot-de-passe-du-serveur") == false)
        #expect("\(identifiants)".contains("basique"))
    }

    @Test("Un code de journal ne porte ni compte ni secret")
    func journalSansDonneePersonnelle() {
        let erreur = ErreurDeTrousseau.identifiantsIncomplets(nature: .jeton)

        #expect(erreur.codeDeJournal == "trousseau.incomplet.jeton")
        #expect(erreur.messageUtilisateur.isEmpty == false)
    }

    // MARK: Enregistrement

    @Test("Enregistrer des identifiants vides efface la ligne au lieu de la laisser")
    func enregistrerVideEfface() async {
        let magasin = MagasinDIdentifiantsEnMemoire()
        await magasin.enregistrer(.cleDApi("cle"), pour: Self.source)

        await magasin.enregistrer(.aucun, pour: Self.source)

        #expect(await magasin.sourcesConnues.isEmpty)
        #expect(await magasin.identifiants(pour: Self.source) == .aucun)
    }

    @Test("Une source sans identifiants rend aucun plutot que de lever")
    func sourceSansIdentifiants() async {
        let magasin = MagasinDIdentifiantsEnMemoire()

        #expect(await magasin.identifiants(pour: Self.source) == .aucun)
    }
}
