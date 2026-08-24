//
// ReglageDeSensDeLecture
//
// Reglage global du sens de lecture et regle de resolution entre ce reglage
// et la surcharge portee par une serie.
//

/// Reglage global du sens de lecture, tel qu il est persiste.
///
/// Le reglage est unique pour toute l application. Il vit dans une table d une
/// seule ligne plutot que dans `UserDefaults` pour trois raisons : la
/// synchronisation iCloud de l etape 10 replique la base et pas les
/// preferences, une lecture de reglage et une lecture de serie se font alors
/// dans la meme transaction, et un test peut le poser sans toucher a l etat du
/// systeme.
///
/// La surcharge par serie vit dans `Manga.sensLectureForce`. La resolution
/// entre les deux est ecrite ici, une seule fois, pour qu aucune couche ne la
/// reinvente a sa facon.
public struct ReglageDeSensDeLecture: Sendable, Codable, Hashable, Identifiable {
    /// Identifiant de la ligne unique. Le reglage etant global, la table n en
    /// contient jamais d autre.
    public static let identifiantDeLaLigneUnique = 1

    public var id: Int
    public var sensGlobal: SensDeLecture

    public init(
        id: Int = Self.identifiantDeLaLigneUnique,
        sensGlobal: SensDeLecture = .parDefaut
    ) {
        self.id = id
        self.sensGlobal = sensGlobal
    }

    /// Sens applique quand la serie porte la surcharge indiquee.
    ///
    /// Une surcharge absente laisse le reglage global decider. Rien n est
    /// devine a partir de la langue de la serie, du titre ou de la source :
    /// une valeur absente reste absente.
    public func sens(surchargeDeSerie surcharge: SensDeLecture?) -> SensDeLecture {
        surcharge ?? sensGlobal
    }

    /// Sens applique a une serie donnee.
    public func sens(pour manga: Manga) -> SensDeLecture {
        sens(surchargeDeSerie: manga.sensLectureForce)
    }
}
