//
// ContexteDePresentation
//
// Le seul endroit du projet ou les deux directions se cotoient, et ou il est
// ecrit noir sur blanc qu elles ne se deduisent pas l une de l autre.
//

/// Les deux directions dont une vue de lecture a besoin, portees ensemble.
///
/// `sensDeLecture` vient du modele : reglage global, surcharge par serie. Il
/// gouverne l ordre des pages, la direction du geste, le sens du curseur, la
/// fleche clavier, l ordre des moities apres division et l orientation des
/// zones de toucher.
///
/// `directionDInterface` vient de la langue du systeme. Elle gouverne la
/// disposition des barres, des libelles et des reglages, rien d autre.
///
/// Les deux sont independantes. Un manga japonais lu par un lecteur arabe
/// donne une interface de droite a gauche et des pages de droite a gauche, un
/// manhwa lu par ce meme lecteur donne une interface de droite a gauche et des
/// pages de gauche a droite. Aucune des deux valeurs ne se calcule a partir de
/// l autre.
public struct ContexteDePresentation: Sendable, Codable, Hashable {
    /// Sens de lecture resolu pour la serie affichee.
    public let sensDeLecture: SensDeLecture

    /// Direction de disposition de l interface.
    public let directionDInterface: DirectionDInterface

    public init(
        sensDeLecture: SensDeLecture,
        directionDInterface: DirectionDInterface
    ) {
        self.sensDeLecture = sensDeLecture
        self.directionDInterface = directionDInterface
    }

    /// Vrai quand les deux directions divergent.
    ///
    /// Utile aux tests et aux journaux de diagnostic, jamais a une decision de
    /// navigation : c est toujours `sensDeLecture` seul qui tranche.
    public var lesDirectionsDivergent: Bool {
        switch (sensDeLecture, directionDInterface) {
        case (.droiteGauche, .gaucheDroite), (.gaucheDroite, .droiteGauche):
            true
        default:
            false
        }
    }
}
