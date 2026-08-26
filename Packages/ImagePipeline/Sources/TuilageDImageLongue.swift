import Core
import CoreGraphics

//
// TuilageDImageLongue
//
// Decoupe d une bande de webtoon en tuiles, section 7.3 du cahier de
// developpement.
//
// Une planche de webtoon monte couramment a vingt mille pixels de haut. La
// limite de texture de Metal est de 16384 pixels, et le depassement ne leve
// rien : la texture n est pas creee, la bande reste noire. C est la quatrieme
// erreur du cahier, celle qui frappe les chapitres les plus lus parce que ce
// sont les plus longs.
//
// La regle est donc posee dans le type et non dans la vue : une tuile fait au
// plus 2048 pixels de haut, huit fois sous la limite, et la vue ne pose jamais
// autre chose qu une tuile. Le rendu ne peut plus echouer par la hauteur, quelle
// que soit la bande.
//
// Trois proprietes tiennent la decoupe.
//
// Les tuiles recouvrent la bande exactement. La tuile `n` commence ou la tuile
// `n - 1` finit, la derniere finit sur la derniere ligne. Une ligne prise deux
// fois ferait begayer le dessin au raccord, une ligne perdue le ferait sauter,
// et les deux se voient d autant mieux que le doigt defile lentement.
//
// Les tuiles sont numerotees du haut vers le bas, comme la bande se lit. Le sens
// de lecture n entre pas dans ce calcul : le mode vertical empile du haut vers
// le bas dans les trois sens, voir MiseEnPage.sensImpose.
//
// La largeur n est jamais coupee. Une bande ajustee a la colonne du lecteur est
// toujours plus etroite que la limite de texture, et c est le decodage qui le
// garantit en bornant la largeur demandee. Couper aussi en largeur ajouterait
// une grille et des raccords verticaux pour un cas qui n existe pas.
//

/// Portion de lignes qu une tuile preleve dans la bande.
public struct DecoupeDeTuile: Sendable, Hashable {
    /// Rang de la tuile dans la bande, a partir du haut.
    public let index: Int

    /// Ligne du premier pixel preleve, comptee depuis le haut de la bande.
    public let origineY: Int

    /// Dimensions de la tuile.
    public let taille: TailleEnPixels

    public init(index: Int, origineY: Int, taille: TailleEnPixels) {
        self.index = max(0, index)
        self.origineY = max(0, origineY)
        self.taille = taille
    }

    /// Lignes de la bande que cette tuile emporte.
    public var lignes: Range<Int> {
        origineY..<(origineY + taille.hauteur)
    }
}

/// Decoupe d une bande longue en tuiles affichables.
public struct TuilageDImageLongue: Sendable, Hashable {
    /// Hauteur maximale d une tuile, section 7.3.
    public static let hauteurMaximaleDeTuile = 2048

    /// Plus grand cote qu une texture Metal accepte.
    ///
    /// Au dela, la texture n est pas creee et le rendu echoue en silence.
    public static let limiteDeTexture = 16384

    /// Hauteur des tuiles pleines, la derniere prenant le reste.
    public let hauteurDeTuile: Int

    /// Construit un tuilage, en refusant une tuile plus haute que la regle.
    ///
    /// - Parameter hauteurDeTuile: hauteur voulue, ramenee entre un pixel et la
    ///   hauteur maximale de la section 7.3. Une tuile plus haute repasserait un
    ///   jour sous la limite de texture d un appareil plus modeste.
    public init(hauteurDeTuile: Int = TuilageDImageLongue.hauteurMaximaleDeTuile) {
        self.hauteurDeTuile = min(max(1, hauteurDeTuile), Self.hauteurMaximaleDeTuile)
    }

    /// Tuilage de la section 7.3, tuiles de 2048 pixels.
    public static let parDefaut = TuilageDImageLongue()

    /// Vrai quand une image de cette taille tient dans une seule texture.
    public static func tientDansUneTexture(_ taille: TailleEnPixels) -> Bool {
        taille.estVide == false
            && taille.largeur <= limiteDeTexture
            && taille.hauteur <= limiteDeTexture
    }

    /// Vrai quand la bande demande plus d une tuile.
    public func doitTuiler(_ taille: TailleEnPixels) -> Bool {
        taille.estVide == false && taille.hauteur > hauteurDeTuile
    }

    /// Nombre de tuiles que cette bande produit, zero quand elle est vide.
    public func nombreDeTuiles(pour taille: TailleEnPixels) -> Int {
        guard taille.estVide == false else { return 0 }

        return (taille.hauteur + hauteurDeTuile - 1) / hauteurDeTuile
    }

    /// Decoupes de la bande, du haut vers le bas.
    ///
    /// Une bande assez courte rend une tuile unique qui la couvre entierement,
    /// et non une liste vide. La couche vue pose alors toujours des tuiles, sans
    /// avoir a tenir deux chemins de rendu selon la longueur de la page.
    public func decoupes(de taille: TailleEnPixels) -> [DecoupeDeTuile] {
        guard taille.estVide == false else { return [] }

        var decoupes: [DecoupeDeTuile] = []
        decoupes.reserveCapacity(nombreDeTuiles(pour: taille))

        var origineY = 0
        var index = 0

        while origineY < taille.hauteur {
            let hauteur = min(hauteurDeTuile, taille.hauteur - origineY)

            decoupes.append(DecoupeDeTuile(
                index: index,
                origineY: origineY,
                taille: TailleEnPixels(largeur: taille.largeur, hauteur: hauteur)
            ))

            origineY += hauteur
            index += 1
        }

        return decoupes
    }

    /// Tuile de rang donne, extraite d une bande deja decodee.
    ///
    /// - Returns: la tuile redessinee dans une matrice a elle, ou nil quand le
    ///   rang sort de la bande ou que le systeme refuse la matrice.
    public func tuile(_ index: Int, de page: ImageDePage) -> ImageDePage? {
        let taille = TailleEnPixels(largeur: page.image.width, hauteur: page.image.height)
        let decoupes = decoupes(de: taille)

        guard decoupes.indices.contains(index) else { return nil }

        return appliquer(decoupes[index], a: page)
    }

    /// Toutes les tuiles de la bande, dans l ordre de lecture.
    ///
    /// - Returns: une liste vide des qu une seule tuile manque. Une bande a
    ///   trous afficherait un morceau de dessin sans que rien ne le signale,
    ///   alors qu une liste vide laisse l appelant poser une page de
    ///   remplacement qui nomme la cause.
    public func tuiles(de page: ImageDePage) -> [ImageDePage] {
        let taille = TailleEnPixels(largeur: page.image.width, hauteur: page.image.height)
        let decoupes = decoupes(de: taille)
        let tuiles = decoupes.compactMap { appliquer($0, a: page) }

        guard tuiles.count == decoupes.count else { return [] }

        return tuiles
    }

    /// Extrait une tuile, redessinee dans une matrice a elle.
    ///
    /// `cropping` seul rendrait une image qui garde la bande entiere vivante
    /// derriere elle. Le budget de tuiles vivantes ne mesurerait alors plus
    /// rien, puisque dix tuiles decoupees dans une bande de trente mega octets
    /// tiendraient toujours ces trente mega octets, et la seule chose recyclee
    /// serait la comptabilite.
    ///
    /// Le redessin se fait a l echelle un pour un. Aucun pixel n est interpole,
    /// donc le raccord entre deux tuiles porte exactement les lignes de la
    /// bande.
    private func appliquer(_ decoupe: DecoupeDeTuile, a page: ImageDePage) -> ImageDePage? {
        guard decoupe.taille.estVide == false,
              decoupe.taille.largeur <= page.image.width,
              decoupe.lignes.upperBound <= page.image.height,
              let coupee = page.image.cropping(
                  to: CGRect(
                      x: 0,
                      y: decoupe.origineY,
                      width: decoupe.taille.largeur,
                      height: decoupe.taille.hauteur
                  )
              ),
              let materialisee = DecodeurDePage.materialiser(coupee)
        else {
            return nil
        }

        return ImageDePage(
            image: materialisee,
            tailleDOrigine: page.tailleDOrigine,
            tailleDecodee: TailleEnPixels(largeur: materialisee.width, hauteur: materialisee.height),
            niveau: page.niveau
        )
    }
}
