import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre les trois ecrans de stockage, section 15 de la section 5.5.
//
// Le document ne dessine pas ces ecrans, il les liste parmi les sous ecrans a
// concevoir cote implementation et fixe deux contraintes : gabarit colonne 580,
// et quatre etats. Les mesures sont donc empruntees a des composants deja
// chiffres, et chaque emprunt est compare a la phrase du document elle meme, pas
// a une copie de sa valeur.
//
// Deux criteres d acceptation se jouent ici. Le premier, les tailles affichees,
// tient au format : une mesure exacte rendue `1000 Ko` au lieu de `1 Mo` reste
// une mesure exacte mal dite. Le troisieme, la confirmation, tient au fait que
// la commande de suppression ne recoit jamais qu une demande deja confirmee,
// ce que le type des commandes rend visible a l appel.
//

/// Materiel partage par les suites de ce fichier.
enum MaterielDeStockage {
    /// Libelles tels que le catalogue de l application les porte.
    static func libellesDuCatalogue() throws -> LibellesDeStockage {
        let catalogue = try CatalogueDeChaines.charger()

        return LibellesDeStockage(
            titre: catalogue["reglages.ligne.stockage.detail"] ?? "",
            description: catalogue["reglages.description.stockage"] ?? "",
            categories: [
                CategorieDeStockage.chapitresTelecharges.rawValue:
                    catalogue["stockage.categorie.chapitresTelecharges"] ?? "",
                CategorieDeStockage.cacheDeChapitres.rawValue:
                    catalogue["stockage.categorie.cacheDeChapitres"] ?? "",
                CategorieDeStockage.cacheDImages.rawValue:
                    catalogue["stockage.categorie.cacheDImages"] ?? "",
            ],
            chapitreNumerote: catalogue["chapitre.numerote"] ?? "",
            chapitreLu: catalogue["chapitre.lu"] ?? "",
            chapitreNonLu: catalogue["stockage.chapitreNonLu"] ?? "",
            cacheDUneSource: catalogue["stockage.cacheDUneSource"] ?? "",
            elementsAnonymes: catalogue["stockage.elementsAnonymes"] ?? "",
            titresAnonymes: [
                CategorieDeStockage.chapitresTelecharges.rawValue:
                    catalogue["stockage.anonymes.chapitresTelecharges"] ?? "",
                CategorieDeStockage.cacheDeChapitres.rawValue:
                    catalogue["stockage.anonymes.cacheDeChapitres"] ?? "",
                CategorieDeStockage.cacheDImages.rawValue:
                    catalogue["stockage.anonymes.cacheDImages"] ?? "",
            ],
            poids: MotifsDePoids(
                octets: catalogue["telechargements.poidsEnOctets"] ?? "",
                kilooctets: catalogue["telechargements.poidsEnKo"] ?? "",
                megaoctets: catalogue["telechargements.poidsEnMo"] ?? "",
                gigaoctets: catalogue["telechargements.poidsEnGo"] ?? ""
            ),
            supprimer: catalogue["selection.supprimer"] ?? "",
            toutSupprimer: catalogue["stockage.toutSupprimer"] ?? "",
            compteurDeSelection: catalogue["selection.compteur"] ?? "",
            fermerLaSelection: catalogue["selection.fermer"] ?? "",
            selectionner: catalogue["selection.selectionner"] ?? "",
            confirmationTitre: catalogue["stockage.confirmation.titre"] ?? "",
            confirmationDescription: catalogue["stockage.confirmation.description"] ?? "",
            confirmationAnnuler: catalogue["historique.confirmation.annuler"] ?? "",
            confirmationSupprimer: catalogue["selection.supprimer"] ?? "",
            videTitre: catalogue["etatVide.stockage.titre"] ?? "",
            videPhrase: catalogue["etatVide.stockage.phrase"] ?? ""
        )
    }

    /// Poste de reference, le chapitre que le document cite ailleurs.
    static func posteDeChapitre(estLu: Bool = false, octets: Int = 32_000_000) -> PosteDeStockage {
        PosteDeStockage(
            id: UUID().uuidString,
            contenu: .chapitre(
                ChapitreDeStockage(
                    chapitreId: UUID(),
                    titreDeLaSerie: "Berserk",
                    numeroDeChapitre: 43,
                    estLu: estLu
                )
            ),
            octets: octets,
            elements: ["dossier"]
        )
    }
}

/// Mesures des ecrans de stockage, comparees au document lui meme.
struct StockageDansLaVueTests {
    @Test("La colonne mesure 580 exactement, contrainte stricte de la section 2.3")
    func laColonneMesure580() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "**580 exactement**"))

        #expect(ligne.contains("Contrainte stricte"))
        #expect(Jetons.Stockage.largeurDeColonne == 580)
        #expect(Jetons.Stockage.largeurDeColonne == Jetons.CarteDeReglages.largeurDeColonne)
    }

    @Test("La carte garde le rayon 12 des cartes de la section 4.2")
    func laCarteGardeLeRayonDesCartes() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "conteneur de rayon 12"))

        #expect(ligne.contains("surface.card"))
        #expect(Jetons.Stockage.rayon == 12)
        #expect(Jetons.Stockage.rayon == Jetons.Rayon.carte)
    }

    @Test("Le filet est encastre de 20 a gauche et affleure a droite")
    func leFiletEstEncastreDe20() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "encastre de 20 a gauche"))

        #expect(ligne.contains("affleurant a droite"))
        #expect(Jetons.Stockage.epaisseurDuSeparateur == 1)
        #expect(Jetons.Stockage.encastrementDuSeparateur == 20)
    }

    @Test("Une ligne de categorie prend la hauteur d une ligne de reglage simple")
    func laLigneDeCategorieFait52() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "Hauteur, version simple"))

        #expect(ligne.contains("52"))
        #expect(Jetons.Stockage.hauteurDeCategorie == 52)
    }

    @Test("Une ligne de poste prend la hauteur d une ligne a description")
    func laLigneDePosteFait76() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "Hauteur, avec description ou curseur")
        )

        #expect(ligne.contains("76"))
        #expect(Jetons.Stockage.hauteurDePoste == 76)
    }

    @Test("La marge laterale et l icone sont celles de la ligne de reglage")
    func lesMesuresDeLaLigneSontEmpruntees() throws {
        let marge = try #require(try SpecificationDeDesign.ligne(contenant: "| Marge laterale | 20 |"))
        let icone = try #require(try SpecificationDeDesign.ligne(contenant: "| Icone | 22, en `accent` |"))

        #expect(marge.isEmpty == false)
        #expect(icone.isEmpty == false)

        #expect(Jetons.Stockage.margeLaterale == 20)
        #expect(Jetons.Stockage.tailleDIcone == 22)
        #expect(Jetons.Stockage.gouttiereApresLIcone == 16)
    }

    @Test("Les ecarts que le document ne chiffre pas sortent de l echelle de la section 1.7")
    func lesEcartsSortentDeLEchelle() {
        #expect(Jetons.Espace.echelle.contains(Jetons.Stockage.ecartApresLeTitre))
        #expect(Jetons.Espace.echelle.contains(Jetons.Stockage.ecartAvantLaTaille))
        #expect(Jetons.Espace.echelle.contains(Jetons.Stockage.ecartAvantLaBarre))
    }

    @Test("La case de selection tient la cible de pointage de la section 7")
    func laCibleDeSelectionTientLaRegle() {
        #expect(Jetons.Stockage.coteDeLaSelection == Jetons.Cible.auDoigt)
        #expect(Jetons.Stockage.coteDeLaSelection >= Jetons.Cible.auPointeur)
    }

    @Test("Chaque categorie porte un symbole, et deux categories n en partagent aucun")
    func chaqueCategoriePorteUnSymbole() {
        let symboles = CategorieDeStockage.allCases.map(Jetons.Stockage.symbole(de:))

        #expect(symboles.allSatisfy { $0.isEmpty == false })
        #expect(Set(symboles).count == symboles.count)
    }

    @Test("Le symbole de l ecran d ensemble est celui de la ligne de reglages qui y mene")
    func leSymboleVientDeLaLigneDeReglages() {
        #expect(Jetons.Stockage.symbole == Jetons.IconeDeReglage.pour(.detailDuStockage))
    }
}
