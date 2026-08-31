//
// SectionDeReglages
//
// Les dix sept sections de l ecran Reglages, section 5.5 de DESIGN-SPEC.md,
// dans l ordre exact du tableau.
//
// L ordre est celui de `allCases`, donc celui de la declaration. Il n est
// recalcule nulle part et ne depend d aucun tri : deplacer un cas deplace la
// section a l ecran, et la suite de tests compare cet ordre au document.
//
// Les rangs 4 et 9 portent le meme nom, Bibliotheque. Le 4 regle le tri, le 9
// regle le comportement. Leurs cas Swift les distinguent, leurs descriptions
// les distinguent a l ecran.
//

/// Une section de l ecran Reglages, section 5.5.
public enum SectionDeReglages: String, Sendable, Codable, CaseIterable, Hashable {
    case confidentialite
    case general
    case bibliothequeTri
    case traduction
    case lecteur
    case prereglagesDeLecture
    case comportementDuLecteur
    case bibliothequeComportement
    case pontNavigateur
    case suivis
    case telechargements
    case sauvegardeEtRestauration
    case iCloud
    case stockage
    case assistance
    case aPropos

    /// Rang de la section dans le tableau de la section 5.5, de 1 a 17.
    public var rang: Int {
        (Self.allCases.firstIndex(of: self) ?? 0) + 1
    }

    /// Nom de la section tel que le document l ecrit, jamais affiche.
    ///
    /// Le libelle visible vient du catalogue de chaines. Ce nom sert a la suite
    /// de tests, qui compare la liste du code au tableau de la section 5.5 sans
    /// le recopier.
    public var nomDuDocument: String {
        switch self {
        case .confidentialite: "Confidentialite"
        case .general: "General"
        case .bibliothequeTri: "Bibliotheque"
        case .traduction: "Traduction"
        case .lecteur: "Lecteur"
        case .prereglagesDeLecture: "Prereglages de lecture"
        case .comportementDuLecteur: "Comportement du lecteur"
        case .bibliothequeComportement: "Bibliotheque"
        case .pontNavigateur: "Pont navigateur"
        case .suivis: "Suivis"
        case .telechargements: "Telechargements"
        case .sauvegardeEtRestauration: "Sauvegarde et restauration"
        case .iCloud: "iCloud"
        case .stockage: "Stockage"
        case .assistance: "Assistance"
        case .aPropos: "A propos"
        }
    }

    /// Lignes de la section, dans l ordre du tableau de la section 5.5.
    public var lignes: [LigneDeReglage] {
        CatalogueDeReglages.lignes(de: self)
    }
}
