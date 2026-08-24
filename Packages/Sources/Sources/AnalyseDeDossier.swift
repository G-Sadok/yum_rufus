import Archive
import Core
import Foundation

//
// AnalyseDeDossier
//
// Ce que l analyse d un dossier local trouve : des series, et dans chaque serie
// des chapitres.
//
// La convention est celle que retiennent les lecteurs de manga qui lisent des
// dossiers, et c est aussi celle que les utilisateurs ont deja sur leur disque.
//
//   racine/
//     Serie A/
//       Chapitre 1.cbz          archive        chapitre
//       Chapitre 2/             images         chapitre
//     Serie B/
//       page01.jpg              images posees  la serie est son seul chapitre
//     Tome unique.cbz           archive        serie a un chapitre
//
// Deux niveaux, pas plus. Une arborescence plus profonde, du genre
// serie/volume/chapitre, n est pas devinable sans se tromper : le meme
// troisieme niveau designe un volume chez l un et une langue chez l autre. Les
// dossiers plus profonds qui portent des images sont donc vus comme des
// chapitres du niveau au dessus, et rien n est invente.
//
// L analyse ne lit aucune archive. Ouvrir chaque CBZ pour compter ses pages
// couterait, sur une bibliotheque de 200000 chapitres, une lecture d index par
// chapitre a chaque analyse. Le nombre de pages est donc connu pour les
// chapitres en dossier, ou il est gratuit, et inconnu pour les archives, ou il
// se paie a l ouverture du chapitre.
//

/// Formats de conteneur reconnus par l analyse.
public enum FormatsDeConteneur {
    /// Extensions que le projet sait deja ouvrir.
    public static let lisibles: Set<String> = DocumentZip.extensions

    /// Extensions reconnues comme chapitres, lisibles ou non.
    ///
    /// Les formats non encore lisibles sont listes quand meme. Les taire ferait
    /// disparaitre les chapitres de la vue sans explication ; les lister donne
    /// a l ouverture un message qui nomme le format et propose une sortie.
    /// CBA et ACE sont volontairement absents, la section 5.2 les exclut.
    public static let connus: Set<String> = lisibles.union([
        "cbr",
        "rar",
        "cb7",
        "7z",
        "cbt",
        "tar",
        "gz",
        "pdf",
        "epub",
    ])
}

/// Forme prise par un chapitre sur le disque.
public enum FormeDeChapitre: Sendable, Hashable {
    /// Un fichier conteneur, avec son extension en minuscules.
    case archive(format: String)

    /// Un dossier d images.
    case dossierDImages
}

/// Chapitre trouve par l analyse.
public struct ChapitreLocal: Sendable, Hashable {
    /// Chemin relatif a la racine de la source, separe par des barres obliques.
    ///
    /// C est l identifiant du chapitre chez cette source. Le chemin relatif est
    /// stable d une analyse a l autre et survit au deplacement du dossier
    /// racine, ce qu un chemin absolu ne ferait pas.
    public let identifiant: String

    /// Nom affiche, extension retiree.
    public let titre: String

    public let numero: Double

    /// Rang dans la serie, a partir de zero.
    public let ordre: Int

    public let forme: FormeDeChapitre

    /// Nombre de pages, connu seulement pour les chapitres en dossier.
    public let nombrePages: Int?

    public let dateModification: Date?

    public init(
        identifiant: String,
        titre: String,
        numero: Double,
        ordre: Int,
        forme: FormeDeChapitre,
        nombrePages: Int? = nil,
        dateModification: Date? = nil
    ) {
        self.identifiant = identifiant
        self.titre = titre
        self.numero = numero
        self.ordre = ordre
        self.forme = forme
        self.nombrePages = nombrePages
        self.dateModification = dateModification
    }
}

/// Serie trouvee par l analyse.
public struct SerieLocale: Sendable, Hashable {
    /// Chemin relatif a la racine de la source.
    public let identifiant: String

    /// Nom affiche, extension retiree quand la serie est une archive isolee.
    public let titre: String

    public let chapitres: [ChapitreLocal]

    /// Date de modification la plus recente de la serie ou de ses chapitres.
    public let dateModification: Date?

    public init(
        identifiant: String,
        titre: String,
        chapitres: [ChapitreLocal],
        dateModification: Date? = nil
    ) {
        self.identifiant = identifiant
        self.titre = titre
        self.chapitres = chapitres
        self.dateModification = dateModification
    }
}

/// Resultat complet de l analyse d un dossier.
public struct AnalyseDeDossier: Sendable {
    /// Series triees selon l ordre naturel de leur titre.
    public let series: [SerieLocale]

    private let parIdentifiant: [String: SerieLocale]

    public init(series: [SerieLocale]) {
        self.series = series
        parIdentifiant = Dictionary(series.map { ($0.identifiant, $0) }, uniquingKeysWith: { premiere, _ in premiere })
    }

    /// Rend la serie portant cet identifiant, ou nul.
    public func serie(_ identifiant: String) -> SerieLocale? {
        parIdentifiant[identifiant]
    }

    /// Rend le chapitre portant cet identifiant, avec sa serie.
    ///
    /// Le chapitre est cherche par son chemin relatif, sans supposer que la
    /// serie soit son dossier parent : une serie qui est son propre chapitre
    /// porte le meme identifiant que lui.
    public func chapitre(_ identifiant: String) -> (serie: SerieLocale, chapitre: ChapitreLocal)? {
        for serie in series {
            if let chapitre = serie.chapitres.first(where: { $0.identifiant == identifiant }) {
                return (serie, chapitre)
            }
        }

        return nil
    }
}
