import Foundation

//
// ErreurDeDocument
//
// Erreurs de la lecture d un conteneur de pages. Elles sont typees et fermees :
// une archive cassee produit un cas nomme, jamais un plantage ni un NSError
// opaque remonte jusqu a la vue.
//

/// Ce qui peut mal tourner a l ouverture ou a la lecture d un document local.
///
/// Chaque cas nomme la cause et indique la sortie, comme l exige la regle de
/// gestion d erreur du projet. Le texte de `messageUtilisateur` sera repris par
/// le catalogue de chaines quand la localisation arrivera ; il vit ici en
/// attendant, parce qu une erreur sans message lisible finit toujours par etre
/// affichee telle quelle.
public enum ErreurDeDocument: Error, Sendable, Equatable {
    /// Le fichier annonce n existe pas ou n est plus accessible.
    case fichierIntrouvable(chemin: String)

    /// Le fichier existe mais n est pas un conteneur reconnu : signature
    /// absente, index central introuvable, ou fichier vide.
    case conteneurIllisible(chemin: String)

    /// Le conteneur est reconnu mais s arrete avant ce que son index annonce.
    /// C est la signature d un telechargement interrompu ou d une copie
    /// partielle.
    case conteneurTronque(chemin: String)

    /// Le conteneur ne porte aucune page affichable.
    case aucunePage(chemin: String)

    /// La position demandee sort du document.
    case indexHorsBornes(demande: Int, nombrePages: Int)

    /// L entree demandee n appartient pas a ce document.
    case entreeIntrouvable(nom: String)

    /// L entree existe mais son contenu ne correspond pas a ce que l index
    /// annonce : somme de controle fausse, taille inattendue, flux invalide.
    case entreeCorrompue(nom: String)

    /// L entree est compressee avec une methode que le lecteur ne connait pas.
    case compressionNonPriseEnCharge(nom: String, methode: Int)

    /// Le conteneur est protege par un mot de passe.
    case conteneurChiffre(chemin: String)

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case let .fichierIntrouvable(chemin):
            "Le fichier \(nomCourt(chemin)) est introuvable."
                + " Verifie qu il n a pas ete deplace ou supprime."
        case let .conteneurIllisible(chemin):
            "Le fichier \(nomCourt(chemin)) n est pas une archive lisible."
                + " Ouvre le dans un autre outil pour verifier son format."
        case let .conteneurTronque(chemin):
            "Le fichier \(nomCourt(chemin)) est incomplet."
                + " Recopie le depuis sa source d origine."
        case let .aucunePage(chemin):
            "Le fichier \(nomCourt(chemin)) ne contient aucune image."
                + " Verifie que c est bien un chapitre."
        case let .indexHorsBornes(demande, nombrePages):
            "La page \(demande + 1) n existe pas, ce chapitre en compte \(nombrePages)."
                + " Reviens au sommaire du chapitre."
        case let .entreeIntrouvable(nom):
            "La page \(nomCourt(nom)) ne fait pas partie de ce chapitre."
                + " Rouvre le chapitre."
        case let .entreeCorrompue(nom):
            "La page \(nomCourt(nom)) est endommagee."
                + " Les autres pages du chapitre restent lisibles."
        case let .compressionNonPriseEnCharge(nom, methode):
            "La page \(nomCourt(nom)) utilise une compression inconnue, code \(methode)."
                + " Reencode l archive en ZIP standard."
        case let .conteneurChiffre(chemin):
            "Le fichier \(nomCourt(chemin)) est protege par un mot de passe."
                + " Retire la protection avant de le lire."
        }
    }

    /// Rend le dernier composant d un chemin.
    ///
    /// Un message d erreur ne montre jamais l arborescence complete : elle porte
    /// le nom de l utilisateur et celui de ses series, et n aide en rien a
    /// comprendre le probleme.
    private func nomCourt(_ chemin: String) -> String {
        let composants = chemin.split(whereSeparator: { $0 == "/" || $0 == "\\" })

        return composants.last.map(String.init) ?? chemin
    }
}
