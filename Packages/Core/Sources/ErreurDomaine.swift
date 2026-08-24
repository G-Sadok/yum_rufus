/// Erreur typee produite par un domaine metier.
///
/// Toutes les erreurs du projet adoptent ce protocole. Chacune nomme la cause
/// et indique la sortie, pour qu aucune erreur systeme brute ne remonte jusqu a
/// la couche vue.
public protocol ErreurDomaine: Error, Sendable, CustomStringConvertible {
    /// Domaine qui a produit l erreur, par exemple Archive ou Storage.
    var domaine: String { get }

    /// Ce qui a echoue, formule pour une personne qui n a pas lu le code.
    var cause: String { get }

    /// Ce que la personne peut faire pour s en sortir.
    var sortie: String { get }
}

public extension ErreurDomaine {
    /// Message destine a l affichage, la cause suivie de la sortie.
    var messageUtilisateur: String {
        "\(cause) \(sortie)"
    }

    /// Representation destinee aux journaux, prefixee par le domaine.
    ///
    /// Elle ne contient que ce que l erreur a bien voulu exposer, jamais de
    /// titre de serie ni d adresse de serveur.
    var description: String {
        "[\(domaine)] \(messageUtilisateur)"
    }
}
