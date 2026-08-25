import Core
import Testing
@testable import ReaderEngine

/// Couvre la fenetre de precharge de la section 6.2 : deux pages en avant, une
/// en arriere, bornees au chapitre et ordonnees par priorite.
struct PlanDePrechargeTests {
    @Test("Deux pages en avant et une en arriere, dans cet ordre de priorite")
    func fenetreParDefaut() {
        #expect(PlanDePrecharge.parDefaut.voisines(de: 5, nombreDePages: 20) == [6, 7, 4])
    }

    @Test("La page lue ne fait jamais partie de ses propres voisines")
    func pageLueExclue() {
        let voisines = PlanDePrecharge.parDefaut.voisines(de: 5, nombreDePages: 20)

        #expect(voisines.contains(5) == false)
    }

    @Test("La premiere page n a pas de voisine en arriere")
    func premierePage() {
        #expect(PlanDePrecharge.parDefaut.voisines(de: 0, nombreDePages: 20) == [1, 2])
    }

    @Test("La derniere page n a pas de voisine en avant")
    func dernierePage() {
        #expect(PlanDePrecharge.parDefaut.voisines(de: 19, nombreDePages: 20) == [18])
    }

    @Test("L avant derniere page ne deborde pas du chapitre")
    func avantDernierePage() {
        #expect(PlanDePrecharge.parDefaut.voisines(de: 18, nombreDePages: 20) == [19, 17])
    }

    @Test("Un chapitre d une seule page n a aucune voisine")
    func chapitreDUnePage() {
        #expect(PlanDePrecharge.parDefaut.voisines(de: 0, nombreDePages: 1).isEmpty)
    }

    @Test("Un chapitre vide ou un index hors bornes ne precharge rien")
    func bornesDegenerees() {
        let plan = PlanDePrecharge.parDefaut

        #expect(plan.voisines(de: 0, nombreDePages: 0).isEmpty)
        #expect(plan.voisines(de: -1, nombreDePages: 20).isEmpty)
        #expect(plan.voisines(de: 20, nombreDePages: 20).isEmpty)
    }

    @Test("Une profondeur negative est ramenee a zero")
    func profondeurNegative() {
        let plan = PlanDePrecharge(enAvant: -3, enArriere: -1)

        #expect(plan.enAvant == 0)
        #expect(plan.enArriere == 0)
        #expect(plan.voisines(de: 5, nombreDePages: 20).isEmpty)
    }

    /// Le sens de lecture decide de quel cote une page se pose, pas de celle qui
    /// vient apres. La precharge suit donc l ordre narratif, le meme dans les
    /// trois sens, et ce test existe pour que personne ne vienne plus tard
    /// renverser la fenetre en droite a gauche en croyant corriger un oubli.
    @Test("La fenetre suit l ordre narratif, identique dans les trois sens")
    func independanteDuSensDeLecture() {
        let plan = PlanDePrecharge.parDefaut
        let attendue = [6, 7, 4]
        let narratif = OrdreDesPages.ordreNarratif(nombreDePages: 20)

        for sens in SensDeLecture.allCases {
            let voisines = plan.voisines(de: 5, nombreDePages: 20)

            #expect(voisines == attendue, "sens \(sens.rawValue)")
            #expect(voisines.allSatisfy { narratif.contains($0) })
        }
    }
}
