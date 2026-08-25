import Core
import Foundation
import Testing

/// Couvre le premier critere de la fonctionnalite : l interface n expose que
/// les actions correspondant aux capacites declarees.
///
/// La verification porte sur les soixante quatre combinaisons de capacites et
/// non sur quelques exemples choisis. Une regle qui se lit comme un tableau se
/// teste comme un tableau, sans quoi la combinaison oubliee sera exactement
/// celle qu une source reelle declarera un jour.
struct ActionsDeSourceTests {
    /// Toutes les combinaisons possibles des six capacites.
    private static let combinaisons: [SourceCapacites] = (0..<64).map { SourceCapacites(rawValue: $0) }

    // MARK: Tableau des actions

    @Test("Chaque capacite commande exactement une action, et aucune n est orpheline")
    func bijectionEntreCapacitesEtActions() {
        let commandees = ActionDeSource.allCases.compactMap(\.capaciteRequise)

        #expect(Set(commandees) == Set(SourceCapacites.connues))
        #expect(commandees.count == SourceCapacites.connues.count)
    }

    @Test("Les actions inconditionnelles sont celles que le protocole impose a toutes")
    func actionsInconditionnelles() {
        #expect(
            Set(ActionDeSource.inconditionnelles) == [.parcourir, .ouvrirUneSerie, .listerLesChapitres, .lireUnChapitre]
        )
    }

    @Test("Sur les soixante quatre combinaisons, une action est offerte si et seulement si sa capacite est declaree")
    func actionsOffertesSurToutesLesCombinaisons() {
        for capacites in Self.combinaisons {
            let offertes = capacites.actionsOffertes

            for action in ActionDeSource.allCases {
                let attendu = action.capaciteRequise.map(capacites.contains) ?? true

                #expect(offertes.contains(action) == attendu, "\(action) pour \(capacites.rawValue)")
                #expect(capacites.offre(action) == attendu, "\(action) pour \(capacites.rawValue)")
            }
        }
    }

    @Test("Une source sans aucune capacite n offre que les actions inconditionnelles")
    func aucuneCapacite() {
        #expect(SourceCapacites([]).actionsOffertes == Set(ActionDeSource.inconditionnelles))
    }

    @Test("Une source qui declare tout offre toutes les actions")
    func toutesLesCapacites() {
        let toutes = SourceCapacites(SourceCapacites.connues)

        #expect(toutes.actionsOffertes == Set(ActionDeSource.allCases))
    }

    @Test("Declarer une capacite n ouvre aucune autre action que la sienne")
    func aucuneFuiteEntreCapacites() {
        for capacite in SourceCapacites.connues {
            let offertes = SourceCapacites(rawValue: capacite.rawValue).actionsOffertes
            let conditionnelles = offertes.filter { $0.capaciteRequise != nil }

            #expect(conditionnelles.count == 1)
            #expect(conditionnelles.first?.capaciteRequise == capacite)
        }
    }

    // MARK: Refus cote source

    @Test("Une action non offerte est refusee par l erreur de la capacite manquante")
    func actionNonOfferteRefusee() throws {
        let source = SourceDeTest(nom: "Dossier", capacites: [.recherche])

        for action in ActionDeSource.allCases where source.offre(action) == false {
            let capacite = try #require(action.capaciteRequise)

            #expect(throws: ErreurDeSource.capaciteIndisponible(capacite: capacite, source: "Dossier")) {
                try source.exiger(action)
            }
        }
    }

    @Test("Une action offerte passe sans lever")
    func actionOfferteAcceptee() throws {
        let source = SourceDeTest(nom: "Dossier", capacites: [.recherche, .pagination])

        for action in ActionDeSource.allCases where source.offre(action) {
            try source.exiger(action)
        }
    }

    @Test("Les actions offertes par une source sont celles de ses capacites")
    func actionsOffertesParLaSource() {
        let source = SourceDeTest(nom: "Dossier", capacites: [.recherche, .pagination])

        #expect(source.actionsOffertes == source.capacites.actionsOffertes)
        #expect(source.actionsOffertes.contains(.rechercher))
        #expect(source.actionsOffertes.contains(.chargerLaSuite))
        #expect(source.actionsOffertes.contains(.filtrer) == false)
        #expect(source.actionsOffertes.contains(.telecharger) == false)
    }

    @Test("Une action refusee cote interface leve la meme erreur que la fonction correspondante")
    func memeErreurQueLaFonction() async throws {
        let source = SourceDeTest(nom: "Dossier", capacites: [.recherche])
        let attendue = ErreurDeSource.capaciteIndisponible(capacite: .filtres, source: "Dossier")

        #expect(throws: attendue) {
            try source.exiger(ActionDeSource.filtrer)
        }

        await #expect(throws: attendue) {
            let requete = RequeteRecherche(texte: "x", filtres: FiltresDeRecherche(genres: ["action"]))

            _ = try await source.rechercher(requete)
        }
    }

    // MARK: Representation stable

    @Test("Le nom textuel des actions est stable")
    func nomsStables() {
        // Ces noms partent dans les reglages et dans les traces. Les renommer
        // en Swift ne doit pas changer ce qui a ete ecrit sur le disque.
        #expect(ActionDeSource.rechercher.rawValue == "rechercher")
        #expect(ActionDeSource.chargerLaSuite.rawValue == "chargerLaSuite")
        #expect(ActionDeSource.publierLaProgression.rawValue == "publierLaProgression")
    }
}
