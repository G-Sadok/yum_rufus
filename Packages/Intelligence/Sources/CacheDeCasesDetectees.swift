import Core
import ImagePipeline

//
// CacheDeCasesDetectees
//
// Planches deja passees dans le detecteur, retenues pour ne jamais l etre deux
// fois.
//
// Le cache est borne en nombre de planches et non en octets, contrairement a
// celui des pages produites. Une planche detectee pese une poignee de
// rectangles, quelques centaines d octets au plus, et compter ses octets
// couterait plus que de les stocker. Le vrai risque n est pas la memoire, c est
// la croissance sans fin sur un chapitre long.
//
// Comme `CacheDePagesIA`, c est une valeur et non un acteur. L acteur de
// detection ne doit contenir aucun point de suspension entre le moment ou il
// cherche et celui ou il depose, sans quoi deux zooms sur la meme planche
// partiraient ensemble et le reseau tournerait deux fois.
//

/// Cache LRU des cases detectees, borne en nombre de planches.
struct CacheDeCasesDetectees {
    /// Nombre de planches retenues au plus.
    let plafond: Int

    private var entrees: [ClePage: [CaseDePage]] = [:]

    /// Cles de la plus recemment utilisee a la plus ancienne.
    private var recence: [ClePage] = []

    init(plafond: Int) {
        self.plafond = max(1, plafond)
    }

    /// Nombre de planches retenues a cet instant.
    var nombreDePlanches: Int {
        entrees.count
    }

    /// Cles retenues, de la plus recemment utilisee a la plus ancienne.
    var clesRetenues: [ClePage] {
        recence
    }

    /// Rend les cases retenues et marque la planche comme la plus recemment
    /// utilisee.
    ///
    /// Une planche sans case detectee est retenue comme les autres, et rend une
    /// suite vide. C est volontaire : sans cela, une planche muette relancerait
    /// le reseau a chaque geste de zoom, ce qui est exactement le cas ou il ne
    /// trouvera rien.
    mutating func cases(pour cle: ClePage) -> [CaseDePage]? {
        guard let retenues = entrees[cle] else { return nil }

        toucher(cle)

        return retenues
    }

    /// Vrai quand la planche est retenue, sans modifier l ordre de recence.
    func contient(_ cle: ClePage) -> Bool {
        entrees[cle] != nil
    }

    /// Depose les cases d une planche.
    mutating func deposer(_ cases: [CaseDePage], pour cle: ClePage) {
        retirer(cle)
        entrees[cle] = cases
        recence.insert(cle, at: 0)
        evincerJusquAuPlafond()
    }

    /// Retire une planche, si elle est retenue.
    mutating func retirer(_ cle: ClePage) {
        guard entrees.removeValue(forKey: cle) != nil else { return }

        recence.removeAll { $0 == cle }
    }

    /// Vide le cache entierement.
    mutating func vider() {
        entrees.removeAll()
        recence.removeAll()
    }

    /// Remonte une cle en tete de l ordre de recence.
    private mutating func toucher(_ cle: ClePage) {
        recence.removeAll { $0 == cle }
        recence.insert(cle, at: 0)
    }

    /// Evince les plus anciennes planches tant que le plafond est franchi.
    private mutating func evincerJusquAuPlafond() {
        while entrees.count > plafond {
            guard let victime = recence.last else { return }

            retirer(victime)
        }
    }
}
