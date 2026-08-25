import Core

//
// BudgetDeDecodage
//
// Plafond memoire d une page decodee pour l affichage.
//
// Ajuster la page a la zone ne suffit pas. Sur un ecran dense, une zone de
// 1600 par 2400 pixels reels reclamerait 15 Mo par page, et six pages en cache
// depasseraient deja la moitie du budget de lecture de la section 12. Le budget
// borne donc le cote demande au decodeur, en plus de l ajustement.
//
// La contrepartie est assumee : au dela du budget, la page affichee est
// legerement plus douce que la zone ne le permettrait. La nettete revient par
// la pleine resolution du zoom actif, portee par ReserveDeZoom.
//

/// Plafond memoire applique a une page decodee pour l affichage.
public struct BudgetDeDecodage: Sendable, Hashable {
    /// Nombre d octets qu une page decodee doit rester strictement sous.
    public let octetsParPage: Int

    /// Construit un budget, en refusant un plafond plus petit qu une vignette.
    public init(octetsParPage: Int) {
        self.octetsParPage = max(Self.plancher, octetsParPage)
    }

    /// Budget applique quand l appelant n en impose pas d autre.
    ///
    /// Douze millions d octets, et non douze mebioctets. Le critere de la
    /// fonctionnalite parle de douze megaoctets sans trancher entre les deux
    /// conventions, cette valeur passe sous la plus stricte des deux.
    public static let parDefaut = BudgetDeDecodage(octetsParPage: 12_000_000)

    /// Plus petit plafond accepte, celui d une vignette de 64 par 64.
    private static let plancher = 64 * 64 * 4

    /// Cote maximal a demander au decodeur pour tenir sous le plafond.
    ///
    /// - Parameters:
    ///   - page: dimensions annoncees par le fichier.
    ///   - cote: cote deja retenu par l ajustement a la zone d affichage.
    /// - Returns: le plus petit des deux cotes, jamais inferieur a un pixel.
    public func coteMaximal(pour page: TailleEnPixels, sansDepasser cote: Int) -> Int {
        guard cote > 0 else { return 1 }
        guard page.estVide == false else { return cote }

        var retenu = min(cote, coteEstime(pour: page))

        // L estimation raisonne en pixels, Core Graphics alloue des lignes
        // alignees. On redescend tant que le compte reel touche le plafond.
        while retenu > 1, Self.octetsOccupes(cote: retenu, page: page) >= octetsParPage {
            retenu -= 1
        }

        return max(1, retenu)
    }

    /// Cote sous lequel la surface decodee tient dans le plafond.
    ///
    /// Une page de cote maximal `c` et de ratio `r` occupe `c * c / r * 4`
    /// octets, d ou la racine.
    private func coteEstime(pour page: TailleEnPixels) -> Int {
        let grand = Double(page.plusGrandCote)
        let petit = Double(min(page.largeur, page.hauteur))
        let surface = Double(octetsParPage) * grand / (4 * petit)

        return max(1, Int(surface.squareRoot()))
    }

    /// Octets occupes par une page ramenee a ce cote, alignement compris.
    static func octetsOccupes(cote: Int, page: TailleEnPixels) -> Int {
        octetsOccupes(par: reduction(de: page, vers: cote))
    }

    /// Octets occupes par une matrice de cette taille, alignement compris.
    ///
    /// Majore toujours ce que Core Graphics alloue reellement. Un test compare
    /// les deux sur des images produites, pour que le modele ne se mette jamais
    /// a mentir sous la realite.
    static func octetsOccupes(par taille: TailleEnPixels) -> Int {
        octetsParLigne(largeur: taille.largeur) * taille.hauteur
    }

    /// Dimensions de la page une fois son plus grand cote ramene a `cote`.
    static func reduction(de page: TailleEnPixels, vers cote: Int) -> TailleEnPixels {
        guard page.estVide == false, cote > 0 else { return .nulle }

        let facteur = Double(cote) / Double(page.plusGrandCote)

        return TailleEnPixels(
            largeur: max(1, Int((Double(page.largeur) * facteur).rounded())),
            hauteur: max(1, Int((Double(page.hauteur) * facteur).rounded()))
        )
    }

    /// Octets d une ligne de pixels RGBA, arrondis a l alignement de Core Graphics.
    ///
    /// Core Graphics choisit lui meme la longueur de ligne et ne la documente
    /// pas. On modelise 128 octets, plus large que l alignement observe, pour
    /// que l estimation majore toujours l allocation reelle. Le prix est de
    /// quelques pixels en moins sur la page decodee, ce qui ne se voit pas.
    private static func octetsParLigne(largeur: Int) -> Int {
        let bruts = largeur * 4
        let alignement = 128

        return (bruts + alignement - 1) / alignement * alignement
    }
}
