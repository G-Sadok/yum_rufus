import Foundation

//
// ErreurDExtension
//
// Ce qui peut faire refuser une extension, de la lecture de son manifeste
// jusqu au blocage d une de ses requetes.
//
// Le type est ferme et chaque cas nomme un refus precis. C est volontaire : la
// section 4.3 pose quatre garanties de securite, et un refus qui ne se
// distingue pas des autres ne se teste pas, ne se journalise pas, et finit par
// etre traite comme un incident reseau quelconque.
//
// Comme `ErreurReseau`, aucun cas ne porte de donnee personnelle. Le seul
// domaine nomme est celui qu une extension a declare ou tente de joindre, pour
// la raison deja ecrite dans `ErreurReseau.domaineNonAutorise` : c est
// exactement ce que l utilisateur doit voir avant de decider.
//

/// Ce qui peut mal tourner avec une extension declarative.
public enum ErreurDExtension: Error, Sendable, Equatable, Hashable {
    // MARK: Lecture du manifeste

    /// Les octets fournis ne decrivent pas un document JSON.
    case manifesteIllisible

    /// Le manifeste porte une cle que le langage declaratif ne connait pas.
    ///
    /// C est le refus qui tient le premier critere de la section 4.3. Une cle
    /// inconnue n est pas ignoree en silence : elle fait rejeter le paquet
    /// entier. Ignorer, ce serait accepter un manifeste dont une partie du
    /// contenu n a jamais ete relue par personne.
    case cleInconnue(nom: String)

    /// Le manifeste annonce une version de format que cet interprete ne sait
    /// pas appliquer.
    case formatNonPrisEnCharge(annoncee: Int, appliquee: Int)

    /// Un champ obligatoire manque, ou porte une valeur vide.
    case champManquant(nom: String)

    /// Un selecteur ou un chemin d extraction ne s analyse pas.
    case extractionMalFormee(texte: String)

    /// Un gabarit d adresse cite une variable qui n existe pas.
    case variableInconnue(nom: String)

    // MARK: Signature

    /// Le paquet ne porte aucune signature.
    case signatureAbsente

    /// La signature ne correspond pas au manifeste qu elle accompagne.
    case signatureInvalide

    /// La signature est bien formee mais aucune cle de publication connue ne
    /// la valide.
    ///
    /// Le cas est distinct du precedent parce que la sortie differe : une
    /// signature invalide veut dire paquet modifie, une cle inconnue veut dire
    /// paquet publie par quelqu un d autre.
    case cleDePublicationInconnue

    // MARK: Domaines

    /// Le manifeste ne declare aucun domaine.
    ///
    /// Une liste blanche vide n autorise rien, donc une extension sans domaine
    /// ne peut rien faire. Le refus est immediat plutot que differe jusqu a la
    /// premiere requete bloquee.
    case aucunDomaineDeclare

    /// Un domaine declare n est pas un nom d hote utilisable.
    case domaineMalForme(domaine: String)

    /// L utilisateur n a pas confirme la liste des domaines.
    case domainesNonConfirmes

    /// La confirmation ne porte pas sur la liste que le manifeste declare.
    ///
    /// C est le refus qui tient le troisieme critere. Une confirmation obtenue
    /// pour trois domaines ne vaut pas pour un paquet qui en declare quatre,
    /// sans quoi il suffirait de modifier le manifeste entre l affichage et
    /// l installation.
    case confirmationNeCorrespondPas

    // MARK: Execution

    /// L extension ne declare pas de regle pour ce que l appelant demande.
    case regleAbsente(capacite: SourceCapacites)

    /// La reponse du serveur ne contient pas ce que les regles y cherchaient.
    case extractionSansResultat(champ: String)

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case .manifesteIllisible:
            "Le manifeste de cette extension n est pas un document lisible."
                + " Recupere le paquet a nouveau depuis son depot."
        case let .cleInconnue(nom):
            "Le manifeste contient une entree \(nom) que l application ne sait pas interpreter."
                + " L extension a ete refusee. Elle vise sans doute une version plus recente."
        case let .formatNonPrisEnCharge(annoncee, appliquee):
            "Cette extension est ecrite pour la version \(annoncee) du format,"
                + " et l application applique la version \(appliquee). Mets l application a jour."
        case let .champManquant(nom):
            "Le manifeste de cette extension ne renseigne pas \(nom)."
                + " Signale le probleme a l auteur du depot."
        case let .extractionMalFormee(texte):
            "Une regle de lecture de cette extension, \(texte), ne s analyse pas."
                + " Signale le probleme a l auteur du depot."
        case let .variableInconnue(nom):
            "Une adresse de cette extension cite une variable \(nom) qui n existe pas."
                + " Signale le probleme a l auteur du depot."
        case .signatureAbsente:
            "Ce paquet d extension n est pas signe."
                + " L application n installe que des extensions signees."
        case .signatureInvalide:
            "La signature de ce paquet ne correspond pas a son contenu."
                + " Le paquet a ete modifie depuis sa publication, ne l installe pas."
        case .cleDePublicationInconnue:
            "Ce paquet est signe par une cle que l application ne connait pas."
                + " Installe l extension depuis un depot de confiance."
        case .aucunDomaineDeclare:
            "Cette extension ne declare aucun domaine, elle ne pourrait donc rien consulter."
                + " Signale le probleme a l auteur du depot."
        case let .domaineMalForme(domaine):
            "Le domaine \(domaine) declare par cette extension n est pas un nom de serveur valable."
                + " Signale le probleme a l auteur du depot."
        case .domainesNonConfirmes:
            "L installation demande de confirmer la liste des domaines que l extension va joindre."
                + " Ouvre la fiche de l extension et relis la liste."
        case .confirmationNeCorrespondPas:
            "La liste des domaines a change depuis que tu l as lue."
                + " Relis la nouvelle liste avant de confirmer l installation."
        case let .regleAbsente(capacite):
            "Cette extension n annonce pas de regle pour \(Self.libelle(capacite))."
                + " Cette action ne devrait pas etre offerte pour cette source."
        case let .extractionSansResultat(champ):
            "La reponse du serveur ne contient pas le champ \(champ) que l extension y cherche."
                + " L extension est sans doute perimee, verifie son depot."
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    ///
    /// Ni le nom du domaine ni le texte d une regle n y figurent : le premier
    /// designe le serveur que l utilisateur consulte, le second peut porter un
    /// titre de serie dans un gabarit. Le journal compte les refus, il ne les
    /// raconte pas.
    public var codeDeJournal: String {
        switch self {
        case .manifesteIllisible: "extension.manifesteIllisible"
        case .cleInconnue: "extension.cleInconnue"
        case .formatNonPrisEnCharge: "extension.formatNonPrisEnCharge"
        case .champManquant: "extension.champManquant"
        case .extractionMalFormee: "extension.extractionMalFormee"
        case .variableInconnue: "extension.variableInconnue"
        case .signatureAbsente: "extension.signatureAbsente"
        case .signatureInvalide: "extension.signatureInvalide"
        case .cleDePublicationInconnue: "extension.cleDePublicationInconnue"
        case .aucunDomaineDeclare: "extension.aucunDomaineDeclare"
        case .domaineMalForme: "extension.domaineMalForme"
        case .domainesNonConfirmes: "extension.domainesNonConfirmes"
        case .confirmationNeCorrespondPas: "extension.confirmationNeCorrespondPas"
        case .regleAbsente: "extension.regleAbsente"
        case .extractionSansResultat: "extension.extractionSansResultat"
        }
    }

    /// Vrai quand le refus vient d une regle de securite et non d un defaut de
    /// forme.
    ///
    /// L interface s en sert pour distinguer ce qui se corrige en recuperant le
    /// paquet a nouveau de ce qui ne se corrige pas du tout.
    public var estUnRefusDeSecurite: Bool {
        switch self {
        case .cleInconnue, .signatureAbsente, .signatureInvalide, .cleDePublicationInconnue,
             .aucunDomaineDeclare, .domainesNonConfirmes, .confirmationNeCorrespondPas:
            true
        default:
            false
        }
    }

    /// Nom lisible d une capacite, pour le message d une regle absente.
    private static func libelle(_ capacite: SourceCapacites) -> String {
        switch capacite {
        case .recherche: "la recherche"
        case .filtres: "les filtres"
        case .pagination: "la pagination"
        case .telechargement: "le telechargement"
        case .progressionDistante: "la progression distante"
        case .plusieursLangues: "le choix de la langue"
        default: "cette action"
        }
    }
}
