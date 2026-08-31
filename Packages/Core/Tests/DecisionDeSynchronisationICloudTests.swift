import Foundation
import Testing
@testable import Core

//
// Couvre la regle qui decide de ce qui part vers iCloud, et surtout ce qui
// n en part pas.
//
// Le test le plus important de ce fichier est celui du mode incognito. Une
// session sans trace qui enverrait la page atteinte vers iCloud deposerait la
// trace sur tous les autres appareils, ce que la section 11 interdit et que
// l utilisateur ne pourrait pas defaire. Le refus ne doit donc pas seulement
// empecher l envoi immediat, il doit aussi empecher l entree au journal :
// autrement le changement repartirait a la fin de la session, avec du retard.
//

@Suite("Decision de synchronisation iCloud")
struct DecisionDeSynchronisationICloudTests {
    static var toutActif: ReglagesDeLApplication {
        var reglages = ReglagesDeLApplication.parDefaut
        reglages.definir(.booleen(true), pour: .synchroniserLaProgression)
        reglages.definir(.booleen(true), pour: .synchroniserLaBibliotheque)

        return reglages
    }

    static var contexteNominal: ContexteICloud {
        ContexteICloud(reglages: toutActif)
    }

    @Test("Une progression part quand tout est en place")
    func envoiNominal() {
        let decision = SynchronisationICloud.decision(
            pour: .progressionDeChapitre,
            selon: Self.contexteNominal
        )

        #expect(decision == .envoyer)
    }

    @Test("Une session incognito bloque l envoi et l entree au journal")
    func incognitoBloque() {
        let contexte = ContexteICloud(
            reglages: Self.toutActif,
            session: .demarree(le: Date(timeIntervalSince1970: 1_700_000_000))
        )

        let decision = SynchronisationICloud.decision(pour: .progressionDeChapitre, selon: contexte)

        #expect(decision == .suspendueParIncognito)
        #expect(decision.entreAuJournal == false)
    }

    @Test("La bibliotheque continue de partir pendant une session incognito")
    func bibliothequePendantIncognito() {
        let contexte = ContexteICloud(
            reglages: Self.toutActif,
            session: .demarree(le: Date(timeIntervalSince1970: 1_700_000_000))
        )

        // La section 11 suspend les traces de lecture, pas la bibliotheque :
        // une serie ajoutee pendant la session est un geste explicite dont
        // l utilisateur attend le resultat sur ses autres appareils.
        #expect(SynchronisationICloud.decision(pour: .serieDeBibliotheque, selon: contexte) == .envoyer)
    }

    @Test("Chaque interrupteur ne gouverne que son entite")
    func interrupteursIndependants() {
        var reglages = ReglagesDeLApplication.parDefaut
        reglages.definir(.booleen(true), pour: .synchroniserLaProgression)
        reglages.definir(.booleen(false), pour: .synchroniserLaBibliotheque)

        let contexte = ContexteICloud(reglages: reglages)

        #expect(SynchronisationICloud.decision(pour: .progressionDeChapitre, selon: contexte) == .envoyer)
        #expect(
            SynchronisationICloud.decision(pour: .serieDeBibliotheque, selon: contexte)
                == .desactiveeParReglage
        )
    }

    @Test("Une installation neuve ne synchronise rien")
    func installationNeuve() {
        let contexte = ContexteICloud(reglages: .parDefaut)

        #expect(
            SynchronisationICloud.decision(pour: .progressionDeChapitre, selon: contexte)
                == .desactiveeParReglage
        )
    }

    @Test("Hors ligne, le changement est garde au lieu d etre perdu")
    func horsLigneGarde() {
        let contexte = Self.contexteNominal.avecReseau(false)
        let decision = SynchronisationICloud.decision(pour: .progressionDeChapitre, selon: contexte)

        #expect(decision == .differeeHorsLigne)
        #expect(decision.entreAuJournal)
    }

    @Test("Sans compte iCloud, rien n est garde")
    func compteAbsent() {
        let contexte = ContexteICloud(
            reglages: Self.toutActif,
            compteOuvert: false
        )

        let decision = SynchronisationICloud.decision(pour: .progressionDeChapitre, selon: contexte)

        #expect(decision == .compteAbsent)
        #expect(decision.entreAuJournal == false)
    }

    @Test("La cadence du produit tient dans le budget de trente secondes")
    func cadenceDansLeBudget() {
        let cadence = CadenceDeSynchronisation.parDefaut

        #expect(cadence.budgetDePropagation == 30)
        #expect(cadence.respecteLeBudget)
        #expect(cadence.pireCasDePropagation < cadence.budgetDePropagation)
    }
}
