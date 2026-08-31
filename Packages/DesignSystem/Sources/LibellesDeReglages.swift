import Core

//
// Libelles de l ecran Reglages, sections 5.5, 6.7 et 6.8 de DESIGN-SPEC.md.
//
// Aucun mot n est ecrit ici. Le paquet DesignSystem sait ou poser un libelle,
// pas comment le formuler : les chaines viennent du catalogue de
// l application, qui les prend dans la section 6 du document.
//

/// Textes de l ecran Reglages, pris dans le catalogue de chaines.
public struct LibellesDeReglages: Sendable, Equatable {
    /// En tete de chaque section, section 5.5.
    public let titresDeSection: [SectionDeReglages: String]

    /// Libelle de chaque ligne, section 5.5.
    public let libellesDeLigne: [IdentifiantDeReglage: String]

    /// Description posee sous une carte, tableau 6.8. Absente pour les sections
    /// que le tableau ne decrit pas.
    public let descriptionsDeSection: [SectionDeReglages: String]

    /// Libelle de chaque valeur de menu, indexe par sa representation
    /// persistee, tableau 6.7.
    public let valeursDeMenu: [String: String]

    /// Note en `caption` qui ferme la section A propos, tableau 6.8.
    public let noteDeFin: String

    /// Etiquette d accessibilite de la couronne d une fonction verrouillee.
    /// Etiquette du chevron d augmentation d un compteur.
    public let augmenter: String

    /// Etiquette du chevron de diminution d un compteur.
    public let diminuer: String

    public init(
        titresDeSection: [SectionDeReglages: String],
        libellesDeLigne: [IdentifiantDeReglage: String],
        descriptionsDeSection: [SectionDeReglages: String],
        valeursDeMenu: [String: String],
        noteDeFin: String,
        augmenter: String,
        diminuer: String
    ) {
        self.titresDeSection = titresDeSection
        self.libellesDeLigne = libellesDeLigne
        self.descriptionsDeSection = descriptionsDeSection
        self.valeursDeMenu = valeursDeMenu
        self.noteDeFin = noteDeFin
        self.augmenter = augmenter
        self.diminuer = diminuer
    }

    /// En tete d une section.
    public func titre(de section: SectionDeReglages) -> String {
        titresDeSection[section] ?? ""
    }

    /// Libelle d une ligne.
    public func libelle(de identifiant: IdentifiantDeReglage) -> String {
        libellesDeLigne[identifiant] ?? ""
    }

    /// Description d une section, nulle quand le tableau 6.8 n en donne pas.
    public func description(de section: SectionDeReglages) -> String? {
        descriptionsDeSection[section]
    }

    /// Libelle d une valeur de menu.
    ///
    /// Une valeur sans libelle retombe sur sa representation persistee. Le cas
    /// signale un trou dans le catalogue, et la suite de tests le detecte avant
    /// qu il n arrive a l ecran.
    public func valeur(_ brute: String) -> String {
        valeursDeMenu[brute] ?? brute
    }
}
