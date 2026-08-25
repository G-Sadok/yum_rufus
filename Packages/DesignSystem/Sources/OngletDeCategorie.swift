import Core
import Foundation

//
// Un onglet de la barre de categories, pret a etre affiche.
//
// Le libelle vient du catalogue de chaines de l application, y compris celui de
// l onglet Tout. Le compteur vient de la base, deja calcule.
//

/// Un onglet de la barre de categories, section 5.1 de DESIGN-SPEC.md.
public struct OngletDeCategorie: Identifiable, Sendable, Equatable {
    /// Onglet ouvert par la selection.
    public let selection: SelectionDeCategorie

    /// Libelle affiche, pris dans le catalogue de chaines.
    public let libelle: String

    /// Nombre de series de l onglet.
    public let compteur: Int

    public init(selection: SelectionDeCategorie, libelle: String, compteur: Int) {
        self.selection = selection
        self.libelle = libelle
        self.compteur = compteur
    }

    public var id: SelectionDeCategorie {
        selection
    }

    /// Vrai quand l onglet accepte d etre renomme, deplace ou supprime.
    ///
    /// Faux pour Tout, qui n a pas de ligne en base a modifier.
    public var estModifiable: Bool {
        !selection.estTout
    }

    /// Onglets de la barre, Tout en premier.
    ///
    /// L ordre ne se negocie pas avec l appelant : Tout ouvre la barre, les
    /// categories suivent dans l ordre persiste de leur rang.
    ///
    /// - Parameters:
    ///   - libelleDeTout: libelle de l onglet Tout, pris dans le catalogue de
    ///     chaines de l application.
    ///   - categories: categories enregistrees, dans n importe quel ordre.
    ///   - compteurs: nombre de series par onglet, lus en une fois.
    public static func barre(
        libelleDeTout: String,
        categories: [Categorie],
        compteurs: CompteursDeCategories
    ) -> [OngletDeCategorie] {
        let tout = OngletDeCategorie(
            selection: .tout,
            libelle: libelleDeTout,
            compteur: compteurs.compteur(pour: .tout)
        )

        let suivants = OrdreDesCategories.trier(categories).map { categorie in
            OngletDeCategorie(
                selection: .categorie(categorie.id),
                libelle: categorie.nom,
                compteur: compteurs.compteur(pour: .categorie(categorie.id))
            )
        }

        return [tout] + suivants
    }
}

/// Commandes ouvertes par le menu contextuel d un onglet.
///
/// Elles n existent que pour les categories enregistrees. Aucune n est
/// proposee sur Tout, qui n a rien a renommer, a deplacer ni a supprimer.
///
/// Les libelles arrivent du catalogue de chaines. La section 6 de
/// DESIGN-SPEC.md ne les fixe pas, l ecran de gestion des categories n etant
/// pas dessine : ils suivent la regle d ecriture de la section 6, le libelle
/// dit ce qui se passe.
public struct CommandesDeCategorie {
    /// Libelle de la commande de renommage.
    public let libelleRenommer: String
    /// Libelle de la commande de suppression.
    public let libelleSupprimer: String
    /// Libelle du deplacement d un rang vers le debut de la barre.
    public let libelleDeplacerAvant: String
    /// Libelle du deplacement d un rang vers la fin de la barre.
    public let libelleDeplacerApres: String

    /// Ouvre le renommage de la categorie.
    public let renommer: (UUID) -> Void
    /// Supprime la categorie.
    public let supprimer: (UUID) -> Void
    /// Deplace la categorie vers le rang demande.
    ///
    /// Le rang compte les categories enregistrees, Tout exclu, et part de zero.
    public let deplacer: (UUID, Int) -> Void

    public init(
        libelleRenommer: String,
        libelleSupprimer: String,
        libelleDeplacerAvant: String,
        libelleDeplacerApres: String,
        renommer: @escaping (UUID) -> Void,
        supprimer: @escaping (UUID) -> Void,
        deplacer: @escaping (UUID, Int) -> Void
    ) {
        self.libelleRenommer = libelleRenommer
        self.libelleSupprimer = libelleSupprimer
        self.libelleDeplacerAvant = libelleDeplacerAvant
        self.libelleDeplacerApres = libelleDeplacerApres
        self.renommer = renommer
        self.supprimer = supprimer
        self.deplacer = deplacer
    }
}
