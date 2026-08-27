import Foundation
import Testing
@testable import Core

//
// Couvre le contenu d un prereglage de lecture, section 7 du tableau de la
// section 5.5 de DESIGN-SPEC.md et section 9 du cahier de developpement.
//
// Le premier critere de la fonctionnalite nomme quatre choses capturees : le
// sens, les filtres, la teinte et les traitements. Chacune a son test, et
// aucune ne se contente d un aller retour reussi : le test change la valeur,
// puis verifie qu elle revient changee. Un contenu qui laisserait tomber un
// champ passerait un aller retour sur les valeurs par defaut sans broncher.
//

struct PrereglagesDeLectureTests {
    // MARK: Ce qu un prereglage capture

    @Test("Un prereglage capture le sens de lecture")
    func captureLeSens() {
        var reglages = ReglagesDeLApplication.parDefaut
        reglages.definir(.choix(SensDeLecture.gaucheDroite.rawValue), pour: .sensDeLecture)

        let contenu = ContenuDePrereglage.capture(reglages: reglages, filtres: .parDefaut)

        #expect(contenu.sens == .gaucheDroite)
        #expect(ContenuDePrereglage.parDefaut.sens == .droiteGauche)
    }

    @Test("Un prereglage capture les cinq curseurs de filtre")
    func captureLesFiltres() {
        var filtres = ReglagesDeFiltres.parDefaut
        filtres.regler(.luminosite, a: 62)
        filtres.regler(.chaleur, a: 18)
        filtres.regler(.nettete, a: 40)
        filtres.regler(.contraste, a: 71)
        filtres.regler(.gamma, a: 33)

        let contenu = ContenuDePrereglage.capture(reglages: .parDefaut, filtres: filtres)

        #expect(contenu.filtres.valeur(.luminosite) == 62)
        #expect(contenu.filtres.valeur(.chaleur) == 18)
        #expect(contenu.filtres.valeur(.nettete) == 40)
        #expect(contenu.filtres.valeur(.contraste) == 71)
        #expect(contenu.filtres.valeur(.gamma) == 33)
    }

    @Test("Un prereglage capture la teinte, le fond du lecteur")
    func captureLaTeinte() {
        var reglages = ReglagesDeLApplication.parDefaut
        reglages.definir(.choix(ChoixDeFondDuLecteur.sepia.rawValue), pour: .fondDuLecteur)

        let contenu = ContenuDePrereglage.capture(reglages: reglages, filtres: .parDefaut)

        #expect(contenu.fond == .sepia)
        #expect(ContenuDePrereglage.parDefaut.fond == .noirOled)
    }

    @Test("Un prereglage capture les trois traitements")
    func captureLesTraitements() {
        var filtres = ReglagesDeFiltres.parDefaut
        filtres.basculer(.reductionDuBruit, true)
        filtres.basculer(.colorisationIA, true)

        let contenu = ContenuDePrereglage.capture(reglages: .parDefaut, filtres: filtres)

        #expect(contenu.filtres.estActif(.reductionDuBruit))
        #expect(contenu.filtres.estActif(.colorisationIA))
        #expect(contenu.filtres.estActif(.ameliorationIA) == false)
    }

    @Test("Un prereglage capture la mise en page et le rognage des bords")
    func captureLeResteDeLaSectionLecteur() {
        var reglages = ReglagesDeLApplication.parDefaut
        reglages.definir(.choix(MiseEnPage.doublePage.rawValue), pour: .miseEnPage)
        reglages.definir(.booleen(true), pour: .rognerLesBords)

        let contenu = ContenuDePrereglage.capture(reglages: reglages, filtres: .parDefaut)

        #expect(contenu.miseEnPage == .doublePage)
        #expect(contenu.rognerLesBords)
    }

    // MARK: Sens de lecture et mise en page

    @Test("La mise en page verticale impose le sens applique")
    func leVerticalImposeLeSens() {
        // Le menu Sens de lecture ne propose que les deux sens horizontaux. Un
        // prereglage en defilement continu doit malgre tout appliquer le sens
        // vertical, sans quoi le moteur composerait des doubles pages sur une
        // sequence qui defile.
        let contenu = ContenuDePrereglage(sens: .droiteGauche, miseEnPage: .continuVertical)

        #expect(contenu.sens == .droiteGauche)
        #expect(contenu.sensApplique == .hautBas)
    }

    @Test("Une mise en page paginee laisse le sens choisi tel quel")
    func lePagineLaisseLeSens() {
        for miseEnPage in [MiseEnPage.pageUnique, .doublePage] {
            let contenu = ContenuDePrereglage(sens: .gaucheDroite, miseEnPage: miseEnPage)
            #expect(contenu.sensApplique == .gaucheDroite, "\(miseEnPage.rawValue)")
        }
    }

    // MARK: Application

    @Test("L application repose les cinq lignes de lecture capturees")
    func applicationDesLignes() {
        var filtres = ReglagesDeFiltres.parDefaut
        filtres.regler(.luminosite, a: 44)

        let contenu = ContenuDePrereglage(
            sens: .gaucheDroite,
            miseEnPage: .doublePage,
            fond: .blanc,
            rognerLesBords: true,
            filtres: filtres
        )

        let appliques = contenu.appliquer(a: .parDefaut)

        #expect(appliques[.sensDeLecture] == .choix(SensDeLecture.gaucheDroite.rawValue))
        #expect(appliques.choix(.miseEnPage, comme: MiseEnPage.self) == .doublePage)
        #expect(appliques.choix(.fondDuLecteur, comme: ChoixDeFondDuLecteur.self) == .blanc)
        #expect(appliques.booleen(.rognerLesBords))
        #expect(appliques.curseur(.luminositeDuLecteur) == 44)
    }

    @Test("L application ne touche a aucun reglage etranger a la lecture")
    func applicationSansDegats() {
        var reglages = ReglagesDeLApplication.parDefaut
        reglages.definir(.choix(ChoixDeTheme.paper.rawValue), pour: .theme)
        reglages.definir(.booleen(true), pour: .incognito)
        reglages.definir(.compteur(4), pour: .pagesGardeesEnMemoire)

        let appliques = ContenuDePrereglage(fond: .sepia).appliquer(a: reglages)

        #expect(appliques.choix(.theme, comme: ChoixDeTheme.self) == .paper)
        #expect(appliques.booleen(.incognito))
        #expect(appliques.compteur(.pagesGardeesEnMemoire) == 4)
        #expect(appliques.choix(.fondDuLecteur, comme: ChoixDeFondDuLecteur.self) == .sepia)
    }

    @Test("L application ecrit toutes les lignes en une seule fois")
    func applicationEnUnSeulLot() {
        // Le magasin pose ce lot dans une seule transaction. Si une ligne
        // capturee cessait d y figurer, l application deviendrait partielle
        // sans que rien ne le signale.
        let lignes = Set(ContenuDePrereglage.parDefaut.valeursAEcrire.keys)

        #expect(lignes == [
            .sensDeLecture,
            .miseEnPage,
            .fondDuLecteur,
            .rognerLesBords,
            .luminositeDuLecteur,
        ])
    }

    @Test("La luminosite du panneau et celle des reglages ne divergent pas")
    func luminositePartagee() {
        // La section 5.5 pose une ligne Luminosite du lecteur, la section 5.7
        // un curseur Luminosite. Deux surfaces, une grandeur.
        var filtres = ReglagesDeFiltres.parDefaut
        filtres.regler(.luminosite, a: 20)

        let appliques = ContenuDePrereglage(filtres: filtres).appliquer(a: .parDefaut)
        let relus = ReglagesDeFiltres.depuis(appliques)

        #expect(relus.valeur(.luminosite) == 20)
    }
}

//
// Forme persistee d un prereglage, nommage de la liste, et part prereglages de
// la sauvegarde de la section 10 du cahier de developpement.
//
// Suite distincte de la precedente, qui couvre ce qu un prereglage capture et
// ce qu il repose. Les deux sujets ne partagent aucun materiel et la coupure
// garde chaque suite lisible d un seul coup d oeil.
//

struct FormePersisteeDesPrereglagesTests {
    // MARK: Colonne JSON

    @Test("Le contenu survit a un aller retour par la colonne JSON")
    func allerRetourComplet() throws {
        var filtres = ReglagesDeFiltres.parDefaut
        filtres.regler(.chaleur, a: 27)
        filtres.regler(.gamma, a: 80)
        filtres.basculer(.ameliorationIA, true)

        let contenu = ContenuDePrereglage(
            sens: .gaucheDroite,
            miseEnPage: .continuVertical,
            fond: .grisSombre,
            rognerLesBords: true,
            filtres: filtres
        )

        let relu = try ContenuDePrereglage(donnees: contenu.donnees())

        #expect(relu == contenu)
        #expect(relu.sens == .gaucheDroite)
        #expect(relu.miseEnPage == .continuVertical)
        #expect(relu.fond == .grisSombre)
        #expect(relu.rognerLesBords)
        #expect(relu.filtres.valeur(.chaleur) == 27)
        #expect(relu.filtres.valeur(.gamma) == 80)
        #expect(relu.filtres.valeur(.contraste) == FiltreDImage.contraste.valeurParDefaut)
        #expect(relu.filtres.estActif(.ameliorationIA))
        #expect(relu.filtres.estActif(.colorisationIA) == false)
    }

    @Test("Un curseur pose sur sa valeur par defaut vaut un curseur jamais touche")
    func egaliteSurLesValeursEffectives() {
        var pose = ReglagesDeFiltres.parDefaut
        pose.regler(.contraste, a: FiltreDImage.contraste.valeurParDefaut)

        #expect(pose == ReglagesDeFiltres.parDefaut)
        #expect(pose.hashValue == ReglagesDeFiltres.parDefaut.hashValue)
    }

    @Test("Un curseur inconnu de cette version est ignore, le reste s applique")
    func curseurInconnuIgnore() throws {
        let json = """
        {
          "version": 1,
          "sens": "gaucheDroite",
          "miseEnPage": "pageUnique",
          "fond": "sepia",
          "rognerLesBords": false,
          "filtres": {
            "curseurs": { "chaleur": 33, "saturation": 90 },
            "traitements": ["reductionDuBruit", "restaurationParIA"]
          }
        }
        """

        let contenu = try ContenuDePrereglage(donnees: Data(json.utf8))

        #expect(contenu.fond == .sepia)
        #expect(contenu.filtres.valeur(.chaleur) == 33)
        #expect(contenu.filtres.estActif(.reductionDuBruit))
        #expect(contenu.filtres.estActif(.ameliorationIA) == false)
    }

    @Test("Un contenu ecrit par une version inconnue est refuse, pas devine")
    func versionInconnueRefusee() throws {
        let json = """
        {"version": 99, "sens": "droiteGauche", "miseEnPage": "pageUnique",
         "fond": "noirOled", "rognerLesBords": false,
         "filtres": {"curseurs": {}, "traitements": []}}
        """

        #expect(throws: ErreurDePrereglage.formatInconnu(version: 99)) {
            try ContenuDePrereglage(donnees: Data(json.utf8))
        }
    }

    @Test("Des octets qui ne decrivent pas un contenu sont refuses")
    func contenuIllisibleRefuse() {
        #expect(throws: ErreurDePrereglage.contenuIllisible) {
            try ContenuDePrereglage(donnees: Data([0x00, 0x01, 0x02]))
        }
    }

    @Test("Un curseur relu hors bornes revient dans ses bornes")
    func curseurHorsBornesContraint() throws {
        let json = """
        {"version": 1, "sens": "droiteGauche", "miseEnPage": "pageUnique",
         "fond": "noirOled", "rognerLesBords": false,
         "filtres": {"curseurs": {"contraste": 900, "gamma": -40}, "traitements": []}}
        """

        let contenu = try ContenuDePrereglage(donnees: Data(json.utf8))

        #expect(contenu.filtres.valeur(.contraste) == 100)
        #expect(contenu.filtres.valeur(.gamma) == 0)
    }

    // MARK: Ordre et nommage

    @Test("La liste se trie naturellement, pas lexicographiquement")
    func triNaturelDeLaListe() throws {
        let noms = ["Webtoon 10", "Webtoon 2", "Manga sombre", "webtoon 1"]
        let prereglages = try noms.map {
            try PrereglageLecture(nom: $0, contenu: .parDefaut)
        }

        let tries = OrdreDesPrereglages.trier(prereglages).map(\.nom)

        #expect(tries == ["Manga sombre", "webtoon 1", "Webtoon 2", "Webtoon 10"])
    }

    @Test("Un nom vide ou fait d espaces est refuse")
    func nomVideRefuse() {
        for nom in ["", "   ", "\n\t"] {
            #expect(throws: ErreurDePrereglage.nomVide) {
                try OrdreDesPrereglages.nomNettoye(nom)
            }
        }
    }

    @Test("Un nom est debarrasse de ses espaces de bordure")
    func nomNettoye() throws {
        #expect(try OrdreDesPrereglages.nomNettoye("  Webtoon  ") == "Webtoon")
    }

    @Test("Un nom deja pris est refuse, aux accents et a la casse pres")
    func nomDejaPrisRefuse() throws {
        let existant = try PrereglageLecture(nom: "Lecture nocturne", contenu: .parDefaut)

        #expect(throws: ErreurDePrereglage.nomDejaPris(nom: "LECTURE NOCTURNE")) {
            try OrdreDesPrereglages.verifierLaDisponibilite(
                de: "LECTURE NOCTURNE",
                parmi: [existant]
            )
        }
    }

    @Test("Le prereglage que l on renomme ne se bloque pas lui meme")
    func renommageSansCollisionAvecSoiMeme() throws {
        let existant = try PrereglageLecture(nom: "Webtoon", contenu: .parDefaut)

        try OrdreDesPrereglages.verifierLaDisponibilite(
            de: "Webtoon",
            parmi: [existant],
            sauf: existant.id
        )
    }

    // MARK: Sauvegarde

    @Test("Les prereglages sont exportes dans la sauvegarde et relus a l identique")
    func sauvegardeAllerRetour() throws {
        var filtres = ReglagesDeFiltres.parDefaut
        filtres.regler(.nettete, a: 55)
        filtres.basculer(.colorisationIA, true)

        let prereglages = try [
            PrereglageLecture(
                nom: "Webtoon",
                contenu: ContenuDePrereglage(miseEnPage: .continuVertical, filtres: filtres)
            ),
            PrereglageLecture(
                nom: "Manga papier",
                contenu: ContenuDePrereglage(fond: .sepia)
            ),
        ]

        let sauvegarde = try SauvegardeDesPrereglages(prereglages)
        let relue = try SauvegardeDesPrereglages(donnees: sauvegarde.donnees())
        let restaures = try relue.restaures()

        #expect(relue.version == SauvegardeDesPrereglages.versionCourante)
        #expect(restaures.map(\.nom) == ["Manga papier", "Webtoon"])
        #expect(restaures.map(\.id) == OrdreDesPrereglages.trier(prereglages).map(\.id))

        let webtoon = try #require(restaures.first { $0.nom == "Webtoon" }).contenu()

        #expect(webtoon.miseEnPage == .continuVertical)
        #expect(webtoon.filtres.valeur(.nettete) == 55)
        #expect(webtoon.filtres.estActif(.colorisationIA))
    }

    @Test("Une sauvegarde n emporte jamais un prereglage qu elle ne sait pas relire")
    func sauvegardeRefuseUnContenuIllisible() {
        let abime = PrereglageLecture(nom: "Abime", donneesReglages: Data([0xAA, 0xBB]))

        #expect(throws: ErreurDePrereglage.contenuIllisible) {
            try SauvegardeDesPrereglages([abime])
        }
    }

    @Test("Une sauvegarde d une version inconnue est refusee")
    func sauvegardeDeVersionInconnue() {
        let json = #"{"version": 42, "prereglages": []}"#

        #expect(throws: ErreurDeSauvegarde.formatInconnu(version: 42)) {
            try SauvegardeDesPrereglages(donnees: Data(json.utf8))
        }
    }

    @Test("Un fichier qui ne decrit pas cette part est refuse")
    func sauvegardeIllisible() {
        #expect(throws: ErreurDeSauvegarde.fichierIllisible) {
            try SauvegardeDesPrereglages(donnees: Data("pas du json".utf8))
        }
    }
}
