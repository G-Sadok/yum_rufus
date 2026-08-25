import Core
import Foundation
import Testing

/// Couvre le deuxieme critere de la fonctionnalite : une source en echec
/// n empeche jamais les autres de fonctionner.
///
/// Les trois facons dont une source peut faire tomber ses voisines sont
/// traitees. Elle leve une erreur, et le groupe de taches annulerait tout. Elle
/// leve une erreur qu aucun type du domaine ne nomme, et l appelant ne saurait
/// pas quoi en faire. Elle ne repond jamais, et l attente commune ne se termine
/// pas. La derniere est la plus vicieuse : elle ne produit aucune trace.
struct RegistreDeSourcesTests {
    /// Delai court, pour que le test d une source muette dure des millisecondes
    /// et non quinze secondes.
    private static let delaiCourt: Duration = .milliseconds(80)

    // MARK: Contenu du registre

    @Test("Le registre garde les sources dans l ordre d inscription")
    func ordreDInscription() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Une"))
        await registre.inscrire(SourceDeTest(nom: "Deux"))
        await registre.inscrire(SourceDeTest(nom: "Trois"))

        #expect(await registre.toutes.map(\.nom) == ["Une", "Deux", "Trois"])
    }

    @Test("Reconfigurer une source la remplace sans la deplacer")
    func remplacementSurPlace() async {
        let registre = RegistreDeSources()
        let identifiant = SourceID()

        await registre.inscrire(SourceDeTest(nom: "Une"))
        await registre.inscrire(SourceDeTest(id: identifiant, nom: "Deux"))
        await registre.inscrire(SourceDeTest(nom: "Trois"))
        await registre.inscrire(SourceDeTest(id: identifiant, nom: "Deux, renommee"))

        #expect(await registre.toutes.map(\.nom) == ["Une", "Deux, renommee", "Trois"])
        #expect(await registre.nombreDeSources == 3)
    }

    @Test("Retirer une source la sort du registre, et le dit")
    func retrait() async {
        let registre = RegistreDeSources()
        let identifiant = SourceID()

        await registre.inscrire(SourceDeTest(id: identifiant, nom: "Une"))

        #expect(await registre.retirer(identifiant))
        #expect(await registre.retirer(identifiant) == false)
        #expect(await registre.nombreDeSources == 0)
    }

    @Test("Le registre retrouve une source par son identifiant")
    func rechercheParIdentifiant() async {
        let registre = RegistreDeSources()
        let identifiant = SourceID()

        await registre.inscrire(SourceDeTest(id: identifiant, nom: "Une"))

        #expect(await registre.source(identifiant)?.nom == "Une")
        #expect(await registre.source(SourceID()) == nil)
    }

    @Test("Un registre vide rend une recolte vide, sans lever")
    func registreVide() async {
        let registre = RegistreDeSources()

        #expect(await registre.verifierToutes().isEmpty)
        #expect(await registre.rechercher(RequeteRecherche(texte: "x")).isEmpty)
    }

    // MARK: Isolation des echecs

    @Test("Une source qui leve laisse les autres repondre")
    func echecIsole() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Saine", series: .suiteDeTest(2), tailleDePage: 10))
        await registre.inscrire(SourceDeTest(nom: "Cassee", panne: .transport(.cannotFindHost)))
        await registre.inscrire(SourceDeTest(nom: "Saine aussi", series: .suiteDeTest(3), tailleDePage: 10))

        let recolte = await registre.parcourir(.tout)

        #expect(recolte.map(\.nom) == ["Saine", "Cassee", "Saine aussi"])
        #expect(recolte[0].valeur?.elements.count == 2)
        #expect(recolte[1].erreur == .reseau(.serveurIntrouvable, source: "Cassee"))
        #expect(recolte[2].valeur?.elements.count == 3)
    }

    @Test("Une erreur qu aucun type du domaine ne nomme reste isolee elle aussi")
    func echecInattenduIsole() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Etrange", panne: .quelconque))
        await registre.inscrire(SourceDeTest(nom: "Saine", series: .suiteDeTest(1), tailleDePage: 10))

        let recolte = await registre.parcourir(.tout)

        #expect(recolte[0].erreur == .echecInattendu(source: "Etrange", raison: "ErreurQuelconque"))
        #expect(recolte[1].aReussi)
    }

    @Test("Plusieurs sources en echec ne masquent pas la seule qui repond")
    func plusieursEchecs() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Une", panne: .transport(.notConnectedToInternet)))
        await registre.inscrire(SourceDeTest(nom: "Deux", panne: .document(.aucunePage(chemin: "a.cbz"))))
        await registre.inscrire(SourceDeTest(nom: "Trois", panne: .source(.accesAuDossierPerdu(source: "Trois"))))
        await registre.inscrire(SourceDeTest(nom: "Quatre", series: .suiteDeTest(1), tailleDePage: 10))

        let recolte = await registre.parcourir(.tout)

        #expect(recolte.filter(\.aReussi).map(\.nom) == ["Quatre"])
        #expect(recolte[1].erreur == .document(.aucunePage(chemin: "a.cbz"), source: "Deux"))
        #expect(recolte[2].erreur == .accesAuDossierPerdu(source: "Trois"))
    }

    @Test("Chaque echec porte un message utilisateur qui nomme sa source")
    func chaqueEchecEstAffichable() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Komga de test", panne: .transport(.userAuthenticationRequired)))

        let recolte = await registre.parcourir(.tout)
        let message = recolte[0].erreur?.messageUtilisateur ?? ""

        #expect(message.contains("Komga de test"))
        #expect(message.contains("identifiants"))
        #expect(recolte[0].erreur?.etatDeConnexion == .identifiantsInvalides)
    }

    // MARK: Source muette

    @Test("Une source qui ne repond jamais est declaree en echec sans retenir les autres")
    func sourceMuette() async {
        let registre = RegistreDeSources(delaiMaximal: Self.delaiCourt)

        await registre.inscrire(SourceDeTest(nom: "Muette", panne: .muette))
        await registre.inscrire(SourceDeTest(nom: "Saine", series: .suiteDeTest(2), tailleDePage: 10))

        let horloge = ContinuousClock()
        let debut = horloge.now
        let recolte = await registre.parcourir(.tout)
        let duree = horloge.now - debut

        #expect(recolte[0].erreur == .reseau(.delaiDepasse, source: "Muette"))
        #expect(recolte[1].valeur?.elements.count == 2)
        // La source muette dort une heure. Si l attente commune avait suivi la
        // plus lente, ce test ne se terminerait pas de la journee.
        #expect(duree < .seconds(5))
    }

    @Test("La verification de connexion ne se fige pas sur une source muette")
    func verificationAvecSourceMuette() async {
        let registre = RegistreDeSources(delaiMaximal: Self.delaiCourt)

        await registre.inscrire(SourceDeTest(nom: "Muette", panne: .muette))
        await registre.inscrire(SourceDeTest(nom: "Saine", etat: .connecte))
        await registre.inscrire(SourceDeTest(nom: "Sans identifiants", etat: .identifiantsInvalides))

        let recolte = await registre.verifierToutes()

        #expect(recolte[0].erreur == .reseau(.delaiDepasse, source: "Muette"))
        #expect(recolte[1].valeur == .connecte)
        #expect(recolte[2].valeur == .identifiantsInvalides)
    }

    // MARK: Ordre et capacites

    @Test("L ordre des resultats suit l inscription et non la vitesse de reponse")
    func ordreIndependantDeLaLatence() async {
        let registre = RegistreDeSources(delaiMaximal: Self.delaiCourt)

        await registre.inscrire(SourceDeTest(nom: "Lente", panne: .muette))
        await registre.inscrire(SourceDeTest(nom: "Rapide", series: .suiteDeTest(1), tailleDePage: 10))

        let recolte = await registre.parcourir(.tout)

        #expect(recolte.map(\.nom) == ["Lente", "Rapide"])
    }

    @Test("La recherche n interroge que les sources qui la declarent")
    func rechercheReserveeAuxSourcesCapables() async {
        let registre = RegistreDeSources()
        let sansRecherche = SourceDeTest(nom: "Sans recherche", capacites: [], series: .suiteDeTest(2))

        await registre.inscrire(SourceDeTest(nom: "Avec recherche", series: .suiteDeTest(2), tailleDePage: 10))
        await registre.inscrire(sansRecherche)

        let recolte = await registre.rechercher(RequeteRecherche(texte: ""))

        // La source sans capacite de recherche n apparait pas dans la recolte,
        // et surtout elle n y apparait pas sous forme d erreur : ne pas savoir
        // chercher n est pas une panne.
        #expect(recolte.map(\.nom) == ["Avec recherche"])
        #expect(await sansRecherche.nombreDAppels == 0)
    }

    @Test("Le registre sait lister les sources par capacite")
    func listeParCapacite() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Complete", capacites: [.recherche, .filtres, .pagination]))
        await registre.inscrire(SourceDeTest(nom: "Simple", capacites: [.recherche]))

        #expect(await registre.sourcesDeclarant(.recherche).map(\.nom) == ["Complete", "Simple"])
        #expect(await registre.sourcesDeclarant([.recherche, .filtres]).map(\.nom) == ["Complete"])
        #expect(await registre.sourcesDeclarant(.telechargement).isEmpty)
    }

    @Test("Une question libre passe par la meme isolation")
    func questionLibreIsolee() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Saine", series: [.deTest("Berserk")]))
        await registre.inscrire(SourceDeTest(nom: "Cassee", panne: .transport(.timedOut)))

        let recolte = await registre.interroger { try await $0.detailsManga("Berserk") }

        #expect(recolte[0].valeur?.titre == "Berserk")
        #expect(recolte[1].erreur == .reseau(.delaiDepasse, source: "Cassee"))
    }
}
