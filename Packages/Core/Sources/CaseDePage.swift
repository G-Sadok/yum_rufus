//
// CaseDePage
//
// Une case detectee dans une planche, et l ordre dans lequel les cases se
// lisent, section 8 du cahier de developpement.
//
// La geometrie vit dans Core pour la meme raison que `DispositionDeZones` et
// `MoitieDImageLarge` : trois couches en ont besoin. Le detecteur du paquet
// Intelligence produit les cases, le moteur de lecture les parcourt, la vue les
// cadre pendant le zoom. Une seconde copie de la regle d ordre divergerait tot
// ou tard, et l ecart ne se verrait qu en droite a gauche, la ou personne ne
// relit.
//
// Les quatre coordonnees sont des fractions de la planche, mesurees depuis le
// bord gauche et depuis le bord haut, quel que soit le sens de lecture et
// quelle que soit la direction de l interface. Rien n est retourne a la
// production : une case deja retournee pour le sens droite a gauche le serait
// une seconde fois par la vue, et le defaut serait invisible en francais.
//
// L ordre de lecture est la seule chose que le sens gouverne ici. Il se
// construit en deux temps, comme un oeil lit une planche. Les cases sont
// d abord regroupees en bandes horizontales, une bande accueillant toute case
// dont le centre tombe encore dans sa hauteur. Chaque bande est ensuite
// parcourue transversalement, en partant du bord ou la lecture commence.
//
// Ce decoupage traite le cas qui casse les tris naifs, la case haute posee
// contre deux cases empilees. Un tri par ordonnee seule la lirait entre les
// deux, un tri par abscisse seule la lirait apres les deux. Le regroupement en
// bande la garde avec elles, et le parcours transversal la donne en premier en
// droite a gauche, ce qui est l ordre reel de lecture.
//

/// Case detectee dans une planche, en parts de la planche.
public struct CaseDePage: Sendable, Equatable, Hashable {
    /// Bord gauche, en part de la largeur de la planche.
    public let abscisse: Double

    /// Bord haut, en part de la hauteur de la planche.
    public let ordonnee: Double

    /// Largeur, en part de la largeur de la planche.
    public let largeur: Double

    /// Hauteur, en part de la hauteur de la planche.
    public let hauteur: Double

    /// Confiance rendue par le detecteur, de zero a un.
    public let confiance: Double

    /// Tolerance admise sur les bords, en part de la planche.
    ///
    /// Un detecteur rend des coordonnees flottantes, et une case qui touche le
    /// bord de la planche ressort reguliserement a un plus un millioniemme. La
    /// refuser pour cela seul reviendrait a perdre une case parfaitement
    /// detectee, alors que le depassement est sous le pixel.
    static let toleranceDeBord = 0.001

    /// Construit une case, ou rend nil quand elle ne tient pas dans la planche.
    ///
    /// La validation est au constructeur et non a l usage : une case qui ment
    /// sur sa position produirait un cadrage de zoom hors de la page, et le
    /// defaut se verrait a l ecran sans qu aucune trace ne dise d ou il vient.
    public init?(
        abscisse: Double,
        ordonnee: Double,
        largeur: Double,
        hauteur: Double,
        confiance: Double = 1
    ) {
        let tolerance = Self.toleranceDeBord

        guard largeur > 0,
              hauteur > 0,
              abscisse >= -tolerance,
              ordonnee >= -tolerance,
              abscisse + largeur <= 1 + tolerance,
              ordonnee + hauteur <= 1 + tolerance,
              confiance >= 0,
              confiance <= 1
        else {
            return nil
        }

        self.abscisse = abscisse
        self.ordonnee = ordonnee
        self.largeur = largeur
        self.hauteur = hauteur
        self.confiance = confiance
    }

    /// Construit une case sans verifier ses bornes.
    ///
    /// Reserve aux valeurs que ce fichier calcule lui meme et dont il connait
    /// deja les bornes, la planche entiere et le cadrage elargi.
    private init(
        abscisseSure: Double,
        ordonneeSure: Double,
        largeurSure: Double,
        hauteurSure: Double,
        confiance: Double
    ) {
        abscisse = abscisseSure
        ordonnee = ordonneeSure
        largeur = largeurSure
        hauteur = hauteurSure
        self.confiance = confiance
    }

    /// La planche entiere prise comme une seule case.
    ///
    /// C est la valeur de repli du detecteur. Une planche sans case detectee
    /// reste lisible : la navigation case par case s y comporte alors comme la
    /// navigation par pages, ce qui est exactement ce que l utilisateur attend
    /// d une page qui n a pas de decoupage lisible.
    public static let plancheEntiere = CaseDePage(
        abscisseSure: 0,
        ordonneeSure: 0,
        largeurSure: 1,
        hauteurSure: 1,
        confiance: 1
    )

    /// Bord droit de la case.
    public var bordDroit: Double {
        abscisse + largeur
    }

    /// Bord bas de la case.
    public var bordBas: Double {
        ordonnee + hauteur
    }

    /// Ordonnee du centre de la case.
    public var centreVertical: Double {
        ordonnee + hauteur / 2
    }

    /// Abscisse du centre de la case.
    public var centreHorizontal: Double {
        abscisse + largeur / 2
    }

    /// Surface de la case, en part de la planche.
    public var surface: Double {
        largeur * hauteur
    }

    /// Cadrage du zoom sur cette case, marge comprise, borne a la planche.
    ///
    /// La marge existe parce qu une case cadree au trait pres se lit mal : le
    /// bord du cadre touche alors le bord de l ecran, et le lecteur perd le
    /// reperage qui lui dit ou il se trouve dans la planche.
    ///
    /// - Parameter marge: part de la planche ajoutee de chaque cote.
    public func elargie(de marge: Double) -> CaseDePage {
        guard marge > 0 else { return self }

        let gauche = max(0, abscisse - marge)
        let haut = max(0, ordonnee - marge)
        let droite = min(1, bordDroit + marge)
        let bas = min(1, bordBas + marge)

        return CaseDePage(
            abscisseSure: gauche,
            ordonneeSure: haut,
            largeurSure: droite - gauche,
            hauteurSure: bas - haut,
            confiance: confiance
        )
    }

    /// Part de surface commune aux deux cases, rapportee a leur union.
    ///
    /// Sert a reconnaitre deux detections de la meme case. Un detecteur en rend
    /// souvent plusieurs pour un meme cadre, et deux cases superposees
    /// ajouteraient une etape de navigation qui ne mene nulle part.
    public func intersectionSurUnion(_ autre: CaseDePage) -> Double {
        let largeurCommune = max(0, min(bordDroit, autre.bordDroit) - max(abscisse, autre.abscisse))
        let hauteurCommune = max(0, min(bordBas, autre.bordBas) - max(ordonnee, autre.ordonnee))
        let commune = largeurCommune * hauteurCommune
        let union = surface + autre.surface - commune

        guard union > 0 else { return 0 }

        return commune / union
    }
}

extension SensDeLecture {
    /// Largeur d une colonne de tri, en part de la planche.
    ///
    /// Deux cases empilees dans la meme colonne ne sont jamais alignees au
    /// millieme pres sur une planche reelle. Sans ce pas, l une passerait pour
    /// une colonne distincte de l autre et la bande se lirait en escalier.
    /// Deux pour cent de la largeur valent une vingtaine de pixels sur une
    /// planche courante, soit moins qu une gouttiere et plus qu un ecart de
    /// detection.
    static var pasDeColonne: Double {
        0.02
    }

    /// Cases rangees dans l ordre ou elles se lisent, selon ce sens.
    ///
    /// L ordre est total et deterministe : deux appels sur le meme jeu de cases
    /// rendent la meme suite, quel que soit l ordre d arrivee. Le detecteur ne
    /// promet aucun ordre de sortie, et une navigation qui changerait de
    /// parcours d une ouverture a l autre serait pire qu une navigation par
    /// pages.
    public func ordonner(_ cases: [CaseDePage]) -> [CaseDePage] {
        guard cases.count > 1 else { return cases }

        return bandes(de: cases).flatMap { bande in
            bande.sorted(by: seLitAvantDansSaBande)
        }
    }

    /// Bandes horizontales, du haut de la planche vers le bas.
    ///
    /// Une case rejoint la bande en cours quand son centre tombe encore dans la
    /// hauteur deja couverte par la bande. Le critere porte sur le centre et non
    /// sur le bord haut : une case dont seul le sommet mord sur la bande
    /// precedente appartient a la suivante, et c est bien ainsi qu elle se lit.
    private func bandes(de cases: [CaseDePage]) -> [[CaseDePage]] {
        let triees = cases.sorted(by: seRencontreAvant)

        var bandes: [[CaseDePage]] = []
        var courante: [CaseDePage] = []
        var bas = 0.0

        for element in triees {
            if courante.isEmpty || element.centreVertical < bas {
                courante.append(element)
                bas = max(bas, element.bordBas)
            } else {
                bandes.append(courante)
                courante = [element]
                bas = element.bordBas
            }
        }

        if courante.isEmpty == false {
            bandes.append(courante)
        }

        return bandes
    }

    /// Ordre dans lequel les cases sont rencontrees avant le decoupage en
    /// bandes : du haut de la planche vers le bas, puis du bord de depart.
    private func seRencontreAvant(_ premiere: CaseDePage, _ seconde: CaseDePage) -> Bool {
        departage(
            premiere,
            seconde,
            par: [
                { $0.ordonnee },
                { [self] in transversale($0) },
                { $0.abscisse },
                { $0.largeur },
            ]
        )
    }

    /// Ordre de parcours d une bande, dans le sens de lecture.
    ///
    /// La colonne vient en premier, arrondie au pas de colonne, puis
    /// l ordonnee, qui range deux cases de la meme colonne du haut vers le bas.
    /// Les deux dernieres mesures ne servent qu a rendre l ordre total, pour que
    /// deux cases de meme position ne dependent pas de la stabilite du tri.
    private func seLitAvantDansSaBande(_ premiere: CaseDePage, _ seconde: CaseDePage) -> Bool {
        departage(
            premiere,
            seconde,
            par: [
                { [self] in (transversale($0) / Self.pasDeColonne).rounded() },
                { $0.ordonnee },
                { $0.abscisse },
                { $0.largeur },
            ]
        )
    }

    /// Compare deux cases mesure par mesure, la premiere qui les separe
    /// tranchant.
    ///
    /// L ordre obtenu est total et strict, ce que le tri exige : deux cases que
    /// toutes les mesures egalent ne sont declarees inferieures ni dans un sens
    /// ni dans l autre.
    private func departage(
        _ premiere: CaseDePage,
        _ seconde: CaseDePage,
        par mesures: [(CaseDePage) -> Double]
    ) -> Bool {
        for mesure in mesures {
            let gauche = mesure(premiere)
            let droite = mesure(seconde)

            if gauche != droite {
                return gauche < droite
            }
        }

        return false
    }

    /// Distance entre le bord ou la lecture commence et le bord d attaque de la
    /// case.
    ///
    /// En droite a gauche, la lecture commence au bord droit de la planche, la
    /// distance se mesure donc depuis ce bord. Le sens vertical range ses cases
    /// de gauche a droite, comme tout ce que le sens horizontal ne gouverne pas.
    private func transversale(_ element: CaseDePage) -> Double {
        commenceParLaDroite ? 1 - element.bordDroit : element.abscisse
    }
}
