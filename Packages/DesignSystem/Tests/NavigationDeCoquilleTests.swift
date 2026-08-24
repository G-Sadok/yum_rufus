import Core
import DesignSystem
import Foundation
import SwiftUI
import Testing

/// Verifie le comportement de la navigation : repli, adaptation au gabarit,
/// clavier, focus, et libelles du catalogue de chaines.
///
/// Les dimensions de la coquille sont verifiees par `CoquilleTests`.
struct NavigationDeCoquilleTests {
    // MARK: Repli de la barre laterale

    @Test("Le repli bascule la barre entre 196 et 56")
    @MainActor
    func repliDeLaBarreLaterale() {
        let etat = EtatDeCoquille(contexte: .bureau)

        #expect(etat.barreLateraleRepliee == false)
        #expect(etat.largeurDeLaBarreLaterale == Jetons.BarreLaterale.largeur)

        etat.basculerLeRepliDeLaBarreLaterale()
        #expect(etat.barreLateraleRepliee)
        #expect(etat.largeurDeLaBarreLaterale == Jetons.BarreLaterale.largeurRepliee)

        etat.basculerLeRepliDeLaBarreLaterale()
        #expect(etat.barreLateraleRepliee == false)
        #expect(etat.largeurDeLaBarreLaterale == Jetons.BarreLaterale.largeur)
    }

    @Test("Une barre d onglets n a pas de repli a basculer")
    @MainActor
    func repliSansEffetSurIPhone() {
        let etat = EtatDeCoquille(contexte: .iPhone)

        #expect(etat.presentation.estUneBarreDOnglets)
        etat.basculerLeRepliDeLaBarreLaterale()
        #expect(etat.barreLateraleRepliee == false)
    }

    @Test("iPad portrait ouvre la barre deja repliee, le paysage la redeploie")
    @MainActor
    func repliSuitLaRotation() {
        let etat = EtatDeCoquille(contexte: .iPadPortrait)
        #expect(etat.barreLateraleRepliee)

        etat.sAdapter(a: .iPadPaysage)
        #expect(etat.presentation == .barreLaterale)
        #expect(etat.barreLateraleRepliee == false)

        etat.sAdapter(a: .iPadPortrait)
        #expect(etat.barreLateraleRepliee)
    }

    @Test("La destination survit au changement de gabarit")
    @MainActor
    func destinationConservee() {
        let etat = EtatDeCoquille(contexte: .iPadPaysage)
        etat.selectionner(.parcourir)

        etat.sAdapter(a: .iPhone)
        #expect(etat.destination == .parcourir)
        #expect(etat.presentation.estUneBarreDOnglets)

        etat.sAdapter(a: .bureau)
        #expect(etat.destination == .parcourir)
        #expect(etat.presentation == .barreLaterale)
    }

    // MARK: Navigation au clavier

    @Test("Chaque destination porte le raccourci de son rang")
    func raccourcisDeNavigation() {
        for destination in DestinationPrincipale.allCases {
            let touche = Jetons.RaccourciDeNavigation.touche(pour: destination)
            #expect(touche.character == Character(String(destination.rang)))
        }
    }

    @Test("Les fleches parcourent les cinq entrees sans boucler")
    @MainActor
    func fleches() {
        let etat = EtatDeCoquille(contexte: .bureau)
        #expect(etat.destination == .bibliotheque)

        etat.allerALaDestinationPrecedente()
        #expect(etat.destination == .bibliotheque, "La premiere entree ne boucle pas vers la derniere")

        for attendue in DestinationPrincipale.allCases.dropFirst() {
            etat.allerALaDestinationSuivante()
            #expect(etat.destination == attendue)
        }

        etat.allerALaDestinationSuivante()
        #expect(etat.destination == .reglages, "La derniere entree ne boucle pas vers la premiere")

        etat.allerALaDestinationPrecedente()
        #expect(etat.destination == .rechercher)
    }

    // MARK: Focus clavier et cibles de pointage

    @Test("Le contour de focus reprend les valeurs de la section 7")
    func contourDeFocus() throws {
        let valeurs = try reglesDAccessibilite()
        let valeur = try #require(valeurs["Focus clavier"], "Le tableau 7 doit fixer le focus clavier")

        #expect(
            LectureDeTableaux.nombres(dans: valeur) == [Jetons.Focus.epaisseur, Jetons.Focus.decalage]
        )
    }

    @Test("Les cibles de pointage reprennent les valeurs de la section 7")
    func ciblesDePointage() throws {
        let valeurs = try reglesDAccessibilite()

        #expect(
            LectureDeTableaux.premierNombre(valeurs["Cible de pointage, iOS et iPadOS"])
                == Jetons.Cible.auDoigt
        )
        #expect(
            LectureDeTableaux.premierNombre(valeurs["Cible de pointage, macOS"])
                == Jetons.Cible.auPointeur
        )
    }

    // MARK: Catalogue de chaines de l application

    @Test("Le catalogue de chaines nomme les cinq entrees comme le tableau 6.1")
    func catalogueDeChaines() throws {
        let tableau = try #require(
            try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Element", "Libelle"]).first
        )

        let attendus = tableau.lignes
            .filter { $0[0].hasPrefix("Barre laterale ") }
            .map { $0[1] }

        let catalogue = try CatalogueDeChaines.charger()

        for (index, destination) in DestinationPrincipale.allCases.enumerated() {
            let cle = "navigation.\(destination.rawValue)"
            #expect(catalogue[cle] == attendus[index], "Cle \(cle)")
        }
    }

    private func reglesDAccessibilite() throws -> [String: String] {
        let tableau = try #require(
            try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Regle", "Valeur"]).first,
            "Le tableau 7 doit exister"
        )

        return LectureDeTableaux.valeursParPropriete(tableau)
    }
}
