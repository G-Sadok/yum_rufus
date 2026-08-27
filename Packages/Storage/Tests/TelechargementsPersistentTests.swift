import Core
import Foundation
import GRDB
import Testing
@testable import Storage

//
// Couvre la file de telechargement persistee.
//
// La persistance est ce qui rend le premier critere possible. Un point de
// reprise garde en memoire ne survit pas a la fermeture de l application, et
// c est justement la fermeture brutale qui produit les telechargements
// interrompus. Les tests ci dessous verifient donc deux choses distinctes : que
// le compte de pages scellees survit, et qu une tache laissee en cours par une
// fermeture brutale retourne dans la file au lieu d occuper une place morte.
//

struct TelechargementsPersistentTests {
    /// Base migree portant une serie et ses chapitres.
    private func base(chapitres: Int = 3) throws -> (BaseDeDonnees, JeuDeDonneesDeTest.Contenu) {
        let base = try BaseDeDonnees.enMemoire()
        let jeu = try JeuDeDonneesDeTest.inserer(dans: base, nombreDeChapitres: chapitres, pagesParChapitre: 24)

        return (base, jeu)
    }

    // MARK: Schema

    @Test("La migration ajoute la priorite et le point de reprise")
    func laMigrationAjouteLesColonnes() throws {
        let base = try BaseDeDonnees.enMemoire()

        try base.ecrivain.read { connexion in
            let colonnes = try Set(connexion.columns(in: "telechargement").map(\.name))

            #expect(colonnes.isSuperset(of: ["priorite", "pagesTerminees", "nombreDePages", "octetsRecus"]))
        }
    }

    @Test("L index de file existe, sinon chaque page scellee rebalaye la table")
    func lIndexDeFileExiste() throws {
        let base = try BaseDeDonnees.enMemoire()

        try base.ecrivain.read { connexion in
            let sql = try String.fetchOne(
                connexion,
                sql: "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = ?",
                arguments: ["idx_telechargement_file"]
            )

            let definition = try #require(sql)

            #expect(definition.contains("telechargement"))
            #expect(definition.contains("etat"))
            #expect(definition.contains("priorite"))
        }
    }

    // MARK: Mise en file

    @Test("Un chapitre mis en file arrive en attente, a la priorite demandee")
    func miseEnFile() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        let tache = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id, priorite: .haute)

        #expect(tache.etat == .enAttente)
        #expect(tache.priorite == .haute)
        #expect(tache.nombreDePages == 24)
        #expect(try magasin.taches().count == 1)
    }

    @Test("Une seconde demande sur le meme chapitre ne cree pas de doublon")
    func aucunDoublon() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id, priorite: .basse)
        let seconde = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id, priorite: .haute)

        #expect(try magasin.taches().count == 1)
        #expect(seconde.priorite == .haute, "Une seconde demande releve la priorite")
    }

    @Test("Une seconde demande relance une tache echouee")
    func relanceApresEchec() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        let tache = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)
        try magasin.echouer(tache.id, message: "Le serveur ne repond plus.")

        let relancee = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)

        #expect(relancee.etat == .enAttente)
        #expect(relancee.messageErreur == nil)
    }

    @Test("Un chapitre inconnu ne peut pas entrer dans la file")
    func chapitreInconnu() throws {
        let (base, _) = try base()
        let magasin = MagasinDeTelechargements(base: base)
        let absent = UUID()

        #expect(throws: ErreurDeTelechargement.chapitreInconnu(identifiant: absent)) {
            try magasin.mettreEnFile(chapitre: absent)
        }
    }

    // MARK: Reprise apres interruption

    @Test("Le point de reprise survit a la fermeture de l application")
    func lePointDeRepriseSurvit() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        let tache = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)
        try magasin.demarrer(tache.id)
        try magasin.noterLaLongueur(de: tache.id, nombreDePages: 24, octetsTotal: nil)
        try magasin.noterUnePageScellee(de: tache.id, pagesTerminees: 14, octetsRecus: 32000)

        // Une seconde ouverture du magasin sur la meme base tient lieu de
        // relancement de l application : rien n est garde en memoire.
        let relu = MagasinDeTelechargements(base: base)
        let relue = try #require(try relu.tache(tache.id))

        #expect(relue.pagesTerminees == 14)
        #expect(relue.octetsRecus == 32000)
        #expect(relue.progression == 14.0 / 24.0)
    }

    @Test("Une tache laissee en cours par une fermeture brutale retourne dans la file")
    func lesTachesInterrompuesRetournentEnAttente() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        let premiere = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)
        let seconde = try magasin.mettreEnFile(chapitre: jeu.chapitres[1].id)
        try magasin.demarrer(premiere.id)
        try magasin.suspendre(seconde.id)

        let remises = try magasin.reprendreLesTachesInterrompues()

        #expect(remises == 1)
        #expect(try magasin.tache(premiere.id)?.etat == .enAttente)
        #expect(try magasin.tache(seconde.id)?.etat == .suspendu, "Une pause n est pas une interruption")
    }

    @Test("Un echec garde le point de reprise, sinon la relance recommencerait tout")
    func lEchecGardeLePointDeReprise() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        let tache = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)
        try magasin.noterLaLongueur(de: tache.id, nombreDePages: 24, octetsTotal: nil)
        try magasin.noterUnePageScellee(de: tache.id, pagesTerminees: 9, octetsRecus: 18000)
        try magasin.echouer(tache.id, message: "Le serveur a coupe la connexion.")

        let relue = try #require(try magasin.tache(tache.id))

        #expect(relue.etat == .echoue)
        #expect(relue.pagesTerminees == 9)
        #expect(relue.messageErreur == "Le serveur a coupe la connexion.")
    }

    // MARK: Progression

    @Test("La progression persistee suit exactement le compte de pages scellees")
    func laProgressionPersisteeEstExacte() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        let tache = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)
        try magasin.noterLaLongueur(de: tache.id, nombreDePages: 20, octetsTotal: nil)

        for page in 1...20 {
            try magasin.noterUnePageScellee(de: tache.id, pagesTerminees: page, octetsRecus: page * 1000)

            let relue = try #require(try magasin.tache(tache.id))

            #expect(relue.progression == Double(page) / 20.0)
        }
    }

    @Test("Une source qui compte mal ne fait pas depasser la progression")
    func laProgressionNeDepassePas() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        let tache = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)
        try magasin.noterLaLongueur(de: tache.id, nombreDePages: 20, octetsTotal: nil)
        try magasin.noterUnePageScellee(de: tache.id, pagesTerminees: 22, octetsRecus: 1000)

        let relue = try #require(try magasin.tache(tache.id))

        #expect(relue.pagesTerminees == 20)
        #expect(relue.progression == 1)
    }

    @Test("Une tache terminee vaut un tour entier")
    func laTacheTermineeEstPleine() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        let tache = try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)
        try magasin.noterLaLongueur(de: tache.id, nombreDePages: 20, octetsTotal: 32000)
        try magasin.terminer(tache.id)

        let relue = try #require(try magasin.tache(tache.id))

        #expect(relue.etat == .termine)
        #expect(relue.progression == 1)
        #expect(relue.pagesTerminees == 20)
    }

    // MARK: Ordre et commandes

    @Test("La file rendue est deja dans son ordre de passage")
    func laFileEstTriee() throws {
        let (base, jeu) = try base(chapitres: 3)
        let magasin = MagasinDeTelechargements(base: base)

        let debut = Date(timeIntervalSince1970: 1_700_000_000)

        try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id, priorite: .basse, le: debut)
        try magasin.mettreEnFile(chapitre: jeu.chapitres[1].id, priorite: .normale, le: debut.addingTimeInterval(1))
        try magasin.mettreEnFile(chapitre: jeu.chapitres[2].id, priorite: .haute, le: debut.addingTimeInterval(2))

        let ordre = try magasin.taches().map(\.chapitreId)

        #expect(ordre == [jeu.chapitres[2].id, jeu.chapitres[1].id, jeu.chapitres[0].id])
    }

    @Test("La ligne de la file porte le titre de la serie et le numero du chapitre")
    func laLignePorteSonTitre() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)

        let ligne = try #require(try magasin.taches().first)

        #expect(ligne.titreDeLaSerie == jeu.manga.titre)
        #expect(ligne.numeroDeChapitre == 1)
        #expect(ligne.serieId == jeu.manga.id)
    }

    @Test("Une commande sur une tache absente est refusee, pas ignoree")
    func commandeSurUneTacheAbsente() throws {
        let (base, _) = try base()
        let magasin = MagasinDeTelechargements(base: base)
        let absente = UUID()

        #expect(throws: ErreurDeTelechargement.tacheInconnue(identifiant: absente)) {
            try magasin.demarrer(absente)
        }
        #expect(throws: ErreurDeTelechargement.tacheInconnue(identifiant: absente)) {
            try magasin.retirer(absente)
        }
    }

    @Test("Supprimer un chapitre emporte sa tache de la file")
    func laSuppressionCascade() throws {
        let (base, jeu) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        try magasin.mettreEnFile(chapitre: jeu.chapitres[0].id)

        try base.ecrivain.write { connexion in
            _ = try Chapitre.deleteOne(connexion, key: jeu.chapitres[0].id)
        }

        #expect(try magasin.taches().isEmpty)
    }

    // MARK: Reglages du sous ecran

    @Test("Une installation neuve telecharge trois chapitres a la fois, en Wi-Fi seulement")
    func reglagesParDefaut() throws {
        let (base, _) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        let reglages = try magasin.reglages()

        #expect(reglages.simultanes == 3)
        #expect(reglages.enWiFiSeulement)
    }

    @Test("La limite simultanee et le Wi-Fi seul survivent au redemarrage")
    func lesReglagesPersistent() throws {
        let (base, _) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        try magasin.definirLesSimultanes(5)
        try magasin.definirLeWiFiSeulement(false)

        let relus = try MagasinDeTelechargements(base: base).reglages()

        #expect(relus.simultanes == 5)
        #expect(relus.enWiFiSeulement == false)
    }

    @Test("Une limite hors bornes est ramenee avant d etre ecrite")
    func laLimiteEcriteResteDansSesBornes() throws {
        let (base, _) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        try magasin.definirLesSimultanes(42)

        #expect(try magasin.reglages().simultanes == 5)
    }

    @Test("La limite simultanee ne pollue pas l ecran Reglages")
    func laLimiteResteHorsDuCatalogue() throws {
        let (base, _) = try base()
        let magasin = MagasinDeTelechargements(base: base)

        try magasin.definirLesSimultanes(4)

        // Le catalogue de la section 5.5 arrete la section 12 a quatre lignes.
        // La cle du sous ecran vit dans la meme table mais reste invisible pour
        // l ecran, qui ignore les cles qu il ne reconnait pas.
        let reglagesDeLEcran = try MagasinDeReglages(base: base).reglages()

        #expect(reglagesDeLEcran.valeursEcrites.keys.contains(.enWiFiSeulement) == false)
        #expect(CatalogueDeReglages.lignes(de: .telechargements).count == 4)
    }
}
