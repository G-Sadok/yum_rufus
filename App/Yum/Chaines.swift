import Core
import Foundation

//
// Acces au catalogue de chaines.
//
// Aucune vue n ecrit un libelle. Elle passe par ce type, qui est le seul point
// du code ou une cle du catalogue apparait. Les libelles eux memes vivent dans
// Ressources/Localizable.xcstrings, et sont ceux de la section 6 de
// DESIGN-SPEC.md, au caractere pres.
//

/// Libelles de l interface, pris dans le catalogue de chaines.
enum Chaines {
    /// Libelle d une destination de la navigation principale, tableau 6.1.
    static func navigation(_ destination: DestinationPrincipale) -> String {
        switch destination {
        case .bibliotheque: Navigation.bibliotheque
        case .historique: Navigation.historique
        case .parcourir: Navigation.parcourir
        case .rechercher: Navigation.rechercher
        case .reglages: Navigation.reglages
        }
    }

    /// Navigation principale, tableau 6.1.
    enum Navigation {
        static let bibliotheque = String(localized: "navigation.bibliotheque")
        static let historique = String(localized: "navigation.historique")
        static let parcourir = String(localized: "navigation.parcourir")
        static let rechercher = String(localized: "navigation.rechercher")
        static let reglages = String(localized: "navigation.reglages")
        static let repli = String(localized: "navigation.repli")
    }

    /// Barre de categories, section 5.1.
    ///
    /// Seul `tout` est fixe par le document. La section 6 ne nomme pas les
    /// commandes de gestion des categories, l ecran n etant pas dessine : elles
    /// suivent les regles d ecriture de la section 6, voix active, le libelle
    /// dit ce qui se passe.
    ///
    /// Les deux deplacements parlent de rang dans la barre et non de gauche ou
    /// de droite. Une direction d ecran s inverserait avec la direction de
    /// l interface, le rang non.
    enum Categorie {
        static let tout = String(localized: "categorie.tout")
        static let creer = String(localized: "categorie.creer")
        static let renommer = String(localized: "categorie.renommer")
        static let supprimer = String(localized: "categorie.supprimer")
        static let deplacerAvant = String(localized: "categorie.deplacerAvant")
        static let deplacerApres = String(localized: "categorie.deplacerApres")
    }

    /// Bloc d appel a l abonnement, tableau 6.1.
    enum Premium {
        static let titre = String(localized: "premium.titre")
        static let sousTitre = String(localized: "premium.sousTitre")
    }

    /// Etats vides, tableau 6.3.
    enum EtatVide {
        static let bibliothequeTitre = String(localized: "etatVide.bibliotheque.titre")
        static let bibliothequePhrase = String(localized: "etatVide.bibliotheque.phrase")
        static let bibliothequeAction = String(localized: "etatVide.bibliotheque.action")

        static let historiqueTitre = String(localized: "etatVide.historique.titre")
        static let historiquePhrase = String(localized: "etatVide.historique.phrase")
        static let historiqueAction = String(localized: "etatVide.historique.action")

        static let parcourirTitre = String(localized: "etatVide.parcourir.titre")
        static let parcourirPhrase = String(localized: "etatVide.parcourir.phrase")

        static let rechercherTitre = String(localized: "etatVide.rechercher.titre")
        static let rechercherPhrase = String(localized: "etatVide.rechercher.phrase")
    }
}
