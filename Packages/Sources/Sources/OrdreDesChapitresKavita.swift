import Core
import Foundation

//
// OrdreDesChapitresKavita
//
// La mise en ordre de lecture des chapitres d une serie Kavita, et les regles de
// numerotation qu elle applique.
//
// Le fichier est separe des reponses parce qu il ne traduit rien : il decide
// d un ordre, et cet ordre est la seule partie de la source qui ne se verifie
// pas en lisant une reponse a cote. Un chapitre mal place ne se voit ni dans une
// trace reseau ni dans un decodage reussi, il se voit en ouvrant le mauvais
// chapitre.
//
// Kavita range ses chapitres dans des volumes, et trois conventions coexistent
// selon la version pour dire qu un chapitre n appartient a aucun tome. Les
// reunir ici, et non a l endroit du tri, evite qu une quatrieme convention
// arrive un jour a un seul des deux endroits.
//
// Le tri se fait sur le volume d abord et le numero de chapitre ensuite. Trier
// sur le seul numero de chapitre paraitrait plus simple et marcherait sur les
// series a numerotation continue, qui sont la majorite. Il melangerait toutes
// les series decoupees en tomes, ou chaque tome recommence a un.
//

/// Un chapitre a sa place dans la serie, volume compris.
struct PlaceDeChapitreKavita: Sendable {
    let volume: VolumeDeKavita
    let chapitre: ChapitreDeKavita

    /// Le chapitre traduit, a son rang dans la serie.
    ///
    /// Le rang est passe par l appelant et non deduit du numero : la section
    /// 4.1 dit que c est le rang qui ordonne la liste, jamais le numero, et un
    /// serveur ou deux chapitres portent le meme numero existe.
    func chapitreDistant(ordre: Int, serie: String) -> ChapitreDistant {
        ChapitreDistant(
            identifiant: String(chapitre.id),
            identifiantManga: serie,
            numero: chapitre.numeroConnu ?? Double(ordre + 1),
            titre: chapitre.titreAffiche,
            datePublication: LecteurDeDateKavita.lire(chapitre.releaseDate),
            nombrePages: chapitre.nombreDePagesConnu,
            ordre: ordre
        )
    }
}

/// Mise en ordre de lecture des chapitres d une serie.
enum OrdreDesChapitresKavita {
    /// Les chapitres de tous les volumes, dans l ordre de lecture.
    static func ordonner(_ volumes: [VolumeDeKavita]) -> [PlaceDeChapitreKavita] {
        volumes
            .flatMap { volume in
                (volume.chapters ?? []).map { PlaceDeChapitreKavita(volume: volume, chapitre: $0) }
            }
            .sorted(by: precede)
    }

    /// Vrai quand le premier chapitre se lit avant le second.
    ///
    /// Le volume decide d abord, le numero de chapitre ensuite, l identifiant en
    /// dernier recours. Ce dernier recours n est pas decoratif : sans lui,
    /// l ordre de deux chapitres portant le meme numero dependrait de celui dans
    /// lequel le serveur les a rendus, et la liste se reorganiserait a chaque
    /// ouverture de fiche.
    private static func precede(_ gauche: PlaceDeChapitreKavita, _ droite: PlaceDeChapitreKavita) -> Bool {
        let volumes = (gauche.volume.rangDeLecture, droite.volume.rangDeLecture)

        guard volumes.0 == volumes.1 else {
            return volumes.0 < volumes.1
        }

        let numeros = (gauche.chapitre.rangDeLecture, droite.chapitre.rangDeLecture)

        guard numeros.0 == numeros.1 else {
            return numeros.0 < numeros.1
        }

        return gauche.chapitre.id < droite.chapitre.id
    }
}

// MARK: - Numerotation

extension VolumeDeKavita {
    /// Rang du volume dans la serie, les chapitres hors volume en dernier.
    ///
    /// Trois conventions coexistent selon la version du serveur pour dire qu un
    /// chapitre n appartient a aucun tome : le numero zero sur les versions
    /// anciennes, et deux sentinelles proches du plus grand entier signe sur
    /// trente deux bits sur les recentes, l une pour les chapitres libres,
    /// l autre pour les hors series. Les trois veulent dire la meme chose pour
    /// nous, et se lisent apres les tomes numerotes, comme dans l interface du
    /// serveur.
    var rangDeLecture: Double {
        guard
            let numero = minNumber ?? number.map(Double.init),
            numero > 0,
            numero < Self.premierNumeroReserve
        else {
            return .greatestFiniteMagnitude
        }

        return numero
    }

    /// Premier numero que Kavita reserve a ses sentinelles.
    private static let premierNumeroReserve: Double = 2_147_483_646
}

extension ChapitreDeKavita {
    /// Le numero annonce, avec ses trois replis.
    ///
    /// Le champ numerique prime. Sans lui le numero textuel est tente, puis le
    /// debut de l intervalle, parce qu un chapitre qui couvre les tomes un a
    /// cinq annonce `1-5` et se lit a la place du un. Un numero negatif est
    /// ecarte : c est ainsi que le serveur marque un hors serie, et non un
    /// chapitre qui se lirait avant le premier.
    var numeroConnu: Double? {
        if let minNumber, minNumber >= 0 {
            return minNumber
        }
        if let number, let valeur = Double(number), valeur >= 0 {
            return valeur
        }
        guard
            let debut = range?.split(separator: "-").first.map(String.init),
            let valeur = Double(debut),
            valeur >= 0
        else {
            return nil
        }

        return valeur
    }

    /// Le numero employe pour trier, les chapitres sans numero en dernier.
    var rangDeLecture: Double {
        numeroConnu ?? .greatestFiniteMagnitude
    }

    /// Le titre du chapitre, ou nul quand le serveur n a fait qu y recopier le
    /// numero.
    var titreAffiche: String? {
        if let titreReel = titleName?.sansBlancs {
            return titreReel
        }
        guard let title = title?.sansBlancs else {
            return nil
        }
        guard title != range?.sansBlancs, title != number?.sansBlancs else {
            return nil
        }

        return title
    }

    /// Nombre de pages, nul quand le serveur n a pas encore analyse le fichier.
    var nombreDePagesConnu: Int? {
        guard let pages, pages > 0 else {
            return nil
        }

        return pages
    }
}
