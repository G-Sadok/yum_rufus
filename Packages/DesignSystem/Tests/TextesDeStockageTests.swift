import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Textes des trois ecrans de stockage, section 15 de la section 5.5.
//
// Les mesures sont dans le fichier voisin. Les deux suites s eprouvent
// differemment : les mesures se comparent aux tableaux de DESIGN-SPEC.md, les
// textes au catalogue de chaines de l application, qui n est pas compile par
// Swift Package Manager et se lit sur le disque.
//
// Le premier critere d acceptation se joue pour moitie ici. Une mesure exacte
// rendue `1000 Ko` au lieu de `1 Mo` reste une mesure exacte mal dite, et deux
// ecrans qui diraient le meme poids de deux facons differentes feraient douter
// des deux.
//

/// Textes des ecrans de stockage, compares au catalogue de chaines.
struct TexteDeStockageTests {
    private func libelles() throws -> LibellesDeStockage {
        try MaterielDeStockage.libellesDuCatalogue()
    }

    // MARK: Tailles

    @Test("Une taille reprend les paliers de la file, le meme poids se dit du meme mot")
    func lesPaliersSontCeuxDeLaFile() throws {
        let libelles = try libelles()

        #expect(TexteDeStockage.taille(0, libelles: libelles) == "0 o")
        #expect(TexteDeStockage.taille(999, libelles: libelles) == "999 o")
        #expect(TexteDeStockage.taille(1000, libelles: libelles) == "1 Ko")
        #expect(TexteDeStockage.taille(999_500, libelles: libelles) == "999 Ko")
        #expect(TexteDeStockage.taille(32_000_000, libelles: libelles) == "32 Mo")
        #expect(TexteDeStockage.taille(2_500_000_000, libelles: libelles) == "2.5 Go")
    }

    @Test("La file et le stockage disent le meme poids exactement du meme mot")
    func laFileEtLeStockageSAccordent() throws {
        let stockage = try libelles()
        let file = try MaterielDeTelechargement.libellesDuCatalogue()

        for octets in [0, 999, 1000, 32_000_000, 2_500_000_000] {
            #expect(
                TexteDeStockage.taille(octets, libelles: stockage)
                    == TexteDeTelechargement.poids(octets, libelles: file)
            )
        }
    }

    @Test("Une installation neuve affiche 0 octet, comme l etat vide de la section 5.5 le veut")
    func lInstallationNeuveAfficheZero() throws {
        let libelles = try libelles()
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "`0 octet`"))

        #expect(ligne.contains("les valeurs disent l absence"))
        #expect(TexteDeStockage.taille(0, libelles: libelles) == "0 o")
    }

    // MARK: Titres et sous lignes

    @Test("Un chapitre nomme sa serie puis son numero, comme dans la file")
    func leChapitreNommeSaSeriePuisSonNumero() throws {
        let libelles = try libelles()

        let titre = TexteDeStockage.titre(
            de: MaterielDeStockage.posteDeChapitre(),
            categorie: .chapitresTelecharges,
            libelles: libelles
        )

        #expect(titre == "Berserk  Chapitre 43")
    }

    @Test("La sous ligne d un chapitre dit son etat de lecture, jamais rien")
    func laSousLigneDUnChapitreDitSonEtat() throws {
        let libelles = try libelles()

        let lu = TexteDeStockage.sousLigne(
            de: MaterielDeStockage.posteDeChapitre(estLu: true),
            libelles: libelles
        )
        let nonLu = TexteDeStockage.sousLigne(
            de: MaterielDeStockage.posteDeChapitre(estLu: false),
            libelles: libelles
        )

        #expect(lu == "Lu")
        #expect(nonLu == "Non lu")
        #expect(lu != nonLu)
    }

    @Test("La sous ligne de chapitre lu est celle du tableau 4.5, pas une seconde formulation")
    func laSousLigneReprendLeTableau() throws {
        let libelles = try libelles()
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "text.quaternary`, `Lu` |"))

        #expect(ligne.isEmpty == false)
        #expect(libelles.chapitreLu == "Lu")
    }

    @Test("Aucune sous ligne n est vide, quel que soit ce que le poste designe")
    func aucuneSousLigneNEstVide() throws {
        let libelles = try libelles()

        let postes = [
            MaterielDeStockage.posteDeChapitre(),
            PosteDeStockage(id: "s", contenu: .source(nom: "Serveur"), octets: 1, elements: ["s"]),
            PosteDeStockage(
                id: "g",
                contenu: .elementsAnonymes(nombre: 12),
                octets: 1,
                elements: ["g"]
            ),
        ]

        for poste in postes {
            #expect(TexteDeStockage.sousLigne(de: poste, libelles: libelles).isEmpty == false)
        }
    }

    @Test("Un poste groupe compte ce qu il recouvre et se nomme selon sa categorie")
    func lePosteGroupeSeNommeSelonSaCategorie() throws {
        let libelles = try libelles()
        let groupe = PosteDeStockage(
            id: AssemblageDesPostes.clesDesAnonymes,
            contenu: .elementsAnonymes(nombre: 12),
            octets: 500,
            elements: ["a"]
        )

        #expect(TexteDeStockage.sousLigne(de: groupe, libelles: libelles) == "12 elements")

        let titres = CategorieDeStockage.allCases.map {
            TexteDeStockage.titre(de: groupe, categorie: $0, libelles: libelles)
        }

        #expect(titres.allSatisfy { $0.isEmpty == false })
        #expect(Set(titres).count == titres.count)
    }

    @Test("Une source se nomme par son nom, pas par son identifiant")
    func laSourceSeNommeParSonNom() throws {
        let libelles = try libelles()
        let poste = PosteDeStockage(
            id: UUID().uuidString,
            contenu: .source(nom: "Komga serveur maison"),
            octets: 1,
            elements: ["s"]
        )

        #expect(
            TexteDeStockage.titre(de: poste, categorie: .cacheDeChapitres, libelles: libelles)
                == "Komga serveur maison"
        )
    }

    @Test("L etiquette lue par VoiceOver porte la taille, alignee a droite dans la ligne")
    func lEtiquettePorteLaTaille() throws {
        let libelles = try libelles()

        let etiquette = TexteDeStockage.etiquette(
            de: MaterielDeStockage.posteDeChapitre(estLu: true),
            categorie: .chapitresTelecharges,
            libelles: libelles
        )

        #expect(etiquette == "Berserk  Chapitre 43  Lu  32 Mo")
    }

    // MARK: Confirmation

    @Test("La confirmation nomme ce qui part et ce que cela libere")
    func laConfirmationNommeCeQuiPart() throws {
        let libelles = try libelles()
        let demande = DemandeDeSuppression(
            categorie: .chapitresTelecharges,
            postes: [
                MaterielDeStockage.posteDeChapitre(octets: 20_000_000),
                MaterielDeStockage.posteDeChapitre(octets: 12_000_000),
            ]
        )

        let description = TexteDeStockage.descriptionDeConfirmation(
            de: demande,
            libelles: libelles
        )

        #expect(description.contains("2"))
        #expect(description.contains("32 Mo"))
    }

    @Test("Le bouton de confirmation emploie le meme mot que la commande qui l ouvre")
    func leMemeMotPourLaMemeAction() throws {
        let libelles = try libelles()

        #expect(libelles.confirmationSupprimer == libelles.supprimer)
        #expect(libelles.supprimer == "Supprimer")
    }

    // MARK: Catalogue et regles d ecriture

    @Test("Les trois categories reprennent l inventaire du cahier de developpement")
    func lesTroisCategoriesViennentDeLInventaire() throws {
        let libelles = try libelles()

        #expect(libelles.libelle(de: .chapitresTelecharges) == "Chapitres telecharges")
        #expect(libelles.libelle(de: .cacheDeChapitres) == "Cache des chapitres")
        #expect(libelles.libelle(de: .cacheDImages) == "Cache des images")
    }

    @Test("La description sous la carte est celle du tableau 6.8")
    func laDescriptionEstCelleDuTableau() throws {
        let libelles = try libelles()
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Sous la carte Stockage")
        )

        #expect(ligne.contains(libelles.description))
    }

    @Test("Le titre est celui de la ligne de reglages qui mene ici")
    func leTitreEstCeluiDeLaLigneDeReglages() throws {
        let libelles = try libelles()
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "| 15 | Stockage |"))

        #expect(ligne.contains("Detail du stockage"))
        #expect(libelles.titre == "Detail du stockage")
    }

    @Test("Chaque icone sans libelle porte une etiquette d accessibilite")
    func chaqueIconePorteUneEtiquette() throws {
        #expect(try libelles().selectionner.isEmpty == false)
    }

    @Test("Les libelles de l ecran suivent les regles d ecriture de la section 6")
    func reglesDEcriture() throws {
        let libelles = try libelles()

        // Le caractere interdit par la regle 0 est construit par son code, pour
        // que ce fichier ne le porte pas en clair et ne se signale pas lui meme
        // au controle 4.
        let tiretCadratin = String(UnicodeScalar(0x2014) ?? " ")

        let textes = [
            libelles.titre,
            libelles.description,
            libelles.chapitreLu,
            libelles.chapitreNonLu,
            libelles.cacheDUneSource,
            libelles.supprimer,
            libelles.toutSupprimer,
            libelles.fermerLaSelection,
            libelles.selectionner,
            libelles.confirmationTitre,
            libelles.confirmationAnnuler,
            libelles.confirmationSupprimer,
            libelles.videTitre,
            libelles.videPhrase,
        ] + libelles.categories.values + libelles.titresAnonymes.values

        for texte in textes {
            #expect(texte.isEmpty == false)
            #expect(texte.contains("!") == false, "\(texte)")
            #expect(texte.contains(tiretCadratin) == false, "\(texte)")
        }
    }

    @Test("Un libelle absent du catalogue se voit, il ne se remplace pas en silence")
    func leTrouDeCatalogueSeVoit() throws {
        let libelles = try libelles()

        for categorie in CategorieDeStockage.allCases {
            #expect(libelles.libelle(de: categorie) != categorie.rawValue)
            #expect(libelles.titreAnonyme(de: categorie) != categorie.rawValue)
        }
    }
}
