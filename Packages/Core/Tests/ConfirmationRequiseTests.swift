import Core
import Testing

/// Garde des actions destructives, section 4.8 de DESIGN-SPEC.md.
struct ConfirmationRequiseTests {
    @Test("Une confirmation sans demande n execute rien")
    func laConfirmationSansDemandeNExecuteRien() {
        var confirmation = ConfirmationRequise()

        let partie = confirmation.confirmer()

        #expect(confirmation.estDemandee == false)
        #expect(partie == false)
    }

    @Test("La demande ouvre la modale, la confirmation la referme et laisse partir l action")
    func laDemandePuisLaConfirmationLaissentPartirLAction() {
        var confirmation = ConfirmationRequise()

        confirmation.demander()
        #expect(confirmation.estDemandee)

        let partie = confirmation.confirmer()

        #expect(partie)
        #expect(confirmation.estDemandee == false)
    }

    @Test("Annuler referme la demande sans rien executer")
    func annulerNExecuteRien() {
        var confirmation = ConfirmationRequise()

        confirmation.demander()
        confirmation.annuler()

        let partie = confirmation.confirmer()

        #expect(confirmation.estDemandee == false)
        #expect(partie == false)
    }

    @Test("Une seconde confirmation ne rejoue pas l action")
    func laConfirmationNeVautQuUneFois() {
        var confirmation = ConfirmationRequise()

        confirmation.demander()

        let premiere = confirmation.confirmer()
        let seconde = confirmation.confirmer()

        #expect(premiere)
        #expect(seconde == false)
    }
}
