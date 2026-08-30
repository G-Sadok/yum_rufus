//
// TraductionDeBulle
//
// Une bulle et le texte traduit qui vient se poser dessus, section 8 du cahier
// de developpement.
//
// Le type garde la bulle d origine entiere plutot que son seul rectangle. La
// surimpression a besoin des deux textes : le traduit pour l afficher, celui
// d origine pour l etiquette d accessibilite et pour la comparaison quand
// l utilisateur veut revoir ce que la page disait. Les separer aurait oblige a
// les reapparier plus loin, sur un index de tableau, qui est exactement le genre
// d appariement qui se decale d un cran sans que rien ne le signale.
//
// Le moteur employe est garde lui aussi. Ce n est pas une trace de debogage :
// une page traduite dans le nuage et une page traduite sur l appareil ne
// donnent pas les memes droits ni la meme mention a l ecran, et la reponse doit
// suivre le resultat plutot que d etre relue dans les reglages, qui ont pu
// changer depuis.
//

/// Bulle traduite, prete a etre posee en surimpression.
public struct TraductionDeBulle: Sendable, Equatable, Hashable {
    /// Bulle d origine, avec son rectangle et son texte lu.
    public let bulle: BulleDeTexte

    /// Texte traduit, dans la langue cible.
    public let texteTraduit: String

    /// Langue vers laquelle la bulle a ete traduite.
    public let langueCible: ChoixDeLangue

    /// Moteur qui a reellement produit ce texte.
    public let moteur: ChoixDeMoteurDeTraduction

    public init(
        bulle: BulleDeTexte,
        texteTraduit: String,
        langueCible: ChoixDeLangue,
        moteur: ChoixDeMoteurDeTraduction
    ) {
        self.bulle = bulle
        self.texteTraduit = texteTraduit
        self.langueCible = langueCible
        self.moteur = moteur
    }

    /// Rectangle de la bulle, en parts de la planche.
    public var cadre: CaseDePage {
        bulle.cadre
    }

    /// Texte lu dans la planche, avant traduction.
    public var texteDOrigine: String {
        bulle.texte
    }

    /// Vrai quand le texte traduit est identique au texte lu.
    ///
    /// Le cas arrive quand la langue cible est deja celle de la planche, et il
    /// se traite a l affichage : poser une surimpression qui redit ce que la
    /// bulle dit deja masque le dessin pour rien.
    public var estInchangee: Bool {
        texteTraduit == texteDOrigine
    }
}

extension SensDeLecture {
    /// Bulles traduites rangees dans l ordre ou elles se lisent.
    ///
    /// Le rangement se fait a la lecture et non a la production, pour la meme
    /// raison que celui des cases : le sens ne change pas ce que la detection
    /// trouve ni ce que le moteur traduit, il ne change que l ordre, et le
    /// faire entrer dans la cle de cache relancerait tout le travail au premier
    /// changement de sens en cours de lecture.
    public func ordonnerLesTraductions(_ traductions: [TraductionDeBulle]) -> [TraductionDeBulle] {
        guard traductions.count > 1 else { return traductions }

        var parBulle = Dictionary(grouping: traductions, by: \.bulle)

        return ordonnerLesBulles(traductions.map(\.bulle)).compactMap { bulle in
            guard var restantes = parBulle[bulle], restantes.isEmpty == false else {
                return nil
            }

            let premiere = restantes.removeFirst()
            parBulle[bulle] = restantes

            return premiere
        }
    }
}
