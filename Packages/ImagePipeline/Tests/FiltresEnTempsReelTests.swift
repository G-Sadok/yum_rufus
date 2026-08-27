import Core
import Foundation
import Testing
@testable import ImagePipeline

//
// Couvre les filtres du panneau de la section 5.7, appliques par Core Image.
//
// Trois criteres sont mesures ici.
//
// Le direct sans a coup : le cout d une passe de rendu sur une page a la taille
// d affichage, apres prechauffage, reste sous le budget de tourne de page de la
// section 12. Et une passe suffit, quel que soit le nombre de filtres armes.
//
// L ordre : couvert par ChaineDeTraitementTests, qui compare la chaine a la
// liste du cahier. Ici on verifie seulement que chaque curseur agit dans le sens
// annonce, sans quoi l ordre porterait sur des etapes qui ne font rien.
//
// La memoire : la page filtree ne pese pas plus de quinze pour cent de plus que
// la page decodee, et filtrer page apres page ne fait pas gonfler le processus.
//

@Suite(.serialized)
struct FiltresEnTempsReelTests {
    private let decodeur = DecodeurDePage()
    private let zoneDeLecture = TailleEnPixels(largeur: 1600, hauteur: 2400)

    /// Marge de quinze pour cent du critere de la fonctionnalite.
    private let margeDeMemoire = 1.15

    /// Budget de tourne de page en local, section 12.
    private let budgetDeRendu: Double = 0.080

    /// Plafond du cache memoire de la section 6.1, en octets.
    private let plafondDuCache = 220_000_000

    // MARK: Neutralite

    @Test("Un panneau neuf rend la page elle meme, sans rien allouer")
    func chaineInerte() throws {
        let page = try #require(ImageDeTest.page())
        let filtree = ChaineDeFiltres().appliquer(a: page)

        #expect(ChaineDeFiltres().estInerte)
        #expect(filtree.image === page.image)
    }

    @Test("La page recue n est jamais modifiee, seule une nouvelle page sort")
    func pageSourceIntacte() throws {
        let page = try #require(ImageDeTest.page())
        let avant = try #require(MoyennesDeCanaux(page.image))

        var reglages = ReglagesDeFiltres.parDefaut
        reglages.regler(.luminosite, a: 20)

        let filtree = ChaineDeFiltres(reglages: reglages).appliquer(a: page)
        let apres = try #require(MoyennesDeCanaux(page.image))

        // Bouger un curseur ne redecode rien : la page d origine reste en place,
        // intacte, et sert de source a la passe suivante.
        #expect(filtree.image !== page.image)
        #expect(apres.moyenne == avant.moyenne)
    }

    // MARK: Sens de chaque curseur

    @Test("Baisser la luminosite assombrit la page")
    func luminositeQuiBaisse() throws {
        let mesures = try mesurer(.luminosite, valeurs: [100, 60, 20])

        #expect(mesures[0].moyenne > mesures[1].moyenne)
        #expect(mesures[1].moyenne > mesures[2].moyenne)
    }

    @Test("Monter la chaleur pousse le rouge et retire du bleu")
    func chaleurQuiMonte() throws {
        let mesures = try mesurer(.chaleur, valeurs: [0, 100])

        #expect(mesures[1].rouge > mesures[0].rouge)
        #expect(mesures[1].bleu < mesures[0].bleu)
    }

    @Test("Monter le gamma eclaircit les tons moyens")
    func gammaQuiMonte() throws {
        let mesures = try mesurer(.gamma, valeurs: [20, 50, 80])

        #expect(mesures[0].moyenne < mesures[1].moyenne)
        #expect(mesures[1].moyenne < mesures[2].moyenne)
    }

    @Test("Monter le contraste ecarte les valeurs de part et d autre du milieu")
    func contrasteQuiMonte() throws {
        let page = try pageDeLecture()
        let etale = try filtrer(page) { $0.regler(.contraste, a: 100) }
        let plat = try filtrer(page) { $0.regler(.contraste, a: 0) }

        let ecartEtale = try ecartType(etale)
        let ecartPlat = try ecartType(plat)
        let ecartDOrigine = try ecartType(page)

        #expect(ecartEtale > ecartDOrigine)
        #expect(ecartPlat < ecartDOrigine)
    }

    @Test("La nettete creuse les transitions de la planche")
    func netteteQuiMonte() throws {
        let page = try pageDeLecture()
        let accentuee = try filtrer(page) { $0.regler(.nettete, a: 100) }

        // Une accentuation depasse de part et d autre de chaque transition.
        // L amplitude de la colonne s ouvre donc, alors que les aplats de part
        // et d autre, eux, ne bougent pas.
        #expect(try amplitude(accentuee) > amplitude(page))
        #expect(accentuee.image !== page.image)
    }

    @Test("La reduction du bruit lisse les transitions et laisse un aplat intact")
    func reductionDuBruitQuiSArme() throws {
        let aplat = try #require(ImageDeTest.page())
        let bandes = try pageDeLecture()

        let aplatLisse = try filtrer(aplat) { $0.basculer(.reductionDuBruit, true) }
        let bandesLissees = try filtrer(bandes) { $0.basculer(.reductionDuBruit, true) }

        // Un aplat n a rien a lisser. Aucun niveau ne doit bouger, ce qui prouve
        // au passage que la passe de rendu elle meme n introduit aucun ecart :
        // sans cette mesure, le test suivant serait vrai meme si le filtre ne
        // faisait rien.
        #expect(try pixelsModifies(entre: aplat, et: aplatLisse) == 0)
        #expect(try pixelsModifies(entre: bandes, et: bandesLissees) > 0)
        #expect(bandesLissees.image !== bandes.image)
    }

    @Test("Les dimensions de la page ne changent jamais")
    func dimensionsConservees() throws {
        let page = try pageDeLecture()
        let filtree = try filtrer(page) { reglages in
            for filtre in FiltreDImage.allCases {
                reglages.regler(filtre, a: filtre.valeurParDefaut == 0 ? 70 : 30)
            }
            reglages.basculer(.reductionDuBruit, true)
        }

        #expect(filtree.image.width == page.image.width)
        #expect(filtree.image.height == page.image.height)
        #expect(filtree.tailleDecodee == page.tailleDecodee)
        #expect(filtree.tailleDOrigine == page.tailleDOrigine)
        #expect(filtree.niveau == page.niveau)
    }

    // MARK: Memoire

    @Test("La page filtree ne pese pas plus de quinze pour cent de plus")
    func poidsDeLaPageFiltree() throws {
        let page = try pageDeLecture()
        let filtree = try filtrer(page) { reglages in
            for filtre in FiltreDImage.allCases {
                reglages.regler(filtre, a: filtre.valeurParDefaut == 0 ? 70 : 30)
            }
            reglages.basculer(.reductionDuBruit, true)
        }

        // C est ce nombre que le plafond du cache memoire de la section 6.1
        // compte. Ne pas le faire grossir, c est ne pas faire grossir le cache.
        let plafond = Double(page.octetsEnMemoire) * margeDeMemoire

        #expect(Double(filtree.octetsEnMemoire) <= plafond)
    }

    @Test("Filtrer quarante pages a la suite ne fait pas gonfler le processus")
    func quaranteFiltragesSansRetention() throws {
        let page = try pageDeLecture()
        let chaine = ChaineDeFiltres(reglages: reglagesComplets())

        // Le premier rendu compile les programmes du contexte. Le compter dans
        // la mesure reviendrait a mesurer le demarrage de Core Image.
        _ = chaine.appliquer(a: page)

        let variation = MesureDeMemoire.variation {
            for _ in 0..<40 {
                let filtree = chaine.appliquer(a: page)
                #expect(filtree.octetsEnMemoire > 0)
            }
        }

        // Quinze pour cent du plafond de cache de la section 6.1. Une chaine qui
        // retiendrait ses intermediaires ajouterait ici plus de 400 Mo.
        #expect(Double(variation) < Double(plafondDuCache) * (margeDeMemoire - 1))
    }

    @Test("Six pages filtrees tiennent sous le plafond du cache memoire")
    func sixPagesFiltrees() throws {
        let page = try pageDeLecture()
        let chaine = ChaineDeFiltres(reglages: reglagesComplets())

        var gardees: [ImageDePage] = []
        for _ in 0..<6 {
            gardees.append(chaine.appliquer(a: page))
        }

        let cumul = gardees.reduce(0) { $0 + $1.octetsEnMemoire }

        #expect(gardees.count == 6)
        #expect(cumul < plafondDuCache)
        #expect(Double(cumul) <= Double(page.octetsEnMemoire * 6) * margeDeMemoire)
    }

    // MARK: Direct

    @Test("Une passe de rendu tient sous le budget de tourne de page")
    func coutDUneModification() throws {
        let page = try pageDeLecture()
        let chaine = ChaineDeFiltres(reglages: reglagesComplets())

        ContexteDeFiltres.partage.prechauffer()
        _ = chaine.appliquer(a: page)

        var durees: [Double] = []
        for _ in 0..<10 {
            let debut = Date()
            _ = chaine.appliquer(a: page)
            durees.append(Date().timeIntervalSince(debut))
        }

        let mediane = durees.sorted()[durees.count / 2]

        // Bouger un curseur ne doit jamais couter plus qu une tourne de page,
        // budget de la section 12. Six filtres armes valent ici une seule passe.
        #expect(mediane < budgetDeRendu, "mediane \(mediane) s")
    }

    @Test("Le nombre de filtres armes ne multiplie pas le cout du rendu")
    func coutStableSelonLeNombreDeFiltres() throws {
        let page = try pageDeLecture()

        var unSeul = ReglagesDeFiltres.parDefaut
        unSeul.regler(.luminosite, a: 40)

        let courte = ChaineDeFiltres(reglages: unSeul)
        let longue = ChaineDeFiltres(reglages: reglagesComplets())

        ContexteDeFiltres.partage.prechauffer()
        _ = courte.appliquer(a: page)
        _ = longue.appliquer(a: page)

        #expect(courte.etapes.count == 1)
        #expect(longue.etapes.count == 6)

        let avecUn = duree { _ = courte.appliquer(a: page) }
        let avecSix = duree { _ = longue.appliquer(a: page) }

        // Six etapes empilees sur une seule passe, pas six passes. Le facteur
        // trois laisse la place au cout reel des noyaux, pas a une passe par
        // etape, qui donnerait six.
        #expect(avecSix < avecUn * 3 + budgetDeRendu, "un \(avecUn) s, six \(avecSix) s")
    }

    // MARK: Parametres

    @Test("Chaque curseur pose sur sa valeur par defaut rend un parametre neutre")
    func parametresNeutres() {
        #expect(ParametresDeFiltres.luminosite(100) == 0)
        #expect(ParametresDeFiltres.contraste(50) == 1)
        #expect(ParametresDeFiltres.gamma(50) == 1)
        #expect(ParametresDeFiltres.nettete(0) == 0)
        #expect(ParametresDeFiltres.temperature(0) == ParametresDeFiltres.temperatureNeutre)
    }

    @Test("Chaque curseur repond de facon monotone d un bout a l autre")
    func parametresMonotones() {
        let courses = stride(from: 0.0, through: 100.0, by: 5.0)

        var luminosites: [Double] = []
        var contrastes: [Double] = []
        var gammas: [Double] = []
        var nettetes: [Double] = []
        var temperatures: [Double] = []

        for valeur in courses {
            luminosites.append(ParametresDeFiltres.luminosite(valeur))
            contrastes.append(ParametresDeFiltres.contraste(valeur))
            gammas.append(ParametresDeFiltres.gamma(valeur))
            nettetes.append(ParametresDeFiltres.nettete(valeur))
            temperatures.append(ParametresDeFiltres.temperature(valeur))
        }

        #expect(luminosites == luminosites.sorted())
        #expect(contrastes == contrastes.sorted())
        #expect(gammas == gammas.sorted(by: >))
        #expect(nettetes == nettetes.sorted())
        #expect(temperatures == temperatures.sorted())
    }

    @Test("Une valeur hors bornes est ramenee dans la course du curseur")
    func parametresBornes() {
        #expect(ParametresDeFiltres.luminosite(-40) == ParametresDeFiltres.luminosite(0))
        #expect(ParametresDeFiltres.contraste(400) == ParametresDeFiltres.contraste(100))
    }

    // MARK: Materiel

    /// Page decodee a la taille d affichage, celle que le lecteur manipule.
    private func pageDeLecture() throws -> ImageDePage {
        try decodeur.decoder(PageDeTest.standard, nom: "filtres.jpg", dans: zoneDeLecture)
    }

    /// Reglages qui arment les six etapes que la chaine sait appliquer.
    private func reglagesComplets() -> ReglagesDeFiltres {
        var reglages = ReglagesDeFiltres.parDefaut

        for filtre in FiltreDImage.allCases {
            reglages.regler(filtre, a: filtre.valeurParDefaut == 0 ? 70 : 30)
        }
        reglages.basculer(.reductionDuBruit, true)

        return reglages
    }

    /// Page filtree par des reglages composes sur place.
    private func filtrer(
        _ page: ImageDePage,
        _ composer: (inout ReglagesDeFiltres) -> Void
    ) throws -> ImageDePage {
        var reglages = ReglagesDeFiltres.parDefaut
        composer(&reglages)

        return ChaineDeFiltres(reglages: reglages).appliquer(a: page)
    }

    /// Moyennes par canal pour chaque position d un curseur.
    private func mesurer(_ filtre: FiltreDImage, valeurs: [Double]) throws -> [MoyennesDeCanaux] {
        let page = try #require(ImageDeTest.page())

        return try valeurs.map { valeur in
            let filtree = try filtrer(page) { $0.regler(filtre, a: valeur) }

            return try #require(MoyennesDeCanaux(filtree.image))
        }
    }

    /// Ecart type des niveaux de gris d une colonne, mesure du contraste reel.
    private func ecartType(_ page: ImageDePage) throws -> Double {
        try #require(MesuresDePage.ecartTypeDUneColonne(de: page))
    }

    /// Ecart entre le niveau le plus clair et le plus sombre d une colonne.
    private func amplitude(_ page: ImageDePage) throws -> Int {
        try #require(MesuresDePage.amplitudeDUneColonne(de: page))
    }

    /// Nombre de pixels dont le niveau de gris differe entre deux pages.
    private func pixelsModifies(entre avant: ImageDePage, et apres: ImageDePage) throws -> Int {
        try #require(MesuresDePage.pixelsModifies(entre: avant, et: apres))
    }

    /// Duree d execution d un bloc, en secondes.
    private func duree(_ bloc: () -> Void) -> Double {
        let debut = Date()
        bloc()

        return Date().timeIntervalSince(debut)
    }
}
