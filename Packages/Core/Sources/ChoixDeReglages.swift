//
// ChoixDeReglages
//
// Les listes de valeurs des lignes de reglage a menu, tableau 6.7 de
// DESIGN-SPEC.md.
//
// Chaque enumeration porte deux representations. Le cas Swift sert au code, la
// representation textuelle est ecrite en base et doit survivre a un renommage.
// `valeurDuDocument` n est jamais affiche : il permet a la suite de tests de
// comparer la liste du code a celle du tableau 6.7 sans la recopier ici.
//

/// Liste de valeurs proposee par une ligne de reglage a menu.
public protocol ChoixDeReglage: RawRepresentable, CaseIterable, Sendable, Hashable where RawValue == String {
    /// Valeur telle que le tableau 6.7 l ecrit.
    var valeurDuDocument: String { get }

    /// Valeur appliquee tant que l utilisateur n a rien choisi.
    static var parDefaut: Self { get }
}

extension ChoixDeReglage {
    /// Representations textuelles de tous les cas, dans l ordre du document.
    public static var valeursPersistees: [String] {
        allCases.map(\.rawValue)
    }

    /// Valeurs du document, dans l ordre du document.
    public static var valeursDuDocument: [String] {
        allCases.map(\.valeurDuDocument)
    }
}

/// Langue de l interface, et langue cible de la traduction.
public enum ChoixDeLangue: String, ChoixDeReglage, Codable {
    case systeme
    case francais
    case english
    case espanol
    case deutsch
    case japonais

    public static let parDefaut = ChoixDeLangue.systeme

    public var valeurDuDocument: String {
        switch self {
        case .systeme: "Systeme"
        case .francais: "Francais"
        case .english: "English"
        case .espanol: "Espanol"
        case .deutsch: "Deutsch"
        case .japonais: "Japonais"
        }
    }

    /// Vrai quand la valeur delegue le choix au systeme.
    ///
    /// La section 5.5 pose la valeur en `accent` dans ce cas, et en
    /// `text.secondary` autrement.
    public var estHeriteDuSysteme: Bool {
        self == .systeme
    }
}

/// Apparence choisie, distincte de l apparence resolue.
///
/// `systeme` n est pas une apparence : c est l absence de choix. La coquille la
/// resout en clair ou en sombre au moment du rendu.
public enum ChoixDApparence: String, ChoixDeReglage, Codable {
    case systeme
    case clair
    case sombre

    public static let parDefaut = ChoixDApparence.systeme

    public var valeurDuDocument: String {
        switch self {
        case .systeme: "Systeme"
        case .clair: "Clair"
        case .sombre: "Sombre"
        }
    }

    public var estHeriteDuSysteme: Bool {
        self == .systeme
    }
}

/// Theme de surfaces choisi, tableau 6.7.
///
/// Les representations textuelles sont celles de `ThemeDeSurface`, qui vit dans
/// le paquet DesignSystem parce qu il porte des couleurs. Le choix, lui, est un
/// reglage persiste, donc il appartient au modele.
public enum ChoixDeTheme: String, ChoixDeReglage, Codable {
    case midnight
    case obsidian
    case slate
    case paper

    public static let parDefaut = ChoixDeTheme.midnight

    public var valeurDuDocument: String {
        switch self {
        case .midnight: "Midnight"
        case .obsidian: "Obsidian"
        case .slate: "Slate"
        case .paper: "Paper"
        }
    }
}

/// Disposition des pages dans le lecteur, tableau 6.7.
public enum MiseEnPage: String, ChoixDeReglage, Codable {
    case pageUnique
    case doublePage
    case continuVertical

    public static let parDefaut = MiseEnPage.pageUnique

    public var valeurDuDocument: String {
        switch self {
        case .pageUnique: "Page unique"
        case .doublePage: "Double page"
        case .continuVertical: "Continu vertical"
        }
    }

    /// Sens de lecture impose par la mise en page, nul quand elle n en impose
    /// aucun.
    ///
    /// Le tableau 6.7 ne propose que deux sens au menu Sens de lecture, alors
    /// que `SensDeLecture` en compte trois. Le sens vertical n est donc pas
    /// choisi directement : il vient de cette mise en page. Les deux reglages
    /// restent distincts en base, le moteur resout la combinaison.
    public var sensImpose: SensDeLecture? {
        self == .continuVertical ? .hautBas : nil
    }

    /// Vrai quand le chapitre suivant se charge sans quitter le lecteur.
    ///
    /// La section 7.4 reserve l enchainement aux modes verticaux, defilement
    /// continu et webtoon, qui sont la meme mise en page ici : le webtoon est un
    /// defilement continu dont les pages sont assez longues pour etre tuilees.
    /// Les modes pagines gardent le lien Chapitre suivant de la barre
    /// inferieure, ou c est l utilisateur qui decide de passer au chapitre
    /// suivant.
    public var enchaineAutomatiquement: Bool {
        self == .continuVertical
    }
}

/// Fond du lecteur, tableau 6.7 et section 1.4.
public enum ChoixDeFondDuLecteur: String, ChoixDeReglage, Codable {
    case noirOled
    case grisSombre
    case blanc
    case sepia

    public static let parDefaut = ChoixDeFondDuLecteur.noirOled

    public var valeurDuDocument: String {
        switch self {
        case .noirOled: "Noir OLED"
        case .grisSombre: "Gris sombre"
        case .blanc: "Blanc"
        case .sepia: "Sepia"
        }
    }
}

/// Delai de suppression d un telechargement apres sa lecture, tableau 6.7.
public enum SuppressionApresLecture: String, ChoixDeReglage, Codable {
    case jamais
    case apres1Jour
    case apres7Jours
    case immediatement

    public static let parDefaut = SuppressionApresLecture.jamais

    public var valeurDuDocument: String {
        switch self {
        case .jamais: "Jamais"
        case .apres1Jour: "Apres 1 jour"
        case .apres7Jours: "Apres 7 jours"
        case .immediatement: "Immediatement"
        }
    }
}

/// Rythme de la sauvegarde automatique, tableau 6.7.
public enum SauvegardeAutomatique: String, ChoixDeReglage, Codable {
    case desactivee
    case chaqueJour
    case chaqueSemaine
    case chaqueMois

    public static let parDefaut = SauvegardeAutomatique.desactivee

    public var valeurDuDocument: String {
        switch self {
        case .desactivee: "Desactivee"
        case .chaqueJour: "Chaque jour"
        case .chaqueSemaine: "Chaque semaine"
        case .chaqueMois: "Chaque mois"
        }
    }
}

/// Qualite des pages telechargees, tableau 6.7.
public enum QualiteDeTelechargement: String, ChoixDeReglage, Codable {
    case originale
    case elevee
    case moyenne

    public static let parDefaut = QualiteDeTelechargement.originale

    public var valeurDuDocument: String {
        switch self {
        case .originale: "Originale"
        case .elevee: "Elevee"
        case .moyenne: "Moyenne"
        }
    }
}
