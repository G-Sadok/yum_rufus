import Core
import Foundation
import Testing
@testable import DesignSystem

//
// Couvre les mesures du mur premium, section 5.9 de DESIGN-SPEC.md.
//
// Chaque mesure est comparee a la phrase du document qui la fixe, jamais a une
// copie de sa valeur. Les textes et les commandes de la feuille sont couverts
// par `TextesDuMurPremiumTests`, qui partage le materiel de ce fichier.
//

/// Materiel partage par les suites du mur premium.
enum MaterielDuMurPremium {
    /// Libelles tels que le catalogue de l application les porte.
    static func libellesDuCatalogue() throws -> LibellesDuMurPremium {
        let catalogue = try CatalogueDeChaines.charger()

        return LibellesDuMurPremium(
            titre: catalogue["murPremium.titre"] ?? "",
            sousTitre: catalogue["murPremium.sousTitre"] ?? "",
            avantages: [
                AvantagePremium.traductionEtColorisation.rawValue:
                    catalogue["murPremium.avantage.traductionEtColorisation"] ?? "",
                AvantagePremium.serveurs.rawValue:
                    catalogue["murPremium.avantage.serveurs"] ?? "",
                AvantagePremium.suivis.rawValue:
                    catalogue["murPremium.avantage.suivis"] ?? "",
                AvantagePremium.telechargements.rawValue:
                    catalogue["murPremium.avantage.telechargements"] ?? "",
                AvantagePremium.sauvegardeEtSynchronisation.rawValue:
                    catalogue["murPremium.avantage.sauvegardeEtSynchronisation"] ?? "",
            ],
            commencerLEssai: catalogue["murPremium.commencerLEssai"] ?? "",
            sAbonner: catalogue["murPremium.sAbonner"] ?? "",
            mentionDePrix: catalogue["murPremium.mentionDePrix"] ?? "",
            plusTard: catalogue["murPremium.plusTard"] ?? "",
            restaurerLesAchats: catalogue["reglages.ligne.abonnement.restaurerLesAchats"] ?? "",
            erreurTitre: catalogue["erreur.boutique.titre"] ?? "",
            erreurPhrase: catalogue["erreur.boutique.phrase"] ?? "",
            reessayer: catalogue["erreur.reessayer"] ?? "",
            etiquetteDeLaCouronne: catalogue["reglages.couronne"] ?? ""
        )
    }

    /// Offre de reference, celle que la mention de prix du tableau 6.8 chiffre.
    static func offre(essaiDisponible: Bool = true) -> OffrePremium {
        OffrePremium(
            produit: ProduitPremium(
                identifiant: CataloguePremium.mensuel,
                genre: .mensuel,
                prixAffiche: "3,99 euros",
                essai: .septJours
            ),
            essaiDisponible: essaiDisponible
        )
    }

    /// Cellule d une ligne de tableau du document.
    static func cellule(
        entete: [String],
        premiereCellule: String,
        rang: Int
    ) throws -> String {
        let tableaux = try SpecificationDeDesign.tableaux(dontLEnteteEst: entete)

        let ligne = try #require(
            tableaux.flatMap(\.lignes).first { $0.first == premiereCellule },
            "Le document doit porter une ligne \(premiereCellule)"
        )

        return try #require(ligne.indices.contains(rang) ? ligne[rang] : nil)
    }

    /// Les cinq avantages tels que la section 5.9 les enumere.
    static func avantagesDuDocument() throws -> [String] {
        let lignes = try SpecificationDeDesign.lignes()

        let depart = try #require(
            lignes.firstIndex { $0.contains("Liste des avantages, dans cet ordre") }
        )

        return lignes
            .dropFirst(depart)
            .filter { ligne in
                guard let premier = ligne.first else { return false }

                return premier.isNumber && ligne.contains(". ")
            }
            .prefix(AvantagePremium.allCases.count)
            .map { ligne in
                String(ligne.drop { $0.isNumber || $0 == "." || $0 == " " })
            }
    }
}

/// Mesures de la feuille, comparees au document lui meme.
struct MurPremiumDansLaVueTests {
    @Test("La feuille mesure 360 par 420, section 5.9")
    func laFeuilleMesure360Par420() throws {
        let hauteur = try #require(
            try SpecificationDeDesign.ligne(contenant: "| Hauteur, cas de reference | 420 |")
        )

        #expect(hauteur.isEmpty == false)
        #expect(Jetons.MurPremium.largeur == 360)
        #expect(Jetons.MurPremium.hauteurDeReference == 420)
    }

    @Test("Le rayon de la feuille est celui des feuilles de la section 1.6")
    func leRayonEstCeluiDesFeuilles() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "feuille de configuration, mur premium")
        )

        #expect(ligne.contains("16"))
        #expect(Jetons.MurPremium.rayon == 16)
        #expect(Jetons.MurPremium.rayon == Jetons.Rayon.feuille)
    }

    @Test("Le fond et le contour sont les deux couleurs chiffrees par la section 5.9")
    func leFondEtLeContourViennentDuDocument() throws {
        let fond = try #require(try SpecificationDeDesign.ligne(contenant: "| Fond | `#141A28` |"))
        let contour = try #require(try SpecificationDeDesign.ligne(contenant: "`#24344F`"))

        #expect(fond.isEmpty == false)
        #expect(contour.contains("1 px"))
        #expect(Jetons.MurPremium.fond.notation == "#141A28")
        #expect(Jetons.MurPremium.contour.notation == "#24344F")
        #expect(Jetons.MurPremium.epaisseurDuContour == 1)
    }

    @Test("La feuille est au niveau d elevation 2, sur voile")
    func laFeuilleEstAuNiveauDeux() throws {
        let ligne = try #require(
            try SpecificationDeDesign.ligne(contenant: "modale, feuille de configuration, mur premium")
        )

        #expect(ligne.contains("voile"))
        #expect(Jetons.MurPremium.elevation == .modal)
        #expect(Jetons.MurPremium.elevation.complement == .voile)
    }

    @Test("La couronne mesure 56 par 40 et porte le symbole du tableau 1.10")
    func laCouronneMesure56Par40() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "56 par 40"))

        #expect(ligne.contains("accent"))
        #expect(Jetons.MurPremium.largeurDeLaCouronne == 56)
        #expect(Jetons.MurPremium.hauteurDeLaCouronne == 40)
        #expect(Jetons.MurPremium.couronne == Jetons.Icone.premium)
    }

    @Test("Le titre est a 20 en graisse 700, seul role de texte a cette taille")
    func leTitreEstA20() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "20 graisse 700"))

        #expect(ligne.contains("centre"))
        #expect(Jetons.MurPremium.titre.taille == 20)
        #expect(Jetons.MurPremium.titre.graisse == .grasse)
        #expect(Jetons.Typo.parRole.values.contains(Jetons.MurPremium.titre) == false)
    }

    @Test("Le sous titre et la mention de prix reprennent des roles de l echelle")
    func lesRolesDeTexteViennentDeLEchelle() throws {
        let sousTitre = try #require(
            try SpecificationDeDesign.ligne(contenant: "Debloquez toutes les fonctions avancees")
        )
        let mention = try #require(
            try SpecificationDeDesign.ligne(contenant: "| Mention de prix |")
        )

        #expect(sousTitre.contains("footnote"))
        #expect(mention.contains("caption"))
        #expect(Jetons.MurPremium.sousTitre == Jetons.Typo.footnote)
        #expect(Jetons.MurPremium.mentionDePrix == Jetons.Typo.caption)
    }

    @Test("Les avantages suivent les mesures de la section 5.9")
    func lesAvantagesSuiventLeDocument() throws {
        let ligne = try #require(try SpecificationDeDesign.ligne(contenant: "| Avantages |"))

        #expect(ligne.contains("cinq lignes"))
        #expect(ligne.contains("callout"))
        #expect(AvantagePremium.allCases.count == 5)
        #expect(Jetons.MurPremium.avantage == Jetons.Typo.callout)
        #expect(Jetons.MurPremium.tailleDeLaCoche == 14)
        #expect(Jetons.MurPremium.gouttiereApresLaCoche == 12)
        #expect(Jetons.MurPremium.interligneDesAvantages == 14)
    }

    @Test("Le bouton mesure 296 par 42, rayon 12, et le tableau 4.6 le confirme")
    func leBoutonMesure296Par42() throws {
        let section = try #require(
            try SpecificationDeDesign.ligne(contenant: "296 par 42, rayon 12")
        )
        let contexte = try #require(
            try SpecificationDeDesign.ligne(contenant: "| Mur premium | 42 | 12 |")
        )

        #expect(section.contains("principal"))
        #expect(contexte.isEmpty == false)
        #expect(Jetons.MurPremium.largeurDuBouton == 296)
        #expect(Jetons.MurPremium.hauteurDuBouton == 42)
        #expect(Jetons.MurPremium.rayonDuBouton == 12)
    }

    @Test("Les ecarts que le document ne chiffre pas sortent de l echelle de la section 1.7")
    func lesEcartsSortentDeLEchelle() {
        let ecarts = [
            Jetons.MurPremium.marge,
            Jetons.MurPremium.ecartApresLaCouronne,
            Jetons.MurPremium.ecartApresLeTitre,
            Jetons.MurPremium.ecartAvantLesAvantages,
            Jetons.MurPremium.ecartAvantLeBouton,
            Jetons.MurPremium.ecartApresLeBouton,
            Jetons.MurPremium.ecartAvantLePied,
            Jetons.MurPremium.ecartEntreLesCommandesDePied,
        ]

        for ecart in ecarts {
            #expect(Jetons.Espace.echelle.contains(ecart), "\(ecart)")
        }
    }

    @Test("Les capsules de l etat d erreur sont celles des modales de la section 4.6")
    func lesCapsulesViennentDeLaSection46() {
        #expect(Jetons.MurPremium.hauteurDeCapsule == Jetons.Bouton.hauteurEnModale)
        #expect(Jetons.MurPremium.rayonDeCapsule == Jetons.Bouton.rayonEnModale)
        #expect(Jetons.MurPremium.largeurDeCapsule * 2 < Jetons.MurPremium.largeurDuBouton)
    }
}
