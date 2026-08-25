import Foundation

//
// CategoriesDeBibliotheque
//
// Regles de classement de la barre de categories, section 5.1 de
// DESIGN-SPEC.md. L entite Categorie elle meme vit dans EntitesDeBibliotheque,
// c est son ordonnancement et sa selection qui vivent ici.
//
// La categorie Tout n est pas une ligne de la table. C est une selection qui ne
// filtre rien. Cette decision porte a elle seule le premier critere de la
// fonctionnalite : ce qui n existe pas en base ne se renomme pas, ne se
// reordonne pas et ne se supprime pas, et rien n a besoin de garder une ligne
// speciale contre l utilisateur.
//

/// Onglet selectionne dans la barre de categories.
public enum SelectionDeCategorie: Sendable, Hashable, Codable {
    /// Toute la bibliotheque, sans filtre. Toujours le premier onglet.
    case tout

    /// Une categorie enregistree.
    case categorie(UUID)

    /// Selection appliquee tant que l utilisateur n a rien choisi.
    public static let defaut = SelectionDeCategorie.tout

    /// Vrai pour l onglet Tout.
    public var estTout: Bool {
        self == .tout
    }

    /// Identifiant de la categorie visee, nul pour l onglet Tout.
    ///
    /// Une commande qui a besoin d un identifiant, comme renommer ou
    /// supprimer, obtient donc nil sur Tout et n a aucune cible a viser.
    public var identifiant: UUID? {
        switch self {
        case .tout: nil
        case let .categorie(identifiant): identifiant
        }
    }
}

extension SelectionDeCategorie: Identifiable {
    public var id: Self {
        self
    }
}

/// Erreurs que la gestion des categories peut remonter jusqu a l interface.
///
/// Chaque cas nomme la cause. La traduction en message utilisateur se fait dans
/// la couche vue, avec le catalogue de chaines.
public enum ErreurDeCategorie: Error, Sendable, Equatable {
    /// Le nom demande est vide, ou ne contient que des espaces.
    case nomVide

    /// Une autre categorie porte deja ce nom, aux accents et a la casse pres.
    case nomDejaPris(nom: String)

    /// La categorie visee n existe pas ou plus.
    case categorieInconnue(identifiant: UUID)

    /// La serie visee n existe pas ou plus.
    case serieInconnue(identifiant: UUID)
}

/// Nombre de series par onglet de la barre de categories.
///
/// Les compteurs arrivent tous ensemble, en une seule lecture. La barre ne
/// demande jamais un compteur categorie par categorie, et la grille ne compte
/// rien pendant son defilement.
public struct CompteursDeCategories: Sendable, Equatable {
    /// Nombre de series de la bibliotheque, compteur de l onglet Tout.
    public let total: Int

    /// Nombre de series par categorie, categories vides comprises.
    public let parCategorie: [UUID: Int]

    public init(total: Int, parCategorie: [UUID: Int]) {
        self.total = total
        self.parCategorie = parCategorie
    }

    /// Compteur affiche par un onglet.
    ///
    /// Une categorie absente du dictionnaire vaut zero : elle existe, elle ne
    /// contient rien. L onglet doit afficher `0`, pas disparaitre.
    public func compteur(pour selection: SelectionDeCategorie) -> Int {
        switch selection {
        case .tout: total
        case let .categorie(identifiant): parCategorie[identifiant] ?? 0
        }
    }
}

/// Ordre des categories dans la barre, et regles de nommage.
///
/// Le rang est une donnee persistee, `categorie.ordre`. Ces fonctions ne font
/// que le produire et le remanier, elles ne le devinent jamais a l affichage.
public enum OrdreDesCategories {
    /// Categories dans l ordre de la barre.
    ///
    /// Le nom departage deux rangs egaux, sans quoi une base ecrite par une
    /// version anterieure, ou par une synchronisation, afficherait un ordre
    /// different a chaque lecture.
    public static func trier(_ categories: [Categorie]) -> [Categorie] {
        categories.sorted { premiere, seconde in
            if premiere.ordre != seconde.ordre {
                return premiere.ordre < seconde.ordre
            }
            return RechercheLocale.normaliser(premiere.nom) < RechercheLocale.normaliser(seconde.nom)
        }
    }

    /// Categories triees et renumerotees de zero a n moins un.
    ///
    /// C est la forme ecrite en base apres un deplacement : des rangs contigus
    /// laissent l ordre suivant sans ambiguite, meme apres une suppression.
    public static func renumeroter(_ categories: [Categorie]) -> [Categorie] {
        trier(categories).enumerated().map { rang, categorie in
            var renumerotee = categorie
            renumerotee.ordre = rang
            return renumerotee
        }
    }

    /// Categories apres deplacement d un onglet vers un autre rang.
    ///
    /// Les rangs hors bornes laissent la liste intacte plutot que de la
    /// tronquer : un glissement relache en dehors de la barre ne doit rien
    /// perdre.
    public static func deplacer(_ categories: [Categorie], de depart: Int, vers arrivee: Int) -> [Categorie] {
        let ordonnees = trier(categories)

        guard ordonnees.indices.contains(depart), ordonnees.indices.contains(arrivee) else {
            return renumeroter(ordonnees)
        }

        var remaniees = ordonnees
        let deplacee = remaniees.remove(at: depart)
        remaniees.insert(deplacee, at: arrivee)

        return remaniees.enumerated().map { rang, categorie in
            var renumerotee = categorie
            renumerotee.ordre = rang
            return renumerotee
        }
    }

    /// Rang d une categorie qui vient d etre creee.
    ///
    /// Une nouvelle categorie se pose en fin de barre, jamais avant les
    /// categories deja rangees par l utilisateur.
    public static func rangSuivant(apres categories: [Categorie]) -> Int {
        guard let dernier = categories.map(\.ordre).max() else { return 0 }
        return dernier + 1
    }

    /// Nom debarrasse de ses espaces de bordure.
    ///
    /// - Throws: `ErreurDeCategorie.nomVide` quand il ne reste rien.
    public static func nomNettoye(_ nom: String) throws -> String {
        let nettoye = nom.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !nettoye.isEmpty else {
            throw ErreurDeCategorie.nomVide
        }

        return nettoye
    }

    /// Verifie qu aucune autre categorie ne porte deja ce nom.
    ///
    /// La comparaison ignore la casse et les diacritiques, comme la recherche
    /// locale. Deux onglets nommes `Termines` et `termines` seraient
    /// indiscernables dans la barre.
    ///
    /// - Parameter sauf: categorie exclue de la comparaison, celle que l on
    ///   renomme.
    public static func verifierLaDisponibilite(
        de nom: String,
        parmi categories: [Categorie],
        sauf identifiant: UUID? = nil
    ) throws {
        let recherche = RechercheLocale.normaliser(nom)

        let collision = categories.contains { categorie in
            categorie.id != identifiant && RechercheLocale.normaliser(categorie.nom) == recherche
        }

        if collision {
            throw ErreurDeCategorie.nomDejaPris(nom: nom)
        }
    }
}
