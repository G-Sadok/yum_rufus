import Core
import Foundation
import Testing
@testable import Sync

//
// Couvre le troisieme critere : le mode hors ligne accumule les changements et
// les rejoue a la reconnexion.
//
// Deux facons de croire ce critere tenu sans qu il le soit, et chacune a son
// test. La premiere est de garder les changements en memoire : ils survivent a
// la coupure mais pas a la fermeture de l application, et c est exactement ce
// que fait un utilisateur qui lit dans un train puis range son telephone. La
// seconde est de vider le journal des l envoi parti, sans attendre l accuse :
// une coupure au milieu de l envoi perd alors tout, silencieusement.
//
// Le test verifie donc l etat du distant, pas la valeur rendue par le moteur.
// Un moteur qui dirait avoir tout renvoye sans que rien ne soit arrive serait
// une regression invisible ici et parfaitement visible sur le second appareil.
//

@Suite("Mode hors ligne et rejeu")
struct ModeHorsLigneTests {
    @Test("Hors ligne, rien ne part et tout est garde")
    func accumulationHorsLigne() async throws {
        let entrepot = EntrepotPartage()
        let conditions = ConditionsDeTest(AtelierDeSynchronisationICloud.contexteNominal.avecReseau(false))
        let appareil = AppareilDeTest(nom: "appareil-a", entrepot: entrepot, conditions: conditions)
        let chapitres = (0..<6).map { _ in UUID() }

        try await appareil.moteur.demarrer()

        for (rang, chapitre) in chapitres.enumerated() {
            try await appareil.moteur.enregistrer(
                AtelierDeSynchronisationICloud.progression(
                    chapitre: chapitre,
                    page: rang,
                    secondes: Double(rang)
                )
            )
        }

        for seconde in 0...60 {
            await appareil.moteur.tic(AtelierDeSynchronisationICloud.instant(Double(seconde)))
        }

        let envois = await entrepot.envois
        let enAttente = await appareil.moteur.changementsEnAttente

        #expect(envois == 0)
        #expect(enAttente == 6)
        #expect(await appareil.moteur.etatCourant == .horsLigne(changements: 6))
    }

    @Test("La reconnexion rejoue tout ce qui attendait")
    func rejeuALaReconnexion() async throws {
        let entrepot = EntrepotPartage()
        let conditions = ConditionsDeTest(AtelierDeSynchronisationICloud.contexteNominal.avecReseau(false))
        let premier = AppareilDeTest(nom: "appareil-a", entrepot: entrepot, conditions: conditions)
        let second = AppareilDeTest(nom: "appareil-b", entrepot: entrepot)
        let chapitres = (0..<6).map { _ in UUID() }

        try await premier.moteur.demarrer()
        try await second.moteur.demarrer()

        for (rang, chapitre) in chapitres.enumerated() {
            try await premier.moteur.enregistrer(
                AtelierDeSynchronisationICloud.progression(
                    chapitre: chapitre,
                    page: rang + 1,
                    secondes: Double(rang)
                )
            )
        }

        conditions.definirLeReseau(true)

        await premier.moteur.tic(AtelierDeSynchronisationICloud.instant(100))
        await second.moteur.synchroniserMaintenant(AtelierDeSynchronisationICloud.instant(101))

        #expect(await premier.moteur.changementsEnAttente == 0)

        for (rang, chapitre) in chapitres.enumerated() {
            let recue = try #require(await second.applicateur.progression(du: chapitre))

            #expect(recue.pageAtteinte == rang + 1)
        }
    }

    @Test("Une journee de lecture hors ligne ne pese que ses chapitres")
    func accumulationRegroupee() async throws {
        let entrepot = EntrepotPartage()
        let conditions = ConditionsDeTest(AtelierDeSynchronisationICloud.contexteNominal.avecReseau(false))
        let appareil = AppareilDeTest(nom: "appareil-a", entrepot: entrepot, conditions: conditions)
        let chapitres = (0..<3).map { _ in UUID() }

        try await appareil.moteur.demarrer()

        // Trois chapitres lus, la position partant toutes les deux secondes.
        for (rang, chapitre) in chapitres.enumerated() {
            for page in 0..<200 {
                try await appareil.moteur.enregistrer(
                    AtelierDeSynchronisationICloud.progression(
                        chapitre: chapitre,
                        page: page,
                        secondes: Double(rang * 400 + page * 2)
                    )
                )
            }
        }

        #expect(await appareil.moteur.changementsEnAttente == 3)

        conditions.definirLeReseau(true)
        await appareil.moteur.tic(AtelierDeSynchronisationICloud.instant(5000))

        let contenu = await entrepot.contenu()

        #expect(contenu.count == 3)

        for ligne in contenu {
            #expect(try ProgressionSynchronisee.lire(ligne).pageAtteinte == 199)
        }
    }

    @Test("Le journal survit a la fermeture de l application")
    func journalPersiste() async throws {
        let entrepot = EntrepotPartage()
        let conditions = ConditionsDeTest(AtelierDeSynchronisationICloud.contexteNominal.avecReseau(false))
        let magasin = MagasinDuJournalEnMemoire()
        let chapitre = UUID()

        let avantFermeture = MoteurDeSynchronisationICloud(
            entrepot: entrepot,
            magasin: magasin,
            applicateur: ApplicateurEspion(),
            appareil: "appareil-a",
            contexte: { conditions.courant }
        )

        try await avantFermeture.demarrer()
        try await avantFermeture.enregistrer(
            AtelierDeSynchronisationICloud.progression(chapitre: chapitre, page: 42, secondes: 0)
        )

        // L application se ferme. Un moteur neuf repart du meme magasin.
        let apresRelance = MoteurDeSynchronisationICloud(
            entrepot: entrepot,
            magasin: magasin,
            applicateur: ApplicateurEspion(),
            appareil: "appareil-a",
            contexte: { conditions.courant }
        )

        try await apresRelance.demarrer()

        #expect(await apresRelance.changementsEnAttente == 1)

        conditions.definirLeReseau(true)
        await apresRelance.tic(AtelierDeSynchronisationICloud.instant(10))

        let contenu = await entrepot.contenu()

        #expect(contenu.count == 1)
        #expect(try ProgressionSynchronisee.lire(#require(contenu.first)).pageAtteinte == 42)
    }

    @Test("Un envoi qui echoue ne vide pas le journal")
    func echecSansPerte() async throws {
        let entrepot = EntrepotPartage()
        let appareil = AppareilDeTest(nom: "appareil-a", entrepot: entrepot)
        let chapitre = UUID()

        try await appareil.moteur.demarrer()
        try await appareil.moteur.enregistrer(
            AtelierDeSynchronisationICloud.progression(chapitre: chapitre, page: 5, secondes: 0)
        )

        await entrepot.faireEchouer(.reseauIndisponible)
        await appareil.moteur.tic(AtelierDeSynchronisationICloud.instant(10))

        #expect(await appareil.moteur.changementsEnAttente == 1)

        await appareil.moteur.tic(AtelierDeSynchronisationICloud.instant(20))

        #expect(await appareil.moteur.changementsEnAttente == 0)
        #expect(await entrepot.contenu().count == 1)
    }

    @Test("Une page tournee pendant l envoi n est pas perdue")
    func lectureAuMilieuDeLEnvoi() async throws {
        let entrepot = EntrepotPartage()
        let magasin = MagasinDuJournalEnMemoire()
        let conditions = ConditionsDeTest(AtelierDeSynchronisationICloud.contexteNominal)
        let chapitre = UUID()

        let moteur = MoteurDeSynchronisationICloud(
            entrepot: entrepot,
            magasin: magasin,
            applicateur: ApplicateurEspion(),
            appareil: "appareil-a",
            contexte: { conditions.courant }
        )

        try await moteur.demarrer()
        try await moteur.enregistrer(
            AtelierDeSynchronisationICloud.progression(chapitre: chapitre, page: 10, secondes: 0)
        )

        await moteur.tic(AtelierDeSynchronisationICloud.instant(10))

        // La lecture continue apres l envoi. La ligne suivante doit partir au
        // tic d apres, et le magasin doit la porter.
        try await moteur.enregistrer(
            AtelierDeSynchronisationICloud.progression(chapitre: chapitre, page: 11, secondes: 12)
        )

        #expect(await moteur.changementsEnAttente == 1)
        #expect(try await magasin.journal().nombreEnAttente == 1)

        await moteur.tic(AtelierDeSynchronisationICloud.instant(20))

        let contenu = await entrepot.contenu()

        #expect(try ProgressionSynchronisee.lire(#require(contenu.first)).pageAtteinte == 11)
    }

    @Test("Une session incognito ne laisse rien partir, ni maintenant ni plus tard")
    func incognitoNAccumulePas() async throws {
        let entrepot = EntrepotPartage()
        let session = SessionIncognito.demarree(le: AtelierDeSynchronisationICloud.depart)
        let conditions = ConditionsDeTest(ContexteICloud(
            reglages: AtelierDeSynchronisationICloud.reglagesActifs,
            premium: .definitif,
            session: session
        ))
        let appareil = AppareilDeTest(nom: "appareil-a", entrepot: entrepot, conditions: conditions)
        let chapitre = UUID()

        try await appareil.moteur.demarrer()

        let decision = try await appareil.moteur.enregistrer(
            AtelierDeSynchronisationICloud.progression(chapitre: chapitre, page: 7, secondes: 0)
        )

        #expect(decision == .suspendueParIncognito)
        #expect(await appareil.moteur.changementsEnAttente == 0)

        // La session se termine. Rien ne doit repartir avec du retard.
        conditions.definir(AtelierDeSynchronisationICloud.contexteNominal)
        await appareil.moteur.tic(AtelierDeSynchronisationICloud.instant(30))

        #expect(await entrepot.contenu().isEmpty)
    }
}
