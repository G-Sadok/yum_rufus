import Core

//
// ErreurDeTraduction
//
// Les echecs possibles de la traduction des bulles.
//
// Un domaine separe de `ErreurDeTraitementIA`, alors que les deux se ressemblent
// et que le projet a par ailleurs choisi de n avoir qu un seul domaine pour la
// surelevation, la colorisation et la detection de cases. La difference est
// reelle et vaut le fichier de plus : les trois autres traitements echouent tous
// autour d un fichier de modele installe sur l appareil, la traduction echoue en
// plus autour d un reseau absent et d un accord non donne. Ranger un
// consentement manquant parmi les erreurs de modele obligerait a repondre a
// l utilisateur avec un message qui parle de modele la ou il faut parler
// d autorisation.
//
// Chaque cas nomme la cause et indique la sortie, comme l impose la regle
// d erreur du projet. La sortie nomme toujours un reglage qui existe, jamais une
// manipulation que l interface ne propose pas.
//

/// Echec de la traduction des bulles d une planche.
public enum ErreurDeTraduction: Error, Sendable, Equatable {
    /// Aucun moteur n est installe pour le choix demande.
    case moteurIndisponible(moteur: ChoixDeMoteurDeTraduction)

    /// Le moteur distant a ete demande alors que le reseau ne repond pas.
    case reseauIndisponible

    /// La detection ou le moteur a refuse la planche.
    case moteurEnEchec(identifiant: String)

    /// La planche ne peut pas etre lue comme une matrice de pixels.
    case plancheIllisible

    /// La planche depasse le plafond memoire du traitement.
    case plancheTropLourde(octets: Int, plafond: Int)

    /// Le moteur n a pas rendu autant de textes qu il en a recus.
    case reponseIncoherente(attendus: Int, recus: Int)

    /// Message destine a l utilisateur.
    ///
    /// Le nom de la fonction est celui de la ligne de reglages qui l arme,
    /// `Traduire les bulles`, pour que la sortie designe un interrupteur que
    /// l utilisateur peut reellement trouver.
    public var messageUtilisateur: String {
        switch self {
        case .moteurIndisponible:
            "Le moteur de traduction n est pas installe. Choisissez un autre moteur de traduction dans les reglages."
        case .reseauIndisponible:
            "Le moteur dans le nuage a besoin d une connexion. Passez au moteur sur l appareil pour lire."
        case .moteurEnEchec:
            "La traduction a echoue sur cette page. La page reste lisible telle quelle."
        case .plancheIllisible, .reponseIncoherente:
            "Cette page n a pas pu etre traduite. Elle reste lisible telle quelle."
        case .plancheTropLourde:
            "Cette page est trop grande pour la traduction sur cet appareil."
        }
    }
}
