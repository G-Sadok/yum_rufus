import Core
import Foundation

//
// RequetesJellyfin
//
// Les chemins de l API de Jellyfin, ses parametres de requete, et la preuve
// d identite qu il attend.
//
// Ils vivent a part pour la meme raison que ceux de Komga et de Kavita : ils
// forment le vocabulaire du serveur et non sa logique, et c est la seule partie
// de la source qui change quand une version renomme un point d entree.
//
// Trois conventions de Jellyfin sont resorbees ici et nulle part ailleurs.
//
// La premiere est le filtre de type, et c est le coeur de cette source. Un
// serveur Jellyfin sert des films, des series, de la musique et des photos par
// le meme point d entree que les livres. Le tableau 4.2 exige de filtrer sur le
// type de media livre : `includeItemTypes` n est donc jamais facultatif ici, et
// aucune liste ne part sans dire ce qu elle veut y trouver.
//
// La deuxieme est la pagination par decalage. Jellyfin ne numerote pas ses
// tranches, il compte les elements sautes. La conversion depuis le numero de
// page du protocole se fait dans `tranche(...)`, une seule fois.
//
// La troisieme est le schema d authentification. Le serveur ne lit pas une cle
// d API dans un entete a lui, il la lit dans un entete `Authorization` d un
// schema nomme `MediaBrowser`, dont les champs sont nommes eux aussi.
//

/// Les chemins de l API de Jellyfin.
enum CheminsJellyfin {
    /// Les bibliotheques du serveur, avec leur type de collection.
    ///
    /// C est le premier filtre sur le type de media : une bibliotheque de films
    /// est ecartee ici, avant qu un seul de ses elements soit demande.
    static let bibliotheques = "Library/MediaFolders"

    /// La liste d elements, filtree par type et paginee par decalage.
    static let elements = "Items"

    /// Le fichier d origine d un element, tel qu il est range sur le serveur.
    static func telechargement(_ identifiant: String) -> String {
        "Items/\(identifiant)/Download"
    }

    /// L image principale d un element, sa couverture pour un livre.
    static func imagePrincipale(_ identifiant: String) -> String {
        "Items/\(identifiant)/Images/Primary"
    }
}

/// Le type d element demande au serveur.
///
/// Une serie est un dossier, un chapitre est un livre. Les deux valeurs sont
/// celles de l enumeration `BaseItemKind` du serveur, et elles sont nommees ici
/// plutot que recopiees a l appel pour qu une liste ne puisse pas partir sans
/// filtre par oubli.
enum TypeDElementJellyfin: String, Sendable, Hashable {
    /// Un dossier, ce qu est une serie dans une bibliotheque de livres.
    case dossier = "Folder"

    /// Un livre, ce qu est un chapitre.
    case livre = "Book"
}

/// Le tri demande a la liste d elements.
///
/// Les champs sont ceux de l enumeration `ItemSortBy` du serveur.
struct TriDeJellyfin: Sendable, Hashable {
    let champ: String
    let ordre: String

    /// Tri sur le titre de classement, celui du catalogue complet.
    static let parTitre = TriDeJellyfin(champ: "SortName", ordre: "Ascending")

    /// Tri sur l arrivee de la serie dans la bibliotheque.
    ///
    /// C est la seule date que Jellyfin tienne pour un dossier. Elle repond a la
    /// moitie de ce que la section 4.1 appelle recentes, les series recemment
    /// ajoutees, et pas a l autre, les series mises a jour : le serveur ne
    /// remonte pas la date d un livre neuf jusqu au dossier qui le contient.
    static let parAjout = TriDeJellyfin(champ: "DateCreated", ordre: "Descending")

    /// Le tri qui correspond a la section demandee, ou nul quand la source ne
    /// sait pas la servir.
    init?(_ section: SectionCatalogue) {
        switch section {
        case .tout:
            self = .parTitre
        case .recentes:
            self = .parAjout
        case .populaires:
            // Jellyfin compte les lectures d un film, pas celles d un livre :
            // une bibliotheque de livres rendrait un classement ou tout vaut
            // zero. Le servir sous le nom de populaires serait un classement
            // invente.
            return nil
        }
    }

    private init(champ: String, ordre: String) {
        self.champ = champ
        self.ordre = ordre
    }
}

/// Les parametres de requete de l API de Jellyfin.
/// Ou chercher des elements, et lesquels y prendre.
struct PorteeJellyfin: Sendable, Hashable {
    /// Identifiant du dossier ou de la bibliotheque interrogee.
    let parent: String

    /// Nature des elements demandes.
    let type: TypeDElementJellyfin

    /// Vrai pour descendre dans les sous dossiers.
    ///
    /// Faux pour la liste des series, qui ne prend que les dossiers de premier
    /// rang. Vrai pour celle des chapitres, une serie rangee par tomes ayant un
    /// etage de plus.
    let recursif: Bool

    /// Les dossiers de premier rang d une bibliotheque, ses series.
    static func series(de bibliotheque: String) -> PorteeJellyfin {
        PorteeJellyfin(parent: bibliotheque, type: .dossier, recursif: false)
    }

    /// Tous les livres sous une serie, quel que soit leur etage.
    static func livres(de serie: String) -> PorteeJellyfin {
        PorteeJellyfin(parent: serie, type: .livre, recursif: true)
    }
}

/// Fenetre demandee dans une liste paginee.
struct PaginationJellyfin: Sendable, Hashable {
    /// Nombre d elements a sauter.
    let depart: Int

    /// Nombre d elements demandes.
    ///
    /// Ramene a un au minimum au moment de la requete, un `limit` a zero valant
    /// chez Jellyfin une absence de limite.
    let taille: Int
}

enum ParametresJellyfin {
    /// Les champs demandes en plus de ceux que le serveur rend toujours.
    ///
    /// `Path` sert a deduire le format d un conteneur quand le serveur ne le
    /// nomme pas, `Overview` et `Genres` remplissent la fiche, `ChildCount`
    /// evite de compter les chapitres pour afficher leur nombre.
    static let champs = "Overview,Genres,DateCreated,PremiereDate,Path,ChildCount"

    /// Une tranche de la liste d elements.
    ///
    /// - Parameters:
    ///   - portee: ou chercher et quoi y prendre.
    ///   - tri: champ et sens de classement demandes au serveur.
    ///   - pagination: fenetre demandee dans la liste.
    ///   - recherche: terme filtre par le serveur, nul pour la liste entiere.
    static func tranche(
        portee: PorteeJellyfin,
        tri: TriDeJellyfin,
        pagination: PaginationJellyfin,
        recherche: String? = nil
    ) -> [URLQueryItem] {
        var parametres = [
            URLQueryItem(name: "parentId", value: portee.parent),
            URLQueryItem(name: "includeItemTypes", value: portee.type.rawValue),
            URLQueryItem(name: "recursive", value: portee.recursif ? "true" : "false"),
            URLQueryItem(name: "sortBy", value: tri.champ),
            URLQueryItem(name: "sortOrder", value: tri.ordre),
            URLQueryItem(name: "startIndex", value: String(max(0, pagination.depart))),
            URLQueryItem(name: "limit", value: String(max(1, pagination.taille))),
            URLQueryItem(name: "fields", value: champs),
        ]

        if let recherche {
            parametres.append(URLQueryItem(name: "searchTerm", value: recherche))
        }

        return parametres
    }

    /// Un element unique, designe par son identifiant.
    ///
    /// La fiche passe par la liste filtree sur un identifiant plutot que par le
    /// point d entree d un element seul : ce dernier a change de chemin entre
    /// deux versions majeures du serveur, la liste non, et les deux rendent la
    /// meme enveloppe.
    static func element(_ identifiant: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "ids", value: identifiant),
            URLQueryItem(name: "recursive", value: "true"),
            URLQueryItem(name: "fields", value: champs),
        ]
    }

    /// L etiquette de version d une image, quand le serveur en publie une.
    ///
    /// Elle change quand la couverture change, ce qui suffit a sortir l ancienne
    /// du cache d images sans avoir a le vider.
    static func image(etiquette: String?) -> [URLQueryItem] {
        guard let etiquette else {
            return []
        }

        return [URLQueryItem(name: "tag", value: etiquette)]
    }
}

/// La preuve d identite que Jellyfin attend, construite depuis une cle d API.
///
/// Le serveur lit sa preuve dans un entete `Authorization` d un schema qui lui
/// est propre, ou chaque champ est nomme. Le client se nomme parce que le
/// serveur l affiche dans sa liste des sessions : une ligne anonyme dans le
/// journal du serveur de l utilisateur n aide personne a reconnaitre ce qui
/// s est connecte.
enum IdentiteJellyfin {
    /// L entete d identite d une source, pour la cle d API donnee.
    static func authentification(cleDApi: String, appareil: SourceID) -> AuthentificationHttp {
        let champs = [
            "Client=\"\(nomDuClient)\"",
            "Device=\"\(nomDuClient)\"",
            // L identifiant d appareil est celui de la source configuree. Deux
            // serveurs Jellyfin ajoutes par le meme utilisateur apparaissent
            // ainsi comme deux sessions distinctes, et non comme une seule qui
            // se deplacerait.
            "DeviceId=\"\(appareil.brut.uuidString)\"",
            "Version=\"\(versionDuClient)\"",
            "Token=\"\(cleDApi)\"",
        ]

        return .entete(nom: "Authorization", valeur: "MediaBrowser " + champs.joined(separator: ", "))
    }

    /// Nom sous lequel le client se presente aux sessions du serveur.
    private static let nomDuClient = "Tsuzuki"

    /// Version annoncee au serveur.
    ///
    /// Elle est fixe et non lue du paquet : Jellyfin ne s en sert que pour
    /// l afficher, et la faire suivre la version de l application ferait
    /// apparaitre une nouvelle session a chaque mise a jour.
    private static let versionDuClient = "1.0"
}
