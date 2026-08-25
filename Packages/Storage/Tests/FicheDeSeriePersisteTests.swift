import Core
import Foundation
import GRDB
import Testing
@testable import Storage

/// Verifie la fiche de serie persistee, section 5.6 de DESIGN-SPEC.md.
///
/// Quatrieme critere de F016 : le filtre et le tri des chapitres sont
/// persistants par serie. Les tests ecrivent, relisent depuis un magasin neuf,
/// et verifient qu une serie n herite jamais du reglage d une autre.
struct FicheDeSeriePersisteTests {
    // MARK: Persistance du filtre et du tri

    @Test("Une serie jamais reglee rend le reglage par defaut sans ecrire de ligne")
    func reglageParDefaut() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)
        let magasin = MagasinDeFicheDeSerie(base: base)

        #expect(try magasin.reglage(pourSerie: jeu.manga.id) == .defaut)

        let lignes = try base.ecrivain.read { connexion in
            try Int.fetchOne(connexion, sql: "SELECT COUNT(*) FROM reglageDeListeDeChapitres")
        }

        #expect(lignes == 0, "Aucune ligne n est ecrite tant que rien n a change")
    }

    @Test("Le filtre et le tri survivent a la fermeture de la fiche")
    func reglagePersiste() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)

        let voulu = ReglageDeListeDeChapitres(
            filtre: .telecharges,
            critere: .datePublication,
            ordre: .croissant
        )

        try MagasinDeFicheDeSerie(base: base).definirLeReglage(voulu, pourSerie: jeu.manga.id)

        // Magasin neuf : rien n est garde en memoire entre les deux acces.
        let relu = try MagasinDeFicheDeSerie(base: base).reglage(pourSerie: jeu.manga.id)

        #expect(relu == voulu)
    }

    @Test("Deux series gardent chacune leur reglage")
    func reglageParSerie() throws {
        let base = try BaseDeDonnees.enMemoire()
        let premiere = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2, titre: "Premiere")
        let seconde = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2, titre: "Seconde")
        let magasin = MagasinDeFicheDeSerie(base: base)

        let reglageDeLaPremiere = ReglageDeListeDeChapitres(filtre: .nonLus, ordre: .croissant)
        let reglageDeLaSeconde = ReglageDeListeDeChapitres(filtre: .lus, critere: .datePublication)

        try magasin.definirLeReglage(reglageDeLaPremiere, pourSerie: premiere.manga.id)
        try magasin.definirLeReglage(reglageDeLaSeconde, pourSerie: seconde.manga.id)

        #expect(try magasin.reglage(pourSerie: premiere.manga.id) == reglageDeLaPremiere)
        #expect(try magasin.reglage(pourSerie: seconde.manga.id) == reglageDeLaSeconde)
    }

    @Test("Un second enregistrement remplace le premier sans le dupliquer")
    func reglageRemplace() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2)
        let magasin = MagasinDeFicheDeSerie(base: base)

        try magasin.definirLeReglage(ReglageDeListeDeChapitres(filtre: .lus), pourSerie: jeu.manga.id)
        try magasin.definirLeReglage(ReglageDeListeDeChapitres(filtre: .nonLus), pourSerie: jeu.manga.id)

        let lignes = try base.ecrivain.read { connexion in
            try Int.fetchOne(connexion, sql: "SELECT COUNT(*) FROM reglageDeListeDeChapitres")
        }

        #expect(lignes == 1)
        #expect(try magasin.reglage(pourSerie: jeu.manga.id).filtre == .nonLus)
    }

    @Test("Regler une serie inconnue est une erreur nommee")
    func serieInconnue() throws {
        let base = try BaseDeDonnees.enMemoire()
        let inconnue = UUID()
        let magasin = MagasinDeFicheDeSerie(base: base)

        #expect(throws: ErreurDeFicheDeSerie.serieInconnue(identifiant: inconnue)) {
            try magasin.definirLeReglage(.defaut, pourSerie: inconnue)
        }
    }

    @Test("Le reglage disparait avec la serie")
    func reglageEnCascade() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2)
        let magasin = MagasinDeFicheDeSerie(base: base)

        try magasin.definirLeReglage(ReglageDeListeDeChapitres(filtre: .lus), pourSerie: jeu.manga.id)

        try base.ecrivain.write { connexion in
            _ = try Manga.deleteOne(connexion, key: jeu.manga.id)
        }

        let lignes = try base.ecrivain.read { connexion in
            try Int.fetchOne(connexion, sql: "SELECT COUNT(*) FROM reglageDeListeDeChapitres")
        }

        #expect(lignes == 0)
    }

    // MARK: Lecture de la fiche

    @Test("La fiche applique le reglage persiste a sa liste")
    func ficheFiltree() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 4)
        let magasin = MagasinDeFicheDeSerie(base: base)

        let premier = try #require(jeu.chapitres.first)
        try magasin.marquer([premier.id], commeLus: true)
        try magasin.definirLeReglage(ReglageDeListeDeChapitres(filtre: .lus), pourSerie: jeu.manga.id)

        let fiche = try magasin.fiche(deLaSerie: jeu.manga.id)

        #expect(fiche.chapitres.map(\.id) == [premier.id])
        #expect(fiche.nombreDeChapitres == 4, "Le filtre ne change pas le compte de la serie")
        #expect(fiche.reglage.filtre == .lus)
        #expect(fiche.nomDeLaSource == jeu.source.nom)
    }

    @Test("La fiche porte l etat de telechargement de chaque chapitre")
    func ficheAvecTelechargements() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)
        let termine = try #require(jeu.chapitres.first)
        let enCours = jeu.chapitres[1]

        try base.ecrivain.write { connexion in
            try Telechargement(
                chapitreId: termine.id,
                etat: .termine,
                dateAjout: Date()
            ).insert(connexion)

            try Telechargement(
                chapitreId: enCours.id,
                etat: .enCours,
                dateAjout: Date()
            ).insert(connexion)
        }

        let fiche = try MagasinDeFicheDeSerie(base: base).fiche(deLaSerie: jeu.manga.id)
        let telecharges = Set(fiche.chapitres.filter(\.estTelecharge).map(\.id))

        #expect(telecharges == [termine.id], "Seul un telechargement termine rend un chapitre hors ligne")
    }

    @Test("Une serie sans chapitre desactive le bouton principal")
    func ficheSansChapitre() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 0)

        let fiche = try MagasinDeFicheDeSerie(base: base).fiche(deLaSerie: jeu.manga.id)

        #expect(fiche.estSansChapitre)
        #expect(fiche.actionPrincipale == .aucunChapitre)
        #expect(fiche.actionPrincipale.estActive == false)
    }

    @Test("Lire la fiche d une serie inconnue est une erreur nommee")
    func ficheInconnue() throws {
        let base = try BaseDeDonnees.enMemoire()
        let inconnue = UUID()

        #expect(throws: ErreurDeFicheDeSerie.serieInconnue(identifiant: inconnue)) {
            try MagasinDeFicheDeSerie(base: base).fiche(deLaSerie: inconnue)
        }
    }

    // MARK: Marquage

    @Test("Marquer une selection lue passe par les declencheurs de non lus")
    func marquerUneSelection() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 4)
        let magasin = MagasinDeFicheDeSerie(base: base)

        let selection = jeu.chapitres.prefix(2).map(\.id)
        try magasin.marquer(selection, commeLus: true)

        #expect(try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base) == 2)

        let fiche = try magasin.fiche(deLaSerie: jeu.manga.id)
        let lus = fiche.chapitres.filter { $0.lecture == .lu }

        #expect(Set(lus.map(\.id)) == Set(selection))
    }

    @Test("Tout marquer lu ne laisse aucun chapitre non lu")
    func toutMarquerLu() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 5)
        let magasin = MagasinDeFicheDeSerie(base: base)

        try magasin.marquerToutLu(pourSerie: jeu.manga.id)

        #expect(try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base) == 0)

        let fiche = try magasin.fiche(deLaSerie: jeu.manga.id)

        #expect(fiche.actionPrincipale.numeroAffiche == nil)
        #expect(fiche.actionPrincipale.estActive, "Une serie lue se relit")
    }

    @Test("Remettre un chapitre non lu efface sa progression")
    func marquerNonLu() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2)
        let magasin = MagasinDeFicheDeSerie(base: base)
        let premier = try #require(jeu.chapitres.first)

        try magasin.marquer([premier.id], commeLus: true)
        try magasin.marquer([premier.id], commeLus: false)

        let fiche = try magasin.fiche(deLaSerie: jeu.manga.id)
        let relu = try #require(fiche.chapitres.first { $0.id == premier.id })

        #expect(relu.lecture == .nonLu)
        #expect(relu.pageAtteinte == 0)
        #expect(relu.dateLecture == nil)
    }
}
