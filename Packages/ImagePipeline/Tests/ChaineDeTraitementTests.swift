import Core
import Foundation
import Testing
@testable import ImagePipeline

//
// Couvre l ordre de la chaine de traitement, section 6.3 du cahier de
// developpement.
//
// L ordre est compare a la liste du document lui meme, jamais a une copie. Une
// interversion dans le code, ou une renumerotation dans le cahier qui
// n arriverait pas jusqu au code, fait virer la suite au rouge.
//

struct ChaineDeTraitementTests {
    /// Libelle de chaque etape tel que la section 6.3 l ecrit.
    ///
    /// Ce ne sont pas des libelles d interface, ce sont les entrees de la liste
    /// numerotee du cahier. Ils vivent ici parce que c est le seul endroit qui
    /// compare le code au document.
    private let libellesDuCahier: [EtapeDeTraitement: String] = [
        .rognageAutomatique: "Rognage automatique des bords",
        .divisionDesImagesLarges: "Division des images larges",
        .reductionDuBruit: "Reduction du bruit",
        .ameliorationIA: "Amelioration IA en deux fois",
        .colorisationIA: "Colorisation IA",
        .nettete: "Nettete",
        .contraste: "Contraste",
        .gamma: "Gamma",
        .luminosite: "Luminosite",
        .chaleur: "Chaleur",
    ]

    // MARK: Ordre

    @Test("La chaine porte les dix etapes de la section 6.3, dans l ordre du cahier")
    func ordreDuCahier() throws {
        let elements = try CahierDeDeveloppement.listeNumerotee(sous: "6.3 Traitements")

        #expect(elements.count == 10)
        #expect(EtapeDeTraitement.chaine.count == 10)
        #expect(EtapeDeTraitement.chaine.map { libellesDuCahier[$0] ?? "" } == elements)
    }

    @Test("Le rang de chaque etape est celui de sa ligne dans le cahier")
    func rangsDuCahier() throws {
        let elements = try CahierDeDeveloppement.listeNumerotee(sous: "6.3 Traitements")

        for etape in EtapeDeTraitement.chaine {
            let attendu = try #require(libellesDuCahier[etape])
            let rang = try #require(elements.firstIndex(of: attendu)) + 1

            #expect(etape.rang == rang, "\(attendu)")
        }
    }

    @Test("Le partage entre etapes couteuses et filtres en temps reel suit le cahier")
    func partageDuCahier() throws {
        let phrase = try #require(
            try CahierDeDeveloppement.lignes().first { $0.contains("Les etapes 6 a 10") }
        )

        #expect(phrase.contains("temps reel"))
        #expect(phrase.contains("Les etapes 1 a 5"))
        #expect(phrase.contains("cache sur disque"))

        for etape in EtapeDeTraitement.chaine {
            #expect(etape.estDeclareeEnTempsReel == (etape.rang >= 6), "\(etape)")
            #expect(etape.estDeclareeCouteuse == (etape.rang <= 5), "\(etape)")
        }
    }

    @Test("Une suite d etapes desordonnee revient toujours dans l ordre du cahier")
    func remiseEnOrdre() {
        let desordre: [EtapeDeTraitement] = [.chaleur, .rognageAutomatique, .gamma, .reductionDuBruit]

        #expect(desordre.dansLOrdreDeLaChaine == [
            .rognageAutomatique,
            .reductionDuBruit,
            .gamma,
            .chaleur,
        ])
    }

    // MARK: Etapes demandees par le panneau

    @Test("Un panneau neuf ne demande aucune etape")
    func panneauNeutre() {
        #expect(ReglagesDeFiltres.parDefaut.etapesDemandees.isEmpty)
        #expect(ReglagesDeFiltres.parDefaut.estNeutre)
    }

    @Test("Les etapes demandees sortent dans l ordre du cahier, pas dans celui du panneau")
    func ordreDesEtapesDemandees() {
        var reglages = ReglagesDeFiltres.parDefaut

        // Armees dans l ordre du panneau de la section 5.7, qui met la
        // luminosite et la chaleur en tete.
        for filtre in FiltreDImage.ordreDuPanneau {
            reglages.regler(filtre, a: filtre.valeurParDefaut == 0 ? 80 : 20)
        }
        reglages.basculer(.reductionDuBruit, true)

        #expect(reglages.etapesDemandees == [
            .reductionDuBruit,
            .nettete,
            .contraste,
            .gamma,
            .luminosite,
            .chaleur,
        ])
    }

    @Test("Un curseur ramene a sa valeur par defaut retire son etape")
    func curseurRemisANeutre() {
        var reglages = ReglagesDeFiltres.parDefaut
        reglages.regler(.contraste, a: 90)

        #expect(reglages.etapesDemandees == [.contraste])

        reglages.regler(.contraste, a: FiltreDImage.contraste.valeurParDefaut)

        #expect(reglages.etapesDemandees.isEmpty)
    }

    @Test("Les traitements par IA gardent leur rang meme sans etre appliques")
    func rangDesTraitementsAVenir() {
        var reglages = ReglagesDeFiltres.parDefaut
        reglages.basculer(.colorisationIA, true)
        reglages.basculer(.reductionDuBruit, true)
        reglages.regler(.nettete, a: 60)

        #expect(reglages.etapesDemandees == [.reductionDuBruit, .colorisationIA, .nettete])

        // La chaine sait appliquer les deux autres, pas la colorisation.
        #expect(ChaineDeFiltres(reglages: reglages).etapes == [.reductionDuBruit, .nettete])
    }

    @Test("Les deux etapes non livrees sont nommees, pas oubliees")
    func etapesAVenirNommees() {
        #expect(ChaineDeTraitement.etapesAVenir == [.ameliorationIA, .colorisationIA])
        #expect(ChaineDeTraitement.etapesImplementees.count == 8)
        #expect(
            (ChaineDeTraitement.etapesImplementees + ChaineDeTraitement.etapesAVenir)
                .dansLOrdreDeLaChaine == EtapeDeTraitement.chaine
        )
    }

    // MARK: Enchainement complet

    @Test("La chaine complete annonce ses etapes dans l ordre du cahier")
    func etapesAppliqueesParLaChaine() {
        var filtres = ReglagesDeFiltres.parDefaut
        filtres.regler(.chaleur, a: 40)
        filtres.regler(.gamma, a: 70)

        let chaine = ChaineDeTraitement(
            rognage: .recommande,
            division: .recommande,
            filtres: filtres
        )

        let planche = TailleEnPixels(largeur: 3000, hauteur: 2000)

        #expect(chaine.etapesAppliquees(a: planche) == [
            .rognageAutomatique,
            .divisionDesImagesLarges,
            .gamma,
            .chaleur,
        ])
    }

    @Test("Une page plus haute que large ne compte pas la division parmi ses etapes")
    func divisionSansEffet() {
        let chaine = ChaineDeTraitement(
            rognage: .parDefaut,
            division: .recommande,
            filtres: .parDefaut
        )

        #expect(chaine.etapesAppliquees(a: TailleEnPixels(largeur: 2000, hauteur: 3000)).isEmpty)
    }

    @Test("Une planche large traverse la chaine entiere et sort en deux moities")
    func plancheCoupeeEtFiltree() throws {
        let source = try #require(
            PlancheLarge.page(taille: TailleEnPixels(largeur: 400, hauteur: 300))
        )

        var filtres = ReglagesDeFiltres.parDefaut
        filtres.regler(.luminosite, a: 40)

        let chaine = ChaineDeTraitement(
            rognage: .parDefaut,
            division: .recommande,
            filtres: filtres
        )

        let moities = chaine.pages(de: source, sens: .droiteGauche)

        #expect(moities.count == 2)

        // Les deux moities couvrent la planche, sans colonne perdue ni comptee
        // deux fois, et chacune est passee par le filtre.
        let colonnes = moities.reduce(0) { $0 + $1.image.width }
        #expect(colonnes == source.image.width)

        for moitie in moities {
            let mesure = try #require(MoyennesDeCanaux(moitie.image))
            let origine = try #require(MoyennesDeCanaux(source.image))

            #expect(mesure.moyenne < origine.moyenne)
        }
    }
}
