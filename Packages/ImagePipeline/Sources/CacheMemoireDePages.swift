//
// CacheMemoireDePages
//
// Cache LRU des pages decodees, borne par PlafondDeCacheMemoire.
//
// Le plafond est tenu par construction et non verifie apres coup. Toute
// insertion se termine par une eviction de la plus ancienne entree tant que
// l une des deux bornes est franchie, et une page qui pese a elle seule plus
// que le plafond d octets est refusee plutot que retenue. Il n existe donc
// aucun instant, entre deux appels, ou le cache detient plus que sa borne.
//
// La page visible est declaree au cache, pas devinee par lui. Elle sert a deux
// choses : elle est la derniere que l eviction sacrifie, et la seule que
// l alerte memoire epargne. Sans elle, une alerte memoire viderait l image que
// l utilisateur a sous les yeux, qu il faudrait redecoder immediatement, au
// pire moment.
//

/// Cache memoire LRU des pages decodees.
public actor CacheMemoireDePages {
    /// Une page retenue, avec le compte d octets fige a l insertion.
    ///
    /// Le compte est fige parce qu il sert a la soustraction lors du retrait.
    /// Le relire sur l image a ce moment la exposerait a un ecart, et le total
    /// deriverait entree apres entree.
    private struct Entree {
        let image: ImageDePage
        let octets: Int
    }

    /// Bornes appliquees a ce cache.
    public let plafond: PlafondDeCacheMemoire

    private var entrees: [ClePage: Entree] = [:]

    /// Cles de la plus recemment utilisee a la plus ancienne.
    private var recence: [ClePage] = []

    private var octetsRetenusInternes = 0
    private var visible: ClePage?

    public init(plafond: PlafondDeCacheMemoire = .parDefaut) {
        self.plafond = plafond
    }

    /// Octets que le cache detient a cet instant.
    public var octetsRetenus: Int {
        octetsRetenusInternes
    }

    /// Nombre de pages que le cache detient a cet instant.
    public var nombreDePages: Int {
        entrees.count
    }

    /// Cles retenues, de la plus recemment utilisee a la plus ancienne.
    public var clesRetenues: [ClePage] {
        recence
    }

    /// Page declaree visible, s il y en a une.
    public var pageVisible: ClePage? {
        visible
    }

    /// Declare la page que l utilisateur a sous les yeux.
    ///
    /// Passer `nil` a la fermeture du lecteur, sans quoi une alerte memoire
    /// epargnerait une page que plus personne n affiche.
    public func marquerVisible(_ cle: ClePage?) {
        visible = cle

        if let cle, entrees[cle] != nil {
            toucher(cle)
        }
    }

    /// Depose une page dans le cache.
    ///
    /// - Returns: vrai quand la page est retenue, faux quand elle est refusee
    ///   parce qu elle pese a elle seule plus que le plafond d octets. Un
    ///   appelant qui recoit faux garde sa reference ou redecode plus petit, il
    ///   ne doit pas supposer que le cache la lui rendra.
    @discardableResult
    public func deposer(_ image: ImageDePage, pour cle: ClePage) -> Bool {
        let octets = image.octetsEnMemoire

        // Une page plus lourde que le plafond ne peut pas y entrer sans le
        // franchir, meme cache vide. On retire la version precedente au passage,
        // sans quoi le cache rendrait une page perimee apres un refus.
        guard octets <= plafond.octets else {
            retirer(cle)

            return false
        }

        retirer(cle)
        entrees[cle] = Entree(image: image, octets: octets)
        recence.insert(cle, at: 0)
        octetsRetenusInternes += octets
        evincerJusquAuPlafond(sauf: cle)

        return entrees[cle] != nil
    }

    /// Rend une page retenue et la marque comme la plus recemment utilisee.
    public func image(pour cle: ClePage) -> ImageDePage? {
        guard let entree = entrees[cle] else { return nil }

        toucher(cle)

        return entree.image
    }

    /// Vrai quand la cle est retenue, sans modifier l ordre de recence.
    public func contient(_ cle: ClePage) -> Bool {
        entrees[cle] != nil
    }

    /// Retire une page, si elle est retenue.
    public func retirer(_ cle: ClePage) {
        guard let entree = entrees.removeValue(forKey: cle) else { return }

        octetsRetenusInternes -= entree.octets
        recence.removeAll { $0 == cle }
    }

    /// Vide le cache entierement, page visible comprise.
    public func vider() {
        entrees.removeAll()
        recence.removeAll()
        octetsRetenusInternes = 0
    }

    /// Reagit a une alerte memoire du systeme.
    ///
    /// Vide tout sauf la page visible, comme l impose le cinquieme point de la
    /// section 6.1. Sans page visible declaree, ou si celle ci n est pas
    /// retenue, le cache est vide entierement.
    ///
    /// - Returns: octets liberes.
    @discardableResult
    public func reagirAUneAlerteMemoire() -> Int {
        let avant = octetsRetenusInternes
        let epargnee = visible.flatMap { cle in entrees[cle].map { (cle: cle, entree: $0) } }

        vider()

        if let epargnee {
            entrees[epargnee.cle] = epargnee.entree
            recence = [epargnee.cle]
            octetsRetenusInternes = epargnee.entree.octets
        }

        return avant - octetsRetenusInternes
    }

    /// Remonte une cle en tete de l ordre de recence.
    private func toucher(_ cle: ClePage) {
        recence.removeAll { $0 == cle }
        recence.insert(cle, at: 0)
    }

    /// Evince les plus anciennes entrees tant qu une borne est franchie.
    ///
    /// La terminaison est garantie : `deposer` a deja refuse toute page plus
    /// lourde que le plafond d octets, et le plafond de pages vaut au moins un.
    /// La boucle trouve donc toujours une victime autre que la nouvelle entree.
    private func evincerJusquAuPlafond(sauf nouvelle: ClePage) {
        while entrees.count > plafond.pages || octetsRetenusInternes > plafond.octets {
            guard let victime = prochaineVictime(sauf: nouvelle) else { return }

            retirer(victime)
        }
    }

    /// Plus ancienne entree evincable.
    ///
    /// La nouvelle entree et la page visible ne sont candidates qu en dernier
    /// recours. Evincer la page visible ferait clignoter l ecran, evincer la
    /// nouvelle rendrait le depot silencieusement sans effet.
    private func prochaineVictime(sauf nouvelle: ClePage) -> ClePage? {
        if let victime = recence.last(where: { $0 != nouvelle && $0 != visible }) {
            return victime
        }

        return recence.last(where: { $0 != nouvelle })
    }
}
