//
// CacheDeRognage
//
// Memoire des zones utiles deja mesurees, indexee par page et par parametres.
//
// La section 6.3 range le rognage parmi les etapes couteuses dont le resultat
// se met en cache sous une cle qui integre le hachage des parametres. Ce cache
// tient cette promesse par construction : la cle interne est fabriquee ici, a
// partir de la cle de page et de l empreinte des reglages, et un appelant ne
// peut pas la contourner en oubliant les parametres.
//
// Ce qui est retenu est la zone, pas la page rognee. La mesure est ce qui
// coute : elle redessine la page entiere en gris puis la parcourt. Decouper
// selon une zone deja connue ne coute qu un redessin de la partie conservee,
// que le cache memoire des pages retient deja de son cote. Retenir ici la
// matrice rognee ferait un troisieme exemplaire de la meme page en memoire,
// pour economiser la moins chere des deux operations.
//
// Une zone pese quelques dizaines d octets, la capacite se compte donc en
// entrees et non en octets. Le plafond existe pour qu une longue session de
// lecture ne fasse pas croitre le dictionnaire sans fin, pas pour tenir un
// budget memoire.
//

/// Zones utiles deja mesurees, retenues par page et par parametres.
public actor CacheDeRognage {
    /// Nombre maximal d entrees retenues.
    public let capacite: Int

    private var zones: [ClePage: ZoneUtile] = [:]

    /// Cles de la plus recemment utilisee a la plus ancienne.
    private var recence: [ClePage] = []

    public init(capacite: Int = 256) {
        self.capacite = max(1, capacite)
    }

    /// Cle sous laquelle la zone d une page est retenue.
    ///
    /// Elle reprend la variante d origine de la page, qui porte deja la taille
    /// demandee et les autres traitements, et lui ajoute l empreinte des
    /// reglages de rognage. Deux jeux de seuils differents donnent donc deux
    /// entrees distinctes, et un changement de seuil ne peut pas faire ressortir
    /// une zone mesuree selon les anciens.
    public static func cle(pour page: ClePage, reglages: ReglagesDeRognage) -> ClePage {
        ClePage(
            chapitre: page.chapitre,
            index: page.index,
            variante: page.variante.isEmpty
                ? reglages.empreinte
                : "\(page.variante)|\(reglages.empreinte)"
        )
    }

    /// Nombre de zones retenues a cet instant.
    public var nombreDEntrees: Int {
        zones.count
    }

    /// Zone deja mesuree pour cette page sous ces reglages, s il y en a une.
    public func zoneConnue(pour page: ClePage, reglages: ReglagesDeRognage) -> ZoneUtile? {
        let cle = Self.cle(pour: page, reglages: reglages)

        guard let zone = zones[cle] else {
            return nil
        }

        toucher(cle)

        return zone
    }

    /// Retient une zone mesuree ailleurs.
    public func deposer(_ zone: ZoneUtile, pour page: ClePage, reglages: ReglagesDeRognage) {
        let cle = Self.cle(pour: page, reglages: reglages)

        zones[cle] = zone
        toucher(cle)
        evincerJusquALaCapacite()
    }

    /// Zone utile de cette page, mesuree seulement si elle n est pas connue.
    ///
    /// - Parameter calcul: analyse a lancer en cas d absence. Elle n est
    ///   appelee qu une fois par page et par jeu de reglages.
    public func zoneUtile(
        pour page: ClePage,
        reglages: ReglagesDeRognage,
        calcul: @Sendable () -> ZoneUtile
    ) -> ZoneUtile {
        if let connue = zoneConnue(pour: page, reglages: reglages) {
            return connue
        }

        let zone = calcul()
        deposer(zone, pour: page, reglages: reglages)

        return zone
    }

    /// Oublie la zone d une page sous ces reglages.
    public func retirer(_ page: ClePage, reglages: ReglagesDeRognage) {
        let cle = Self.cle(pour: page, reglages: reglages)

        zones.removeValue(forKey: cle)
        recence.removeAll { $0 == cle }
    }

    /// Oublie toutes les zones.
    public func vider() {
        zones.removeAll()
        recence.removeAll()
    }

    /// Remonte une cle en tete de la recence.
    private func toucher(_ cle: ClePage) {
        recence.removeAll { $0 == cle }
        recence.insert(cle, at: 0)
    }

    /// Retire les entrees les plus anciennes tant que la capacite est franchie.
    private func evincerJusquALaCapacite() {
        while zones.count > capacite, let ancienne = recence.last {
            zones.removeValue(forKey: ancienne)
            recence.removeLast()
        }
    }
}
