//
// DirectionDInterface
//
// Direction de disposition de l interface. Notion distincte du sens de
// lecture, et volontairement rangee dans un type separe.
//

/// Direction dans laquelle l interface se dispose, dictee par la langue
/// affichee par le systeme.
///
/// Cette valeur ne dit rien du sens de lecture d une serie et ne s en deduit
/// jamais. En arabe l interface passe de droite a gauche alors qu un manhwa
/// continue de se lire de gauche a droite, et un manga japonais lu dans une
/// interface francaise se lit toujours de droite a gauche.
///
/// Aucune conversion entre `DirectionDInterface` et `SensDeLecture` n existe,
/// et il ne faut pas en ajouter. C est cette absence qui rend impossible le
/// bogue invisible en francais et systematique en arabe.
public enum DirectionDInterface: String, Sendable, Codable, CaseIterable, Hashable {
    /// Disposition occidentale, la plus courante.
    case gaucheDroite

    /// Disposition de l arabe, de l hebreu ou du persan.
    case droiteGauche

    /// Direction appliquee quand la langue du systeme est inconnue.
    public static let parDefaut: DirectionDInterface = .gaucheDroite

    /// Racines de langue dont l interface se dispose de droite a gauche.
    private static let racinesDeDroiteAGauche: Set<String> = [
        "ar", "ckb", "dv", "fa", "he", "ps", "sd", "ug", "ur", "yi",
    ]

    /// Direction de l interface pour un code de langue au format BCP 47.
    ///
    /// Seule la racine du code est examinee, pour que `ar-EG` reponde comme
    /// `ar`. Un code vide ou inconnu retombe sur `parDefaut`.
    public static func pourLangue(_ codeBCP47: String) -> DirectionDInterface {
        let racine = codeBCP47
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map { String($0).lowercased() }

        guard let racine, racinesDeDroiteAGauche.contains(racine) else {
            return parDefaut
        }

        return .droiteGauche
    }
}
