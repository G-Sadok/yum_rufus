import Foundation

//
// ErreurDuPont
//
// Ce qui peut faire refuser une requete arrivee sur le pont navigateur.
//
// Meme regle que pour les autres erreurs du domaine : chaque cas nomme la cause
// et indique la sortie. Une regle de plus vaut ici, et elle est stricte.
//
// Aucun cas ne porte l adresse de la machine refusee, ni le jeton presente, ni
// l adresse de la serie envoyee. Le journal du projet ne porte pas de donnee
// personnelle, et sur ce chemin la, tout ce qui arrive en est une : l adresse
// dit d ou lit l utilisateur, l adresse de la serie dit quel catalogue il
// consulte, et le jeton presente est un secret meme quand il est faux.
//
// Le refus d une connexion non locale et le refus d un jeton sont deux cas
// distincts alors que l extension voit deux fois un refus. La sortie n est pas
// la meme : une connexion non locale vient d une machine du reseau et ne se
// corrige pas, un jeton refuse se corrige en recollant celui des reglages.
//

/// Ce qui peut mal tourner sur le pont navigateur.
public enum ErreurDuPont: Error, Sendable, Equatable {
    /// Le pont est desactive, donc rien n ecoute.
    case pontDesactive

    /// La connexion ne vient pas de cet appareil.
    case connexionNonLocale

    /// La requete ne presente aucun jeton, ou le pont n en a pas.
    case jetonAbsent

    /// Le jeton presente n est pas celui du pont.
    case jetonRefuse

    /// La requete n est pas lisible comme requete HTTP.
    case requeteMalformee

    /// Le chemin demande n existe pas sur le pont.
    case cheminInconnu

    /// La methode employee n est pas celle du chemin demande.
    case methodeNonAutorisee

    /// Le corps de la requete n est pas un envoi de serie lisible.
    case envoiIllisible

    /// L adresse de la serie n est pas une adresse que le pont accepte.
    case adresseRefusee

    /// L application n a pas pu prendre l envoi en charge.
    case receptionImpossible

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case .pontDesactive:
            "Le pont navigateur est desactive."
                + " Active le dans les reglages pour envoyer une serie depuis le navigateur."
        case .connexionNonLocale:
            "Le pont n accepte que les connexions venues de cet appareil."
                + " Installe l extension sur cet appareil plutot que sur une autre machine."
        case .jetonAbsent:
            "L extension n a presente aucun jeton."
                + " Copie le jeton depuis les reglages du pont, puis colle le dans l extension."
        case .jetonRefuse:
            "Le jeton presente n est pas celui du pont."
                + " Recopie le jeton affiche dans les reglages, il a pu etre renouvele."
        case .requeteMalformee, .envoiIllisible:
            "L extension n a pas envoye de serie lisible."
                + " Mets l extension a jour, puis renvoie la page."
        case .cheminInconnu, .methodeNonAutorisee:
            "L extension s adresse au pont d une facon qu il ne reconnait pas."
                + " Mets l extension a jour, puis renvoie la page."
        case .adresseRefusee:
            "Cette page ne peut pas etre envoyee au pont."
                + " Le pont n accepte que les adresses en HTTPS."
        case .receptionImpossible:
            "L application n a pas pu prendre cette serie en charge."
                + " Reessaie, puis ouvre la page dans l application si le refus persiste."
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    public var codeDeJournal: String {
        switch self {
        case .pontDesactive: "pont.desactive"
        case .connexionNonLocale: "pont.connexionNonLocale"
        case .jetonAbsent: "pont.jetonAbsent"
        case .jetonRefuse: "pont.jetonRefuse"
        case .requeteMalformee: "pont.requeteMalformee"
        case .cheminInconnu: "pont.cheminInconnu"
        case .methodeNonAutorisee: "pont.methodeNonAutorisee"
        case .envoiIllisible: "pont.envoiIllisible"
        case .adresseRefusee: "pont.adresseRefusee"
        case .receptionImpossible: "pont.receptionImpossible"
        }
    }
}
