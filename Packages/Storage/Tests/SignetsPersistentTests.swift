import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Signets de page, section 3.1 du cahier de developpement et sous ecran Signets
// de la section 5.5 de DESIGN-SPEC.md.
//
// Trois choses sont verifiees ici, dans l ordre des criteres de la
// fonctionnalite : la vignette survit a l ecriture, le saut rend la page
// marquee, et la sauvegarde emporte les signets.
//

struct SignetsPersistentTests {
    /// Base migree portant une serie de trois chapitres de trente pages.
    private func baseGarnie(
        titre: String = "Serie marquee"
    ) throws -> (base: BaseDeDonnees, jeu: JeuDeDonneesDeTest.Contenu) {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(
            dans: base,
            nombreDeChapitres: 3,
            pagesParChapitre: 30,
            titre: titre
        )

        return (base, jeu)
    }

    // MARK: Pose et vignette

    @Test("Un signet pose garde la page, la note et la vignette de la page marquee")
    func poseAvecVignette() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        let pose = try magasin.poser(
            chapitre: jeu.chapitres[1].id,
            page: 11,
            note: "  Le duel  ",
            vignette: "vignette-du-signet.jpg"
        )

        let relus = try magasin.signets()

        #expect(relus.count == 1)
        #expect(relus[0].id == pose.id)
        #expect(relus[0].pageIndex == 11)
        #expect(relus[0].note == "Le duel")
        #expect(relus[0].vignetteLocale == "vignette-du-signet.jpg")
    }

    @Test("La liste porte la serie et le chapitre, que la table des signets ignore")
    func listeJointe() throws {
        let (base, jeu) = try baseGarnie(titre: "Berserk")
        let magasin = MagasinDeSignets(base: base)

        try magasin.poser(chapitre: jeu.chapitres[2].id, page: 3)

        let relus = try magasin.signets()

        #expect(relus[0].titreDeLaSerie == "Berserk")
        #expect(relus[0].serieId == jeu.manga.id)
        #expect(relus[0].numeroDeChapitre == 3)
        #expect(relus[0].nombreDePages == 30)
    }

    @Test("Une page ne porte qu un signet, un second appui remplace la vignette")
    func unSeulSignetParPage() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        let premier = try magasin.poser(chapitre: jeu.chapitres[0].id, page: 5, vignette: "un.jpg")
        let second = try magasin.poser(chapitre: jeu.chapitres[0].id, page: 5, vignette: "deux.jpg")

        #expect(try magasin.nombre() == 1)
        #expect(second.id == premier.id)
        #expect(second.vignetteLocale == "deux.jpg")
    }

    @Test("Le bouton Signet pose au premier appui et retire au second")
    func basculeDuBouton() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)
        let chapitre = jeu.chapitres[0].id

        let pose = try magasin.basculer(chapitre: chapitre, page: 7, vignette: "sept.jpg")
        #expect(pose != nil)
        #expect(try magasin.signet(chapitre: chapitre, page: 7) != nil)

        let retrait = try magasin.basculer(chapitre: chapitre, page: 7)
        #expect(retrait == nil)
        #expect(try magasin.signet(chapitre: chapitre, page: 7) == nil)
        #expect(try magasin.nombre() == 0)
    }

    @Test("Un signet retire rend le nom de sa vignette, pour que le fichier parte aussi")
    func retraitRendLaVignette() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        let pose = try magasin.poser(chapitre: jeu.chapitres[0].id, page: 2, vignette: "deux.jpg")

        #expect(try magasin.retirer(pose.id) == "deux.jpg")
        #expect(try magasin.nombre() == 0)
    }

    @Test("Une page negative et un chapitre inconnu sont refuses")
    func poseRefusee() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)
        let inconnu = UUID()

        #expect(throws: ErreurDeSignet.pageInvalide(index: -3)) {
            try magasin.poser(chapitre: jeu.chapitres[0].id, page: -3)
        }

        #expect(throws: ErreurDeSignet.chapitreInconnu(identifiant: inconnu)) {
            try magasin.poser(chapitre: inconnu, page: 0)
        }
    }

    @Test("La note se modifie sans toucher a la page ni a la vignette")
    func modificationDeLaNote() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        let pose = try magasin.poser(chapitre: jeu.chapitres[0].id, page: 9, vignette: "neuf.jpg")
        let modifie = try magasin.modifierLaNote(pose.id, en: "A relire")

        #expect(modifie.note == "A relire")
        #expect(modifie.pageIndex == 9)
        #expect(modifie.vignetteLocale == "neuf.jpg")
    }

    // MARK: Saut

    @Test("Le saut depuis l ecran des signets ouvre le chapitre a la page marquee")
    func sautVersLaBonnePage() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        try magasin.poser(chapitre: jeu.chapitres[0].id, page: 4)
        let vise = try magasin.poser(chapitre: jeu.chapitres[2].id, page: 17)
        try magasin.poser(chapitre: jeu.chapitres[1].id, page: 23)

        let position = try magasin.position(de: vise.id)

        #expect(position.chapitreId == jeu.chapitres[2].id)
        #expect(position.pageIndex == 17)
        #expect(position.decalageDeDefilement == 0)
    }

    @Test("Le saut vers un signet supprime echoue au lieu d ouvrir une page au hasard")
    func sautVersUnSignetDisparu() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        let pose = try magasin.poser(chapitre: jeu.chapitres[0].id, page: 6)
        try magasin.retirer(pose.id)

        #expect(throws: ErreurDeSignet.signetInconnu(identifiant: pose.id)) {
            try magasin.position(de: pose.id)
        }
    }

    @Test("Un signet pose au dela des pages annoncees ouvre la derniere page existante")
    func sautBorneParLeChapitre() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1, pagesParChapitre: 30)
        let magasin = MagasinDeSignets(base: base)

        let pose = try magasin.poser(chapitre: jeu.chapitres[0].id, page: 24)

        // La source republie le chapitre en version plus courte.
        try base.ecrivain.write { connexion in
            try connexion.execute(
                sql: "UPDATE chapitre SET nombrePages = 10 WHERE id = ?",
                arguments: [jeu.chapitres[0].id]
            )
        }

        #expect(try magasin.position(de: pose.id).pageIndex == 9)
    }

    // MARK: Suppression du chapitre

    @Test("Supprimer un chapitre emporte ses signets")
    func cascadeDepuisLeChapitre() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        try magasin.poser(chapitre: jeu.chapitres[0].id, page: 1)
        try magasin.poser(chapitre: jeu.chapitres[1].id, page: 2)

        _ = try base.ecrivain.write { connexion in
            try Chapitre.deleteOne(connexion, key: jeu.chapitres[0].id)
        }

        #expect(try magasin.nombre() == 1)
    }

    // MARK: Sauvegarde

    @Test("La sauvegarde emporte les signets, page, note et vignette comprises")
    func sauvegardeDesSignets() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        try magasin.poser(chapitre: jeu.chapitres[0].id, page: 3, note: "Debut", vignette: "a.jpg")
        try magasin.poser(chapitre: jeu.chapitres[1].id, page: 14, vignette: "b.jpg")

        let sauvegarde = try magasin.sauvegarde()
        let relue = try SauvegardeDesSignets(donnees: sauvegarde.donnees())

        #expect(relue.signets.count == 2)
        #expect(relue.signets.contains { $0.note == "Debut" && $0.vignetteLocale == "a.jpg" })
        #expect(relue.signets.contains { $0.pageIndex == 14 && $0.vignetteLocale == "b.jpg" })
    }

    @Test("Une restauration en remplacement rend exactement les signets du fichier")
    func restaurationEnRemplacant() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        try magasin.poser(chapitre: jeu.chapitres[0].id, page: 3, note: "Debut", vignette: "a.jpg")
        let sauvegarde = try magasin.sauvegarde()

        try magasin.retirer(chapitre: jeu.chapitres[0].id, page: 3)
        try magasin.poser(chapitre: jeu.chapitres[2].id, page: 20)

        try magasin.restaurer(sauvegarde, enRemplacant: true)

        let relus = try magasin.signets()

        #expect(relus.count == 1)
        #expect(relus[0].pageIndex == 3)
        #expect(relus[0].note == "Debut")
        #expect(relus[0].vignetteLocale == "a.jpg")
    }

    @Test("Une restauration en fusion ajoute sans creer de double")
    func restaurationEnFusion() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        try magasin.poser(chapitre: jeu.chapitres[0].id, page: 3, note: "Debut")
        let sauvegarde = try magasin.sauvegarde()

        try magasin.poser(chapitre: jeu.chapitres[1].id, page: 8)
        try magasin.restaurer(sauvegarde, enRemplacant: false)

        let relus = try magasin.signets()

        #expect(relus.count == 2)
        #expect(relus.contains { $0.pageIndex == 3 && $0.note == "Debut" })
        #expect(relus.contains { $0.pageIndex == 8 })
    }

    @Test("Un signet restaure sur une page deja marquee prend la place du precedent")
    func restaurationSurUnePageOccupee() throws {
        let (base, jeu) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        try magasin.poser(chapitre: jeu.chapitres[0].id, page: 3, note: "Depuis la sauvegarde")
        let sauvegarde = try magasin.sauvegarde()

        try magasin.retirer(chapitre: jeu.chapitres[0].id, page: 3)
        try magasin.poser(chapitre: jeu.chapitres[0].id, page: 3, note: "Pose apres coup")

        try magasin.restaurer(sauvegarde, enRemplacant: false)

        let relus = try magasin.signets()

        #expect(relus.count == 1)
        #expect(relus[0].note == "Depuis la sauvegarde")
    }

    @Test("Un signet dont le chapitre est absent de cette installation est ignore")
    func restaurationDUnChapitreAbsent() throws {
        let (base, _) = try baseGarnie()
        let magasin = MagasinDeSignets(base: base)

        let orphelin = Signet(chapitreId: UUID(), pageIndex: 2, dateCreation: Date())

        try magasin.restaurer(SauvegardeDesSignets([orphelin]), enRemplacant: false)

        #expect(try magasin.nombre() == 0)
    }
}
