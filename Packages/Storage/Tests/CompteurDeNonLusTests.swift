import Core
import Foundation
import GRDB
import Testing
@testable import Storage

/// Verifie que `manga.chapitresNonLus` reste juste quoi qu il arrive aux
/// chapitres.
///
/// Le compteur est denormalise pour que la grille n ait jamais a compter
/// pendant le defilement. Un compteur denormalise faux est pire qu un comptage
/// lent : il affiche une pastille qui ment. Chaque evenement capable de le
/// faire bouger a donc son test.
struct CompteurDeNonLusTests {
    @Test("Inserer des chapitres non lus incremente le compteur")
    func insertionIncremente() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)

        let compte = try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base)
        #expect(compte == 3)
    }

    @Test("Inserer un chapitre deja lu laisse le compteur tranquille")
    func insertionDUnChapitreLu() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2)

        try base.ecrivain.write { connexion in
            var chapitre = Chapitre(
                mangaId: jeu.manga.id,
                identifiantDistant: "deja-lu",
                numero: 99,
                ordreDansSerie: 99
            )
            chapitre.estLu = true
            try chapitre.insert(connexion)
        }

        let compte = try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base)
        #expect(compte == 2)
    }

    @Test("Marquer un chapitre lu decremente le compteur")
    func marquageLuDecremente() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)

        try base.ecrivain.write { connexion in
            var premier = try #require(jeu.chapitres.first)
            premier.estLu = true
            try premier.update(connexion)
        }

        let compte = try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base)
        #expect(compte == 2)
    }

    @Test("Remettre un chapitre non lu incremente le compteur")
    func remiseNonLuIncremente() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)
        var premier = try #require(jeu.chapitres.first)

        try base.ecrivain.write { connexion in
            premier.estLu = true
            try premier.update(connexion)
        }

        try base.ecrivain.write { connexion in
            premier.estLu = false
            try premier.update(connexion)
        }

        let compte = try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base)
        #expect(compte == 3)
    }

    @Test("Une mise a jour qui ne touche pas estLu ne bouge pas le compteur")
    func miseAJourNeutre() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)

        try base.ecrivain.write { connexion in
            var premier = try #require(jeu.chapitres.first)
            premier.titre = "Titre revise"
            premier.pageAtteinte = 4
            try premier.update(connexion)
        }

        let compte = try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base)
        #expect(compte == 3)
    }

    @Test("Supprimer un chapitre non lu decremente le compteur")
    func suppressionDecremente() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)

        try base.ecrivain.write { connexion in
            let premier = try #require(jeu.chapitres.first)
            _ = try Chapitre.deleteOne(connexion, key: premier.id)
        }

        let compte = try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base)
        #expect(compte == 2)
    }

    @Test("Supprimer un chapitre deja lu laisse le compteur tranquille")
    func suppressionDUnChapitreLu() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)
        var premier = try #require(jeu.chapitres.first)

        try base.ecrivain.write { connexion in
            premier.estLu = true
            try premier.update(connexion)
            _ = try Chapitre.deleteOne(connexion, key: premier.id)
        }

        let compte = try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base)
        #expect(compte == 2)
    }

    @Test("Deplacer un chapitre non lu transfere une unite entre les deux series")
    func changementDeSerie() throws {
        let base = try BaseDeDonnees.enMemoire()
        let depart = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)
        let arrivee = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            titre: "Serie d arrivee"
        )

        try base.ecrivain.write { connexion in
            var premier = try #require(depart.chapitres.first)
            premier.mangaId = arrivee.manga.id
            // L identifiant distant est unique par serie. Le conserver tel
            // quel heurterait celui du chapitre deja present dans la serie
            // d arrivee, et c est le schema qui a raison.
            premier.identifiantDistant = "chapitre-transfere"
            try premier.update(connexion)
        }

        let compteDepart = try JeuDeDonneesDeTest.chapitresNonLus(de: depart.manga.id, dans: base)
        let compteArrivee = try JeuDeDonneesDeTest.chapitresNonLus(de: arrivee.manga.id, dans: base)

        #expect(compteDepart == 2)
        #expect(compteArrivee == 2)
    }

    /// Le piege du compteur denormalise : une seule instruction qui change a
    /// la fois la serie et l etat de lecture reveille deux familles de
    /// declencheurs. Sans garde, la correction serait appliquee deux fois.
    @Test("Deplacer et marquer lu dans la meme instruction ne compte qu une fois")
    func changementDeSerieEtMarquageSimultanes() throws {
        let base = try BaseDeDonnees.enMemoire()
        let depart = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3)
        let arrivee = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 1,
            titre: "Serie d arrivee"
        )

        try base.ecrivain.write { connexion in
            var premier = try #require(depart.chapitres.first)
            premier.mangaId = arrivee.manga.id
            premier.identifiantDistant = "chapitre-transfere"
            premier.estLu = true
            try premier.update(connexion)
        }

        let compteDepart = try JeuDeDonneesDeTest.chapitresNonLus(de: depart.manga.id, dans: base)
        let compteArrivee = try JeuDeDonneesDeTest.chapitresNonLus(de: arrivee.manga.id, dans: base)

        #expect(compteDepart == 2, "La serie de depart doit perdre exactement un non lu")
        #expect(compteArrivee == 1, "La serie d arrivee recoit un chapitre deja lu")
    }

    @Test("La grille lit le compteur sans compter les chapitres")
    func laGrilleLitLaColonneDenormalisee() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 4)

        try base.ecrivain.write { connexion in
            var premier = try #require(jeu.chapitres.first)
            premier.estLu = true
            try premier.update(connexion)
        }

        let lignes = try base.ecrivain.read { connexion in
            try MangaDeGrille.enBibliotheque().fetchAll(connexion)
        }

        let ligne = try #require(lignes.first { $0.id == jeu.manga.id })
        #expect(ligne.chapitresNonLus == 3)
        #expect(ligne.titre == jeu.manga.titre)
    }
}
