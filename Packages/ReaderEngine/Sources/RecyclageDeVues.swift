//
// RecyclageDeVues
//
// Pool de vues reutilisees par le mode Defilement continu, section 7.1 du
// cahier de developpement.
//
// Le mode continu empile un chapitre entier. Une vue par page tiendrait des
// centaines de vues vivantes et autant de pages decodees, ce qui sort du budget
// memoire de la section 12 bien avant de sortir du budget de defilement.
//
// Le pool ne cree donc jamais plus de vues que sa capacite. Une page qui sort de
// la fenetre rend sa vue, la page qui entre la reprend. Le nombre de vues
// vivantes ne depend pas de la longueur du chapitre, seulement de la fenetre.
//
// Deux details comptent autant que le principe.
//
// La vue rendue est reprise par son rang le plus petit, pas dans un ordre
// d arrivee. Une attribution deterministe se teste, et surtout elle evite qu un
// aller retour rende a chaque passage une vue differente a la meme page, ce qui
// annulerait tout ce que la vue avait garde en cache.
//
// Le pool distingue les vues vivantes des vues creees. C est la seconde mesure
// qui trahit un recyclage casse : si elle continue de monter pendant le
// defilement, le pool n a rien recycle, il a construit.
//

/// Vue attribuee a une page.
public struct AttributionDeVue: Sendable, Equatable, Hashable {
    /// Page affichee, indexee a partir de zero.
    public let page: Int

    /// Vue qui la porte, identifiee par son rang dans le pool.
    public let vue: Int

    public init(page: Int, vue: Int) {
        self.page = page
        self.vue = vue
    }
}

/// Ce qu une mise a jour du pool change.
public struct ChangementDeRecyclage: Sendable, Equatable {
    /// Pages sorties de la fenetre, avec la vue qu elles rendent.
    public let liberees: [AttributionDeVue]

    /// Pages entrees dans la fenetre, avec la vue qu elles recoivent.
    public let attribuees: [AttributionDeVue]

    public init(liberees: [AttributionDeVue], attribuees: [AttributionDeVue]) {
        self.liberees = liberees
        self.attribuees = attribuees
    }

    /// Vrai quand la mise a jour n a rien deplace.
    public var estVide: Bool {
        liberees.isEmpty && attribuees.isEmpty
    }
}

/// Attribution des vues aux pages montees, a nombre de vues borne.
public struct RecyclageDeVues: Sendable, Equatable {
    /// Nombre maximal de vues que le pool creera, quelle que soit la longueur du
    /// chapitre.
    public let capacite: Int

    /// Fenetre de pages actuellement montee.
    public private(set) var fenetre: Range<Int>

    private var vueParPage: [Int: Int]
    private var libres: [Int]
    private var creees: Int

    /// Construit un pool.
    ///
    /// - Parameter capacite: nombre de vues vivantes voulu. La valeur sort de
    ///   `DefilementContinu.capaciteDeRecyclage(hauteurDeLaFenetre:plan:)`, qui
    ///   la calcule a partir de la geometrie reelle du chapitre.
    public init(capacite: Int) {
        self.capacite = max(1, capacite)
        fenetre = 0..<0
        vueParPage = [:]
        libres = []
        creees = 0
    }

    /// Nombre de vues actuellement attachees a une page.
    public var nombreDeVuesVivantes: Int {
        vueParPage.count
    }

    /// Nombre de vues creees depuis l ouverture du chapitre.
    ///
    /// Ne bouge plus des que la fenetre a ete remplie une premiere fois.
    public var nombreDeVuesCreees: Int {
        creees
    }

    /// Pages montees, dans l ordre narratif.
    public var pagesVivantes: [Int] {
        vueParPage.keys.sorted()
    }

    /// Vue qui porte cette page, nulle quand la page n est pas montee.
    public func vue(pourPage page: Int) -> Int? {
        vueParPage[page]
    }

    /// Monte la fenetre demandee en recyclant les vues deja creees.
    ///
    /// - Parameter nouvelle: pages a garder montees. Une fenetre plus large que
    ///   la capacite est ramenee a la capacite plutot que de faire creer une vue
    ///   de plus : c est l appelant qui a mal dimensionne le pool, et le
    ///   defilement n est pas le moment de le lui faire payer.
    /// - Returns: les vues rendues et les vues attribuees par cette mise a jour.
    @discardableResult
    public mutating func mettreAJour(fenetre nouvelle: Range<Int>) -> ChangementDeRecyclage {
        let retenue = Self.borner(nouvelle, capacite: capacite)

        guard retenue != fenetre else {
            return ChangementDeRecyclage(liberees: [], attribuees: [])
        }

        let liberees = liberer(horsDe: retenue)
        let attribuees = attribuer(dans: retenue)

        fenetre = retenue

        return ChangementDeRecyclage(liberees: liberees, attribuees: attribuees)
    }

    /// Rend au pool les vues des pages sorties de la fenetre.
    private mutating func liberer(horsDe retenue: Range<Int>) -> [AttributionDeVue] {
        var liberees: [AttributionDeVue] = []

        for page in pagesVivantes where retenue.contains(page) == false {
            guard let vue = vueParPage.removeValue(forKey: page) else { continue }

            libres.append(vue)
            liberees.append(AttributionDeVue(page: page, vue: vue))
        }

        libres.sort()

        return liberees
    }

    /// Attribue une vue a chaque page entree dans la fenetre.
    private mutating func attribuer(dans retenue: Range<Int>) -> [AttributionDeVue] {
        var attribuees: [AttributionDeVue] = []

        for page in retenue where vueParPage[page] == nil {
            guard let vue = prendreUneVue() else { continue }

            vueParPage[page] = vue
            attribuees.append(AttributionDeVue(page: page, vue: vue))
        }

        return attribuees
    }

    /// Reprend la vue libre de plus petit rang, ou en cree une si la capacite le
    /// permet encore.
    private mutating func prendreUneVue() -> Int? {
        if libres.isEmpty == false {
            return libres.removeFirst()
        }

        guard creees < capacite else { return nil }

        let vue = creees
        creees += 1

        return vue
    }

    /// Ramene une fenetre dans le chapitre et sous la capacite.
    private static func borner(_ fenetre: Range<Int>, capacite: Int) -> Range<Int> {
        let debut = max(0, fenetre.lowerBound)
        let fin = max(debut, fenetre.upperBound)
        let largeur = min(fin - debut, capacite)

        return debut..<(debut + largeur)
    }
}
