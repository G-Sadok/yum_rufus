import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Couvre le marquage du chapitre quitte pendant un enchainement, section 7.4.
//
// Le marquage passe par le protocole de Core, donc par le meme chemin que le
// moteur de lecture emprunte reellement. Un test qui appellerait `marquer` en
// direct verifierait une ecriture que le lecteur n emploie pas.
//
// Le compteur de chapitres non lus est verifie a chaque fois. Il est
// denormalise et tenu par declencheur, et un marquage qui l oublierait
// laisserait la grille afficher une pastille fausse jusqu a la prochaine
// reconstruction de l index.
//

struct MarquageAuPassageTests {
    @Test("Le chapitre quitte est marque lu, avec sa date et sa derniere page")
    func marquageDuChapitreQuitte() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2, pagesParChapitre: 20)
        let magasin = MagasinDeFicheDeSerie(base: base)
        let premier = try #require(jeu.chapitres.first)

        try await magasin.marquerLu(premier.id)

        let enBase = try await base.ecrivain.read { connexion in
            try Chapitre.fetchOne(connexion, key: premier.id)
        }
        let relu = try #require(enBase)

        #expect(relu.estLu)
        #expect(relu.pageAtteinte == 19)
        #expect(relu.dateLecture != nil)
    }

    @Test("Le marquage au passage met a jour le compteur de non lus")
    func compteurDeNonLus() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 3, pagesParChapitre: 10)
        let magasin = MagasinDeFicheDeSerie(base: base)
        let premier = try #require(jeu.chapitres.first)

        try await magasin.marquerLu(premier.id)

        let compte = try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base)
        #expect(compte == 2)
    }

    @Test("Marquer deux fois le meme chapitre ne change rien")
    func marquageIdempotent() async throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 2, pagesParChapitre: 10)
        let magasin = MagasinDeFicheDeSerie(base: base)
        let premier = try #require(jeu.chapitres.first)

        try await magasin.marquerLu(premier.id)
        try await magasin.marquerLu(premier.id)

        let compte = try JeuDeDonneesDeTest.chapitresNonLus(de: jeu.manga.id, dans: base)
        #expect(compte == 1)
    }

    @Test("Un chapitre disparu pendant la lecture ne fait pas echouer le marquage")
    func chapitreDisparu() async throws {
        let base = try BaseDeDonnees.enMemoire()
        try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let magasin = MagasinDeFicheDeSerie(base: base)

        // Une serie retiree de la bibliotheque pendant que le lecteur est
        // ouvert. Le moteur ne doit pas remonter d erreur pour cela : il n y a
        // plus rien a marquer, et la lecture en cours n a pas a s arreter.
        try await magasin.marquerLu(UUID())
    }
}
