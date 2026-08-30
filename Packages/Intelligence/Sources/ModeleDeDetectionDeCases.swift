import Core

//
// ModeleDeDetectionDeCases
//
// Ce que la detection de cases attend d un modele, et rien de plus.
//
// Le protocole ne ressemble pas a ceux des deux autres traitements, et la
// difference n est pas de forme. La surelevation et la colorisation entrent en
// pixels et sortent en pixels, elles se decoupent donc en tuiles et se
// recomposent. Un detecteur entre en pixels et sort en geometrie : le decouper
// en tuiles couperait les cases elles memes, et il faudrait ensuite recoller
// les moities de cadre d une tuile a l autre, ce qui est un second probleme plus
// dur que le premier. Le detecteur voit donc la planche entiere, une seule fois.
//
// La sortie est en parts de la planche et non en pixels. Le detecteur travaille
// sur la page decodee, dont la taille depend de l ecran et du niveau de
// decodage, et une case exprimee en pixels de cette page ne voudrait plus rien
// dire des que la meme page serait redecodee pour le zoom. Les fractions
// traversent tous les niveaux de decodage sans conversion.
//
// Le protocole ne trie rien et ne filtre rien. Le seuil de confiance, la
// suppression des cadres qui se recouvrent et l ordre de lecture appartiennent a
// l acteur, qui les applique de la meme facon quel que soit le reseau installe.
// Un modele qui trierait lui meme rendrait ces regles invisibles et
// intestables.
//

/// Modele qui rend les cases d une planche.
public protocol ModeleDeDetectionDeCases: Sendable {
    /// Nom du modele, cle de sa fiche de licence et de ses cles de cache.
    var identifiant: String { get }

    /// Detecte les cases d une planche.
    ///
    /// - Parameter planche: page decodee, en pixels.
    /// - Returns: les cases trouvees, en parts de la planche, dans un ordre
    ///   quelconque et sans filtrage.
    /// - Throws: `ErreurDeTraitementIA` quand le modele refuse l entree ou ne
    ///   rend rien d exploitable.
    func detecter(_ planche: MatriceDePixels) throws -> [CaseDePage]
}
