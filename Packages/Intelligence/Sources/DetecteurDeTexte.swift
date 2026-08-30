import Core

//
// DetecteurDeTexte
//
// Ce que la traduction attend d une detection de texte, et rien de plus.
//
// Le protocole ressemble a celui du detecteur de cases plutot qu a ceux de la
// surelevation et de la colorisation, et pour la meme raison : il entre en
// pixels et sort en geometrie. Une planche decoupee en tuiles couperait les
// bulles en deux, et il faudrait ensuite recoller les moities de phrase, ce qui
// est un probleme plus dur que celui qu on croyait resoudre.
//
// La sortie est en parts de la planche, comme partout ailleurs dans le projet.
// La page decodee change de taille avec l ecran et avec le niveau de decodage,
// et une bulle exprimee en pixels de cette page ne voudrait plus rien dire des
// que la meme page serait redecodee pour un zoom.
//
// Le protocole ne trie rien, ne filtre rien et ne traduit rien. Le seuil de
// confiance, la fusion des cadres qui se recouvrent et l ordre de lecture
// appartiennent a l acteur, qui les applique de la meme facon quelle que soit la
// detection installee.
//

/// Detection qui rend les bulles de texte d une planche.
public protocol DetecteurDeTexte: Sendable {
    /// Nom de la detection, qui entre dans les cles de cache.
    ///
    /// Il doit changer des que la detection change, sans quoi une mise a jour
    /// ferait ressortir du cache des bulles trouvees par la version precedente.
    var identifiant: String { get }

    /// Repere les bulles d une planche et lit leur texte.
    ///
    /// - Parameter planche: page decodee, en pixels.
    /// - Returns: les bulles trouvees, en parts de la planche, dans un ordre
    ///   quelconque et sans filtrage. Une suite vide quand la planche ne porte
    ///   aucun texte lisible, ce qui n est pas un echec.
    /// - Throws: `ErreurDeTraduction` quand la detection ne peut pas aboutir.
    func bulles(_ planche: MatriceDePixels) throws -> [BulleDeTexte]
}
