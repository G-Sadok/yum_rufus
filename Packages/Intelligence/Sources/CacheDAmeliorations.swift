import ImagePipeline

//
// CacheDAmeliorations
//
// Pages deja ameliorees, retenues pour ne jamais l etre deux fois.
//
// La section 8 le demande en une phrase : le resultat est mis en cache et jamais
// recalcule. La phrase vise le cout. Une page de trente tuiles passees dans un
// reseau de surelevation se compte en secondes, et le lecteur revient sans arret
// sur la page precedente, en tournant en arriere, en fermant un menu, en
// changeant de mode. Recalculer a chaque retour rendrait la fonction
// inutilisable alors meme qu elle marche.
//
// Le cache est une valeur et non un acteur, contrairement au cache memoire des
// pages. La raison est la garantie de serialisation : l acteur d amelioration ne
// doit contenir aucun point de suspension entre le moment ou il cherche dans le
// cache et celui ou il y depose, sans quoi deux traitements de la meme page
// pourraient partir ensemble et le calcul serait fait deux fois. Un cache
// acteur imposerait un await a chaque acces. Celui ci vit dans l etat de
// l acteur, il est donc deja protege par lui, et sans attente.
//
// Le plafond est celui d une page amelioree, pas celui d une page decodee. Une
// surelevation par deux quadruple le nombre de pixels : deux pages ameliorees
// pesent autant que huit pages decodees. La borne est donc basse en nombre
// d entrees et haute en octets, et elle laisse le cache des pages de la section
// 6.1 tenir a cote sous le budget de lecture de la section 12.
//

extension PlafondDeCacheMemoire {
    /// Bornes du cache des pages ameliorees.
    ///
    /// Deux pages et cent millions d octets. Une page amelioree pese jusqu a
    /// quarante huit millions d octets, quatre fois le plafond de decodage,
    /// deux tiennent donc sous cette borne. Ajoutees aux 220 Mo du cache des
    /// pages decodees, l ensemble reste sous les 400 Mo que la section 12
    /// accorde a la lecture.
    public static let pagesAmeliorees = PlafondDeCacheMemoire(pages: 2, octets: 100_000_000)
}

/// Cache LRU des pages ameliorees, borne par PlafondDeCacheMemoire.
struct CacheDAmeliorations {
    /// Une page retenue, avec le compte d octets fige a l insertion.
    private struct Entree {
        let image: ImageDePage
        let octets: Int
    }

    /// Bornes appliquees a ce cache.
    let plafond: PlafondDeCacheMemoire

    private var entrees: [ClePage: Entree] = [:]

    /// Cles de la plus recemment utilisee a la plus ancienne.
    private var recence: [ClePage] = []

    private var octets = 0

    init(plafond: PlafondDeCacheMemoire = .pagesAmeliorees) {
        self.plafond = plafond
    }

    /// Octets que le cache detient a cet instant.
    var octetsRetenus: Int {
        octets
    }

    /// Nombre de pages que le cache detient a cet instant.
    var nombreDePages: Int {
        entrees.count
    }

    /// Cles retenues, de la plus recemment utilisee a la plus ancienne.
    var clesRetenues: [ClePage] {
        recence
    }

    /// Rend une page retenue et la marque comme la plus recemment utilisee.
    mutating func image(pour cle: ClePage) -> ImageDePage? {
        guard let entree = entrees[cle] else { return nil }

        toucher(cle)

        return entree.image
    }

    /// Vrai quand la cle est retenue, sans modifier l ordre de recence.
    func contient(_ cle: ClePage) -> Bool {
        entrees[cle] != nil
    }

    /// Depose une page amelioree.
    ///
    /// - Returns: vrai quand la page est retenue, faux quand elle pese a elle
    ///   seule plus que le plafond d octets. Le traitement a de toute facon eu
    ///   lieu, l appelant rend sa page, mais il ne doit pas supposer que le
    ///   cache la lui rendra la prochaine fois.
    @discardableResult
    mutating func deposer(_ image: ImageDePage, pour cle: ClePage) -> Bool {
        let poids = image.octetsEnMemoire

        guard poids <= plafond.octets else {
            retirer(cle)

            return false
        }

        retirer(cle)
        entrees[cle] = Entree(image: image, octets: poids)
        recence.insert(cle, at: 0)
        octets += poids
        evincerJusquAuPlafond(sauf: cle)

        return entrees[cle] != nil
    }

    /// Retire une page, si elle est retenue.
    mutating func retirer(_ cle: ClePage) {
        guard let entree = entrees.removeValue(forKey: cle) else { return }

        octets -= entree.octets
        recence.removeAll { $0 == cle }
    }

    /// Vide le cache entierement.
    mutating func vider() {
        entrees.removeAll()
        recence.removeAll()
        octets = 0
    }

    /// Remonte une cle en tete de l ordre de recence.
    private mutating func toucher(_ cle: ClePage) {
        recence.removeAll { $0 == cle }
        recence.insert(cle, at: 0)
    }

    /// Evince les plus anciennes entrees tant qu une borne est franchie.
    ///
    /// La terminaison est garantie : `deposer` a deja refuse toute page plus
    /// lourde que le plafond d octets, et le plafond de pages vaut au moins un.
    private mutating func evincerJusquAuPlafond(sauf nouvelle: ClePage) {
        while entrees.count > plafond.pages || octets > plafond.octets {
            guard let victime = recence.last(where: { $0 != nouvelle }) else { return }

            retirer(victime)
        }
    }
}
