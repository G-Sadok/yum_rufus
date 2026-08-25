import Core
import Foundation
import ImagePipeline

//
// AtelierDeDecodage
//
// Ce qui transforme les octets d une page en image prete a poser.
//
// Le moteur passe par cette abstraction plutot que d appeler `DecodeurDePage`
// directement, pour deux raisons. La chaine de traitements de la section 6.3
// viendra s inserer ici, entre le decodage et le cache, sans toucher a la
// precharge. Et un test peut retenir un decodage a la milliseconde pres, ce qui
// est le seul moyen d observer qu une precharge cede bien le passage a la page
// visible.
//

/// Produit une image affichable a partir des octets d une page.
public protocol AtelierDeDecodage: Sendable {
    /// Decode une page a la taille ou elle sera affichee.
    ///
    /// - Parameters:
    ///   - donnees: octets bruts de la page.
    ///   - nom: nom de l entree, repris dans les erreurs.
    ///   - zone: zone d affichage en pixels reels.
    /// - Throws: l erreur du decodeur quand la page est illisible.
    func decoder(_ donnees: Data, nom: String, dans zone: TailleEnPixels) throws -> ImageDePage
}

/// Atelier adosse au decodage sous echantillonne de la section 6.1.
public struct AtelierSousEchantillonne: AtelierDeDecodage {
    private let decodeur = DecodeurDePage()
    private let budget: BudgetDeDecodage

    public init(budget: BudgetDeDecodage = .parDefaut) {
        self.budget = budget
    }

    public func decoder(_ donnees: Data, nom: String, dans zone: TailleEnPixels) throws -> ImageDePage {
        try decodeur.decoder(donnees, nom: nom, dans: zone, budget: budget)
    }
}
