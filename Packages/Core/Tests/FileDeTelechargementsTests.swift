import Foundation
import Testing
@testable import Core

//
// Couvre l ordre de la file et le planificateur, section 4.11 de DESIGN-SPEC.md.
//
// Le second critere d acceptation de la fonctionnalite, la limite de
// telechargements simultanes respectee, se joue ici. Le planificateur est une
// fonction pure : la limite peut donc etre eprouvee sur des etats de file
// complets, y compris ceux qu un enchainement reel met des heures a produire,
// et non sur le seul enchainement qui s est produit le jour du test.
//

struct FileDeTelechargementsTests {
    /// Instant de reference, pour que les dates de mise en file soient fixes.
    private static let origine = Date(timeIntervalSince1970: 1_700_000_000)

    private func tache(
        _ rang: Int,
        etat: EtatTelechargement = .enAttente,
        priorite: PrioriteDeTelechargement = .normale,
        pagesTerminees: Int = 0,
        nombreDePages: Int = 24,
        octetsTotal: Int? = nil
    ) -> TelechargementAffiche {
        TelechargementAffiche(
            id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", rang))") ?? UUID(),
            chapitreId: UUID(),
            serieId: UUID(),
            titreDeLaSerie: "Berserk",
            numeroDeChapitre: Double(rang),
            etat: etat,
            priorite: priorite,
            pagesTerminees: pagesTerminees,
            nombreDePages: nombreDePages,
            octetsTotal: octetsTotal,
            dateAjout: Self.origine.addingTimeInterval(Double(rang))
        )
    }

    // MARK: Ordre de passage

    @Test("La priorite passe avant la date de mise en file")
    func laPrioriteDecideDabord() {
        let file = [
            tache(1, priorite: .normale),
            tache(2, priorite: .basse),
            tache(3, priorite: .haute),
        ]

        let ordre = OrdreDeLaFile.trier(file).map(\.numeroDeChapitre)

        #expect(ordre == [3, 1, 2])
    }

    @Test("A priorite egale, la file respecte l ordre de mise en file")
    func laDateDepartageLesEgalites() {
        let file = [tache(3), tache(1), tache(2)]

        #expect(OrdreDeLaFile.trier(file).map(\.numeroDeChapitre) == [1, 2, 3])
    }

    @Test("Deux taches egales en tout donnent toujours la meme file")
    func lOrdreEstTotal() {
        let premiere = tache(1)
        let seconde = TelechargementAffiche(
            id: UUID(uuidString: "ffffffff-0000-0000-0000-000000000001") ?? UUID(),
            chapitreId: UUID(),
            serieId: UUID(),
            titreDeLaSerie: "Berserk",
            numeroDeChapitre: 1,
            dateAjout: premiere.dateAjout
        )

        #expect(OrdreDeLaFile.trier([seconde, premiere]).map(\.id) == [premiere.id, seconde.id])
        #expect(OrdreDeLaFile.trier([premiere, seconde]).map(\.id) == [premiere.id, seconde.id])
    }

    // MARK: Limite de telechargements simultanes

    @Test("Le planificateur ne demarre jamais plus que la limite", arguments: 1...5)
    func laLimiteEstRespectee(limite: Int) {
        let file = (1...12).map { tache($0) }

        let decision = PlanificateurDeTelechargements.decision(
            taches: file,
            reglages: ReglagesDeTelechargement(simultanes: limite),
            reseau: .wifi
        )

        #expect(decision.aDemarrer.count == limite)
        #expect(PlanificateurDeTelechargements.actives(apres: decision, sur: file) == limite)
    }

    @Test("Les places deja occupees comptent dans la limite")
    func lesPlacesOccupeesComptent() {
        let file = [
            tache(1, etat: .enCours),
            tache(2, etat: .enCours),
            tache(3),
            tache(4),
        ]

        let decision = PlanificateurDeTelechargements.decision(
            taches: file,
            reglages: ReglagesDeTelechargement(simultanes: 3),
            reseau: .wifi
        )

        #expect(decision.aDemarrer.count == 1)
        #expect(PlanificateurDeTelechargements.actives(apres: decision, sur: file) == 3)
    }

    @Test("Une limite baissee rend des places avant d en accorder")
    func laLimiteBaisseeRendDesPlaces() {
        let file = (1...4).map { tache($0, etat: .enCours) }

        let decision = PlanificateurDeTelechargements.decision(
            taches: file,
            reglages: ReglagesDeTelechargement(simultanes: 2),
            reseau: .wifi
        )

        #expect(decision.aDemarrer.isEmpty)
        #expect(decision.aRemettreEnAttente.count == 2)
        #expect(PlanificateurDeTelechargements.actives(apres: decision, sur: file) == 2)

        // Ce sont les dernieres de la file qui rendent leur place, pas les
        // premieres : sinon une limite baissee arreterait le telechargement le
        // plus avance pour laisser tourner le plus recent.
        #expect(decision.aRemettreEnAttente == [file[2].id, file[3].id])
    }

    @Test("La limite est toujours ramenee dans les bornes du cahier")
    func laLimiteResteDansSesBornes() {
        #expect(ReglagesDeTelechargement(simultanes: 0).simultanes == 1)
        #expect(ReglagesDeTelechargement(simultanes: 99).simultanes == 5)
        #expect(ReglagesDeTelechargement().simultanes == 3)
    }

    @Test("Une tache en pause ne prend jamais une place")
    func lesTachesEnPauseNeDemarrentPas() {
        let file = [
            tache(1, etat: .suspendu),
            tache(2, etat: .termine),
            tache(3, etat: .echoue),
            tache(4, etat: .annule),
        ]

        let decision = PlanificateurDeTelechargements.decision(
            taches: file,
            reglages: ReglagesDeTelechargement(simultanes: 5),
            reseau: .wifi
        )

        #expect(decision.estVide)
    }

    // MARK: Restriction au reseau

    @Test("Le reglage Wi-Fi seulement arrete la file sur reseau cellulaire")
    func leWiFiSeulementArreteLaFile() {
        let file = [tache(1, etat: .enCours), tache(2)]

        let decision = PlanificateurDeTelechargements.decision(
            taches: file,
            reglages: ReglagesDeTelechargement(simultanes: 3, enWiFiSeulement: true),
            reseau: .cellulaire
        )

        #expect(decision.aDemarrer.isEmpty)
        #expect(decision.aRemettreEnAttente == [file[0].id])
        #expect(PlanificateurDeTelechargements.actives(apres: decision, sur: file) == 0)
    }

    @Test("Sans le reglage, le reseau cellulaire laisse la file travailler")
    func sansLeReglageLeCellulairePasse() {
        let file = [tache(1)]

        let decision = PlanificateurDeTelechargements.decision(
            taches: file,
            reglages: ReglagesDeTelechargement(simultanes: 3, enWiFiSeulement: false),
            reseau: .cellulaire
        )

        #expect(decision.aDemarrer == [file[0].id])
    }

    @Test("Hors ligne, aucun reglage ne fait travailler la file")
    func horsLigneRienNeDemarre() {
        let file = [tache(1)]

        for enWiFiSeulement in [true, false] {
            let decision = PlanificateurDeTelechargements.decision(
                taches: file,
                reglages: ReglagesDeTelechargement(simultanes: 3, enWiFiSeulement: enWiFiSeulement),
                reseau: .horsLigne
            )

            #expect(decision.aDemarrer.isEmpty)
        }
    }

    @Test("Une tache arretee par le reseau retourne en attente, pas en pause")
    func leReseauNeMetPasEnPause() {
        // La distinction est celle de la section 4.11 : la pause est un geste de
        // l utilisateur, et le retour du Wi-Fi ne doit pas la defaire.
        let file = [tache(1, etat: .enCours)]

        let decision = PlanificateurDeTelechargements.decision(
            taches: file,
            reglages: ReglagesDeTelechargement(),
            reseau: .horsLigne
        )

        #expect(decision.aRemettreEnAttente == [file[0].id])
    }

    // MARK: Progression

    @Test("La progression par chapitre est la part de pages scellees")
    func laProgressionEstExacte() {
        let enCours = tache(1, etat: .enCours, pagesTerminees: 14, nombreDePages: 24)

        #expect(enCours.progression == 14.0 / 24.0)
    }

    @Test("La progression ne depasse jamais un tour, meme si la source compte mal")
    func laProgressionEstPlafonnee() {
        let debordante = tache(1, etat: .enCours, pagesTerminees: 22, nombreDePages: 20)

        #expect(debordante.progression == 1)
        #expect(AvancementDeTelechargement.pagesFaites(22, sur: 20) == 20)
    }

    @Test("Une longueur inconnue laisse la progression a zero plutot que de mentir")
    func laLongueurInconnueNeMentPas() {
        #expect(tache(1, pagesTerminees: 3, nombreDePages: 0).progression == 0)
    }

    @Test("Une tache terminee vaut un meme quand la source n a jamais dit sa longueur")
    func laTacheTermineeVautUn() {
        #expect(tache(1, etat: .termine, nombreDePages: 0).progression == 1)
    }

    @Test("Une progression negative n existe pas")
    func laProgressionNeDescendPasSousZero() {
        #expect(AvancementDeTelechargement.part(-3, sur: 20) == 0)
        #expect(AvancementDeTelechargement.pagesFaites(-3, sur: 20) == 0)
    }
}
