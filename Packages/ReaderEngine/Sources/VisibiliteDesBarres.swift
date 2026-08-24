//
// VisibiliteDesBarres
//
// Regle d apparition et de retrait des deux barres du lecteur, section 5.7 de
// DESIGN-SPEC.md.
//
// Barres masquees par defaut. Elles apparaissent au tap central, ou au
// deplacement de la souris sur macOS, et se retirent apres trois secondes
// d inactivite. Le masquage au glissement obeit a l option Masquer les barres
// en glissant de la section 9 du cahier de developpement, active par defaut.
//
// L instant est passe en argument plutot que lu ici. C est ce qui rend la regle
// verifiable sans faire attendre la suite de tests trois secondes.
//

/// Etat d affichage des deux barres du lecteur.
public struct VisibiliteDesBarres: Sendable, Equatable {
    /// Duree d inactivite apres laquelle les barres se retirent, en secondes.
    public static let delaiDInactivite: Double = 3

    /// Vrai quand les deux barres sont affichees.
    public private(set) var barresAffichees: Bool

    /// Instant de la derniere activite prise en compte.
    public private(set) var instantDeLaDerniereActivite: Double

    /// Option Masquer les barres en glissant.
    public var masquageAuGlissement: Bool

    /// Construit l etat de depart, barres masquees.
    ///
    /// - Parameters:
    ///   - masquageAuGlissement: option de la section 9, active par defaut.
    ///   - instant: origine du compte d inactivite.
    public init(masquageAuGlissement: Bool = true, instant: Double = 0) {
        barresAffichees = false
        instantDeLaDerniereActivite = instant
        self.masquageAuGlissement = masquageAuGlissement
    }

    /// Appui sur la zone centrale : affiche ou masque les barres.
    @discardableResult
    public mutating func basculerParAppuiCentral(instant: Double) -> Bool {
        instantDeLaDerniereActivite = instant
        barresAffichees.toggle()

        return true
    }

    /// Deplacement du pointeur : revele les barres et relance le compte.
    ///
    /// - Returns: vrai quand les barres viennent d apparaitre.
    @discardableResult
    public mutating func revelerParDeplacementDePointeur(instant: Double) -> Bool {
        instantDeLaDerniereActivite = instant

        guard barresAffichees == false else { return false }

        barresAffichees = true

        return true
    }

    /// Glissement sur la surface de lecture.
    ///
    /// Retire les barres quand l option est active. Quand elle ne l est pas, le
    /// glissement reste une activite et relance le compte d inactivite au lieu
    /// de laisser les barres disparaitre pendant que l utilisateur navigue.
    ///
    /// - Returns: vrai quand les barres viennent de disparaitre.
    @discardableResult
    public mutating func signalerUnGlissement(instant: Double) -> Bool {
        instantDeLaDerniereActivite = instant

        guard masquageAuGlissement, barresAffichees else { return false }

        barresAffichees = false

        return true
    }

    /// Vrai quand le delai d inactivite est ecoule et que les barres sont la.
    public func doitSeMasquer(a instant: Double) -> Bool {
        barresAffichees && instant - instantDeLaDerniereActivite >= Self.delaiDInactivite
    }

    /// Retire les barres si le delai d inactivite est ecoule.
    ///
    /// - Returns: vrai quand les barres viennent de disparaitre.
    @discardableResult
    public mutating func masquerSiInactif(a instant: Double) -> Bool {
        guard doitSeMasquer(a: instant) else { return false }

        barresAffichees = false

        return true
    }
}
