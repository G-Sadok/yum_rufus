import Core
import Foundation
import Testing
@testable import Sync

//
// Couvre le premier critere : la progression de lecture se propage entre deux
// appareils en moins de trente secondes.
//
// La mesure est faite en temps simule, seconde par seconde, sous la cadence
// exacte du produit. Ce n est pas un contournement du critere, c est ce qui le
// rend verifiable a chaque execution : le nombre mesure est le nombre de
// secondes d horloge qui separent le geste de son arrivee, exactement ce que
// l utilisateur compterait avec un chronometre, sans les trente secondes
// d attente reelle qui feraient desactiver le test au premier jour presse.
//
// Le pire cas est choisi volontairement : l appareil qui recoit vient tout
// juste de sonder quand le geste a lieu, il devra donc attendre un cycle
// complet. Un test qui laisserait le sondage tomber au bon moment mesurerait
// la chance, pas le budget.
//

@Suite("Propagation entre deux appareils")
struct PropagationEntreAppareilsTests {
    /// Fait avancer les deux appareils seconde par seconde et rend le delai
    /// auquel le second connait la progression du premier.
    ///
    /// Rend nul quand la propagation n a pas eu lieu dans la fenetre observee.
    static func delaiDePropagation(
        de emetteur: AppareilDeTest,
        vers recepteur: AppareilDeTest,
        chapitre: UUID,
        depuis debut: TimeInterval,
        fenetre: TimeInterval
    ) async throws -> TimeInterval? {
        var seconde = debut

        while seconde <= debut + fenetre {
            await emetteur.moteur.tic(AtelierDeSynchronisationICloud.instant(seconde))
            await recepteur.moteur.tic(AtelierDeSynchronisationICloud.instant(seconde))

            if try await recepteur.applicateur.progression(du: chapitre) != nil {
                return seconde - debut
            }

            seconde += 1
        }

        return nil
    }

    @Test("Une page tournee sur un appareil arrive sur l autre en moins de trente secondes")
    func propagationDansLeBudget() async throws {
        let entrepot = EntrepotPartage()
        let premier = AppareilDeTest(nom: "appareil-a", entrepot: entrepot)
        let second = AppareilDeTest(nom: "appareil-b", entrepot: entrepot)
        let chapitre = UUID()

        try await premier.moteur.demarrer()
        try await second.moteur.demarrer()

        // Le recepteur vient de sonder : il attendra un cycle entier, c est le
        // pire cas du budget.
        await second.moteur.tic(AtelierDeSynchronisationICloud.instant(0))

        try await premier.moteur.enregistrer(
            AtelierDeSynchronisationICloud.progression(chapitre: chapitre, page: 12, secondes: 0)
        )

        let delai = try await Self.delaiDePropagation(
            de: premier,
            vers: second,
            chapitre: chapitre,
            depuis: 0,
            fenetre: 120
        )

        let mesure = try #require(delai, "la progression n est jamais arrivee")

        #expect(mesure < CadenceDeSynchronisation.parDefaut.budgetDePropagation)

        // La mesure doit aussi tenir dans le pire cas annonce par la cadence.
        // Sans cette ligne, une cadence relachee jusqu a vingt neuf secondes
        // passerait le budget tout en ayant perdu toute marge.
        #expect(mesure <= CadenceDeSynchronisation.parDefaut.pireCasDePropagation)

        let recue = try #require(await second.applicateur.progression(du: chapitre))

        #expect(recue.pageAtteinte == 12)
        #expect(recue.chapitreId == chapitre)
    }

    @Test("La progression qui arrive est bien la derniere page tournee")
    func derniereProgressionRetenue() async throws {
        let entrepot = EntrepotPartage()
        let premier = AppareilDeTest(nom: "appareil-a", entrepot: entrepot)
        let second = AppareilDeTest(nom: "appareil-b", entrepot: entrepot)
        let chapitre = UUID()

        try await premier.moteur.demarrer()
        try await second.moteur.demarrer()

        // Une rafale de lecture : dix pages en dix huit secondes.
        for page in 0..<10 {
            try await premier.moteur.enregistrer(
                AtelierDeSynchronisationICloud.progression(
                    chapitre: chapitre,
                    page: page,
                    secondes: Double(page) * 2
                )
            )
        }

        _ = try await Self.delaiDePropagation(
            de: premier,
            vers: second,
            chapitre: chapitre,
            depuis: 18,
            fenetre: 120
        )

        let recue = try #require(await second.applicateur.progression(du: chapitre))

        #expect(recue.pageAtteinte == 9)
    }

    @Test("Une rafale de lecture ne fait pas une requete par page")
    func regroupementDesEnvois() async throws {
        let entrepot = EntrepotPartage()
        let appareil = AppareilDeTest(nom: "appareil-a", entrepot: entrepot)
        let chapitre = UUID()

        try await appareil.moteur.demarrer()

        for page in 0..<30 {
            try await appareil.moteur.enregistrer(
                AtelierDeSynchronisationICloud.progression(
                    chapitre: chapitre,
                    page: page,
                    secondes: Double(page) * 2
                )
            )
        }

        await appareil.moteur.tic(AtelierDeSynchronisationICloud.instant(60))

        let envois = await entrepot.envois
        let contenu = await entrepot.contenu()

        #expect(envois == 1)
        #expect(contenu.count == 1)
        #expect(try ProgressionSynchronisee.lire(#require(contenu.first)).pageAtteinte == 29)
    }

    @Test("Une notification distante propage sans attendre le sondage")
    func propagationImmediate() async throws {
        let entrepot = EntrepotPartage()
        let premier = AppareilDeTest(nom: "appareil-a", entrepot: entrepot)
        let second = AppareilDeTest(nom: "appareil-b", entrepot: entrepot)
        let chapitre = UUID()

        try await premier.moteur.demarrer()
        try await second.moteur.demarrer()

        try await premier.moteur.enregistrer(
            AtelierDeSynchronisationICloud.progression(chapitre: chapitre, page: 3, secondes: 0)
        )

        await premier.moteur.synchroniserMaintenant(AtelierDeSynchronisationICloud.instant(1))
        await second.moteur.synchroniserMaintenant(AtelierDeSynchronisationICloud.instant(2))

        let recue = try #require(await second.applicateur.progression(du: chapitre))

        #expect(recue.pageAtteinte == 3)
    }

    @Test("Le lot distant est repris la ou il s etait arrete")
    func repriseParLots() async throws {
        let entrepot = EntrepotPartage(taillleDeLot: 2)
        let premier = AppareilDeTest(nom: "appareil-a", entrepot: entrepot)
        let second = AppareilDeTest(nom: "appareil-b", entrepot: entrepot)
        let chapitres = (0..<7).map { _ in UUID() }

        try await premier.moteur.demarrer()
        try await second.moteur.demarrer()

        for (rang, chapitre) in chapitres.enumerated() {
            try await premier.moteur.enregistrer(
                AtelierDeSynchronisationICloud.progression(chapitre: chapitre, page: rang, secondes: 0)
            )
        }

        await premier.moteur.synchroniserMaintenant(AtelierDeSynchronisationICloud.instant(5))
        await second.moteur.synchroniserMaintenant(AtelierDeSynchronisationICloud.instant(6))

        for chapitre in chapitres {
            #expect(try await second.applicateur.progression(du: chapitre) != nil)
        }
    }

    @Test("Un jeton refuse par le distant fait repartir de la zone entiere")
    func jetonPerime() async throws {
        let entrepot = EntrepotPartage()
        let premier = AppareilDeTest(nom: "appareil-a", entrepot: entrepot)
        let second = AppareilDeTest(nom: "appareil-b", entrepot: entrepot)
        let chapitre = UUID()

        try await premier.moteur.demarrer()
        try await second.moteur.demarrer()

        try await premier.moteur.enregistrer(
            AtelierDeSynchronisationICloud.progression(chapitre: chapitre, page: 8, secondes: 0)
        )

        await premier.moteur.synchroniserMaintenant(AtelierDeSynchronisationICloud.instant(5))
        await entrepot.faireEchouer(.jetonPerime)
        await second.moteur.synchroniserMaintenant(AtelierDeSynchronisationICloud.instant(6))

        let recue = try #require(await second.applicateur.progression(du: chapitre))

        #expect(recue.pageAtteinte == 8)
    }
}
