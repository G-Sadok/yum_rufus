//
// DispositionDeZones
//
// Les quatre dispositions du menu Zones de toucher de la section 9 du cahier de
// developpement, et la geometrie de leurs zones.
//
// La geometrie vit dans Core parce que deux couches en ont besoin : le moteur
// de lecture, qui traduit un appui en intention, et la surimpression du
// tutoriel de la section 5.7 de DESIGN-SPEC.md, qui dessine les zones pendant
// quatre secondes. DesignSystem ne depend que de Core, poser la geometrie dans
// le moteur obligerait a la recopier dans la vue.
//
// Les zones se definissent dans le repere de la lecture, jamais dans celui de
// l ecran : une coordonnee d avancement, qui va du debut du chapitre vers sa
// fin, et une coordonnee transversale. Le sens de lecture tourne ensuite ce
// repere vers l ecran. C est ce qui ferme l erreur 6 du cahier des charges, ou
// une zone finit calee sur la direction de l interface au lieu du sens de
// lecture : aucune fonction de ce fichier ne recoit la direction de
// l interface, et aucune ne pourrait donc s en servir.
//

/// Ce qu une zone de toucher declenche.
public enum RoleDeZone: String, Sendable, Codable, CaseIterable, Hashable {
    /// Avance d une page dans le sens de lecture.
    case avance

    /// Recule d une page dans le sens de lecture.
    case recule

    /// Affiche ou masque les barres. Cette zone ne navigue jamais.
    case menu

    /// Role obtenu par l option Inverser les zones.
    ///
    /// L option echange les deux roles actifs et ne touche pas au menu : la
    /// bande centrale de la section 5.7 appelle les barres avec ou sans
    /// inversion.
    public var inverse: RoleDeZone {
        switch self {
        case .avance: .recule
        case .recule: .avance
        case .menu: .menu
        }
    }

    /// Vrai quand la zone fait tourner une page.
    public var navigue: Bool {
        self != .menu
    }
}

/// Rectangle d une zone de toucher, en parts de la surface de lecture.
///
/// Les quatre valeurs sont des fractions entre zero et un, mesurees depuis le
/// bord gauche et depuis le bord haut de la surface, quel que soit le sens de
/// lecture et quelle que soit la direction de l interface. La vue les multiplie
/// par sa taille, elle n a aucune orientation a retrouver.
public struct ZoneDeToucher: Sendable, Equatable, Hashable {
    /// Ce que la zone declenche.
    public let role: RoleDeZone

    /// Bord gauche de la zone.
    public let abscisse: Double

    /// Bord haut de la zone.
    public let ordonnee: Double

    /// Largeur de la zone.
    public let largeur: Double

    /// Hauteur de la zone.
    public let hauteur: Double

    public init(
        role: RoleDeZone,
        abscisse: Double,
        ordonnee: Double,
        largeur: Double,
        hauteur: Double
    ) {
        self.role = role
        self.abscisse = abscisse
        self.ordonnee = ordonnee
        self.largeur = largeur
        self.hauteur = hauteur
    }

    /// Part de la surface totale que la zone occupe.
    public var part: Double {
        largeur * hauteur
    }

    /// Vrai quand le point tombe dans la zone.
    ///
    /// Les bords sont ouverts en haut et fermes en bas, sauf a l extremite de
    /// la surface qui reste fermee des deux cotes. Deux zones voisines ne se
    /// disputent donc jamais un point, et aucun point de la surface n echappe a
    /// toutes les zones.
    public func contient(abscisse: Double, ordonnee: Double) -> Bool {
        Self.contient(abscisse, de: self.abscisse, a: self.abscisse + largeur)
            && Self.contient(ordonnee, de: self.ordonnee, a: self.ordonnee + hauteur)
    }

    private static func contient(_ valeur: Double, de debut: Double, a fin: Double) -> Bool {
        valeur >= debut && (valeur < fin || fin >= 1)
    }
}

/// Disposition des zones de toucher, menu Zones de toucher de la section 9.
///
/// Le document ne chiffre que Standard, dans la section 5.7 de DESIGN-SPEC.md :
/// trois bandes de 28, 44 et 28 pour cent le long de l axe de lecture. Les deux
/// autres dispositions reprennent la meme part de 28 pour cent plutot que d en
/// inventer une, et ne different que par la place qu elles donnent a chaque
/// role. Aucune valeur nouvelle n entre ainsi dans le produit.
public enum DispositionDeZones: String, ChoixDeReglage, Codable {
    /// Aucune zone active. Toute la surface appelle les barres.
    ///
    /// C est le defaut de la section 9. La lecture tourne alors au balayage et
    /// au clavier, et un appui ne tourne jamais une page par megarde.
    case desactive

    /// Trois bandes le long de l axe de lecture, section 5.7.
    case standard

    /// Les quatre bords tournent une page, le menu se limite au centre.
    ///
    /// Les deux bandes de Standard restent en place, et la bande centrale gagne
    /// a son tour deux bandes actives en travers : le bord amont recule, le bord
    /// aval avance. Le pouce trouve une zone active depuis n importe quel bord
    /// de l ecran, ce qu une tenue a une main demande.
    case bord

    /// Disposition d une liseuse : un bandeau de menu, un petit retour, et tout
    /// le reste avance.
    ///
    /// Le bandeau de menu se pose en travers de l axe de lecture, en tete. Sous
    /// lui, la bande amont de 28 pour cent recule et les 72 pour cent restants
    /// avancent. C est la disposition qui demande le moins de precision, parce
    /// que le geste le plus frequent, avancer, recoit la plus grande surface.
    case kindle

    /// Disposition appliquee tant que l utilisateur n a rien choisi, section 9.
    public static let parDefaut = DispositionDeZones.desactive

    /// Part de la surface occupee par une bande active, section 5.7.
    public static let partDUneBande = 0.28

    /// Part de la surface occupee par la bande centrale, section 5.7.
    public static let partDeLaBandeCentrale = 1 - 2 * partDUneBande

    /// Valeur telle que la section 9 l ecrit, jamais affichee.
    ///
    /// Sert a rapprocher le code du document. Le texte affiche passe par le
    /// catalogue de chaines.
    public var valeurDuDocument: String {
        switch self {
        case .desactive: "Desactive"
        case .standard: "Standard"
        case .bord: "Bord"
        case .kindle: "Kindle"
        }
    }

    /// Vrai quand la disposition pose au moins une zone qui tourne une page.
    public var aDesZonesActives: Bool {
        bandes.contains { $0.role.navigue }
    }

    /// Zones de la disposition, posees dans le repere de l ecran.
    ///
    /// - Parameters:
    ///   - sens: sens de lecture resolu pour la serie. Il oriente les zones.
    ///   - zonesInversees: option Inverser les zones de la section 9. Elle
    ///     echange les deux roles actifs, apres l orientation et jamais avant :
    ///     inverser d abord reviendrait a inverser deux fois en droite a
    ///     gauche, et l option n aurait plus aucun effet visible.
    public func zones(sens: SensDeLecture, zonesInversees: Bool = false) -> [ZoneDeToucher] {
        bandes.map { $0.zone(sens: sens, zonesInversees: zonesInversees) }
    }

    /// Role de la zone qui contient ce point.
    ///
    /// - Parameters:
    ///   - abscisse: part de la largeur, mesuree depuis le bord gauche.
    ///   - ordonnee: part de la hauteur, mesuree depuis le bord haut.
    ///   - sens: sens de lecture resolu pour la serie.
    ///   - zonesInversees: option Inverser les zones.
    /// - Returns: le role de la zone touchee. Un point hors de la surface est
    ///   d abord ramene dans la surface.
    public func role(
        pourAbscisse abscisse: Double,
        ordonnee: Double,
        sens: SensDeLecture,
        zonesInversees: Bool = false
    ) -> RoleDeZone {
        let horizontal = min(max(abscisse, 0), 1)
        let vertical = min(max(ordonnee, 0), 1)

        let touchee = zones(sens: sens, zonesInversees: zonesInversees)
            .first { $0.contient(abscisse: horizontal, ordonnee: vertical) }

        // Aucune disposition ne laisse de trou, la suite de tests le verifie.
        // Le repli reste le menu plutot qu une navigation : un point que
        // personne ne reclame ne doit pas tourner une page.
        return touchee?.role ?? .menu
    }

    /// Bandes de la disposition, dans le repere de la lecture.
    private var bandes: [BandeDeLecture] {
        let part = Self.partDUneBande
        let fin = 1 - part

        switch self {
        case .desactive:
            return [BandeDeLecture(avancement: 0...1, travers: 0...1, role: .menu)]

        case .standard:
            return [
                BandeDeLecture(avancement: 0...part, travers: 0...1, role: .recule),
                BandeDeLecture(avancement: part...fin, travers: 0...1, role: .menu),
                BandeDeLecture(avancement: fin...1, travers: 0...1, role: .avance),
            ]

        case .bord:
            return [
                BandeDeLecture(avancement: 0...part, travers: 0...1, role: .recule),
                BandeDeLecture(avancement: part...fin, travers: 0...part, role: .recule),
                BandeDeLecture(avancement: part...fin, travers: part...fin, role: .menu),
                BandeDeLecture(avancement: part...fin, travers: fin...1, role: .avance),
                BandeDeLecture(avancement: fin...1, travers: 0...1, role: .avance),
            ]

        case .kindle:
            return [
                BandeDeLecture(avancement: 0...1, travers: 0...part, role: .menu),
                BandeDeLecture(avancement: 0...part, travers: part...1, role: .recule),
                BandeDeLecture(avancement: part...1, travers: part...1, role: .avance),
            ]
        }
    }
}

/// Une bande de la disposition, exprimee dans le repere de la lecture.
///
/// L avancement va du debut du chapitre vers sa fin, le travers lui est
/// perpendiculaire. Ni l un ni l autre ne designe un bord d ecran tant que le
/// sens de lecture n est pas applique.
private struct BandeDeLecture {
    let avancement: ClosedRange<Double>
    let travers: ClosedRange<Double>
    let role: RoleDeZone

    /// Bande posee dans le repere de l ecran.
    func zone(sens: SensDeLecture, zonesInversees: Bool) -> ZoneDeToucher {
        let roleRetenu = zonesInversees ? role.inverse : role
        let longueur = avancement.upperBound - avancement.lowerBound
        let epaisseur = travers.upperBound - travers.lowerBound

        switch sens {
        case .gaucheDroite:
            return ZoneDeToucher(
                role: roleRetenu,
                abscisse: avancement.lowerBound,
                ordonnee: travers.lowerBound,
                largeur: longueur,
                hauteur: epaisseur
            )

        case .droiteGauche:
            // L avancement va vers la gauche. La bande se reflete donc sur
            // l axe vertical, et c est sa fin qui donne son bord gauche.
            return ZoneDeToucher(
                role: roleRetenu,
                abscisse: 1 - avancement.upperBound,
                ordonnee: travers.lowerBound,
                largeur: longueur,
                hauteur: epaisseur
            )

        case .hautBas:
            // L axe de lecture devient vertical, le travers devient horizontal.
            return ZoneDeToucher(
                role: roleRetenu,
                abscisse: travers.lowerBound,
                ordonnee: avancement.lowerBound,
                largeur: epaisseur,
                hauteur: longueur
            )
        }
    }
}
