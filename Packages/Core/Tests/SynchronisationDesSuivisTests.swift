import Foundation
import Testing
@testable import Core

//
// Couvre la regle qui decide qu une progression part, troisieme critere de la
// fonctionnalite.
//
// Le point le plus important du fichier est le dernier test : le mode incognito
// gagne dans toutes les combinaisons, y compris celles ou tout le reste est au
// vert. Sans lui, la regle pourrait dependre de l ordre dans lequel un appelant
// pose ses questions.
//

@Suite("Regle d envoi vers les suivis")
struct SynchronisationDesSuivisTests {
    /// Reglages d une installation ou l envoi est actif et sans confirmation.
    static var envoiActif: ReglagesDeLApplication {
        var reglages = ReglagesDeLApplication.parDefaut
        reglages.definir(.booleen(true), pour: .envoyerLaProgression)
        reglages.definir(.booleen(false), pour: .confirmerAvantDEnvoyer)

        return reglages
    }

    /// Compte connecte employe par les tests.
    static let compte = CompteDeSuivi(identifiant: "1", pseudonyme: "lectrice")

    /// Liaison posee sur une serie, arretee au chapitre 10.
    static let liaison = LiaisonSuivi(
        mangaId: UUID(),
        service: .aniList,
        identifiantDistant: "77",
        chapitreVu: 10
    )

    /// Contexte ou tout est au vert.
    static func contexteFavorable(
        session: SessionIncognito = .inactive,
        reglages: ReglagesDeLApplication? = nil,
        confirmationAccordee: Bool = false
    ) -> ContexteDeSynchronisation {
        ContexteDeSynchronisation(
            etat: .connecte(compte),
            reglages: reglages ?? envoiActif,
            session: session,
            confirmationAccordee: confirmationAccordee
        )
    }

    @Test("Une progression neuve part quand tout est au vert")
    func envoiNominal() {
        let decision = SynchronisationDesSuivis.decision(
            liaison: Self.liaison,
            chapitreLu: 11,
            contexte: Self.contexteFavorable()
        )

        #expect(decision == .envoyer)
        #expect(decision.envoie)
    }

    @Test("Une session incognito suspend l envoi")
    func incognitoSuspend() {
        let decision = SynchronisationDesSuivis.decision(
            liaison: Self.liaison,
            chapitreLu: 11,
            contexte: Self.contexteFavorable(session: .demarree(le: Date()))
        )

        #expect(decision == .suspendueParIncognito)
        #expect(decision.envoie == false)
    }

    @Test("L ecriture commandee est bien celle de la section 11")
    func ecritureCommandee() {
        #expect(SynchronisationDesSuivis.ecritureConcernee == .synchronisationVersLesSuivis)
        #expect(SynchronisationDesSuivis.ecritureConcernee.laisseUneTraceDeLecture)
    }

    @Test("L interrupteur inactif arrete l envoi")
    func reglageInactif() {
        let decision = SynchronisationDesSuivis.decision(
            liaison: Self.liaison,
            chapitreLu: 11,
            contexte: Self.contexteFavorable(reglages: .parDefaut)
        )

        #expect(decision == .desactiveeParReglage)
    }

    @Test("Un service deconnecte ou expire n envoie rien")
    func serviceDeconnecte() {
        for etat in [EtatDeConnexionDeSuivi.deconnecte, .expire(Self.compte)] {
            let contexte = ContexteDeSynchronisation(
                etat: etat,
                reglages: Self.envoiActif,
                session: .inactive
            )

            #expect(
                SynchronisationDesSuivis.decision(
                    liaison: Self.liaison,
                    chapitreLu: 11,
                    contexte: contexte
                ) == .serviceDeconnecte
            )
        }
    }

    @Test("Une serie non liee n envoie rien")
    func serieNonLiee() {
        let decision = SynchronisationDesSuivis.decision(
            liaison: nil,
            chapitreLu: 11,
            contexte: Self.contexteFavorable()
        )

        #expect(decision == .aucuneLiaison)
    }

    @Test("Une progression deja connue du service ne repart pas")
    func dejaAJour() {
        let decision = SynchronisationDesSuivis.decision(
            liaison: Self.liaison,
            chapitreLu: 10,
            contexte: Self.contexteFavorable()
        )

        #expect(decision == .dejaAJour)
    }

    @Test("La confirmation demandee retient l envoi jusqu a l accord")
    func confirmationDemandee() {
        var reglages = Self.envoiActif
        reglages.definir(.booleen(true), pour: .confirmerAvantDEnvoyer)

        let sansAccord = SynchronisationDesSuivis.decision(
            liaison: Self.liaison,
            chapitreLu: 11,
            contexte: Self.contexteFavorable(reglages: reglages)
        )
        let avecAccord = SynchronisationDesSuivis.decision(
            liaison: Self.liaison,
            chapitreLu: 11,
            contexte: Self.contexteFavorable(reglages: reglages, confirmationAccordee: true)
        )

        #expect(sansAccord == .confirmationRequise)
        #expect(avecAccord == .envoyer)
    }

    @Test("Le mode incognito gagne sur toutes les autres combinaisons")
    func incognitoGagneToujours() {
        var avecConfirmation = Self.envoiActif
        avecConfirmation.definir(.booleen(true), pour: .confirmerAvantDEnvoyer)

        let session = SessionIncognito.demarree(le: Date())
        let combinaisons = [
            Self.contexteFavorable(session: session),
            Self.contexteFavorable(session: session, reglages: .parDefaut),
            Self.contexteFavorable(session: session),
            Self.contexteFavorable(session: session, reglages: avecConfirmation, confirmationAccordee: true),
            ContexteDeSynchronisation(
                etat: .deconnecte,
                reglages: Self.envoiActif,
                session: session
            ),
        ]

        for contexte in combinaisons {
            #expect(
                SynchronisationDesSuivis.decision(
                    liaison: Self.liaison,
                    chapitreLu: 99,
                    contexte: contexte
                ) == .suspendueParIncognito
            )
        }
    }

    @Test("La session incognito arretee laisse repartir l envoi")
    func apresLIncognito() {
        var session = SessionIncognito.demarree(le: Date())
        session.arreter()

        let decision = SynchronisationDesSuivis.decision(
            liaison: Self.liaison,
            chapitreLu: 11,
            contexte: Self.contexteFavorable(session: session)
        )

        #expect(decision == .envoyer)
    }

    @Test("Le chapitre vu ne recule jamais")
    func progressionMonotone() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let enAvant = SynchronisationDesSuivis.liaisonAEnvoyer(Self.liaison, chapitreLu: 12, le: date)
        let enArriere = SynchronisationDesSuivis.liaisonAEnvoyer(Self.liaison, chapitreLu: 3, le: date)
        let identique = SynchronisationDesSuivis.liaisonAEnvoyer(Self.liaison, chapitreLu: 10, le: date)

        #expect(enAvant?.chapitreVu == 12)
        #expect(enAvant?.dateSynchronisation == date)
        #expect(enArriere == nil)
        #expect(identique == nil)
    }

    @Test("Le statut ne change que si l appelant en fournit un")
    func statutFacultatif() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let sansStatut = SynchronisationDesSuivis.liaisonAEnvoyer(Self.liaison, chapitreLu: 12, le: date)
        let avecStatut = SynchronisationDesSuivis.liaisonAEnvoyer(
            Self.liaison,
            chapitreLu: 12,
            statut: .termine,
            le: date
        )

        #expect(sansStatut?.statut == .enLecture)
        #expect(avecStatut?.statut == .termine)
    }
}
