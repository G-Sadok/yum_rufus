import Foundation

//
// GardeDeSuppression
//
// Ce qui rend vrai le troisieme critere de la gestion du stockage : aucune
// suppression n est possible sans confirmation.
//
// La garde etend `ConfirmationRequise` sur un point, et un seul : elle retient
// ce que la confirmation vise. Un booleen suffisait a la modale de la section
// 4.8 tant qu un ecran ne detruisait qu une chose. Ici trois ecrans detruisent
// des ensembles differents, et la cible doit voyager avec la demande : sans
// elle, la vue garderait de son cote la liste a supprimer, et rien
// n empecherait la liste de changer entre la demande et la confirmation.
//
// La regle est la meme que celle de `ConfirmationRequise` : `confirmer` ne rend
// une cible que si la demande a ete posee, et une seule fois. Une confirmation
// qui arrive sans demande, par un raccourci laisse actif ou par un double appel,
// ne detruit rien.
//

/// Ce qu une suppression demandee emporterait.
public struct DemandeDeSuppression: Sendable, Equatable, Hashable {
    /// Categorie visee.
    public let categorie: CategorieDeStockage

    /// Noms sur le disque a supprimer.
    public let elements: [String]

    /// Poids total de ce qui partirait, pour que la modale le dise.
    public let octets: Int

    /// Nombre de postes vises, pour que la modale le dise aussi.
    public let nombreDePostes: Int

    public init(categorie: CategorieDeStockage, elements: [String], octets: Int, nombreDePostes: Int) {
        self.categorie = categorie
        self.elements = elements
        self.octets = octets
        self.nombreDePostes = nombreDePostes
    }

    /// Demande portant sur un ensemble de postes.
    ///
    /// Les postes sont deplies en noms de disque ici et non a l execution : ce
    /// qui est confirme est exactement ce qui sera supprime, meme si la liste
    /// affichee change pendant que la modale est ouverte.
    public init(categorie: CategorieDeStockage, postes: [PosteDeStockage]) {
        self.init(
            categorie: categorie,
            elements: postes.flatMap(\.elements),
            octets: postes.reduce(0) { $0 + $1.octets },
            nombreDePostes: postes.count
        )
    }

    /// Vrai quand la demande ne porte sur rien.
    ///
    /// Une demande vide ne doit pas ouvrir de modale : une modale qui demande de
    /// confirmer la suppression de rien apprend a confirmer sans lire.
    public var estVide: Bool {
        elements.isEmpty
    }
}

/// Garde d une suppression, qui n execute rien sans confirmation prealable.
public struct GardeDeSuppression: Sendable, Equatable {
    /// Ce que la confirmation en cours vise, nul quand rien n est demande.
    public private(set) var demande: DemandeDeSuppression?

    public init() {
        demande = nil
    }

    /// Vrai quand la modale de confirmation doit etre visible.
    public var estDemandee: Bool {
        demande != nil
    }

    /// Ouvre la demande. La suppression reste a faire.
    ///
    /// Une demande vide est ignoree : elle ouvrirait une modale qui ne detruit
    /// rien, et apprendrait a confirmer sans lire.
    public mutating func demander(_ demande: DemandeDeSuppression) {
        guard demande.estVide == false else {
            return
        }

        self.demande = demande
    }

    /// Referme la demande sans rien supprimer.
    ///
    /// C est ce que declenchent le bouton Annuler, la touche d echappement et le
    /// clic sur le voile, section 4.8.
    public mutating func annuler() {
        demande = nil
    }

    /// Referme la demande et rend ce qui peut etre supprime.
    ///
    /// - Returns: la demande posee, ou nil si aucune ne l avait ete.
    public mutating func confirmer() -> DemandeDeSuppression? {
        let posee = demande
        demande = nil

        return posee
    }
}
