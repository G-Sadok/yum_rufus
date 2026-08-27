import Foundation

//
// SignetsDePage
//
// Ce que l ecran Signets a besoin de savoir, et les deux regles que le domaine
// porte : l ordre de la liste et le saut vers la page marquee.
//
// Le saut n est pas une affaire de vue. Un signet designe un chapitre et un
// index de page, exactement ce qu une position de lecture transporte : le rendre
// ici plutot que dans l ecran evite qu une seconde facon de dire ou aller
// apparaisse le jour ou un autre ecran voudra sauter au meme endroit.
//
// L index de page est celui du modele, indexe a partir de zero, et il le reste
// jusqu au moteur. Seul le texte affiche ajoute un a l index, comme la sous
// ligne d une ligne de chapitre le fait deja.
//

/// Un signet tel que la liste de l ecran Signets l affiche.
///
/// La vignette voyage sous forme de nom de fichier, jamais d image : Core ne
/// decode rien, et la vignette se decode a sa taille d affichage comme toutes
/// les images du produit.
public struct SignetAffiche: Sendable, Equatable, Hashable, Identifiable {
    /// Identifiant du signet, cible de la suppression unitaire.
    public let id: UUID

    /// Chapitre marque, ouvert quand la ligne est activee.
    public let chapitreId: UUID

    /// Serie a laquelle le chapitre appartient.
    public let serieId: UUID

    /// Titre de la serie, premiere ligne de l entree.
    public let titreDeLaSerie: String

    /// Numero du chapitre, seconde ligne de l entree.
    public let numeroDeChapitre: Double

    /// Titre du chapitre, absent chez beaucoup de sources.
    public let titreDuChapitre: String?

    /// Page marquee, indexee a partir de zero.
    public let pageIndex: Int

    /// Nombre de pages du chapitre, zero tant que la source ne l annonce pas.
    public let nombreDePages: Int

    /// Note libre laissee par l utilisateur, absente le plus souvent.
    public let note: String?

    /// Instant de la pose du signet.
    public let dateCreation: Date

    /// Nom du fichier de vignette, relatif au dossier des vignettes.
    ///
    /// Un nom et non un chemin absolu : le dossier de l application change
    /// d emplacement a chaque reinstallation sur iOS, et un chemin absolu
    /// enregistre aujourd hui designerait demain un fichier qui n existe plus.
    public let vignetteLocale: String?

    public init(
        id: UUID = UUID(),
        chapitreId: UUID,
        serieId: UUID,
        titreDeLaSerie: String,
        numeroDeChapitre: Double,
        titreDuChapitre: String? = nil,
        pageIndex: Int,
        nombreDePages: Int = 0,
        note: String? = nil,
        dateCreation: Date,
        vignetteLocale: String? = nil
    ) {
        self.id = id
        self.chapitreId = chapitreId
        self.serieId = serieId
        self.titreDeLaSerie = titreDeLaSerie
        self.numeroDeChapitre = numeroDeChapitre
        self.titreDuChapitre = titreDuChapitre
        self.pageIndex = pageIndex
        self.nombreDePages = nombreDePages
        self.note = note
        self.dateCreation = dateCreation
        self.vignetteLocale = vignetteLocale
    }

    /// Position de lecture que le saut depuis l ecran des signets doit ouvrir.
    ///
    /// La position est ramenee dans les bornes du chapitre : un signet pose sur
    /// une page qui a disparu depuis, parce que la source a remplace le fichier
    /// par une version plus courte, ouvre la derniere page existante au lieu
    /// d un index vide. Le decalage de defilement vaut zero, un signet designe
    /// une page entiere et non un point dans cette page.
    public var position: PositionDeLecture {
        PositionDeLecture(chapitreId: chapitreId, pageIndex: pageIndex)
            .normalisee(nombreDePages: nombreDePages)
    }
}

// MARK: Erreurs

/// Erreurs que la gestion des signets peut remonter jusqu a l interface.
///
/// Chaque cas nomme la cause. La traduction en message utilisateur se fait dans
/// la couche vue, avec le catalogue de chaines.
public enum ErreurDeSignet: Error, Sendable, Equatable {
    /// Le signet vise n existe pas ou plus.
    case signetInconnu(identifiant: UUID)

    /// Le chapitre vise n existe pas ou plus.
    case chapitreInconnu(identifiant: UUID)

    /// L index de page demande est negatif.
    case pageInvalide(index: Int)
}

// MARK: Ordre et note

/// Ordre de la liste des signets, et nettoyage de la note.
public enum OrdreDesSignets {
    /// Signets dans l ordre de la liste.
    ///
    /// La liste se range par serie, puis par chapitre, puis par page, et non par
    /// date de pose. Un ecran de signets sert a retrouver un passage : classer
    /// par date disperserait les pages d un meme chapitre entre des series sans
    /// rapport, alors que l ordre de lecture les garde ensemble.
    ///
    /// L identifiant departe deux signets par ailleurs egaux, ce qui rend
    /// l ordre total : deux lectures de la meme base rendent toujours la meme
    /// liste.
    public static func trier(_ signets: [SignetAffiche]) -> [SignetAffiche] {
        signets.sorted { premier, second in
            switch TriNaturel.comparer(premier.titreDeLaSerie, second.titreDeLaSerie) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: break
            }

            if premier.numeroDeChapitre != second.numeroDeChapitre {
                return premier.numeroDeChapitre < second.numeroDeChapitre
            }

            if premier.pageIndex != second.pageIndex {
                return premier.pageIndex < second.pageIndex
            }

            return premier.id.uuidString < second.id.uuidString
        }
    }

    /// Signets persistes dans un ordre stable, chapitre puis page.
    ///
    /// Employe par la sauvegarde, qui ne connait ni le titre de la serie ni le
    /// numero du chapitre. Deux exports d une base inchangee produisent ainsi le
    /// meme fichier.
    public static func trierBruts(_ signets: [Signet]) -> [Signet] {
        signets.sorted { premier, second in
            if premier.chapitreId != second.chapitreId {
                return premier.chapitreId.uuidString < second.chapitreId.uuidString
            }

            if premier.pageIndex != second.pageIndex {
                return premier.pageIndex < second.pageIndex
            }

            return premier.id.uuidString < second.id.uuidString
        }
    }

    /// Note debarrassee de ses espaces de bordure.
    ///
    /// Une note vide vaut aucune note. Enregistrer une chaine vide ferait
    /// afficher une seconde ligne haute de rien sous le titre du chapitre, et la
    /// ligne dirait qu une note existe la ou il n y en a pas.
    public static func noteNettoyee(_ note: String?) -> String? {
        guard let nettoyee = note?.trimmingCharacters(in: .whitespacesAndNewlines),
              nettoyee.isEmpty == false
        else {
            return nil
        }

        return nettoyee
    }

    /// Verifie qu un index de page peut porter un signet.
    ///
    /// - Throws: `ErreurDeSignet.pageInvalide` quand l index est negatif.
    public static func verifierLaPage(_ index: Int) throws {
        guard index >= 0 else {
            throw ErreurDeSignet.pageInvalide(index: index)
        }
    }
}
