//
// ValeurDeReglage
//
// Valeur portee par une ligne de reglage, et sa forme persistee.
//
// La base range une chaine par reglage. Le type de la valeur n est pas ecrit a
// cote : il vient du catalogue, qui declare la valeur par defaut de chaque
// ligne. Relire une chaine sans son modele n a donc aucun sens, et la lecture
// exige toujours les deux. C est ce qui empeche un booleen mal reecrit de
// revenir en nombre au redemarrage suivant.
//

/// Valeur d une ligne de reglage.
public enum ValeurDeReglage: Sendable, Codable, Equatable, Hashable {
    /// Etat d un interrupteur.
    case booleen(Bool)

    /// Representation persistee d un cas de menu.
    case choix(String)

    /// Entier borne d un compteur.
    case compteur(Int)

    /// Nombre d un curseur.
    case curseur(Double)

    /// Ligne de navigation, ou valeur en lecture seule. Rien n est persiste.
    case aucune

    /// Vrai quand la valeur est ecrite en base.
    public var estPersistee: Bool {
        self != .aucune
    }

    /// Forme persistee de la valeur, nulle quand rien n est a ecrire.
    ///
    /// Les nombres passent par la description de `Double` et de `Int`, qui
    /// ecrivent toujours un point decimal quelle que soit la langue de
    /// l appareil. Un formateur localise ecrirait une virgule en francais, et
    /// la base voyage avec la sauvegarde vers des appareils configures
    /// autrement.
    public var texte: String? {
        switch self {
        case let .booleen(actif): actif ? "true" : "false"
        case let .choix(valeur): valeur
        case let .compteur(valeur): String(valeur)
        case let .curseur(valeur): String(valeur)
        case .aucune: nil
        }
    }

    /// Valeur relue depuis la base, du type impose par le modele.
    ///
    /// - Parameters:
    ///   - texte: chaine lue dans la colonne.
    ///   - modele: valeur par defaut de la ligne, qui donne le type attendu.
    /// - Returns: la valeur relue, ou nulle quand la chaine ne correspond pas
    ///   au type attendu. L appelant retombe alors sur le modele.
    public static func lire(_ texte: String, selon modele: ValeurDeReglage) -> ValeurDeReglage? {
        switch modele {
        case .booleen:
            switch texte {
            case "true": .booleen(true)
            case "false": .booleen(false)
            default: nil
            }

        case .choix:
            texte.isEmpty ? nil : .choix(texte)

        case .compteur:
            Int(texte).map(ValeurDeReglage.compteur)

        case .curseur:
            Double(texte).map(ValeurDeReglage.curseur)

        case .aucune:
            nil
        }
    }
}
