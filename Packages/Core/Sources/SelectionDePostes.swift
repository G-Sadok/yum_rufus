import Foundation

//
// SelectionDePostes
//
// Selection multiple d un ecran de detail du stockage, et barre d actions
// qu elle ouvre, sur le modele de la section 4.5 de DESIGN-SPEC.md.
//
// Le type reprend la regle de `SelectionDeChapitres`, la barre existe si et
// seulement si la selection n est pas vide, et s en separe sur un point : un
// poste est designe par son nom sur le disque et non par un identifiant de la
// base. Un fichier de cache n existe dans aucune table, et une selection typee
// `UUID` ne pourrait tout simplement pas le viser.
//
// La barre du stockage ne propose qu une action, Supprimer. Marquer lu et
// Telecharger n ont aucun sens sur un fichier de cache, et une barre qui
// afficherait trois actions dont deux inertes vaudrait moins qu une barre qui
// n en montre qu une.
//

/// Postes retenus dans un ecran de detail du stockage.
public struct SelectionDePostes: Sendable, Equatable {
    /// Cles des postes retenus.
    public private(set) var cles: Set<String>

    public init(cles: Set<String> = []) {
        self.cles = cles
    }

    /// Vrai quand aucun poste n est retenu.
    public var estVide: Bool {
        cles.isEmpty
    }

    /// Nombre de postes retenus, affiche par le compteur `N selectionnes`.
    public var nombre: Int {
        cles.count
    }

    /// Vrai quand la barre d actions contextuelle est a l ecran.
    public var barreEstOuverte: Bool {
        estVide == false
    }

    /// Vrai quand le poste fait partie de la selection.
    public func contient(_ cle: String) -> Bool {
        cles.contains(cle)
    }

    /// Ajoute le poste s il est absent, le retire sinon.
    public mutating func basculer(_ cle: String) {
        if cles.contains(cle) {
            cles.remove(cle)
        } else {
            cles.insert(cle)
        }
    }

    /// Retient tous les postes affiches.
    public mutating func toutSelectionner(_ postes: [PosteDeStockage]) {
        cles = Set(postes.map(\.id))
    }

    /// Vide la selection et referme la barre.
    public mutating func vider() {
        cles.removeAll()
    }

    /// Retire de la selection les postes qui ne sont plus affiches.
    ///
    /// Une suppression qui reussit fait disparaitre des lignes. Sans ce
    /// resserrement, la barre resterait ouverte sur des postes effaces et le
    /// compteur annoncerait plus de lignes que la liste n en montre.
    public mutating func restreindre(a postes: [PosteDeStockage]) {
        cles.formIntersection(Set(postes.map(\.id)))
    }

    /// Postes retenus, dans l ordre de la liste affichee.
    ///
    /// L ordre vient de la liste et non de l ensemble : un ensemble n en a pas,
    /// et la modale de confirmation doit annoncer un nombre stable.
    public func postesRetenus(dans postes: [PosteDeStockage]) -> [PosteDeStockage] {
        postes.filter { cles.contains($0.id) }
    }
}
