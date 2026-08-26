import Foundation

//
// ErreurDeTransfert
//
// Ce qui peut faire refuser un depot pendant une reception Wi-Fi.
//
// Meme regle que pour les autres erreurs du domaine : chaque cas nomme la cause
// et indique la sortie, et le journal ne porte jamais de nom de fichier, qui
// vient de la bibliotheque de l utilisateur.
//
// Le refus par plafond d essais merite son cas separe du refus de code. Les
// deux se ressemblent de l exterieur, mais la sortie n est pas la meme : un
// code faux se corrige en le retapant, une reception verrouillee ne se rouvre
// qu en refermant la feuille et en la rouvrant, avec un code neuf.
//

/// Ce qui peut mal tourner pendant une reception Wi-Fi.
public enum ErreurDeTransfert: Error, Sendable, Equatable {
    /// La feuille est fermee, donc le serveur ne tourne plus.
    case receptionFermee

    /// Le code presente n est pas celui affiche a l ecran.
    case codeRefuse

    /// Trop de codes faux ont ete presentes, la reception est verrouillee.
    case tropDEssais(essais: Int)

    /// Le nom de fichier propose ne peut pas etre pose dans le dossier.
    case nomDeFichierRefuse

    /// Le format recu n est pas un chapitre reconnu.
    case formatNonRecevable(format: String)

    /// Le depot depasse le plafond accepte par requete.
    case depotTropVolumineux(plafondOctets: Int)

    /// La requete n est pas un depot de fichier lisible.
    case requeteMalformee

    /// L ecriture dans le dossier de la source a echoue.
    case ecritureImpossible

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case .receptionFermee:
            "La reception est terminee."
                + " Rouvre le transfert Wi-Fi sur l appareil pour en demarrer une autre."
        case .codeRefuse:
            "Ce code ne correspond pas a celui affiche sur l appareil."
                + " Verifie les six chiffres, puis reessaie."
        case let .tropDEssais(essais):
            "La reception a ete verrouillee apres \(essais) codes refuses."
                + " Referme puis rouvre le transfert Wi-Fi sur l appareil pour obtenir un code neuf."
        case .nomDeFichierRefuse:
            "Ce nom de fichier ne peut pas etre range dans la bibliotheque."
                + " Renomme le fichier, puis depose le a nouveau."
        case let .formatNonRecevable(format):
            "Le format \(format) n est pas un chapitre reconnu."
                + " Depose une archive CBZ, CBR, CB7, CBT, un PDF, un EPUB ou des images."
        case let .depotTropVolumineux(plafond):
            "Ce depot depasse la taille acceptee en une fois, \(plafond / (1024 * 1024)) Mo."
                + " Depose les fichiers par lots plus petits."
        case .requeteMalformee:
            "Le navigateur n a pas envoye de fichier lisible."
                + " Recharge la page, puis choisis a nouveau les fichiers."
        case .ecritureImpossible:
            "L application n a pas pu ecrire dans le dossier de la source."
                + " Verifie que le dossier existe toujours et qu il est accessible en ecriture."
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    public var codeDeJournal: String {
        switch self {
        case .receptionFermee: "transfert.receptionFermee"
        case .codeRefuse: "transfert.codeRefuse"
        case .tropDEssais: "transfert.tropDEssais"
        case .nomDeFichierRefuse: "transfert.nomDeFichierRefuse"
        case .formatNonRecevable: "transfert.formatNonRecevable"
        case .depotTropVolumineux: "transfert.depotTropVolumineux"
        case .requeteMalformee: "transfert.requeteMalformee"
        case .ecritureImpossible: "transfert.ecritureImpossible"
        }
    }
}
