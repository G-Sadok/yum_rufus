//
// BulleDeTexte
//
// Une bulle reperee dans une planche, et le texte qu elle porte, section 8 du
// cahier de developpement.
//
// La geometrie est celle de `CaseDePage`, reprise telle quelle plutot que
// recopiee. Les deux objets sont des rectangles exprimes en parts de la planche,
// mesures depuis le bord gauche et depuis le bord haut, et ils partagent les
// trois regles qui comptent : la validation au constructeur, le recouvrement qui
// reconnait deux detections du meme objet, et l ordre de lecture qui depend du
// sens de la serie. Une seconde copie de ces regles divergerait, et l ecart ne
// se verrait qu en droite a gauche.
//
// Le texte est celui que la detection a lu, jamais celui que la traduction a
// produit. Les deux vivent dans deux types distincts parce qu ils n ont pas la
// meme duree de vie : le texte lu ne depend que de la planche, le texte traduit
// depend en plus de la langue cible et du moteur, et les deux ne se mettent donc
// pas en cache sous la meme cle.
//

/// Bulle reperee dans une planche, avec le texte qu elle porte.
public struct BulleDeTexte: Sendable, Equatable, Hashable {
    /// Rectangle de la bulle, en parts de la planche.
    public let cadre: CaseDePage

    /// Texte lu dans la bulle, dans la langue d origine.
    public let texte: String

    /// Construit une bulle, ou rend nil quand elle ne porte aucun texte.
    ///
    /// Une bulle vide n est pas une erreur de detection, c est une bulle de
    /// dessin, un fond de case ou un cadre sans lettre. La refuser ici evite
    /// qu elle ne produise plus loin une surimpression qui masquerait le dessin
    /// sans rien apporter.
    public init?(cadre: CaseDePage, texte: String) {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)

        guard propre.isEmpty == false else { return nil }

        self.cadre = cadre
        self.texte = propre
    }

    /// Confiance rendue par la detection, de zero a un.
    public var confiance: Double {
        cadre.confiance
    }

    /// Rectangle de la bulle en points, dans une planche de cette taille.
    ///
    /// La conversion se fait ici et nulle part ailleurs. Les coordonnees sont
    /// des fractions precisement pour traverser tous les niveaux de decodage
    /// sans conversion, et une seconde formule de passage en points aurait sa
    /// propre facon de se tromper d un demi point.
    ///
    /// - Parameters:
    ///   - largeur: largeur de la planche affichee, en points.
    ///   - hauteur: hauteur de la planche affichee, en points.
    public func cadreEnPoints(largeur: Double, hauteur: Double) -> CadreEnPoints {
        CadreEnPoints(
            abscisse: cadre.abscisse * largeur,
            ordonnee: cadre.ordonnee * hauteur,
            largeur: cadre.largeur * largeur,
            hauteur: cadre.hauteur * hauteur
        )
    }
}

/// Rectangle exprime en points, dans le repere de la planche affichee.
public struct CadreEnPoints: Sendable, Equatable, Hashable {
    /// Bord gauche, en points depuis le bord gauche de la planche.
    public let abscisse: Double

    /// Bord haut, en points depuis le bord haut de la planche.
    public let ordonnee: Double

    /// Largeur, en points.
    public let largeur: Double

    /// Hauteur, en points.
    public let hauteur: Double

    public init(abscisse: Double, ordonnee: Double, largeur: Double, hauteur: Double) {
        self.abscisse = abscisse
        self.ordonnee = ordonnee
        self.largeur = largeur
        self.hauteur = hauteur
    }

    /// Vrai quand le rectangle n a aucune surface.
    public var estVide: Bool {
        largeur <= 0 || hauteur <= 0
    }
}

extension SensDeLecture {
    /// Bulles rangees dans l ordre ou elles se lisent, selon ce sens.
    ///
    /// L ordre est celui des cases, et c est voulu : une planche se lit bulle
    /// apres bulle comme elle se lit case apres case, en bandes horizontales
    /// parcourues depuis le bord ou la lecture commence. Une seconde regle
    /// d ordre aurait fini par contredire la premiere sur les planches ou les
    /// deux objets se superposent, qui sont toutes les planches.
    ///
    /// Le nom differe de celui des cases plutot que de le surcharger. Deux
    /// surcharges que seul le type d element separe rendent `ordonner([])`
    /// ambigu, et le compilateur refuse alors un appel parfaitement clair pour
    /// qui le lit.
    public func ordonnerLesBulles(_ bulles: [BulleDeTexte]) -> [BulleDeTexte] {
        guard bulles.count > 1 else { return bulles }

        // Le regroupement est consomme au fur et a mesure. Deux bulles au meme
        // cadre sont rares mais possibles, une planche pouvant porter deux
        // lectures du meme rectangle, et les confondre en perdrait une.
        var parCadre = Dictionary(grouping: bulles, by: \.cadre)

        return ordonner(bulles.map(\.cadre)).compactMap { cadre in
            guard var restantes = parCadre[cadre], restantes.isEmpty == false else {
                return nil
            }

            let premiere = restantes.removeFirst()
            parCadre[cadre] = restantes

            return premiere
        }
    }
}
