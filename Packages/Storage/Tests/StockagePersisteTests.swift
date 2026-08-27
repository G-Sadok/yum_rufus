import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Couvre le nommage des postes du stockage et le journal du nettoyage.
//
// Le magasin est la seule couche qui transforme un identifiant de dossier en
// quelque chose de lisible. Deux choses sont verifiees ici, et ce sont les deux
// facons dont un ecran de stockage peut mentir : nommer le mauvais chapitre, ou
// perdre en route un dossier que la base ne connait pas. Le second cas est le
// plus dangereux des deux, parce qu il fait disparaitre des octets bien reels
// d un ecran dont le seul role est de dire ou passe la place.
//

struct StockagePersisteTests {
    private func base(chapitres: Int = 3) throws -> (BaseDeDonnees, JeuDeDonneesDeTest.Contenu) {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: chapitres,
            pagesParChapitre: 24,
            titre: "Berserk"
        )

        return (base, jeu)
    }

    private func pesage(_ identifiant: UUID, _ octets: Int) -> PesageSurDisque {
        PesageSurDisque(nom: identifiant.uuidString, octets: octets)
    }

    /// Marque un chapitre lu, avec ou sans date.
    ///
    /// L ecriture vit dans une fonction synchrone plutot qu au corps des tests
    /// asynchrones : dans un contexte `async`, GRDB retient sa surcharge
    /// asynchrone de `write`, et la closure devrait alors capturer le jeu de
    /// donnees a travers une frontiere de concurrence sans rien y gagner.
    private func marquerLu(_ chapitre: Chapitre, date: Date?, dans base: BaseDeDonnees) throws {
        try base.ecrivain.write { connexion in
            var modifie = chapitre
            modifie.estLu = true
            modifie.dateLecture = date
            try modifie.update(connexion)
        }
    }

    // MARK: Nommage

    @Test("Un dossier de chapitre devient un poste nomme par sa serie et son numero")
    func leChapitreEstNommeParSaSerie() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDuStockage(base: base)

        let postes = try magasin.postes(
            depuis: [pesage(jeu.chapitres[0].id, 32_000_000)],
            de: .chapitresTelecharges
        )

        let chapitre = try #require(postes.first?.chapitre)

        #expect(chapitre.chapitreId == jeu.chapitres[0].id)
        #expect(chapitre.titreDeLaSerie == "Berserk")
        #expect(chapitre.numeroDeChapitre == 1)
        #expect(chapitre.estLu == false)
        #expect(postes[0].octets == 32_000_000)
    }

    @Test("La sous ligne dit si le chapitre est lu, ce que la base seule sait")
    func lEtatDeLectureRemonteJusquAuPoste() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDuStockage(base: base)

        try marquerLu(jeu.chapitres[0], date: nil, dans: base)

        let postes = try magasin.postes(
            depuis: [pesage(jeu.chapitres[0].id, 100)],
            de: .chapitresTelecharges
        )

        #expect(postes.first?.chapitre?.estLu == true)
    }

    @Test("Un dossier de cache devient un poste nomme par sa source")
    func laSourceEstNommee() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDuStockage(base: base)

        let postes = try magasin.postes(depuis: [pesage(jeu.source.id, 500)], de: .cacheDeChapitres)

        #expect(postes.first?.contenu == .source(nom: "Dossier de test"))
    }

    @Test("Un dossier que la base ne connait plus garde son poids dans le poste groupe")
    func leDossierInconnuGardeSonPoids() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDuStockage(base: base)

        let postes = try magasin.postes(
            depuis: [pesage(jeu.chapitres[0].id, 400), pesage(UUID(), 600)],
            de: .chapitresTelecharges
        )

        #expect(postes.count == 2)
        #expect(postes.reduce(0) { $0 + $1.octets } == 1000)

        let groupe = try #require(postes.first { $0.id == AssemblageDesPostes.clesDesAnonymes })

        #expect(groupe.octets == 600)
        #expect(groupe.contenu == .elementsAnonymes(nombre: 1))
    }

    @Test("Le cache d images ne cherche aucun nom, ses fichiers n en portent pas")
    func leCacheDImagesResteAnonyme() throws {
        let (base, _) = try base()
        let magasin = MagasinDuStockage(base: base)

        let postes = try magasin.postes(
            depuis: [PesageSurDisque(nom: "a1b2c3", octets: 700)],
            de: .cacheDImages
        )

        #expect(postes.count == 1)
        #expect(postes[0].contenu == .elementsAnonymes(nombre: 1))
        #expect(postes[0].octets == 700)
    }

    @Test("Un ecran sans aucun fichier ne demande rien a la base")
    func laListeVideNeDemandeRien() throws {
        let (base, _) = try base()
        let magasin = MagasinDuStockage(base: base)

        #expect(try magasin.postes(depuis: [], de: .chapitresTelecharges).isEmpty)
    }

    // MARK: Journal du nettoyage

    @Test("Seuls les chapitres lus remontent, et avec leur date de lecture")
    func seulsLesChapitresLusRemontent() async throws {
        let (base, jeu) = try base()
        let magasin = MagasinDuStockage(base: base)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        try marquerLu(jeu.chapitres[0], date: date, dans: base)

        let lus = try await magasin.chapitresLus(parmi: jeu.chapitres.map(\.id))

        #expect(lus.count == 1)
        #expect(lus[0].chapitreId == jeu.chapitres[0].id)
        #expect(lus[0].dateLecture == date)
    }

    @Test("Un chapitre marque lu sans date remonte quand meme, sans date inventee")
    func laDateAbsenteResteAbsente() async throws {
        let (base, jeu) = try base()
        let magasin = MagasinDuStockage(base: base)

        try marquerLu(jeu.chapitres[0], date: nil, dans: base)

        let lus = try await magasin.chapitresLus(parmi: [jeu.chapitres[0].id])

        #expect(lus.count == 1)
        #expect(lus[0].dateLecture == nil)
    }

    @Test("Un dossier hors de la bibliotheque ne remonte dans aucun resultat")
    func leDossierHorsBibliothequeNeRemontePas() async throws {
        let (base, _) = try base()
        let magasin = MagasinDuStockage(base: base)

        #expect(try await magasin.chapitresLus(parmi: [UUID()]).isEmpty)
        #expect(try await magasin.chapitresLus(parmi: []).isEmpty)
    }

    @Test("La file oublie la tache d un chapitre efface, et elle seule")
    func laFileOublieLaBonneTache() throws {
        let (base, jeu) = try base()
        let file = MagasinDeTelechargements(base: base)
        let magasin = MagasinDuStockage(base: base)

        try file.mettreEnFile(chapitre: jeu.chapitres[0].id)
        try file.mettreEnFile(chapitre: jeu.chapitres[1].id)

        let retirees = try magasin.retirerLesTaches(desChapitres: [jeu.chapitres[0].id])

        #expect(retirees == 1)
        #expect(try file.tache(pourLeChapitre: jeu.chapitres[0].id) == nil)
        #expect(try file.tache(pourLeChapitre: jeu.chapitres[1].id) != nil)
    }

    @Test("Oublier une liste vide ne touche pas la file")
    func oublierRienNeToucheRien() throws {
        let (base, jeu) = try base()
        let file = MagasinDeTelechargements(base: base)
        let magasin = MagasinDuStockage(base: base)

        try file.mettreEnFile(chapitre: jeu.chapitres[0].id)

        #expect(try magasin.retirerLesTaches(desChapitres: []) == 0)
        #expect(try file.taches().count == 1)
    }
}
