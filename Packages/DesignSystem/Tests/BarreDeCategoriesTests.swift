import Core
import DesignSystem
import Foundation
import Testing

/// Verifie la barre de categories contre la section 5.1 de DESIGN-SPEC.md.
///
/// Comme pour la coquille, aucune valeur du document n est recopiee ici. Les
/// tests lisent DESIGN-SPEC.md sur disque et comparent le code a la source.
struct BarreDeCategoriesTests {
    // MARK: Dimensions

    @Test("La barre reprend les trois valeurs chiffrees de la section 5.1")
    func dimensionsDeLaBarre() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "**Barre de categories**"),
            "La section 5.1 doit decrire la barre de categories"
        )

        let valeurs = LectureDeTableaux.nombres(dans: ligne)

        #expect(
            valeurs == [
                Jetons.BarreDeCategories.hauteur,
                Jetons.BarreDeCategories.rayonDeLOngletActif,
                Jetons.BarreDeCategories.margeBasse,
            ],
            "Hauteur, rayon de l onglet actif, marge basse : \(valeurs)"
        )
    }

    @Test("Le compteur se pose a la distance ecrite par la section 5.1")
    func ecartDuCompteur() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Le compteur est en"),
            "La section 5.1 doit decrire le compteur"
        )

        #expect(LectureDeTableaux.nombres(dans: ligne).last == Jetons.BarreDeCategories.ecartDuCompteur)
        #expect(ligne.contains("text.tertiary"), "Le compteur est en text.tertiary")
        #expect(ligne.contains("tabulaires"), "Le compteur emploie des chiffres tabulaires")
    }

    @Test("Le rayon de l onglet actif est celui du tableau 1.6")
    func rayonDuTableau16() throws {
        let tableau = try #require(
            try SpecificationDeDesign.tableaux(dontLEnteteEst: ["Valeur", "Element"]).first,
            "Le tableau 1.6 doit exister"
        )

        let ligne = try #require(
            tableau.lignes.first { $0[1].contains("onglet de categorie actif") },
            "Le tableau 1.6 doit nommer l onglet de categorie actif"
        )

        #expect(
            LectureDeTableaux.premierNombre(ligne[0]) == Jetons.BarreDeCategories.rayonDeLOngletActif
        )
    }

    @Test("Le remplissage et l ecart entre onglets restent sur l echelle de 4")
    func valeursSurLEchelle() {
        #expect(Jetons.Espace.echelle.contains(Jetons.BarreDeCategories.remplissageHorizontal))
        #expect(Jetons.Espace.echelle.contains(Jetons.BarreDeCategories.espaceEntreOnglets))
        #expect(Jetons.Espace.echelle.contains(Jetons.BarreDeCategories.margeBasse))
    }

    @Test("Le libelle d un onglet n emploie pas la graisse reservee de la section 1.5")
    func graisseDuLibelle() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "La graisse 600 est reservee"),
            "La section 1.5 doit enumerer les cas de la graisse 600"
        )

        #expect(
            ligne.contains("onglet") == false,
            "L onglet de categorie ne fait pas partie des cinq cas de la graisse 600"
        )
        #expect(Jetons.BarreDeCategories.libelle.graisse == .normale)
        #expect(Jetons.BarreDeCategories.libelle == Jetons.Typo.callout)
    }

    @Test("La cible d un onglet tient la taille minimale au pointeur de la section 7")
    func cibleDePointage() {
        #expect(Jetons.BarreDeCategories.hauteur >= Jetons.Cible.auPointeur)
    }

    // MARK: Composition de la barre

    @Test("Tout ouvre la barre, les categories suivent dans leur ordre persiste")
    func toutEstToujoursEnPremier() {
        let prevus = Categorie(nom: "Prevus", ordre: 2)
        let enCours = Categorie(nom: "En cours", ordre: 0)
        let termines = Categorie(nom: "Termines", ordre: 1)

        let onglets = OngletDeCategorie.barre(
            libelleDeTout: "Tout",
            categories: [prevus, enCours, termines],
            compteurs: CompteursDeCategories(
                total: 128,
                parCategorie: [enCours.id: 24, termines.id: 61, prevus.id: 43]
            )
        )

        #expect(onglets.map(\.selection.estTout) == [true, false, false, false])
        #expect(onglets.map(\.libelle) == ["Tout", "En cours", "Termines", "Prevus"])
        #expect(onglets.map(\.compteur) == [128, 24, 61, 43])
    }

    @Test("Les libelles de reference de la section 5.1 se retrouvent dans la barre")
    func libellesDeReference() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Libelles de reference"),
            "La section 5.1 doit donner les libelles de reference"
        )

        let references = libellesEtCompteurs(de: ligne)
        let categories = references.dropFirst().enumerated().map { rang, reference in
            Categorie(nom: reference.libelle, ordre: rang)
        }

        var parCategorie: [UUID: Int] = [:]
        for (categorie, reference) in zip(categories, references.dropFirst()) {
            parCategorie[categorie.id] = reference.compteur
        }

        let onglets = try OngletDeCategorie.barre(
            libelleDeTout: #require(references.first).libelle,
            categories: categories,
            compteurs: CompteursDeCategories(
                total: #require(references.first).compteur,
                parCategorie: parCategorie
            )
        )

        #expect(onglets.map(\.libelle) == references.map(\.libelle))
        #expect(onglets.map(\.compteur) == references.map(\.compteur))
    }

    @Test("Le catalogue de chaines nomme le premier onglet comme la section 5.1")
    func libelleDeTout() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "Libelles de reference"))
        let premier = try #require(libellesEtCompteurs(de: ligne).first)
        let catalogue = try CatalogueDeChaines.charger()

        #expect(catalogue["categorie.tout"] == premier.libelle)
    }

    // MARK: La categorie Tout

    @Test("Tout n accepte aucune commande de gestion")
    func toutNestPasModifiable() {
        let categorie = Categorie(nom: "En cours", ordre: 0)

        let onglets = OngletDeCategorie.barre(
            libelleDeTout: "Tout",
            categories: [categorie],
            compteurs: CompteursDeCategories(total: 1, parCategorie: [categorie.id: 1])
        )

        #expect(onglets.map(\.estModifiable) == [false, true])
        #expect(onglets.map(\.selection.identifiant) == [nil, categorie.id])
    }

    @Test("Une barre sans aucune categorie garde son onglet Tout")
    func barreSansCategorie() {
        let onglets = OngletDeCategorie.barre(
            libelleDeTout: "Tout",
            categories: [],
            compteurs: CompteursDeCategories(total: 0, parCategorie: [:])
        )

        #expect(onglets.map(\.selection) == [.tout])
        #expect(onglets.map(\.compteur) == [0])
    }

    // MARK: Lecture du document

    /// Couples libelle et compteur d une ligne de libelles de reference.
    ///
    /// La ligne ecrit chaque onglet entre accents graves, sous la forme
    /// `Tout 128`. Le libelle est ce qui precede le nombre.
    private func libellesEtCompteurs(de ligne: String) -> [(libelle: String, compteur: Int)] {
        ligne
            .components(separatedBy: "`")
            .filter { morceau in morceau.contains(where: \.isNumber) }
            .compactMap { morceau in
                guard let compteur = LectureDeTableaux.premierNombre(morceau) else { return nil }

                let libelle = morceau
                    .prefix { !$0.isNumber }
                    .trimmingCharacters(in: .whitespaces)

                guard !libelle.isEmpty else { return nil }

                return (libelle, Int(compteur))
            }
    }
}
