import Core
import Foundation

//
// NettoyageDesTelechargementsLus
//
// Le passage qui applique la ligne Supprimer apres lecture de la section 9 des
// reglages, et le second critere de la fonctionnalite.
//
// Il ne decide rien. La decision appartient a `SuppressionAutomatiqueDesTelechargements`,
// qui est une fonction pure et se teste comme telle. Ce type fait le tour : il
// demande au disque ce qui est pose, a la base ce qui est lu, applique la
// decision, efface, puis oublie les taches devenues sans objet.
//
// L ordre compte. Le dossier part avant que la tache ne soit oubliee : une
// coupure entre les deux laisse une ligne `Termine` sur un chapitre absent, ce
// que le passage suivant corrigera, la ou l ordre inverse laisserait un dossier
// que plus rien ne designe et que plus rien ne nettoiera.
//
// Le nettoyage ne demande aucune confirmation, et c est voulu. La confirmation a
// ete donnee une fois, en sortant la ligne Supprimer apres lecture de sa valeur
// `Jamais` : redemander a chaque chapitre ferait d un reglage automatique une
// interruption permanente. Il ne touche par ailleurs que des chapitres lus et
// telecharges, que leur source sait toujours rendre, comme la description de la
// section 6.8 l annonce.
//

/// Applique la suppression automatique des telechargements lus.
public struct NettoyageDesTelechargementsLus: Sendable {
    private let inspecteur: InspecteurDeStockageSurDisque
    private let journal: any JournalDuStockage

    /// Construit le nettoyage.
    ///
    /// - Parameters:
    ///   - inspecteur: acces au disque des chapitres telecharges.
    ///   - journal: acces a la bibliotheque, pour l etat de lecture et la file.
    public init(inspecteur: InspecteurDeStockageSurDisque, journal: any JournalDuStockage) {
        self.inspecteur = inspecteur
        self.journal = journal
    }

    /// Supprime ce que le reglage autorise a supprimer a cet instant.
    ///
    /// - Parameters:
    ///   - reglage: valeur de la ligne Supprimer apres lecture.
    ///   - maintenant: instant de reference, injecte pour que la suite de tests
    ///     porte sur des delais choisis.
    /// - Returns: les chapitres dont le telechargement a reellement ete efface.
    @discardableResult
    public func executer(
        reglage: SuppressionApresLecture,
        maintenant: Date = Date()
    ) async throws -> [UUID] {
        guard reglage.supprimeLesTelechargementsLus else {
            return []
        }

        let poses = inspecteur.chapitresPoses()

        guard poses.isEmpty == false else {
            return []
        }

        let lus = try await journal.chapitresLus(parmi: poses)
        let vises = SuppressionAutomatiqueDesTelechargements.chapitresASupprimer(
            parmi: lus,
            reglage: reglage,
            maintenant: maintenant
        )

        guard vises.isEmpty == false else {
            return []
        }

        // `filter` et non une boucle : la suppression peut lever, et une clause
        // `where` n accepte pas `try`. Le filtre garde les chapitres dont le
        // dossier existait vraiment, ceux que la file doit oublier.
        let effaces = try vises.filter { try inspecteur.supprimerLeChapitre($0) }

        guard effaces.isEmpty == false else {
            return []
        }

        try await journal.oublierLesTelechargements(de: effaces)

        return effaces
    }
}
