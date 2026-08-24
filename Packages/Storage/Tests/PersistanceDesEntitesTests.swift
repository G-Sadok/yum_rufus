import Core
import Foundation
import GRDB
import Testing
@testable import Storage

/// Verifie que chaque entite de la section 3.1 fait l aller retour complet
/// entre le modele et la base.
///
/// Une colonne oubliee dans le schema, ou nommee autrement que dans le modele,
/// ne se voit ni a la compilation ni a l insertion. Elle se voit ici, a la
/// relecture, quand la valeur revient differente de celle ecrite.
struct PersistanceDesEntitesTests {
    /// Date sans partie fractionnaire. La base stocke les dates a la
    /// milliseconde, comparer une date prise au vol echouerait sur l arrondi
    /// sans rien dire du schema.
    static let dateDeReference = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Une source fait l aller retour sans rien perdre")
    func allerRetourSource() throws {
        let base = try BaseDeDonnees.enMemoire()
        let source = Source(
            type: .komga,
            nom: "Serveur de la maison",
            configurationChiffree: Data([0x01, 0x02, 0x03]),
            versionExtension: "1.4.0",
            langue: "fr",
            ordreAffichage: 3,
            estActive: false,
            dateDerniereVerification: Self.dateDeReference,
            etatConnexion: .identifiantsInvalides
        )

        let relue = try base.ecrivain.write { connexion -> Source? in
            try source.insert(connexion)
            return try Source.fetchOne(connexion, key: source.id)
        }

        #expect(relue == source)
    }

    @Test("Une serie conserve ses listes et son sens de lecture force")
    func allerRetourManga() throws {
        let base = try BaseDeDonnees.enMemoire()
        let source = Source(type: .fichiersLocaux, nom: "Dossier")
        let manga = Manga(
            sourceId: source.id,
            identifiantDistant: "serie-1",
            titre: "Serie",
            titresAlternatifs: ["Autre titre", "Titre encore autre"],
            auteurs: ["Autrice"],
            dessinateurs: ["Dessinateur"],
            resume: "Un resume",
            genres: ["Action", "Drame"],
            statut: .enCours,
            langue: "ja",
            urlCouverture: "https://exemple.test/couverture.jpg",
            cheminCouvertureLocale: "/couvertures/serie-1.jpg",
            sensLectureForce: .droiteGauche,
            estDansBibliotheque: true,
            dateAjout: Self.dateDeReference,
            dateDerniereMiseAJour: Self.dateDeReference,
            dateDerniereLecture: Self.dateDeReference
        )

        let relue = try base.ecrivain.write { connexion -> Manga? in
            try source.insert(connexion)
            try manga.insert(connexion)
            return try Manga.fetchOne(connexion, key: manga.id)
        }

        #expect(relue == manga)
        #expect(relue?.sensLectureForce == .droiteGauche)
        #expect(relue?.titresAlternatifs.count == 2)
    }

    @Test("Un sens de lecture absent reste absent apres relecture")
    func sensDeLectureNonForce() throws {
        let base = try BaseDeDonnees.enMemoire()
        let source = Source(type: .fichiersLocaux, nom: "Dossier")
        let manga = Manga(sourceId: source.id, identifiantDistant: "serie-2", titre: "Serie")

        let relue = try base.ecrivain.write { connexion -> Manga? in
            try source.insert(connexion)
            try manga.insert(connexion)
            return try Manga.fetchOne(connexion, key: manga.id)
        }

        #expect(relue?.sensLectureForce == nil, "Un sens absent ne doit jamais etre devine")
    }

    @Test("Un chapitre conserve son numero decimal")
    func allerRetourChapitre() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)

        let bonus = Chapitre(
            mangaId: jeu.manga.id,
            identifiantDistant: "chapitre-bonus",
            numero: 10.5,
            titre: "Chapitre bonus",
            groupeTraduction: "Groupe",
            langue: "fr",
            datePublication: Self.dateDeReference,
            nombrePages: 18,
            estLu: false,
            pageAtteinte: 7,
            dateLecture: Self.dateDeReference,
            ordreDansSerie: 11
        )

        let relu = try base.ecrivain.write { connexion -> Chapitre? in
            try bonus.insert(connexion)
            return try Chapitre.fetchOne(connexion, key: bonus.id)
        }

        #expect(relu == bonus)
        #expect(relu?.numero == 10.5, "Un numero decimal arrondi perd les chapitres bonus")
    }

    @Test("Categories et ordres de lecture font l aller retour, liaisons comprises")
    func allerRetourDesEntitesDeBibliotheque() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let chapitre = try #require(jeu.chapitres.first)

        let categorie = Categorie(nom: "En cours", ordre: 1)
        let ordre = OrdreDeLecture(nom: "Chronologie", descriptif: "Univers complet")

        try base.ecrivain.write { connexion in
            try categorie.insert(connexion)
            try MangaCategorie(mangaId: jeu.manga.id, categorieId: categorie.id).insert(connexion)
            try ordre.insert(connexion)
            try OrdreDeLectureChapitre(
                ordreDeLectureId: ordre.id,
                chapitreId: chapitre.id,
                position: 0
            ).insert(connexion)
        }

        let relues = try base.ecrivain.read { connexion in
            try (
                categorie: Categorie.fetchOne(connexion, key: categorie.id),
                ordre: OrdreDeLecture.fetchOne(connexion, key: ordre.id),
                liaisonsDeCategorie: MangaCategorie.fetchCount(connexion),
                liaisonsDOrdre: OrdreDeLectureChapitre.fetchCount(connexion)
            )
        }

        #expect(relues.categorie == categorie)
        #expect(relues.ordre == ordre)
        #expect(relues.liaisonsDeCategorie == 1)
        #expect(relues.liaisonsDOrdre == 1)
    }

    @Test("Historique et signets font l aller retour")
    func allerRetourDeLHistoriqueEtDesSignets() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let chapitre = try #require(jeu.chapitres.first)

        let historique = EntreeHistorique(
            chapitreId: chapitre.id,
            dateLecture: Self.dateDeReference,
            dureeSeconde: 640,
            pageAtteinte: 12
        )
        let signet = Signet(
            chapitreId: chapitre.id,
            pageIndex: 4,
            note: "Planche marquante",
            dateCreation: Self.dateDeReference,
            vignetteLocale: "/vignettes/1.jpg"
        )

        let relues = try base.ecrivain.write { connexion in
            try historique.insert(connexion)
            try signet.insert(connexion)

            return try (
                historique: EntreeHistorique.fetchOne(connexion, key: historique.id),
                signet: Signet.fetchOne(connexion, key: signet.id)
            )
        }

        #expect(relues.historique == historique)
        #expect(relues.signet == signet)
    }

    @Test("Telechargements, prereglages et liaisons de suivi font l aller retour")
    func allerRetourDesEntitesDeService() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let chapitre = try #require(jeu.chapitres.first)

        let telechargement = Telechargement(
            chapitreId: chapitre.id,
            etat: .echoue,
            progression: 0.42,
            octetsTotal: 12345,
            dateAjout: Self.dateDeReference,
            messageErreur: "Serveur injoignable, verifie l adresse du serveur"
        )
        let prereglage = PrereglageLecture(nom: "Webtoon", donneesReglages: Data([0xAA, 0xBB]))
        let liaison = LiaisonSuivi(
            mangaId: jeu.manga.id,
            service: .aniList,
            identifiantDistant: "42",
            statut: .enLecture,
            chapitreVu: 12.5,
            note: 8,
            dateSynchronisation: Self.dateDeReference
        )

        let relues = try base.ecrivain.write { connexion in
            try telechargement.insert(connexion)
            try prereglage.insert(connexion)
            try liaison.insert(connexion)

            return try (
                telechargement: Telechargement.fetchOne(connexion, key: telechargement.id),
                prereglage: PrereglageLecture.fetchOne(connexion, key: prereglage.id),
                liaison: LiaisonSuivi.fetchOne(connexion, key: liaison.id)
            )
        }

        #expect(relues.telechargement == telechargement)
        #expect(relues.prereglage == prereglage)
        #expect(relues.liaison == liaison)
    }

    @Test("Une page conserve sa position et ses dimensions")
    func allerRetourPage() throws {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: 1)
        let chapitre = try #require(jeu.chapitres.first)

        let page = Page(
            chapitreId: chapitre.id,
            index: 12,
            urlDistante: "https://exemple.test/12.jpg",
            cheminLocal: "/pages/12.jpg",
            largeur: 3000,
            hauteur: 4500,
            octets: 1_240_000
        )

        let relue = try base.ecrivain.write { connexion -> Page? in
            try page.insert(connexion)
            return try Page.fetchOne(connexion, key: page.id)
        }

        #expect(relue == page)
    }
}
