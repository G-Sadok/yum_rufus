//
// VarianteDeLigneDeReglage
//
// Les cinq variantes de la ligne de reglage, section 4.1 de DESIGN-SPEC.md, et
// les deux formes de sa variante premium.
//
// La variante appartient au modele et non a la vue : c est elle qui decide ce
// qu une ligne persiste. Un interrupteur ecrit un booleen, un curseur un
// nombre, une ligne de navigation n ecrit rien. La couche vue se contente de
// dessiner ce que la variante annonce.
//

/// Ce qu une ligne de reglage porte a droite de son libelle, section 4.1.
public enum VarianteDeLigneDeReglage: String, Sendable, Codable, CaseIterable, Hashable {
    /// Commutateur 48 par 28, pour un reglage a deux etats.
    case interrupteur

    /// Valeur alignee a droite, suivie du chevron double qui ouvre le menu.
    ///
    /// Une ligne dont la liste de choix est vide affiche sa valeur sans
    /// chevron : le document interdit un chevron qui n ouvre rien.
    case valeurEtMenu

    /// Chevron simple vers la droite, qui mene a un autre ecran.
    case navigation

    /// Libelle et valeur sur la premiere ligne, curseur sur la seconde.
    case curseur

    /// Valeur suivie de deux chevrons empiles, pour un entier borne.
    case compteur

    /// Nom de la variante tel que la section 4.1 l ecrit.
    ///
    /// Il ne s affiche jamais. Il existe pour que la suite de tests compare la
    /// liste du code a celle du document sans la recopier.
    public var nomDuDocument: String {
        switch self {
        case .interrupteur: "Interrupteur"
        case .valeurEtMenu: "Valeur et menu"
        case .navigation: "Navigation"
        case .curseur: "Curseur"
        case .compteur: "Compteur"
        }
    }
}

/// Forme premium posee sur une ligne de reglage, section 4.1.
///
/// Les deux formes partagent le fond `surface.premium` et le libelle en accent.
/// Elles different par ce qu elles portent a droite et par ce que le clic
/// declenche.
public enum FormeDeLignePremium: String, Sendable, Codable, CaseIterable, Hashable {
    /// Appel a l abonnement : couronne a gauche, chevron simple a droite.
    case appelALAbonnement

    /// Fonction verrouillee : icone de la fonction a gauche, couronne a droite,
    /// aucun controle. Le clic ouvre le mur premium, pas le reglage.
    case fonctionVerrouillee

    /// Vrai quand la ligne remplace son controle par une couronne.
    public var remplaceLeControle: Bool {
        self == .fonctionVerrouillee
    }
}

/// Bornes d un reglage numerique, curseur ou compteur.
public struct BornesDeReglage: Sendable, Codable, Equatable, Hashable {
    /// Valeur la plus basse acceptee.
    public let minimum: Double
    /// Valeur la plus haute acceptee.
    public let maximum: Double
    /// Increment entre deux valeurs consecutives.
    public let pas: Double

    public init(minimum: Double, maximum: Double, pas: Double) {
        self.minimum = minimum
        self.maximum = maximum
        self.pas = pas
    }

    /// Valeur ramenee entre les deux bornes.
    public func contraindre(_ valeur: Double) -> Double {
        min(max(valeur, minimum), maximum)
    }

    /// Bornes du curseur de luminosite et de tout reglage exprime en pourcent.
    public static let pourcentage = BornesDeReglage(minimum: 0, maximum: 100, pas: 1)
}
