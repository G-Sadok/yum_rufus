import ImagePipeline

//
// PileDeTuiles
//
// Geometrie des tuiles dans la pile du mode webtoon, sections 7.1 et 7.3 du
// cahier de developpement.
//
// La pile de pages de F040 dit ou commence chaque page. Elle ne suffit pas au
// webtoon : ce que la vue pose n est pas une page mais une tuile, et une bande
// de vingt mille pixels en porte dix. Compter les vues vivantes en pages
// donnerait un budget faux d un facteur dix, precisement sur les chapitres ou il
// compte.
//
// Cette pile numerote donc les tuiles a la suite, du haut du chapitre au bas. Un
// rang de tuile est un entier, les rangs d une page se suivent, et les rangs de
// deux pages voisines se suivent aussi. Deux consequences.
//
// La fenetre de tuiles a monter est un intervalle d entiers, ce qui la rend
// directement utilisable par le pool de F040 : une vue y porte une tuile au lieu
// d une page, le recyclage ne change pas.
//
// Le budget de tuiles vivantes se calcule comme la capacite de F040, en
// cherchant le pire cas sur toute la pile, et non en supposant une bande
// moyenne. Un chapitre qui melange une couverture courte et une bande de vingt
// mille pixels n a pas la meme demande selon l endroit.
//
// Les hauteurs de tuile sont donnees en parts et non en points. La vue connait
// la hauteur d une page a la largeur de colonne choisie, la chaine d images
// connait la decoupe en pixels, et c est le rapport entre les deux qui compte.
// Passer des parts evite d avoir a refaire cette pile a chaque changement de
// largeur de colonne.
//

/// Endroit d une tuile dans le chapitre.
public struct AdresseDeTuile: Sendable, Equatable, Hashable {
    /// Page qui porte la tuile, indexee a partir de zero.
    public let page: Int

    /// Rang de la tuile dans sa page, a partir du haut.
    public let tuile: Int

    public init(page: Int, tuile: Int) {
        self.page = max(0, page)
        self.tuile = max(0, tuile)
    }
}

/// Pile des tuiles d un chapitre lu en webtoon.
public struct PileDeTuiles: Sendable, Equatable {
    /// Pile des pages sur laquelle les tuiles se posent.
    public let pile: DefilementContinu

    /// Nombre de tuiles de chaque page, dans l ordre narratif.
    public let tuilesParPage: [Int]

    /// Debut de chaque tuile dans la pile, cumule une fois pour toutes.
    private let debuts: [Double]

    /// Hauteur de chaque tuile, en points de la pile.
    private let hauteurs: [Double]

    /// Rang de la premiere tuile de chaque page.
    private let premiersRangs: [Int]

    /// Recul applique au bord bas d une fenetre avant de chercher la tuile qui
    /// s y trouve. Meme raison qu au bord bas de la pile de pages.
    private static let bordExclusif: Double = 1e-6

    /// Nombre de tuiles gardees en avance sur le defilement.
    ///
    /// La section 5.8 de DESIGN-SPEC demande une tuile prechargee. Elle entre
    /// dans le budget, donc le pool ne creera pas de vue supplementaire pour
    /// elle au moment ou le doigt descend.
    public static let tuilesEnAvance = 1

    /// Empile les tuiles d un chapitre.
    ///
    /// - Parameters:
    ///   - pile: pile des pages du chapitre, interstices compris.
    ///   - partsParPage: hauteur relative de chaque tuile, page par page. Une
    ///     page sans part declaree compte pour une tuile unique, ce qui est le
    ///     cas d une page assez courte pour tenir dans une seule texture.
    public init(pile: DefilementContinu, partsParPage: [[Double]]) {
        var debuts: [Double] = []
        var hauteurs: [Double] = []
        var premiersRangs: [Int] = []
        var tuilesParPage: [Int] = []

        for page in 0..<pile.nombreDePages {
            let parts = Self.partsRetenues(partsParPage.indices.contains(page) ? partsParPage[page] : [])
            let hauteurDeLaPage = pile.hauteur(dePage: page)
            let total = parts.reduce(0, +)

            premiersRangs.append(debuts.count)
            tuilesParPage.append(parts.count)

            var pose = pile.debut(dePage: page)

            for (rang, part) in parts.enumerated() {
                // La derniere tuile prend le reste plutot que sa part calculee.
                // Un arrondi repete sur dix tuiles decalerait la page suivante,
                // et le decalage grandirait a chaque page du chapitre.
                let hauteur = rang == parts.count - 1
                    ? pile.debut(dePage: page) + hauteurDeLaPage - pose
                    : hauteurDeLaPage * part / total

                debuts.append(pose)
                hauteurs.append(max(0, hauteur))
                pose += hauteur
            }
        }

        self.pile = pile
        self.tuilesParPage = tuilesParPage
        self.debuts = debuts
        self.hauteurs = hauteurs
        self.premiersRangs = premiersRangs
    }

    /// Empile les tuiles d un chapitre a partir de leur decoupe en pixels.
    ///
    /// - Parameters:
    ///   - pile: pile des pages du chapitre.
    ///   - decoupes: decoupes rendues par la chaine d images, page par page. Les
    ///     hauteurs en pixels servent de parts, ce qui donne des tuiles
    ///     proportionnelles a ce que la vue posera reellement.
    public init(pile: DefilementContinu, decoupes: [[DecoupeDeTuile]]) {
        self.init(
            pile: pile,
            partsParPage: decoupes.map { $0.map { Double($0.taille.hauteur) } }
        )
    }

    /// Nombre de tuiles du chapitre entier.
    public var nombreDeTuiles: Int {
        debuts.count
    }

    /// Vrai quand le chapitre ne porte aucune tuile.
    public var estVide: Bool {
        debuts.isEmpty
    }

    /// Rang de cette tuile dans le chapitre, nul hors du chapitre.
    public func rang(page: Int, tuile: Int) -> Int? {
        guard premiersRangs.indices.contains(page),
              tuile >= 0,
              tuile < tuilesParPage[page]
        else {
            return nil
        }

        return premiersRangs[page] + tuile
    }

    /// Adresse de la tuile de ce rang, nulle hors du chapitre.
    public func adresse(deRang rang: Int) -> AdresseDeTuile? {
        guard debuts.indices.contains(rang) else { return nil }

        let page = pageDuRang(rang)

        return AdresseDeTuile(page: page, tuile: rang - premiersRangs[page])
    }

    /// Debut d une tuile dans la pile, nul hors du chapitre.
    public func debut(deRang rang: Int) -> Double {
        guard debuts.indices.contains(rang) else { return 0 }

        return debuts[rang]
    }

    /// Hauteur d une tuile, nulle hors du chapitre.
    public func hauteur(deRang rang: Int) -> Double {
        guard hauteurs.indices.contains(rang) else { return 0 }

        return hauteurs[rang]
    }

    /// Tuiles qui touchent la fenetre affichee.
    ///
    /// - Parameters:
    ///   - decalage: position du bord haut de la fenetre dans la pile.
    ///   - hauteurDeLaFenetre: hauteur visible, en points.
    public func tuilesVisibles(auDecalage decalage: Double, hauteurDeLaFenetre: Double) -> Range<Int> {
        guard estVide == false else { return 0..<0 }

        let haut = min(max(decalage, 0), pile.hauteurTotale)
        let bas = max(haut, haut + max(0, hauteurDeLaFenetre) - Self.bordExclusif)

        let premiere = tuileCommencantAvant(haut)
        let derniere = max(premiere, tuileCommencantAvant(bas))

        return premiere..<(derniere + 1)
    }

    /// Nombre de tuiles a garder vivantes pour ce chapitre.
    ///
    /// C est le plus grand nombre de tuiles simultanement visibles sur toute la
    /// pile, augmente de la tuile prechargee. Le budget ne depend donc ni de la
    /// longueur du chapitre ni de l endroit ou l on se trouve : c est ce qui en
    /// fait un budget et non une moyenne.
    public func budgetDeTuiles(hauteurDeLaFenetre: Double, enAvance: Int = tuilesEnAvance) -> Int {
        guard estVide == false else { return 0 }

        let fenetre = max(0, hauteurDeLaFenetre)
        var maximum = 1
        var derniere = 0

        for premiere in debuts.indices {
            let limite = debuts[premiere] + hauteurs[premiere] + fenetre

            derniere = max(derniere, premiere)
            while derniere + 1 < nombreDeTuiles, debuts[derniere + 1] < limite {
                derniere += 1
            }

            maximum = max(maximum, derniere - premiere + 1)
        }

        return maximum + max(0, enAvance)
    }

    /// Fenetre de tuiles a garder montees pour ce decalage.
    ///
    /// La fenetre porte toujours le meme nombre de tuiles tant que le chapitre
    /// en compte assez, et elle contient toujours toutes les tuiles visibles.
    ///
    /// La marge se pose devant et non derriere, contrairement a la fenetre de
    /// pages de F040 : la section 5.8 demande une tuile en avance, et un retour
    /// en arriere d une tuile ramene de toute facon la tuile precedente dans la
    /// fenetre avant qu elle ne soit visible.
    public func fenetreDeTuiles(
        auDecalage decalage: Double,
        hauteurDeLaFenetre: Double,
        budget: Int
    ) -> Range<Int> {
        guard estVide == false, budget > 0 else { return 0..<0 }

        let largeur = min(budget, nombreDeTuiles)
        let visibles = tuilesVisibles(auDecalage: decalage, hauteurDeLaFenetre: hauteurDeLaFenetre)
        let debut = min(visibles.lowerBound, nombreDeTuiles - largeur)

        return debut..<(debut + largeur)
    }

    /// Page qui porte ce rang, par dichotomie sur les premiers rangs.
    private func pageDuRang(_ rang: Int) -> Int {
        var bas = 0
        var haut = premiersRangs.count - 1

        while bas < haut {
            let milieu = (bas + haut + 1) / 2

            if premiersRangs[milieu] <= rang {
                bas = milieu
            } else {
                haut = milieu - 1
            }
        }

        return bas
    }

    /// Derniere tuile dont le debut precede ce decalage, par dichotomie.
    private func tuileCommencantAvant(_ decalage: Double) -> Int {
        var bas = 0
        var haut = nombreDeTuiles - 1

        while bas < haut {
            let milieu = (bas + haut + 1) / 2

            if debuts[milieu] <= decalage {
                bas = milieu
            } else {
                haut = milieu - 1
            }
        }

        return bas
    }

    /// Parts d une page, ramenees a une liste utilisable.
    ///
    /// Une page sans part, ou dont les parts sont toutes nulles, compte pour une
    /// tuile unique. Une part negative est ramenee a zero, ce qui la rend
    /// invisible sans deranger le cumul des suivantes.
    private static func partsRetenues(_ parts: [Double]) -> [Double] {
        let retenues = parts.map { max(0, $0) }

        guard retenues.isEmpty == false, retenues.reduce(0, +) > 0 else {
            return [1]
        }

        return retenues
    }
}
