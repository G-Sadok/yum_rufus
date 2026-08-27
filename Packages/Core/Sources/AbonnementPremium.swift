import Foundation

//
// AbonnementPremium
//
// Ce que la boutique vend, tel que la section 10 du cahier de developpement le
// decrit : un abonnement mensuel, un abonnement annuel, et un achat definitif.
// Un essai de sept jours ouvre le parcours.
//
// Le modele ne connait pas StoreKit et ne le connaitra jamais. Il decrit un
// produit par ce dont l ecran a besoin, un identifiant, un genre, un prix deja
// mis en forme et une periode d essai eventuelle. L adaptateur qui parle a la
// boutique du systeme traduit dans un sens, et rien ne remonte de l autre. Sans
// cette frontiere, le mur premium ne serait testable que sur un appareil connecte
// a un compte de test.
//
// Les identifiants sont ceux du fichier de configuration StoreKit du depot. Ils
// sont ecrits ici parce que le code doit demander des produits par leur nom, et
// la suite de tests compare cette liste au fichier lui meme plutot qu a une
// copie de ses valeurs.
//

/// Les trois formes sous lesquelles Premium se vend.
public enum GenreDeProduitPremium: String, Sendable, Codable, CaseIterable, Hashable {
    /// Abonnement reconduit chaque mois.
    case mensuel

    /// Abonnement reconduit chaque annee.
    case annuel

    /// Achat unique, sans reconduction ni expiration.
    case definitif

    /// Vrai quand le produit se reconduit et peut donc expirer.
    ///
    /// L achat definitif est le seul a ne jamais expirer. Toute regle de
    /// degradation part de cette distinction.
    public var estUnAbonnement: Bool {
        self != .definitif
    }
}

/// Duree pendant laquelle Premium est ouvert sans etre facture.
public struct PeriodeDEssai: Sendable, Equatable, Hashable {
    /// Nombre de jours offerts.
    public let jours: Int

    public init(jours: Int) {
        self.jours = jours
    }

    /// Essai de sept jours, seule duree retenue par la section 0.1 du
    /// DESIGN-SPEC et par la section 10 du cahier de developpement.
    public static let septJours = PeriodeDEssai(jours: 7)

    /// Secondes d une journee, employees par le seul repli du calcul de fin.
    static let secondesParJour: Double = 24 * 60 * 60

    /// Instant ou l essai se termine.
    ///
    /// Le calcul passe par le calendrier et non par une multiplication de
    /// secondes : un changement d heure legale pendant l essai raccourcirait ou
    /// allongerait sinon la periode d une heure. Le repli sur les secondes ne
    /// sert que si le calendrier refuse l operation, ce qui n arrive pas avec un
    /// nombre de jours positif, et evite une force unwrap.
    public func fin(depuis debut: Date, calendrier: Calendar = .current) -> Date {
        calendrier.date(byAdding: .day, value: jours, to: debut)
            ?? debut.addingTimeInterval(Double(jours) * Self.secondesParJour)
    }
}

/// Un produit vendu par la boutique, vu par l application.
public struct ProduitPremium: Sendable, Equatable, Hashable, Identifiable {
    /// Identifiant du produit chez la boutique.
    public let identifiant: String

    /// Forme de vente.
    public let genre: GenreDeProduitPremium

    /// Prix deja mis en forme par la boutique, dans la devise du compte.
    ///
    /// L application ne formate jamais un prix elle meme. Elle ne connait ni la
    /// devise du compte, ni les regles locales d affichage, et la boutique les
    /// connait toutes les deux.
    public let prixAffiche: String

    /// Periode offerte a la souscription, nulle quand le produit n en offre pas.
    public let essai: PeriodeDEssai?

    public init(
        identifiant: String,
        genre: GenreDeProduitPremium,
        prixAffiche: String,
        essai: PeriodeDEssai? = nil
    ) {
        self.identifiant = identifiant
        self.genre = genre
        self.prixAffiche = prixAffiche
        self.essai = essai
    }

    public var id: String {
        identifiant
    }
}

/// Identifiants des produits Premium, ceux du fichier de configuration StoreKit.
public enum CataloguePremium {
    /// Abonnement mensuel, produit mis en avant par le mur.
    public static let mensuel = "com.yum.lecteur.premium.mensuel"

    /// Abonnement annuel.
    public static let annuel = "com.yum.lecteur.premium.annuel"

    /// Achat definitif.
    public static let definitif = "com.yum.lecteur.premium.definitif"

    /// Les trois identifiants a demander a la boutique.
    public static let identifiants = [mensuel, annuel, definitif]

    /// Genre du produit designe, nul quand l identifiant n est pas des notres.
    ///
    /// Un identifiant inconnu n est pas une curiosite : c est une transaction
    /// qui ne concerne pas cette application, et elle ne doit rien debloquer.
    public static func genre(de identifiant: String) -> GenreDeProduitPremium? {
        switch identifiant {
        case mensuel: .mensuel
        case annuel: .annuel
        case definitif: .definitif
        default: nil
        }
    }

    /// Produit mis en avant par le mur premium.
    ///
    /// La mention de prix du tableau 6.8 parle d un tarif mensuel, le mur porte
    /// donc l abonnement mensuel. Les deux autres produits restent accessibles,
    /// mais depuis la gestion de l abonnement, pas depuis le mur.
    public static func misEnAvant(parmi produits: [ProduitPremium]) -> ProduitPremium? {
        produits.first { $0.identifiant == mensuel } ?? produits.first
    }
}
