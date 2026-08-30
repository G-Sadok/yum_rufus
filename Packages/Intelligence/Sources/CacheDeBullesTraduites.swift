import Core
import ImagePipeline

//
// CacheDeBullesTraduites
//
// Planches deja detectees et traduites, retenues pour ne jamais l etre deux
// fois.
//
// Le cache est borne en nombre de planches et non en octets, comme celui des
// cases detectees et pour la meme raison : une planche traduite pese quelques
// phrases, et compter ses octets couterait plus que de les stocker. Le vrai
// risque n est pas la memoire, c est la croissance sans fin sur un chapitre
// long.
//
// La borne est plus basse que celle des cases. Une planche traduite pese ses
// textes, pas seulement des rectangles, et la traduction n a pas besoin de
// couvrir tout le voisinage precharge : elle se declenche a la demande sur la
// page regardee, la ou la detection de cases suit le zoom.
//
// C est une valeur et non un acteur, pour la meme raison que les deux autres
// caches de ce paquet : l acteur ne doit contenir aucun point de suspension
// entre le moment ou il cherche et celui ou il depose, sans quoi deux demandes
// sur la meme planche partiraient ensemble et le moteur tournerait deux fois.
// Dans le cas du moteur distant, cela voudrait dire payer deux fois.
//

/// Cache LRU des bulles traduites, borne en nombre de planches.
struct CacheDeBullesTraduites {
    /// Nombre de planches retenues au plus.
    let plafond: Int

    private var entrees: [ClePage: [TraductionDeBulle]] = [:]

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

    /// Rend les bulles retenues et marque la planche comme la plus recemment
    /// utilisee.
    ///
    /// Une planche sans bulle est retenue comme les autres, et rend une suite
    /// vide. C est volontaire : sans cela, une planche muette relancerait la
    /// detection a chaque affichage, ce qui est exactement le cas ou elle ne
    /// trouvera rien.
    mutating func bulles(pour cle: ClePage) -> [TraductionDeBulle]? {
        guard let retenues = entrees[cle] else { return nil }

        toucher(cle)

        return retenues
    }

    /// Vrai quand la planche est retenue, sans modifier l ordre de recence.
    func contient(_ cle: ClePage) -> Bool {
        entrees[cle] != nil
    }

    /// Depose les bulles traduites d une planche.
    mutating func deposer(_ bulles: [TraductionDeBulle], pour cle: ClePage) {
        retirer(cle)
        entrees[cle] = bulles
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
