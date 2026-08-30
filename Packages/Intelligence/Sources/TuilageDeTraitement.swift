import Core

//
// TuilageDeTraitement
//
// Decoupe d une page en tuiles de 256 avec recouvrement de 16, exactement ce
// que la section 8 impose au modele de surelevation, et que la colorisation
// reprend telle quelle avec le cote de tuile de son propre modele.
//
// Deux raisons a ce decoupage, et elles ne se remplacent pas.
//
// La premiere est la memoire. Un reseau de convolution tient en memoire ses
// activations intermediaires, qui pesent plusieurs dizaines de fois l entree.
// Lui donner une page entiere reviendrait a demander quelques gigaoctets sur un
// appareil qui n en a pas, et le systeme terminerait l application. Une tuile de
// 256 borne cette depense a une valeur connue, quelle que soit la planche.
//
// La seconde est le raccord, et c est elle qui dicte le recouvrement. Un reseau
// de convolution n a pas la meme sortie au bord de son entree qu au milieu :
// faute de voisinage, il extrapole. Deux tuiles posees bord a bord montreraient
// donc deux extrapolations differentes de part et d autre d une meme ligne, et
// cette ligne se verrait sur toute la hauteur de la planche. Les seize pixels de
// recouvrement existent pour que la recomposition puisse fondre l une dans
// l autre au lieu de les juxtaposer.
//
// Trois proprietes tiennent la decoupe.
//
// Toutes les tuiles font exactement le cote demande. Le modele converti annonce
// une entree de taille fixe, une tuile plus courte au bord le ferait echouer. La
// derniere tuile d une ligne ou d une colonne n est donc pas raccourcie, elle
// est ramenee contre le bord, ce qui lui donne un recouvrement plus large que
// seize et jamais plus etroit. Une page plus petite qu une tuile est completee
// par recopie du bord avant d etre tuilee, voir `MatriceDePixels.remplie`.
//
// Les tuiles couvrent la page entiere. La reunion des tuiles est exactement la
// page, sans trou, ce que la suite de tests verifie sur des dizaines de tailles.
//
// Les tuiles sont numerotees ligne par ligne, de gauche a droite puis du haut
// vers le bas. La recomposition s appuie sur cet ordre pour ne tenir en memoire
// qu une bande de sortie a la fois, au lieu de la page entiere en flottants.
//

/// Position d une tuile dans la page a traiter.
public struct DecoupeDeTraitement: Sendable, Hashable {
    /// Rang de la tuile, ligne par ligne depuis le coin superieur gauche.
    public let index: Int

    /// Rang de la colonne de tuiles.
    public let colonne: Int

    /// Rang de la ligne de tuiles.
    public let ligne: Int

    /// Abscisse du premier pixel preleve.
    public let origineX: Int

    /// Ordonnee du premier pixel preleve, comptee depuis le haut.
    public let origineY: Int

    /// Dimensions de la tuile, toujours le cote du tuilage.
    public let taille: TailleEnPixels

    /// Vrai quand le bord gauche de la tuile est celui de la page.
    public let contreLeBordGauche: Bool

    /// Vrai quand le bord droit de la tuile est celui de la page.
    public let contreLeBordDroit: Bool

    /// Vrai quand le bord haut de la tuile est celui de la page.
    public let contreLeBordHaut: Bool

    /// Vrai quand le bord bas de la tuile est celui de la page.
    public let contreLeBordBas: Bool

    /// Colonnes de la page que cette tuile emporte.
    public var colonnes: Range<Int> {
        origineX..<(origineX + taille.largeur)
    }

    /// Lignes de la page que cette tuile emporte.
    public var lignes: Range<Int> {
        origineY..<(origineY + taille.hauteur)
    }
}

/// Decoupe d une page en tuiles carrees qui se recouvrent.
public struct TuilageDeTraitement: Sendable, Hashable {
    /// Cote d une tuile, section 8 du cahier de developpement.
    public static let coteDeTuile = 256

    /// Recouvrement entre deux tuiles voisines, section 8.
    public static let recouvrementDeTuile = 16

    /// Cote d une tuile carree.
    public let cote: Int

    /// Nombre de pixels partages par deux tuiles voisines.
    public let recouvrement: Int

    /// Construit un tuilage, en ramenant chaque valeur dans son domaine.
    ///
    /// Le recouvrement est borne sous le cote : un recouvrement egal au cote
    /// donnerait un pas nul, donc une infinite de tuiles au meme endroit.
    public init(
        cote: Int = TuilageDeTraitement.coteDeTuile,
        recouvrement: Int = TuilageDeTraitement.recouvrementDeTuile
    ) {
        let coteRetenu = max(2, cote)

        self.cote = coteRetenu
        self.recouvrement = min(max(0, recouvrement), coteRetenu - 1)
    }

    /// Tuilage de la section 8 : tuiles de 256, recouvrement de 16.
    public static let parDefaut = TuilageDeTraitement()

    /// Distance entre les origines de deux tuiles voisines.
    public var pas: Int {
        cote - recouvrement
    }

    /// Dimensions auxquelles une page doit etre completee avant d etre tuilee.
    ///
    /// Une page plus petite qu une tuile dans une dimension est agrandie a la
    /// tuile dans cette dimension, et laissee telle quelle dans l autre.
    public func tailleRemplie(pour taille: TailleEnPixels) -> TailleEnPixels {
        TailleEnPixels(largeur: max(taille.largeur, cote), hauteur: max(taille.hauteur, cote))
    }

    /// Origines des tuiles sur un axe, de la premiere a la derniere.
    ///
    /// La derniere origine est ramenee contre le bord, ce qui garantit la
    /// couverture complete sans jamais raccourcir la tuile.
    public func origines(pour longueur: Int) -> [Int] {
        guard longueur > cote else { return [0] }

        var origines: [Int] = []
        var origine = 0

        while origine + cote < longueur {
            origines.append(origine)
            origine += pas
        }

        origines.append(longueur - cote)

        return origines
    }

    /// Nombre de tuiles que cette page produit.
    public func nombreDeTuiles(pour taille: TailleEnPixels) -> Int {
        guard taille.estVide == false else { return 0 }

        let remplie = tailleRemplie(pour: taille)

        return origines(pour: remplie.largeur).count * origines(pour: remplie.hauteur).count
    }

    /// Vrai quand cette page demande plus d une tuile.
    public func doitTuiler(_ taille: TailleEnPixels) -> Bool {
        nombreDeTuiles(pour: taille) > 1
    }

    /// Decoupes de la page, ligne de tuiles par ligne de tuiles.
    ///
    /// La page doit avoir ete completee au prealable, sans quoi une dimension
    /// plus petite que le cote donnerait des tuiles qui debordent. La taille
    /// nulle rend une liste vide plutot qu une tuile de remplissage.
    public func decoupes(de taille: TailleEnPixels) -> [DecoupeDeTraitement] {
        guard taille.estVide == false else { return [] }

        let remplie = tailleRemplie(pour: taille)
        let abscisses = origines(pour: remplie.largeur)
        let ordonnees = origines(pour: remplie.hauteur)
        let tuile = TailleEnPixels(largeur: cote, hauteur: cote)

        var decoupes: [DecoupeDeTraitement] = []
        decoupes.reserveCapacity(abscisses.count * ordonnees.count)

        for (rangDeLigne, origineY) in ordonnees.enumerated() {
            for (rangDeColonne, origineX) in abscisses.enumerated() {
                decoupes.append(DecoupeDeTraitement(
                    index: decoupes.count,
                    colonne: rangDeColonne,
                    ligne: rangDeLigne,
                    origineX: origineX,
                    origineY: origineY,
                    taille: tuile,
                    contreLeBordGauche: rangDeColonne == 0,
                    contreLeBordDroit: rangDeColonne == abscisses.count - 1,
                    contreLeBordHaut: rangDeLigne == 0,
                    contreLeBordBas: rangDeLigne == ordonnees.count - 1
                ))
            }
        }

        return decoupes
    }
}
