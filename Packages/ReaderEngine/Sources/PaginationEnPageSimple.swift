import Core

//
// PaginationEnPageSimple
//
// Position de lecture dans un chapitre affiche une page a la fois, section 7.1
// du cahier de developpement.
//
// C est une valeur, pas un objet. Elle se copie, se compare et se teste sans
// rien construire autour, et les regles de bornes vivent a un seul endroit au
// lieu d etre reecrites dans chaque geste.
//

/// Position de lecture dans un chapitre lu page par page.
public struct PaginationEnPageSimple: Sendable, Equatable {
    /// Nombre de pages du chapitre.
    public let nombreDePages: Int

    /// Sens de lecture resolu pour la serie.
    public let sens: SensDeLecture

    /// Page affichee, indexee a partir de zero.
    public private(set) var index: Int

    /// Construit une position, bornee au chapitre.
    ///
    /// - Parameters:
    ///   - nombreDePages: nombre de pages, ramene a zero s il est negatif.
    ///   - sens: sens de lecture resolu pour la serie.
    ///   - index: page de depart, ramenee dans le chapitre.
    public init(nombreDePages: Int, sens: SensDeLecture, index: Int = 0) {
        let total = max(0, nombreDePages)
        self.nombreDePages = total
        self.sens = sens
        self.index = total == 0 ? 0 : min(max(0, index), total - 1)
    }

    /// Vrai quand le chapitre ne contient aucune page.
    public var estVide: Bool {
        nombreDePages == 0
    }

    /// Numero affiche a l utilisateur, qui compte a partir de un.
    ///
    /// Vaut zero sur un chapitre vide, ou aucune page n est affichee.
    public var numeroDePage: Int {
        estVide ? 0 : index + 1
    }

    /// Vrai quand la page affichee est la premiere du chapitre.
    public var estALaPremierePage: Bool {
        estVide || index == 0
    }

    /// Vrai quand la page affichee est la derniere du chapitre.
    public var estALaDernierePage: Bool {
        estVide || index == nombreDePages - 1
    }

    /// Avancement dans le chapitre, entre zero et un.
    ///
    /// La derniere page vaut un, pour que le curseur de la barre inferieure
    /// atteigne son extremite a la fin du chapitre. Un chapitre d une seule
    /// page vaut zero, faute de course a parcourir.
    public var progression: Double {
        guard nombreDePages > 1 else { return 0 }

        return Double(index) / Double(nombreDePages - 1)
    }

    /// Applique une intention de navigation.
    ///
    /// - Returns: vrai quand la page affichee a change. Faux quand l intention
    ///   ne navigue pas, ou quand elle bute sur une extremite du chapitre.
    @discardableResult
    public mutating func appliquer(_ intention: IntentionDeNavigation) -> Bool {
        switch intention {
        case .pageSuivante:
            allerALaPage(index + 1)
        case .pagePrecedente:
            allerALaPage(index - 1)
        case .aucune:
            false
        }
    }

    /// Applique la touche du clavier, traduite par le sens de lecture.
    @discardableResult
    public mutating func appliquer(touche: ToucheDeNavigation) -> Bool {
        appliquer(NavigationDeLecture.intention(pourTouche: touche, sens: sens))
    }

    /// Applique le balayage, traduit par le sens de lecture.
    @discardableResult
    public mutating func appliquer(balayage: BalayageDeNavigation) -> Bool {
        appliquer(NavigationDeLecture.intention(pourBalayage: balayage, sens: sens))
    }

    /// Applique un appui sur la surface de lecture, en disposition Standard.
    ///
    /// - Parameters:
    ///   - fraction: position de l appui le long de l axe, mesuree depuis le
    ///     bord gauche, quel que soit le sens de lecture.
    ///   - zonesInversees: option Inverser les zones de la section 9.
    @discardableResult
    public mutating func appliquer(appuiSurFraction fraction: Double, zonesInversees: Bool = false) -> Bool {
        appliquer(
            ZonesDeToucher.intention(
                pourFraction: fraction,
                sens: sens,
                zonesInversees: zonesInversees
            )
        )
    }

    /// Applique un appui sur la surface de lecture, dans la disposition reglee.
    ///
    /// - Parameters:
    ///   - abscisse: part de la largeur, mesuree depuis le bord gauche.
    ///   - ordonnee: part de la hauteur, mesuree depuis le bord haut.
    ///   - disposition: disposition choisie au reglage Zones de toucher.
    ///   - zonesInversees: option Inverser les zones de la section 9.
    @discardableResult
    public mutating func appliquer(
        appuiSurAbscisse abscisse: Double,
        ordonnee: Double,
        disposition: DispositionDeZones,
        zonesInversees: Bool = false
    ) -> Bool {
        appliquer(
            ZonesDeToucher.intention(
                pourAbscisse: abscisse,
                ordonnee: ordonnee,
                sens: sens,
                disposition: disposition,
                zonesInversees: zonesInversees
            )
        )
    }

    /// Va directement a une page.
    ///
    /// - Returns: vrai quand la page affichee a change. Une position hors du
    ///   chapitre ne deplace rien, elle n est pas ramenee sur une extremite :
    ///   la lecture ne saute pas silencieusement a la derniere page parce qu un
    ///   geste a depasse la fin.
    @discardableResult
    public mutating func allerALaPage(_ nouvelIndex: Int) -> Bool {
        guard estVide == false,
              (0..<nombreDePages).contains(nouvelIndex),
              nouvelIndex != index
        else {
            return false
        }

        index = nouvelIndex

        return true
    }

    /// Va a la page correspondant a un avancement du curseur.
    ///
    /// - Parameter progression: avancement entre zero et un, deja remis dans le
    ///   sens de lecture par `CurseurDeProgression`.
    @discardableResult
    public mutating func allerALaProgression(_ progression: Double) -> Bool {
        guard estVide == false else { return false }

        let bornee = min(max(progression, 0), 1)
        let vise = Int((bornee * Double(nombreDePages - 1)).rounded())

        return allerALaPage(vise)
    }
}
