import Core
import Foundation
import Testing

/// Verifie les regles de classement de la barre de categories, section 5.1 de
/// DESIGN-SPEC.md.
///
/// Ces tests portent sur le modele seul. La persistance de l ordre est
/// verifiee par `CategoriesPersistentTests` dans le paquet Storage.
struct CategoriesDeBibliothequeTests {
    // MARK: La categorie Tout

    @Test("L onglet Tout ne designe aucune ligne de la base")
    func toutNEstPasUneLigne() {
        #expect(SelectionDeCategorie.tout.estTout)
        #expect(SelectionDeCategorie.tout.identifiant == nil)
        #expect(SelectionDeCategorie.defaut == .tout)
    }

    @Test("Une selection de categorie porte l identifiant de sa ligne")
    func selectionDeCategorie() {
        let identifiant = UUID()
        let selection = SelectionDeCategorie.categorie(identifiant)

        #expect(selection.estTout == false)
        #expect(selection.identifiant == identifiant)
    }

    @Test("Le compteur de Tout est le total de la bibliotheque")
    func compteurDeTout() {
        let enCours = UUID()
        let compteurs = CompteursDeCategories(total: 128, parCategorie: [enCours: 24])

        #expect(compteurs.compteur(pour: .tout) == 128)
        #expect(compteurs.compteur(pour: .categorie(enCours)) == 24)
    }

    @Test("Une categorie vide affiche zero et ne disparait pas de la barre")
    func compteurDUneCategorieVide() {
        let compteurs = CompteursDeCategories(total: 3, parCategorie: [:])

        #expect(compteurs.compteur(pour: .categorie(UUID())) == 0)
    }

    // MARK: Ordre

    @Test("Les categories sortent dans l ordre de leur rang")
    func triParRang() {
        let categories = [
            Categorie(nom: "Prevus", ordre: 2),
            Categorie(nom: "En cours", ordre: 0),
            Categorie(nom: "Termines", ordre: 1),
        ]

        #expect(OrdreDesCategories.trier(categories).map(\.nom) == ["En cours", "Termines", "Prevus"])
    }

    @Test("Le nom departage deux rangs egaux")
    func triAuNomARangEgal() {
        let categories = [
            Categorie(nom: "Termines", ordre: 0),
            Categorie(nom: "En cours", ordre: 0),
        ]

        #expect(OrdreDesCategories.trier(categories).map(\.nom) == ["En cours", "Termines"])
    }

    @Test("La renumerotation rend les rangs contigus a partir de zero")
    func renumerotation() {
        let categories = [
            Categorie(nom: "En cours", ordre: 4),
            Categorie(nom: "Termines", ordre: 9),
        ]

        #expect(OrdreDesCategories.renumeroter(categories).map(\.ordre) == [0, 1])
    }

    @Test("Un deplacement reordonne la barre et renumerote les rangs")
    func deplacement() {
        let categories = [
            Categorie(nom: "En cours", ordre: 0),
            Categorie(nom: "Termines", ordre: 1),
            Categorie(nom: "Prevus", ordre: 2),
        ]

        let apres = OrdreDesCategories.deplacer(categories, de: 2, vers: 0)

        #expect(apres.map(\.nom) == ["Prevus", "En cours", "Termines"])
        #expect(apres.map(\.ordre) == [0, 1, 2])
    }

    @Test("Un rang hors bornes laisse la barre intacte")
    func deplacementHorsBornes() {
        let categories = [
            Categorie(nom: "En cours", ordre: 0),
            Categorie(nom: "Termines", ordre: 1),
        ]

        let apres = OrdreDesCategories.deplacer(categories, de: 0, vers: 7)

        #expect(apres.map(\.nom) == ["En cours", "Termines"])
        #expect(apres.map(\.ordre) == [0, 1])
    }

    @Test("Une categorie creee se pose en fin de barre")
    func rangDUneNouvelleCategorie() {
        #expect(OrdreDesCategories.rangSuivant(apres: []) == 0)

        let categories = [
            Categorie(nom: "En cours", ordre: 0),
            Categorie(nom: "Termines", ordre: 5),
        ]

        #expect(OrdreDesCategories.rangSuivant(apres: categories) == 6)
    }

    // MARK: Nommage

    @Test("Le nom perd ses espaces de bordure")
    func nomNettoye() throws {
        #expect(try OrdreDesCategories.nomNettoye("  En cours  ") == "En cours")
    }

    @Test("Un nom vide est refuse")
    func nomVide() {
        #expect(throws: ErreurDeCategorie.nomVide) {
            try OrdreDesCategories.nomNettoye("   ")
        }
    }

    @Test("Deux noms qui ne different que par la casse ou les accents entrent en collision")
    func nomDejaPris() {
        let categories = [Categorie(nom: "Termines", ordre: 0)]

        #expect(throws: ErreurDeCategorie.nomDejaPris(nom: "TERMINES")) {
            try OrdreDesCategories.verifierLaDisponibilite(de: "TERMINES", parmi: categories)
        }

        // Le nom d une categorie est une donnee saisie par l utilisateur, elle
        // porte donc les accents que la langue impose, la ou le code du projet
        // s en passe.
        let accentue = "Termin\u{00E9}s"

        #expect(throws: ErreurDeCategorie.nomDejaPris(nom: accentue)) {
            try OrdreDesCategories.verifierLaDisponibilite(de: accentue, parmi: categories)
        }
    }

    @Test("Une categorie qui garde son nom ne se heurte pas a elle meme")
    func renommageSansChangement() throws {
        let categorie = Categorie(nom: "En cours", ordre: 0)

        try OrdreDesCategories.verifierLaDisponibilite(
            de: "En cours",
            parmi: [categorie],
            sauf: categorie.id
        )
    }
}
