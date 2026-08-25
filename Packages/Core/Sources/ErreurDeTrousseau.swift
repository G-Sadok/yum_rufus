import Foundation

//
// ErreurDeTrousseau
//
// Ce qui peut mal tourner quand les identifiants d une source sont ranges dans
// le trousseau ou en sont relus.
//
// Comme les autres erreurs du projet, chaque cas nomme la cause et indique la
// sortie, et aucun code d erreur brut du systeme ne remonte jusqu a la vue.
// Le code du systeme est conserve dans le cas correspondant, parce que sans lui
// un refus du trousseau est indiagnosticable, mais il ne s affiche pas.
//

/// Ce qui peut mal tourner du cote du trousseau.
public enum ErreurDeTrousseau: Error, Sendable, Equatable {
    /// Le trousseau a refuse la lecture ou l ecriture, avec son code brut.
    ///
    /// Les deux causes courantes sont un binaire sans droit de trousseau, et un
    /// appareil verrouille qui n a pas encore ete deverrouille une fois depuis
    /// son demarrage.
    case refusParLeSysteme(code: Int32)

    /// La ligne existe mais ses octets ne sont pas ceux que le projet ecrit.
    case donneeIllisible

    /// La forme est connue mais le secret qui devrait l accompagner manque.
    case identifiantsIncomplets(nature: NatureDAuthentification)

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case .refusParLeSysteme:
            "Le trousseau du systeme a refuse l acces aux identifiants de cette source."
                + " Deverrouille l appareil, puis relance la verification de la source."
        case .donneeIllisible:
            "Les identifiants enregistres pour cette source ne sont plus lisibles."
                + " Saisis les a nouveau dans la feuille de configuration."
        case .identifiantsIncomplets:
            "Les identifiants enregistres pour cette source sont incomplets."
                + " Saisis les a nouveau dans la feuille de configuration."
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    ///
    /// Ni le nom de la source, ni le compte, ni le secret n y figurent. Le code
    /// du systeme, lui, y figure : il ne vient pas de la bibliotheque de
    /// l utilisateur et c est la seule chose qui rend un refus diagnosticable.
    public var codeDeJournal: String {
        switch self {
        case let .refusParLeSysteme(code): "trousseau.refus.\(code)"
        case .donneeIllisible: "trousseau.donneeIllisible"
        case let .identifiantsIncomplets(nature): "trousseau.incomplet.\(nature.rawValue)"
        }
    }
}
