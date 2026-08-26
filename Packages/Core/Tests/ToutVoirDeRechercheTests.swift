import Core
import Foundation
import Testing

/// Couvre le troisieme critere de l ecran Rechercher, section 5.4 de
/// DESIGN-SPEC.md : le lien Tout voir ouvre la liste complete de la source.
///
/// La suite couvre aussi ce que l ecran dit quand il n a rien a montrer, parce
/// que les deux se repondent : un lien qui ouvrirait une liste vide serait la
/// meme faute qu un ecran qui annoncerait des resultats qu il n a pas.
struct ToutVoirDeRechercheTests {
    // MARK: Troisieme critere

    @Test("Le lien Tout voir ouvre la liste complete de la source")
    func toutVoir() async {
        let registre = RegistreDeSources()
        let premiere = SourceID()
        let seconde = SourceID()

        await registre.inscrire(
            SourceDeTest(id: premiere, nom: "Premiere", series: .suiteDeTest(5), tailleDePage: 5)
        )
        await registre.inscrire(
            SourceDeTest(id: seconde, nom: "Seconde", series: .suiteDeTest(2), tailleDePage: 2)
        )

        var etat = await EcranDeRechercheDeTest.rechercher(registre)

        #expect(etat.groupeDeplie == nil, "Aucune liste complete n est ouverte au depart")

        let ouverture = etat.deplier(premiere)

        #expect(ouverture)
        #expect(etat.sourceDepliee == premiere)
        #expect(etat.groupeDeplie?.nom == "Premiere")
        #expect(etat.groupeDeplie?.resultats.count == 5)
        #expect(
            etat.groupeDeplie?.resultats == etat.groupe(premiere)?.resultats,
            "La liste complete est celle de la source designee, entiere"
        )

        etat.replier()

        #expect(etat.groupeDeplie == nil)
    }

    @Test("Une source sans resultat ou en echec n ouvre aucune liste complete")
    func toutVoirRefuse() async {
        let registre = RegistreDeSources()
        let vide = SourceID()
        let cassee = SourceID()

        await registre.inscrire(SourceDeTest(id: vide, nom: "Vide", series: .suiteDeTest(2)))
        await registre.inscrire(
            SourceDeTest(id: cassee, nom: "Cassee", panne: .transport(.cannotFindHost))
        )

        var etat = await EcranDeRechercheDeTest.rechercher(
            registre,
            terme: "Aucune correspondance"
        )

        let surUneRangeeVide = etat.deplier(vide)
        let surUneRangeeEnEchec = etat.deplier(cassee)
        let surUneSourceInconnue = etat.deplier(SourceID())

        #expect(etat.groupe(vide)?.nombreDeResultats == 0)
        #expect(surUneRangeeVide == false)
        #expect(surUneRangeeEnEchec == false)
        #expect(surUneSourceInconnue == false)
        #expect(etat.groupeDeplie == nil)
    }

    @Test("Une source qui perd ses resultats referme sa liste complete")
    func repliAutomatique() async {
        let registre = RegistreDeSources()
        let source = SourceID()

        await registre.inscrire(SourceDeTest(id: source, nom: "Une", series: .suiteDeTest(2)))

        var etat = await EcranDeRechercheDeTest.rechercher(registre)
        let ouverture = etat.deplier(source)

        #expect(ouverture)

        etat.remettreEnChargement(source)

        #expect(etat.groupeDeplie == nil, "Une liste videe ne reste pas ouverte sur du vide")
    }

    // MARK: Etat d ensemble

    @Test("Un ecran sans source interrogeable le dit, sans erreur ni resultat")
    func aucuneSource() async {
        let registre = RegistreDeSources()
        let etat = await EcranDeRechercheDeTest.etatInitial(registre)

        #expect(etat.aucuneSourceInterrogee)
        #expect(etat.estTerminee)
        #expect(etat.toutesLesSourcesOntEchoue == false)
        #expect(etat.aucunResultat == false)
    }

    @Test("Des sources qui ne connaissent rien donnent une absence de resultat")
    func absenceDeResultat() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Une", series: .suiteDeTest(2)))
        await registre.inscrire(SourceDeTest(nom: "Deux", series: .suiteDeTest(2)))

        let etat = await EcranDeRechercheDeTest.rechercher(registre, terme: "Introuvable")

        #expect(etat.aucunResultat)
        #expect(etat.nombreTotalDeResultats == 0)
        #expect(etat.groupes.allSatisfy { $0.nombreDeResultats == 0 })
    }

    @Test("Une reponse venue d une source inconnue de l ecran est ignoree")
    func reponseOrpheline() async {
        let registre = RegistreDeSources()

        await registre.inscrire(SourceDeTest(nom: "Une", series: .suiteDeTest(2)))

        var etat = await EcranDeRechercheDeTest.etatInitial(registre)
        let avant = etat

        etat.appliquer(
            ResultatDeSource(
                source: SourceID(),
                nom: "Venue d ailleurs",
                resultat: .success(PageResultats(elements: [.deTest("Intruse")]))
            )
        )

        #expect(etat == avant)
    }

    @Test("Le compteur d une rangee distingue le chargement de l absence")
    func compteurDeResultats() async {
        let registre = RegistreDeSources()
        let source = SourceID()

        await registre.inscrire(
            SourceDeTest(id: source, nom: "Une", series: .suiteDeTest(4), tailleDePage: 2)
        )

        var etat = await EcranDeRechercheDeTest.etatInitial(registre)

        #expect(etat.groupe(source)?.nombreDeResultats == nil, "Rien a compter avant la reponse")

        for await resultat in await registre.rechercherAuFilDeLEau(
            EcranDeRechercheDeTest.requete()
        ) {
            etat.appliquer(resultat)
        }

        #expect(etat.groupe(source)?.nombreDeResultats == 2)
        #expect(etat.groupe(source)?.ilResteDesPages == true)
        #expect(etat.nombreTotalDeResultats == 2)
    }
}
