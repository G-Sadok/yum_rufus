import Foundation

//
// FournisseurDeChapitre
//
// D ou viennent les octets d une page pendant la lecture.
//
// Le moteur de lecture ne sait pas ouvrir une archive ni interroger un serveur,
// et il n a pas a l apprendre. Il demande les octets d une page a ce
// fournisseur, qu une archive locale, un catalogue distant ou un jeu de test
// implementent chacun a leur maniere. Sans cette frontiere, la precharge serait
// intestable, puisque la tester reviendrait a fabriquer une archive complete
// pour chaque scenario d annulation.
//

/// Octets bruts d une page, tels que la source les porte.
public struct DonneesDePage: Sendable {
    /// Nom de l entree, repris dans les erreurs de decodage.
    public let nom: String

    /// Octets de la page, dans le format du fichier.
    public let donnees: Data

    public init(nom: String, donnees: Data) {
        self.nom = nom
        self.donnees = donnees
    }
}

/// Source des octets d un chapitre ouvert.
public protocol FournisseurDeChapitre: Sendable {
    /// Chapitre ouvert, tel qu il est identifie dans le catalogue.
    var chapitre: UUID { get }

    /// Nombre de pages du chapitre.
    var nombreDePages: Int { get }

    /// Octets bruts d une page.
    ///
    /// - Parameter index: position de la page, indexee a partir de zero.
    /// - Throws: l erreur de la source quand la page est illisible.
    func octets(page index: Int) async throws -> DonneesDePage
}
