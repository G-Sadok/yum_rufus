import Core
import Foundation
import GRDB
import Testing
@testable import Storage

/// Verifie les categories persistees : ordre, appartenance multiple, compteurs.
///
/// Les regles de classement elles memes sont verifiees par
/// `CategoriesDeBibliothequeTests` dans le paquet Core. Ce qui se joue ici est
/// ce que la base garde entre deux ouvertures.
struct CategoriesPersistentTests {
    // MARK: La categorie Tout

    @Test("L onglet Tout n a aucune ligne a supprimer et montre toute la bibliotheque")
    func toutNestPasSupprimable() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        let premiere = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2, titre: "Serie A")
        try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, titre: "Serie B")

        let enCours = try magasin.creer(nom: "En cours")
        try magasin.ajouter(premiere.manga.id, a: enCours.id)

        // Toutes les categories enregistrees disparaissent, Tout reste.
        try magasin.supprimer(enCours.id)

        #expect(try magasin.categories().isEmpty)
        #expect(try magasin.series(dans: .tout).count == 2)
        #expect(SelectionDeCategorie.tout.identifiant == nil)
    }

    @Test("Supprimer une categorie ne retire aucune serie de la bibliotheque")
    func suppressionSansPerteDeSerie() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        let contenu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let enCours = try magasin.creer(nom: "En cours")
        let prevus = try magasin.creer(nom: "Prevus")
        try magasin.definirLesCategories([enCours.id, prevus.id], pourSerie: contenu.manga.id)

        try magasin.supprimer(enCours.id)

        #expect(try magasin.series(dans: .tout).count == 1)
        #expect(try magasin.categories(deLaSerie: contenu.manga.id).map(\.nom) == ["Prevus"])
    }

    // MARK: Appartenance multiple

    @Test("Une serie appartient a plusieurs categories a la fois")
    func appartenanceMultiple() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        let contenu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)
        let enCours = try magasin.creer(nom: "En cours")
        let prevus = try magasin.creer(nom: "Prevus")

        try magasin.ajouter(contenu.manga.id, a: enCours.id)
        try magasin.ajouter(contenu.manga.id, a: prevus.id)

        #expect(try magasin.categories(deLaSerie: contenu.manga.id).map(\.nom) == ["En cours", "Prevus"])
        #expect(try magasin.series(dans: .categorie(enCours.id)).map(\.id) == [contenu.manga.id])
        #expect(try magasin.series(dans: .categorie(prevus.id)).map(\.id) == [contenu.manga.id])
    }

    @Test("Ajouter deux fois la meme serie a la meme categorie ne cree qu une liaison")
    func ajoutRepete() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        let contenu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let enCours = try magasin.creer(nom: "En cours")

        try magasin.ajouter(contenu.manga.id, a: enCours.id)
        try magasin.ajouter(contenu.manga.id, a: enCours.id)

        #expect(try magasin.compteurs().compteur(pour: .categorie(enCours.id)) == 1)
    }

    @Test("Retirer une serie d une categorie la laisse dans les autres")
    func retraitCible() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        let contenu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let enCours = try magasin.creer(nom: "En cours")
        let prevus = try magasin.creer(nom: "Prevus")
        try magasin.definirLesCategories([enCours.id, prevus.id], pourSerie: contenu.manga.id)

        try magasin.retirer(contenu.manga.id, de: enCours.id)

        #expect(try magasin.categories(deLaSerie: contenu.manga.id).map(\.nom) == ["Prevus"])
    }

    @Test("Une affectation vide laisse la serie dans la bibliotheque")
    func affectationVide() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        let contenu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let enCours = try magasin.creer(nom: "En cours")
        try magasin.ajouter(contenu.manga.id, a: enCours.id)

        try magasin.definirLesCategories([], pourSerie: contenu.manga.id)

        #expect(try magasin.categories(deLaSerie: contenu.manga.id).isEmpty)
        #expect(try magasin.series(dans: .tout).count == 1)
    }

    // MARK: Ordre persistant

    @Test("L ordre de la barre survit a la fermeture de la base")
    func ordrePersistant() throws {
        let dossier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("categories-\(UUID().uuidString)", isDirectory: true)
        let fichier = dossier.appendingPathComponent("bibliotheque.sqlite")

        defer { try? FileManager.default.removeItem(at: dossier) }

        let identifiants: [UUID]

        do {
            let base = try BaseDeDonnees.surDisque(a: fichier)
            let magasin = MagasinDeCategories(base: base)

            let enCours = try magasin.creer(nom: "En cours")
            let termines = try magasin.creer(nom: "Termines")
            let prevus = try magasin.creer(nom: "Prevus")

            try magasin.reordonner([prevus.id, enCours.id, termines.id])
            identifiants = [prevus.id, enCours.id, termines.id]
        }

        let rouverte = try BaseDeDonnees.surDisque(a: fichier)
        let magasin = MagasinDeCategories(base: rouverte)

        #expect(try magasin.categories().map(\.id) == identifiants)
        #expect(try magasin.categories().map(\.nom) == ["Prevus", "En cours", "Termines"])
        #expect(try magasin.categories().map(\.ordre) == [0, 1, 2])
    }

    @Test("Un deplacement ecrit les nouveaux rangs en base")
    func deplacementPersiste() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        try magasin.creer(nom: "En cours")
        try magasin.creer(nom: "Termines")
        let prevus = try magasin.creer(nom: "Prevus")

        try magasin.deplacer(prevus.id, vers: 0)

        #expect(try magasin.categories().map(\.nom) == ["Prevus", "En cours", "Termines"])
        #expect(try magasin.categories().map(\.ordre) == [0, 1, 2])
    }

    @Test("Une suppression rend les rangs contigus")
    func rangsContigusApresSuppression() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        let enCours = try magasin.creer(nom: "En cours")
        try magasin.creer(nom: "Termines")
        try magasin.creer(nom: "Prevus")

        try magasin.supprimer(enCours.id)

        #expect(try magasin.categories().map(\.ordre) == [0, 1])
        #expect(try magasin.categories().map(\.nom) == ["Termines", "Prevus"])
    }

    @Test("Une categorie creee se pose apres les categories deja rangees")
    func creationEnFinDeBarre() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        try magasin.creer(nom: "En cours")
        try magasin.creer(nom: "Termines")

        #expect(try magasin.categories().map(\.nom) == ["En cours", "Termines"])
    }

    // MARK: Nommage

    @Test("Deux categories ne peuvent pas porter le meme nom")
    func nomUnique() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        try magasin.creer(nom: "En cours")

        #expect(throws: ErreurDeCategorie.nomDejaPris(nom: "EN COURS")) {
            try magasin.creer(nom: "EN COURS")
        }
    }

    @Test("Un renommage garde le rang de l onglet")
    func renommageGardeLeRang() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        try magasin.creer(nom: "En cours")
        let termines = try magasin.creer(nom: "Termines")

        let renommee = try magasin.renommer(termines.id, en: "  Lus  ")

        #expect(renommee.nom == "Lus")
        #expect(renommee.ordre == 1)
        #expect(try magasin.categories().map(\.nom) == ["En cours", "Lus"])
    }

    @Test("Une categorie inconnue est refusee, jamais inventee")
    func categorieInconnue() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)
        let fantome = UUID()

        #expect(throws: ErreurDeCategorie.categorieInconnue(identifiant: fantome)) {
            try magasin.renommer(fantome, en: "En cours")
        }
        #expect(throws: ErreurDeCategorie.categorieInconnue(identifiant: fantome)) {
            try magasin.supprimer(fantome)
        }
        #expect(throws: ErreurDeCategorie.categorieInconnue(identifiant: fantome)) {
            try magasin.deplacer(fantome, vers: 0)
        }
    }

    @Test("Une serie inconnue est refusee")
    func serieInconnue() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)
        let categorie = try magasin.creer(nom: "En cours")
        let fantome = UUID()

        #expect(throws: ErreurDeCategorie.serieInconnue(identifiant: fantome)) {
            try magasin.ajouter(fantome, a: categorie.id)
        }
    }

    // MARK: Compteurs

    @Test("Les compteurs de la barre arrivent tous ensemble")
    func compteursDeLaBarre() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        let premiere = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, titre: "Serie A")
        let seconde = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, titre: "Serie B")
        try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, titre: "Serie C")

        let enCours = try magasin.creer(nom: "En cours")
        let prevus = try magasin.creer(nom: "Prevus")
        let vide = try magasin.creer(nom: "Termines")

        try magasin.ajouter(premiere.manga.id, a: enCours.id)
        try magasin.ajouter(seconde.manga.id, a: enCours.id)
        try magasin.ajouter(seconde.manga.id, a: prevus.id)

        let compteurs = try magasin.compteurs()

        #expect(compteurs.compteur(pour: .tout) == 3)
        #expect(compteurs.compteur(pour: .categorie(enCours.id)) == 2)
        #expect(compteurs.compteur(pour: .categorie(prevus.id)) == 1)
        #expect(compteurs.compteur(pour: .categorie(vide.id)) == 0)
    }

    @Test("Une serie sortie de la bibliotheque ne compte plus dans sa categorie")
    func compteurHorsBibliotheque() throws {
        let base = try BaseDeDonnees.enMemoire()
        let magasin = MagasinDeCategories(base: base)

        let contenu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let enCours = try magasin.creer(nom: "En cours")
        try magasin.ajouter(contenu.manga.id, a: enCours.id)

        try base.ecrivain.write { connexion in
            try connexion.execute(
                sql: "UPDATE manga SET estDansBibliotheque = 0 WHERE id = ?",
                arguments: [contenu.manga.id]
            )
        }

        let compteurs = try magasin.compteurs()

        #expect(compteurs.compteur(pour: .tout) == 0)
        #expect(compteurs.compteur(pour: .categorie(enCours.id)) == 0)
    }
}
