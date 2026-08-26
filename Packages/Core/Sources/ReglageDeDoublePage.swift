//
// ReglageDeDoublePage
//
// Decalage de couverture du mode double page, tel qu il est persiste, et regle
// de resolution entre le reglage global et la surcharge portee par une serie.
//

/// Decalage applique avant la premiere paire du mode double page.
///
/// La composition en paires a une periode de deux : decaler de deux pages
/// redonne exactement les memes paires que ne pas decaler du tout. Un decalage
/// n a donc que deux valeurs utiles, et les exprimer en cas plutot qu en entier
/// evite qu une valeur abimee en base produise une pagination que personne ne
/// sait relire.
///
/// Le tableau 7.1 du cahier de developpement decrit le mode double page par
/// deux contraintes : ordre inverse en droite a gauche, et couverture seule.
/// La seconde est la valeur par defaut de ce reglage.
public enum DecalageDeCouverture: Int, Sendable, Codable, CaseIterable, Hashable {
    /// Les paires commencent a la premiere page. Aucune page isolee en tete.
    case aucun = 0

    /// La premiere page est affichee seule, les paires commencent a la seconde.
    case couvertureSeule = 1

    /// Valeur appliquee tant que ni la serie ni le reglage global ne tranchent.
    public static let parDefaut = DecalageDeCouverture.couvertureSeule

    /// Nombre de pages affichees seules avant la premiere paire.
    public var pagesAvantLaPremierePaire: Int {
        rawValue
    }

    /// Decalage equivalent a un nombre de pages quelconque.
    ///
    /// La periode etant de deux, un decalage de trois pages compose les memes
    /// paires qu un decalage d une page. La reduction modulo deux accepte aussi
    /// les valeurs negatives, qu un calcul en amont peut produire sans que cela
    /// signifie autre chose.
    public static func normalise(_ pages: Int) -> DecalageDeCouverture {
        let reste = ((pages % 2) + 2) % 2

        return reste == 0 ? .aucun : .couvertureSeule
    }
}

/// Reglage global du decalage de couverture, tel qu il est persiste.
///
/// Il vit dans une table d une seule ligne pour les memes raisons que
/// `ReglageDeSensDeLecture` : la synchronisation iCloud replique la base et pas
/// les preferences, la lecture du reglage et celle de la serie tiennent dans la
/// meme transaction, et un test peut le poser sans toucher a l etat du systeme.
///
/// La surcharge par serie vit dans `Manga.decalageDeCouvertureForce`. La
/// resolution entre les deux est ecrite ici, une seule fois.
public struct ReglageDeDoublePage: Sendable, Codable, Hashable, Identifiable {
    /// Identifiant de la ligne unique. Le reglage etant global, la table n en
    /// contient jamais d autre.
    public static let identifiantDeLaLigneUnique = 1

    public var id: Int
    public var decalageGlobal: DecalageDeCouverture

    public init(
        id: Int = Self.identifiantDeLaLigneUnique,
        decalageGlobal: DecalageDeCouverture = .parDefaut
    ) {
        self.id = id
        self.decalageGlobal = decalageGlobal
    }

    /// Decalage applique quand la serie porte la surcharge indiquee.
    ///
    /// Une surcharge absente laisse le reglage global decider. Rien n est
    /// devine a partir du nombre de pages ou de la forme de la premiere image :
    /// une valeur absente reste absente.
    public func decalage(surchargeDeSerie surcharge: DecalageDeCouverture?) -> DecalageDeCouverture {
        surcharge ?? decalageGlobal
    }

    /// Decalage applique a une serie donnee.
    public func decalage(pour manga: Manga) -> DecalageDeCouverture {
        decalage(surchargeDeSerie: manga.decalageDeCouvertureForce)
    }
}
