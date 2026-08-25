import Foundation

//
// ErreurDeSource
//
// Erreurs du systeme de sources. Comme pour `ErreurDeDocument`, chaque cas
// nomme la cause et indique la sortie, et aucune erreur opaque du systeme ne
// remonte jusqu a la vue.
//
// Une source qui echoue ne fait jamais tomber les autres : ces erreurs sont
// portees par la source qui les leve et se traitent source par source.
//

/// Ce qui peut mal tourner quand une source est interrogee.
public enum ErreurDeSource: Error, Sendable, Equatable {
    /// La fonction demandee correspond a une capacite que la source ne declare
    /// pas. C est un defaut d appelant, pas une panne.
    case capaciteIndisponible(capacite: SourceCapacites, source: String)

    /// La source ne sert pas cette section de catalogue.
    case sectionNonPriseEnCharge(section: SectionCatalogue, source: String)

    /// Le dossier ou le serveur ne repond pas, ou l acces a ete revoque.
    case sourceInjoignable(source: String)

    /// Le signet de securite est absent, illisible, ou ne designe plus rien.
    case accesAuDossierPerdu(source: String)

    /// L identifiant de serie ne designe rien chez cette source.
    case mangaIntrouvable(identifiant: String)

    /// L identifiant de chapitre ne designe rien chez cette source.
    case chapitreIntrouvable(identifiant: String)

    /// Le chapitre existe mais son format n est pas encore lisible.
    case formatNonPrisEnCharge(nom: String, format: String)

    /// La page ne s obtient pas par une requete reseau. Elle vit a l interieur
    /// d un conteneur, et se lit par le protocole `DocumentLocal`.
    case pageNonAdressableParRequete(entree: String)

    /// Le transport a echoue, avec la panne nommee par `ErreurReseau`.
    ///
    /// Le nom de la source est porte ici et non dans `ErreurReseau` : une meme
    /// panne de transport frappe n importe quelle source, et la dupliquer par
    /// source rendrait la traduction impossible a tester une fois pour toutes.
    case reseau(ErreurReseau, source: String)

    /// La lecture du conteneur a echoue, avec la cause nommee par
    /// `ErreurDeDocument`.
    ///
    /// Le cas existe pour que le message precis d une archive cassee survive au
    /// passage par le registre, au lieu d etre reduit a un echec inattendu.
    case document(ErreurDeDocument, source: String)

    /// Echec qu aucun cas ne nomme, ce qui est toujours un defaut a corriger.
    ///
    /// La raison ne porte que le nom du type d erreur, jamais sa description :
    /// celle du systeme contient regulierement un chemin de fichier ou une
    /// adresse de serveur, que la regle de journalisation interdit d ecrire.
    case echecInattendu(source: String, raison: String)

    /// Message destine a l utilisateur, qui nomme la cause et indique la sortie.
    public var messageUtilisateur: String {
        switch self {
        case let .capaciteIndisponible(capacite, source):
            "La source \(source) ne propose pas \(Self.libelle(capacite))."
                + " Cette action ne devrait pas etre offerte pour cette source."
        case let .sectionNonPriseEnCharge(section, source):
            "La source \(source) ne classe pas ses series par \(Self.libelle(section))."
                + " Choisis une autre section."
        case let .sourceInjoignable(source):
            "La source \(source) ne repond pas."
                + " Verifie qu elle est toujours accessible, puis relance la verification."
        case let .accesAuDossierPerdu(source):
            "L acces au dossier de la source \(source) a ete perdu."
                + " Choisis le dossier a nouveau pour redonner l autorisation."
        case let .mangaIntrouvable(identifiant):
            "La serie \(nomCourt(identifiant)) n existe plus dans cette source."
                + " Relance une analyse de la source."
        case let .chapitreIntrouvable(identifiant):
            "Le chapitre \(nomCourt(identifiant)) n existe plus dans cette source."
                + " Relance une analyse de la source."
        case let .formatNonPrisEnCharge(nom, format):
            "Le chapitre \(nomCourt(nom)) est au format \(format), qui n est pas encore lisible."
                + " Convertis le en CBZ en attendant."
        case let .pageNonAdressableParRequete(entree):
            "La page \(nomCourt(entree)) est rangee dans une archive."
                + " Elle se lit par le conteneur, pas par une requete."
        case let .reseau(reseau, source):
            "La source \(source) est en echec. " + reseau.messageUtilisateur
        case let .document(document, source):
            "La source \(source) n a pas pu lire ce fichier. " + document.messageUtilisateur
        case let .echecInattendu(source, _):
            "La source \(source) a echoue pour une raison que l application ne sait pas nommer."
                + " Relance la verification, et signale le probleme si il se repete."
        }
    }

    /// Etat de connexion a retenir pour la source apres cette erreur.
    ///
    /// L ecran Parcourir en tire sa pastille, et la feuille de configuration
    /// s ouvre ou non selon que les identifiants sont en cause.
    public var etatDeConnexion: EtatConnexion {
        switch self {
        case let .reseau(reseau, _):
            reseau.etatDeConnexion
        case .sourceInjoignable, .accesAuDossierPerdu:
            .injoignable
        default:
            .erreur
        }
    }

    /// Identifiant stable pour le journal, sans aucune donnee personnelle.
    ///
    /// Ni le nom de la source, ni l identifiant de serie, ni le nom de fichier
    /// n y figurent : les trois viennent de la bibliotheque de l utilisateur.
    public var codeDeJournal: String {
        switch self {
        case .capaciteIndisponible: "source.capaciteIndisponible"
        case .sectionNonPriseEnCharge: "source.sectionNonPriseEnCharge"
        case .sourceInjoignable: "source.injoignable"
        case .accesAuDossierPerdu: "source.accesAuDossierPerdu"
        case .mangaIntrouvable: "source.mangaIntrouvable"
        case .chapitreIntrouvable: "source.chapitreIntrouvable"
        case .formatNonPrisEnCharge: "source.formatNonPrisEnCharge"
        case .pageNonAdressableParRequete: "source.pageNonAdressableParRequete"
        case let .reseau(reseau, _): "source." + reseau.codeDeJournal
        case .document: "source.document"
        case let .echecInattendu(_, raison): "source.echecInattendu.\(raison)"
        }
    }

    /// Traduit une erreur quelconque levee par une source.
    ///
    /// Point de passage unique du registre. Une erreur deja typee traverse sans
    /// etre deguisee, une erreur de transport devient `reseau`, une erreur de
    /// conteneur devient `document`, et ce qui reste devient `echecInattendu`
    /// avec le seul nom de son type. Rien n est perdu et rien n est invente.
    public static func depuis(_ erreur: any Error, source: String) -> ErreurDeSource {
        if let deja = erreur as? ErreurDeSource {
            return deja
        }
        if let reseau = ErreurReseau.depuis(erreur) {
            return .reseau(reseau, source: source)
        }
        if let document = erreur as? ErreurDeDocument {
            return .document(document, source: source)
        }

        return .echecInattendu(source: source, raison: String(describing: type(of: erreur)))
    }

    /// Nom lisible d une capacite, pour les messages.
    private static func libelle(_ capacite: SourceCapacites) -> String {
        switch capacite {
        case .recherche: "la recherche"
        case .filtres: "les filtres"
        case .pagination: "la pagination"
        case .telechargement: "le telechargement"
        case .progressionDistante: "la progression distante"
        case .plusieursLangues: "le choix de la langue"
        default: "cette fonction"
        }
    }

    /// Nom lisible d une section, pour les messages.
    private static func libelle(_ section: SectionCatalogue) -> String {
        switch section {
        case .tout: "titre"
        case .recentes: "date"
        case .populaires: "popularite"
        }
    }

    /// Rend le dernier composant d un chemin.
    ///
    /// Un message d erreur ne montre jamais l arborescence complete : elle porte
    /// le nom de l utilisateur et celui de ses series.
    private func nomCourt(_ chemin: String) -> String {
        let composants = chemin.split(whereSeparator: { $0 == "/" || $0 == "\\" })

        return composants.last.map(String.init) ?? chemin
    }
}
