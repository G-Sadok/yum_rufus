//
// TutorielDeZones
//
// Tutoriel de premiere ouverture des zones de toucher, section 5.7 de
// DESIGN-SPEC.md : les zones ne sont jamais visibles, sauf pendant ce tutoriel
// ou elles apparaissent quatre secondes.
//
// L instant est passe en argument plutot que lu ici, comme pour la visibilite
// des barres. C est ce qui rend la duree verifiable sans faire attendre la
// suite de tests quatre secondes.
//
// Le drapeau deja vu est une donnee persistee, pas un etat de session. Un
// tutoriel qui reapparaitrait a chaque lancement ne serait plus un tutoriel de
// premiere ouverture. `MagasinDuTutorielDeZones` le relit au demarrage et
// l ecrit une fois.
//

/// Etat du tutoriel qui montre les zones de toucher a la premiere ouverture.
public struct TutorielDeZones: Sendable, Equatable {
    /// Duree pendant laquelle les zones restent visibles, en secondes.
    public static let duree: Double = 4

    /// Vrai quand le tutoriel a deja ete montre, sur cette installation.
    public private(set) var dejaVu: Bool

    /// Vrai quand les zones sont visibles en ce moment.
    public private(set) var estAffiche: Bool

    /// Instant ou les zones sont apparues.
    private var instantDApparition: Double

    /// - Parameter dejaVu: drapeau relu depuis la base. Vrai coupe le tutoriel
    ///   pour de bon.
    public init(dejaVu: Bool = false) {
        self.dejaVu = dejaVu
        estAffiche = false
        instantDApparition = 0
    }

    /// Ouverture du lecteur.
    ///
    /// Le tutoriel ne se declenche pas quand la disposition ne pose aucune zone
    /// active : montrer une surface entierement consacree au menu
    /// n apprendrait rien, et consommerait la seule occasion de montrer les
    /// zones a l utilisateur qui les activera plus tard.
    ///
    /// - Returns: vrai quand les zones viennent d apparaitre.
    @discardableResult
    public mutating func ouvrirLeLecteur(disposition: DispositionDeZones, instant: Double) -> Bool {
        guard dejaVu == false, disposition.aDesZonesActives else { return false }

        dejaVu = true
        estAffiche = true
        instantDApparition = instant

        return true
    }

    /// Vrai quand les quatre secondes sont ecoulees et que les zones sont la.
    public func doitSeMasquer(a instant: Double) -> Bool {
        estAffiche && instant - instantDApparition >= Self.duree
    }

    /// Retire les zones si la duree est ecoulee.
    ///
    /// - Returns: vrai quand les zones viennent de disparaitre.
    @discardableResult
    public mutating func masquerSiEcoule(a instant: Double) -> Bool {
        guard doitSeMasquer(a: instant) else { return false }

        estAffiche = false

        return true
    }

    /// Zones a dessiner, vides tant que le tutoriel n est pas affiche.
    ///
    /// La vue ne decide pas de la visibilite : elle recoit une liste vide quand
    /// il n y a rien a montrer. Les zones ne sont visibles nulle part ailleurs
    /// dans le produit, c est la regle de la section 5.7.
    public func zones(
        disposition: DispositionDeZones,
        sens: SensDeLecture,
        zonesInversees: Bool = false
    ) -> [ZoneDeToucher] {
        guard estAffiche else { return [] }

        return disposition.zones(sens: sens, zonesInversees: zonesInversees)
    }
}
