import Core
import DesignSystem
import Foundation
import Testing

/// Verifie les dimensions de la coquille contre les sections 2.1 a 2.5 de
/// DESIGN-SPEC.md, et l ordre des cinq destinations contre les sections 2.2,
/// 6.1 et 1.10.
///
/// Comme pour les jetons, aucune valeur du document n est recopiee ici. Les
/// tests lisent DESIGN-SPEC.md sur disque et comparent le code a la source.
///
/// Le comportement de la navigation est verifie par `NavigationDeCoquilleTests`.
struct CoquilleTests {
    // MARK: Ordre des cinq entrees

    @Test("Les cinq entrees sont dans l ordre impose par la section 2.2")
    func ordreDesEntrees() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Cinq entrees dans cet ordre strict"),
            "La section 2.2 doit enoncer l ordre des cinq entrees"
        )

        let libelles = try #require(ligne.components(separatedBy: ":").last)
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "."))) }
            .filter { !$0.isEmpty }

        #expect(libelles.count == 5, "Cinq entrees, ni plus ni moins")
        #expect(
            DestinationPrincipale.allCases.map(\.rawValue) == libelles.map { $0.lowercased() },
            "Ordre du document : \(libelles)"
        )
    }

    @Test("Le tableau 6.1 nomme les memes entrees dans le meme ordre")
    func libellesDeNavigation() throws {
        let tableau = try #require(
            try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Element", "Libelle"]).first,
            "Le tableau 6.1 doit exister"
        )

        let libelles = tableau.lignes
            .filter { $0[0].hasPrefix("Barre laterale ") }
            .map { $0[1] }

        #expect(
            DestinationPrincipale.allCases.map(\.rawValue) == libelles.map { $0.lowercased() },
            "Libelles du tableau 6.1 : \(libelles)"
        )
    }

    @Test("Le rang d une destination suit l ordre de la barre laterale")
    func rangDesDestinations() {
        #expect(DestinationPrincipale.allCases.map(\.rang) == [1, 2, 3, 4, 5])
        #expect(DestinationPrincipale.defaut == .bibliotheque)
    }

    @Test("Chaque destination porte le symbole du tableau 1.10")
    func symbolesDesDestinations() throws {
        let tableau = try #require(
            try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Element", "Symbole"]).first,
            "Le tableau 1.10 doit exister"
        )

        let symboles = Dictionary(
            uniqueKeysWithValues: tableau.lignes.map { ($0[0].lowercased(), $0[1]) }
        )

        for destination in DestinationPrincipale.allCases {
            #expect(
                Jetons.icone(de: destination) == symboles[destination.rawValue],
                "Symbole de \(destination.rawValue)"
            )
        }
    }

    // MARK: Dimensions

    @Test("La barre laterale reprend les dimensions de la section 2.2")
    func dimensionsDeLaBarreLaterale() throws {
        let valeurs = try valeursDuTableau(signe: "Largeur repliee")
        let nombre = LectureDeTableaux.premierNombre

        #expect(nombre(valeurs["Largeur"]) == Jetons.BarreLaterale.largeur)
        #expect(nombre(valeurs["Largeur repliee"]) == Jetons.BarreLaterale.largeurRepliee)
        #expect(nombre(valeurs["Marge d encastrement"]) == Jetons.BarreLaterale.margeDEncastrement)
        #expect(nombre(valeurs["Rayon"]) == Jetons.BarreLaterale.rayon)
        #expect(nombre(valeurs["Hauteur de ligne"]) == Jetons.BarreLaterale.hauteurDeLigne)
        #expect(nombre(valeurs["Rayon de ligne"]) == Jetons.BarreLaterale.rayonDeLigne)

        #expect(
            LectureDeTableaux.nombres(dans: valeurs["Icone"])
                == [Jetons.BarreLaterale.decalageDIcone, Jetons.BarreLaterale.tailleDIcone]
        )
        #expect(
            LectureDeTableaux.nombres(dans: valeurs["Libelle"])
                == [Jetons.BarreLaterale.decalageDeLibelle, Jetons.BarreLaterale.libelle.taille]
        )
    }

    @Test("Le bloc d appel premium reprend les valeurs de la section 2.2")
    func blocPremium() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Le bloc d appel premium se cale en bas"),
            "La section 2.2 doit decrire le bloc premium"
        )

        let valeurs = LectureDeTableaux.nombres(dans: ligne)
        #expect(valeurs.first == Jetons.BarreLaterale.hauteurDuBlocPremium, "Hauteur 52")
        #expect(valeurs.dropFirst().first == Jetons.BarreLaterale.rayonDuBlocPremium, "Rayon 12")
    }

    @Test("La fenetre reprend les dimensions de la section 2.1")
    func dimensionsDeLaFenetre() throws {
        let valeurs = try valeursDuTableau(signe: "Taille minimale")
        let nombres = LectureDeTableaux.nombres

        #expect(
            nombres(valeurs["Taille minimale"])
                == [Jetons.Fenetre.largeurMinimale, Jetons.Fenetre.hauteurMinimale]
        )
        #expect(
            nombres(valeurs["Taille par defaut a la premiere ouverture"])
                == [Jetons.Fenetre.largeurParDefaut, Jetons.Fenetre.hauteurParDefaut]
        )
        #expect(nombres(valeurs["Barre de titre"]).last == Jetons.Fenetre.hauteurDeBarreDeTitre)
        #expect(
            LectureDeTableaux.premierNombre(valeurs["Rayon de fenetre"]) == Jetons.Fenetre.rayon
        )

        let filet = try #require(valeurs["Filet sous la barre de titre"])
        #expect(LectureDeTableaux.premierNombre(filet) == Jetons.Fenetre.epaisseurDuFilet)
        #expect(filet.contains(Jetons.Fenetre.filetSousLaBarreDeTitre.notation))
    }

    @Test("Les deux gabarits de contenu reprennent la section 2.3")
    func gabaritsDeContenu() throws {
        let large = try #require(try SpecificationDeDesign.ligne(contenant: "**Gabarit large**"))
        #expect(
            LectureDeTableaux.nombres(dans: large)
                == [Jetons.Contenu.margeLaterale, Jetons.Contenu.largeurMaximale]
        )

        let colonne = try #require(try SpecificationDeDesign.ligne(contenant: "**Gabarit colonne**"))
        #expect(
            LectureDeTableaux.nombres(dans: colonne).first == Jetons.Contenu.largeurDeColonne
        )
    }

    // MARK: Adaptation iPad et iPhone

    @Test("Chaque contexte du tableau 2.5 recoit la presentation annoncee")
    func presentationParContexte() throws {
        let tableau = try #require(
            try SpecificationDeDesign.tableaux(
                dontLEnteteEst: ["Contexte", "Barre de navigation", "Marge laterale", "Gabarit colonne"]
            ).first,
            "Le tableau 2.5 doit exister"
        )

        for ligne in tableau.lignes {
            verifierLaLigneDuTableau25(ligne)
        }
    }

    @Test("macOS garde la barre laterale deployee")
    func presentationSurBureau() {
        #expect(PresentationDeNavigation.pour(.bureau) == .barreLaterale)
        #expect(PresentationDeNavigation.pour(.bureau).estUneBarreDOnglets == false)
    }

    // MARK: Lecture du document

    private func valeursDuTableau(signe propriete: String) throws -> [String: String] {
        let tableau = try #require(
            try LectureDeTableaux.tableauDeProprietes(contenantLaPropriete: propriete),
            "Aucun tableau ne porte la propriete \(propriete)"
        )

        return LectureDeTableaux.valeursParPropriete(tableau)
    }

    private func verifierLaLigneDuTableau25(_ ligne: [String]) {
        let navigation = ligne[1]
        let marge = LectureDeTableaux.premierNombre(ligne[2])
        let colonne = LectureDeTableaux.premierNombre(ligne[3])

        switch ligne[0] {
        case "iPad paysage":
            #expect(PresentationDeNavigation.pour(.iPadPaysage) == .barreLaterale)
            #expect(navigation.contains("\(Int(Jetons.BarreLaterale.largeur))"))
            #expect(marge == Jetons.Contenu.margeLaterale)
            #expect(colonne == Jetons.Contenu.largeurDeColonne)

        case "iPad portrait":
            #expect(PresentationDeNavigation.pour(.iPadPortrait) == .barreLateraleRepliee)
            #expect(navigation.contains("\(Int(Jetons.BarreLaterale.largeurRepliee))"))
            #expect(marge == Jetons.Contenu.margeLaterale)
            #expect(colonne == Jetons.Contenu.largeurDeColonne)

        case "iPhone":
            #expect(PresentationDeNavigation.pour(.iPhone).estUneBarreDOnglets)
            #expect(navigation.contains("barre d onglets basse"))
            #expect(marge == Jetons.Contenu.margeLateraleCompacte)

        default:
            Issue.record("Contexte inconnu dans le tableau 2.5 : \(ligne[0])")
        }
    }
}
