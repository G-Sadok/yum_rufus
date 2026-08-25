import Foundation

//
// ConfirmationRequise
//
// Garde d une action destructive qui ne s execute jamais sur un seul geste.
//
// La regle vit ici plutot que dans la vue pour une raison simple : une modale
// que l on oublie d afficher ne se voit pas au compilateur, alors qu une action
// qui ne demande pas sa confirmation se voit au test. `confirmer` ne rend vrai
// que si la demande a ete posee, et une seule fois.
//

/// Etat d une demande de confirmation, section 4.8 de DESIGN-SPEC.md.
public struct ConfirmationRequise: Sendable, Equatable {
    /// Vrai quand la modale de confirmation doit etre visible.
    public private(set) var estDemandee: Bool

    public init() {
        estDemandee = false
    }

    /// Ouvre la demande. L action reste a faire.
    public mutating func demander() {
        estDemandee = true
    }

    /// Referme la demande sans rien executer.
    ///
    /// C est ce que declenchent le bouton Annuler, la touche d echappement et
    /// le clic sur le voile.
    public mutating func annuler() {
        estDemandee = false
    }

    /// Referme la demande et dit si l action peut partir.
    ///
    /// - Returns: vrai seulement si la demande avait ete posee. Une
    ///   confirmation qui arrive sans demande, par un raccourci laisse actif ou
    ///   par un double appel, n execute rien.
    public mutating func confirmer() -> Bool {
        let etaitDemandee = estDemandee
        estDemandee = false

        return etaitDemandee
    }
}
