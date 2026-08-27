import Core
import Foundation

//
// Lecture du fichier de configuration StoreKit du depot.
//
// Les tests d achat ne comparent pas le code a une copie des tarifs. Ils lisent
// `App/Yum.storekit`, le fichier que le schema Xcode charge quand
// l application tourne en developpement, et construisent leurs produits depuis
// lui. Une offre d essai retiree du fichier, un identifiant renomme, une periode
// changee, et la suite vire au rouge.
//
// C est la meme methode que `SpecificationDeDesign` pour DESIGN-SPEC.md : la
// source de verite est le document, pas une constante recopiee a cote.
//

/// Un produit du fichier de configuration.
struct ProduitDeConfiguration: Decodable {
    let productID: String
    let displayPrice: String
    let type: String
}

/// Une offre d essai declaree par un abonnement.
struct OffreDeConfiguration: Decodable {
    let paymentMode: String
    let subscriptionPeriod: String

    /// Vrai quand l offre est une periode entierement gratuite.
    var estGratuite: Bool {
        paymentMode == "free"
    }

    /// Duree de l offre en jours.
    var jours: Int? {
        DureeIso8601.jours(subscriptionPeriod)
    }
}

/// Un abonnement du fichier de configuration.
struct AbonnementDeConfiguration: Decodable {
    let productID: String
    let displayPrice: String
    let recurringSubscriptionPeriod: String
    let introductoryOffer: OffreDeConfiguration?
}

/// Un groupe d abonnements du fichier de configuration.
struct GroupeDeConfiguration: Decodable {
    let id: String
    let name: String
    let subscriptions: [AbonnementDeConfiguration]
}

/// Le fichier de configuration StoreKit, lu tel quel.
struct ConfigurationDeBoutique: Decodable {
    let products: [ProduitDeConfiguration]
    let subscriptionGroups: [GroupeDeConfiguration]

    /// Tous les abonnements, toutes familles confondues.
    var abonnements: [AbonnementDeConfiguration] {
        subscriptionGroups.flatMap(\.subscriptions)
    }

    /// Produits du domaine construits depuis le fichier.
    ///
    /// La conversion est celle que l adaptateur StoreKit fait en production, a
    /// ceci pres qu elle part du fichier au lieu de partir de la boutique. Un
    /// produit du fichier que le catalogue du code ne connait pas est ecarte
    /// ici comme il le serait la : c est exactement ce que la verification
    /// metier refuse.
    var produits: [ProduitPremium] {
        let abonnes = abonnements.compactMap { abonnement -> ProduitPremium? in
            guard let genre = CataloguePremium.genre(de: abonnement.productID) else {
                return nil
            }

            let essai = abonnement.introductoryOffer
                .flatMap { offre in offre.estGratuite ? offre.jours : nil }
                .map(PeriodeDEssai.init(jours:))

            return ProduitPremium(
                identifiant: abonnement.productID,
                genre: genre,
                prixAffiche: abonnement.displayPrice,
                essai: essai
            )
        }

        let uniques = products.compactMap { produit -> ProduitPremium? in
            guard let genre = CataloguePremium.genre(de: produit.productID) else {
                return nil
            }

            return ProduitPremium(
                identifiant: produit.productID,
                genre: genre,
                prixAffiche: produit.displayPrice
            )
        }

        return abonnes + uniques
    }

    /// Produit du domaine portant cet identifiant.
    func produit(_ identifiant: String) -> ProduitPremium? {
        produits.first { $0.identifiant == identifiant }
    }
}

/// Acces au fichier de configuration depuis le disque.
enum ConfigurationStoreKit {
    /// Chemin du fichier, resolu depuis l emplacement de ce fichier de test.
    static var chemin: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // racine du depot
            .appendingPathComponent("App/Yum.storekit")
    }

    /// Configuration lue et decodee.
    static func charger() throws -> ConfigurationDeBoutique {
        let donnees = try Data(contentsOf: chemin)

        return try JSONDecoder().decode(ConfigurationDeBoutique.self, from: donnees)
    }
}

/// Conversion des durees ISO 8601 employees par les fiches produit.
enum DureeIso8601 {
    /// Duree en jours, nulle quand la notation n est pas reconnue.
    ///
    /// Les fiches produit n emploient que quatre unites. Le mois et l annee sont
    /// convertis en jours de calendrier moyens, ce qui suffit ici : seule la
    /// periode d essai est mesuree en jours, et elle s ecrit en jours ou en
    /// semaines.
    static func jours(_ notation: String) -> Int? {
        guard notation.hasPrefix("P") else {
            return nil
        }

        let corps = notation.dropFirst()

        guard let unite = corps.last, let nombre = Int(corps.dropLast()) else {
            return nil
        }

        switch unite {
        case "D": return nombre
        case "W": return nombre * 7
        case "M": return nombre * 30
        case "Y": return nombre * 365
        default: return nil
        }
    }
}
