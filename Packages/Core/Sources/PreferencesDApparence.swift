//
// PreferencesDApparence
//
// Les deux reglages qui gouvernent la peinture de toute l application, lignes
// Apparence et Theme de la section 3 du tableau de la section 5.5.
//
// Ils voyagent ensemble parce qu ils se resolvent ensemble : une palette n a de
// sens que pour un couple theme et apparence. Les separer obligerait chaque
// appelant a les rassembler, et laisserait la porte ouverte a un ecran repeint
// avec le theme neuf et l apparence d avant.
//
// Le type reste dans Core, sans la moindre couleur : il ne dit pas a quoi
// ressemble un theme, il dit lequel l utilisateur a choisi.
//

/// Choix de theme et d apparence retenus par l utilisateur.
public struct PreferencesDApparence: Sendable, Equatable, Hashable {
    /// Theme de surfaces choisi, tableau 6.7.
    public let theme: ChoixDeTheme

    /// Apparence choisie, `systeme` tant que l utilisateur suit le systeme.
    public let apparence: ChoixDApparence

    public init(theme: ChoixDeTheme = .parDefaut, apparence: ChoixDApparence = .parDefaut) {
        self.theme = theme
        self.apparence = apparence
    }

    /// Preferences d une installation neuve, ou rien n a jamais ete choisi.
    public static let parDefaut = PreferencesDApparence()
}

extension ReglagesDeLApplication {
    /// Theme et apparence lus dans les reglages.
    ///
    /// Une valeur absente ou devenue illisible retombe sur le defaut du
    /// catalogue, comme toute autre ligne : l application se repeint toujours,
    /// meme apres une ecriture corrompue.
    public var preferencesDApparence: PreferencesDApparence {
        PreferencesDApparence(
            theme: choix(.theme, comme: ChoixDeTheme.self),
            apparence: choix(.apparence, comme: ChoixDApparence.self)
        )
    }
}
