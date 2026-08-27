import Foundation
import Testing
@testable import Core

//
// Verrouillage de l app, section 11 du cahier de developpement.
//
// Le delai n est pas recopie dans la suite. Il est lu dans le document, ce qui
// fait de la constante du code et de la phrase du cahier des charges une seule
// et meme decision : changer l une sans l autre fait virer la suite au rouge.
//

/// Le delai vient du document, pas d une copie.
struct DelaiDeVerrouillageTests {
    /// Delai en secondes tel que la section 11 l ecrit.
    private func delaiDuDocument() throws -> TimeInterval {
        let phrase = try #require(
            try CahierDeDeveloppement.ligne(contenant: "Verrouillage au bout de"),
            "La section 11 ne fixe plus de delai de verrouillage"
        )

        let chiffres = phrase
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { $0.isEmpty == false }

        let premier = try #require(chiffres.first)

        return try #require(TimeInterval(premier))
    }

    @Test("Le delai du code est celui de la section 11")
    func leDelaiEstCeluiDuDocument() throws {
        let phrase = try #require(try CahierDeDeveloppement.ligne(contenant: "Verrouillage au bout de"))

        #expect(phrase.contains("secondes en arriere plan"))
        #expect(try delaiDuDocument() == VerrouillageDeLApp.delaiEnArrierePlan)
        #expect(VerrouillageDeLApp.delaiEnArrierePlan == 30)
    }

    @Test("La section 11 impose l authentification locale et le repli sur le code")
    func leDocumentImposeLeRepli() throws {
        // Le fragment porte le tiret de puce de la section 11. Sans lui, la
        // premiere ligne trouvee serait la description de la carte
        // Confidentialite de la section 9, qui parle du meme reglage sans en
        // fixer la technique.
        let phrase = try #require(
            try CahierDeDeveloppement.ligne(contenant: "- Verrouillage de l app :")
        )

        #expect(phrase.contains("LocalAuthentication"))
        #expect(phrase.contains("repli sur le code de l appareil"))
    }
}

/// Le seuil des trente secondes en arriere plan.
struct SeuilDeVerrouillageTests {
    private let depart = Date(timeIntervalSince1970: 1_700_000_000)

    /// Verrou arme, application deja passee en arriere plan.
    private func verrouEnArrierePlan() -> VerrouillageDeLApp {
        var verrou = VerrouillageDeLApp(estArme: true)
        verrou.passerEnArrierePlan(le: depart)

        return verrou
    }

    @Test("Un retour avant le delai laisse l application ouverte")
    func avantLeDelaiRienNeSePasse() {
        var verrou = verrouEnArrierePlan()

        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(29.9))

        #expect(verrou.etat == .ouvert)
        #expect(verrou.etat.demandeUneAuthentification == false)
    }

    @Test("Un retour a la trentieme seconde exactement verrouille")
    func aLaTrentiemeSecondeLeVerrouSeFerme() {
        var verrou = verrouEnArrierePlan()

        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(30))

        #expect(verrou.etat == .verrouille)
        #expect(verrou.etat.demandeUneAuthentification)
    }

    @Test("Un retour apres le delai verrouille")
    func apresLeDelaiLeVerrouSeFerme() {
        var verrou = verrouEnArrierePlan()

        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(3600))

        #expect(verrou.etat == .verrouille)
    }

    @Test("Le verrou se ferme meme sans retour au premier plan")
    func leVerrouSeFermeSansRetour() {
        var verrou = verrouEnArrierePlan()

        #expect(verrou.etat(a: depart.addingTimeInterval(29)) == .ouvert)
        #expect(verrou.etat(a: depart.addingTimeInterval(30)) == .verrouille)

        verrou.verrouillerSiLeDelaiEstEcoule(a: depart.addingTimeInterval(31))

        #expect(verrou.etat == .verrouille)
    }

    @Test("L echeance annoncee tombe trente secondes apres le passage en arriere plan")
    func lEcheanceEstAnnoncee() {
        let verrou = verrouEnArrierePlan()

        #expect(verrou.dateDeVerrouillagePrevue == depart.addingTimeInterval(30))
    }

    @Test("Au premier plan, aucune echeance n est annoncee")
    func auPremierPlanAucuneEcheance() {
        var verrou = verrouEnArrierePlan()

        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(5))

        #expect(verrou.dateDeVerrouillagePrevue == nil)
        #expect(verrou.passeEnArrierePlanLe == nil)
    }

    @Test("Deux absences courtes ne s additionnent pas")
    func deuxAbsencesCourtesNeSAdditionnentPas() {
        var verrou = VerrouillageDeLApp(estArme: true)

        verrou.passerEnArrierePlan(le: depart)
        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(20))
        #expect(verrou.etat == .ouvert)

        verrou.passerEnArrierePlan(le: depart.addingTimeInterval(60))
        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(80))

        // Quarante secondes d absence cumulees, mais jamais trente d affilee.
        #expect(verrou.etat == .ouvert)
    }

    @Test("Reglage inactif, l application ne se verrouille jamais")
    func sansReglageAucunVerrouillage() {
        var verrou = VerrouillageDeLApp(estArme: false)

        verrou.passerEnArrierePlan(le: depart)
        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(86400))

        #expect(verrou.etat == .ouvert)
        #expect(verrou.dateDeVerrouillagePrevue == nil)
    }

    @Test("Un verrou deja ferme le reste tant que rien ne le rouvre")
    func unVerrouFermeLeReste() {
        var verrou = verrouEnArrierePlan()

        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(45))
        #expect(verrou.etat == .verrouille)

        verrou.passerEnArrierePlan(le: depart.addingTimeInterval(50))
        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(51))
        #expect(verrou.etat == .verrouille)

        verrou.deverrouiller()
        #expect(verrou.etat == .ouvert)
    }
}

/// Ce que le reglage fait, et ce qu il ne fait pas.
struct ReglageDeVerrouillageTests {
    private let depart = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Armer le reglage ne ferme pas l application sous les doigts")
    func armerNeVerrouillePas() {
        var verrou = VerrouillageDeLApp()

        verrou.armer()

        #expect(verrou.estArme)
        #expect(verrou.etat == .ouvert)
    }

    @Test("Desarmer le reglage rouvre une application deja verrouillee")
    func desarmerRouvre() {
        var verrou = VerrouillageDeLApp(estArme: true)

        verrou.passerEnArrierePlan(le: depart)
        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(60))
        #expect(verrou.etat == .verrouille)

        verrou.desarmer()

        #expect(verrou.estArme == false)
        #expect(verrou.etat == .ouvert)
        #expect(verrou.passeEnArrierePlanLe == nil)
    }

    @Test("Le reglage arme apres coup s applique au passage suivant")
    func leReglageArmeSAppliqueEnsuite() {
        var verrou = VerrouillageDeLApp(estArme: false)

        verrou.passerEnArrierePlan(le: depart)
        verrou.armer()
        verrou.revenirAuPremierPlan(le: depart.addingTimeInterval(60))

        // La date d entree en arriere plan est retenue meme quand le verrou
        // n est pas arme, la question ne se pose qu au moment de la reponse.
        #expect(verrou.etat == .verrouille)
    }
}

/// Choix du moyen d authentification et repli sur le code.
struct PolitiqueDeDeverrouillageTests {
    @Test("La biometrie passe devant quand l appareil la propose")
    func laBiometriePasseDevant() {
        let moyen = PolitiqueDeDeverrouillage.moyen(parmi: [.biometrie, .codeDeLAppareil])

        #expect(moyen == .biometrie)
    }

    @Test("Sans biometrie, le code de l appareil prend le relais")
    func leCodePrendLeRelais() {
        let moyen = PolitiqueDeDeverrouillage.moyen(parmi: [.codeDeLAppareil])

        #expect(moyen == .codeDeLAppareil)
        #expect(PolitiqueDeDeverrouillage.peutSArmer(avec: [.codeDeLAppareil]))
    }

    @Test("Un appareil sans code ne peut pas armer le verrou")
    func sansCodeLeVerrouNeSArmePas() {
        #expect(PolitiqueDeDeverrouillage.moyen(parmi: []) == nil)
        #expect(PolitiqueDeDeverrouillage.peutSArmer(avec: []) == false)
    }
}

/// L authentification, remplacee par un double pendant les tests.
struct AuthentificationDeVerrouillageTests {
    /// Authentification de test, qui rend ce qu on lui a dit de rendre.
    private struct AuthentificationDeTest: AuthentificationLocale {
        let disponibles: Set<MoyenDeDeverrouillage>
        let resultat: Result<MoyenDeDeverrouillage, ErreurDeVerrouillage>

        func moyensDisponibles() async -> Set<MoyenDeDeverrouillage> {
            disponibles
        }

        func deverrouiller(raison _: String) async throws -> MoyenDeDeverrouillage {
            try resultat.get()
        }
    }

    @Test("Une authentification reussie rouvre l application")
    func uneAuthentificationReussieRouvre() async throws {
        let authentification = AuthentificationDeTest(
            disponibles: [.biometrie, .codeDeLAppareil],
            resultat: .success(.biometrie)
        )
        var verrou = VerrouillageDeLApp(estArme: true, etat: .verrouille)

        let moyen = try await authentification.deverrouiller(raison: "raison de test")
        verrou.deverrouiller()

        #expect(moyen == .biometrie)
        #expect(verrou.etat == .ouvert)
    }

    @Test("Un renoncement laisse l application fermee sans erreur affichee")
    func unRenoncementLaisseFerme() async {
        let authentification = AuthentificationDeTest(
            disponibles: [.codeDeLAppareil],
            resultat: .failure(.annuleParLUtilisateur)
        )
        let verrou = VerrouillageDeLApp(estArme: true, etat: .verrouille)

        await #expect(throws: ErreurDeVerrouillage.annuleParLUtilisateur) {
            _ = try await authentification.deverrouiller(raison: "raison de test")
        }

        #expect(verrou.etat == .verrouille)
    }

    @Test("Un echec laisse l application fermee")
    func unEchecLaisseFerme() async {
        let authentification = AuthentificationDeTest(
            disponibles: [.biometrie],
            resultat: .failure(.echecDeLAuthentification)
        )
        let verrou = VerrouillageDeLApp(estArme: true, etat: .verrouille)

        await #expect(throws: ErreurDeVerrouillage.echecDeLAuthentification) {
            _ = try await authentification.deverrouiller(raison: "raison de test")
        }

        #expect(verrou.etat == .verrouille)
    }
}
