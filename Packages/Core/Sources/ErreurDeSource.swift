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
        }
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
